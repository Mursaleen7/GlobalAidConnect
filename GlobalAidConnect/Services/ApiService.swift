import Foundation
import Combine
import SwiftUI
import AVFoundation
import Speech
import CoreLocation

// MARK: - API Service
class ApiService: ObservableObject {
    // Published properties for real-time data
    @Published var activeCrises: [Crisis]? = nil
    @Published var recentUpdates: [Update]? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Published properties for AI responses
    @Published var isProcessingAI: Bool = false
    @Published var currentConversation: [AIMessage] = []
    @Published var aiErrorMessage: String? = nil
    
    // Published properties for emergency reporting
    @Published var currentEmergency: EmergencyReport? = nil
    @Published var emergencyAnalysis: EmergencyAnalysisResponse? = nil
    @Published var isProcessingEmergency: Bool = false
    @Published var emergencyError: String? = nil
    @Published var recognizedSpeech: String = ""
    @Published var isRecognizingSpeech: Bool = false
    
    // Published properties for situation analysis
    @Published var situationAnalysis: SituationAnalysis? = nil
    @Published var isProcessingSituation: Bool = false
    @Published var situationError: String? = nil
    
    // Published properties for emergency messaging
    @Published var emergencyMessage: EmergencyMessage? = nil
    @Published var emergencyServiceResponse: EmergencyServiceResponse? = nil
    @Published var isMessageSending: Bool = false
    @Published var messageStatus: EmergencyMessagingService.MessageStatus? = nil
    
    // Speech recognition properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // NASA EONET API endpoint (no API key needed)
    private let baseURL = "https://eonet.gsfc.nasa.gov/api/v3"
    
    // For tracking processed updates
    private var processedEventIds = Set<String>()
    
    // Cancellables set for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSpeechRecognizer()
        setupSubscriptions()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    private func setupSubscriptions() {
        // Subscribe to emergency message status updates
        EmergencyMessagingService.shared.messageSendingStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.messageStatus = status
                
                switch status {
                case .preparing, .sending:
                    self?.isMessageSending = true
                case .delivered, .failed:
                    self?.isMessageSending = false
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func fetchInitialData() {
        Task {
            await fetchActiveCrises()
            await generateRecentUpdates()
        }
    }
    
    func fetchActiveCrises() async {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        let endpoint = "/events?status=open&days=30&limit=20"
        
        do {
            guard let url = URL(string: baseURL + endpoint) else {
                throw NSError(domain: "InvalidURL", code: -1, userInfo: nil)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvalidResponse", code: -2, userInfo: nil)
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                let decoder = JSONDecoder()
                let eonetResponse = try decoder.decode(EONETResponse.self, from: data)
                
                // Map NASA EONET events to our Crisis model
                let crises = mapEONETEventsToCrises(eonetResponse.events)
                
                DispatchQueue.main.async {
                    self.activeCrises = crises
                    self.isLoading = false
                }
            } else {
                throw NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil)
            }
        } catch {
            handleError(error: error)
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    private func mapEONETEventsToCrises(_ events: [EONETEvent]) -> [Crisis] {
        return events.compactMap { event in
            guard let latestGeometry = event.geometry.first,
                  latestGeometry.coordinates.count >= 2 else {
                return nil
            }
            
            // Get coordinates (note: EONET uses [longitude, latitude] format)
            let longitude = latestGeometry.coordinates[0]
            let latitude = latestGeometry.coordinates[1]
            
            // Get event category for severity estimation
            let categoryTitle = event.categories.first?.title ?? "Unknown"
            let severity = calculateSeverity(category: categoryTitle, event: event)
            
            // Get approximate location name based on coordinates
            let location = getLocationName(latitude: latitude, longitude: longitude, categoryTitle: categoryTitle)
            
            // Parse date
            let dateFormatter = ISO8601DateFormatter()
            let startDate = dateFormatter.date(from: latestGeometry.date) ?? Date()
            
            // Create description combining event info
            let description = event.description ?? "A \(categoryTitle.lowercased()) event has been reported in this area. Monitor local authorities for more information."
            
            return Crisis(
                id: event.id,
                name: event.title,
                location: location,
                severity: severity,
                startDate: startDate,
                description: description,
                affectedPopulation: estimateAffectedPopulation(category: categoryTitle, coordinates: Coordinates(latitude: latitude, longitude: longitude)),
                coordinatorContact: "info@globalaidconnect.org",
                coordinates: Coordinates(latitude: latitude, longitude: longitude)
            )
        }
    }
    
    private func calculateSeverity(category: String, event: EONETEvent) -> Int {
        // Assign severity based on event category and other factors
        switch category {
        case "Volcanoes", "Severe Storms", "Wildfires" where event.title.contains("Extreme"):
            return 5
        case "Wildfires", "Floods", "Earthquakes":
            return 4
        case "Drought", "Landslides":
            return 3
        case "Sea and Lake Ice", "Snow":
            return 2
        default:
            return 1
        }
    }
    
    private func getLocationName(latitude: Double, longitude: Double, categoryTitle: String) -> String {
        // In a real app, you would use reverse geocoding here
        // For now, we'll just create an approximate location string based on coordinates
        let latDirection = latitude >= 0 ? "N" : "S"
        let longDirection = longitude >= 0 ? "E" : "W"
        let formattedLat = String(format: "%.1f", abs(latitude))
        let formattedLong = String(format: "%.1f", abs(longitude))
        
        // Find continent/region based on coordinates (very simplified)
        let region = getApproximateRegion(latitude: latitude, longitude: longitude)
        
        return "\(region), \(formattedLat)°\(latDirection) \(formattedLong)°\(longDirection)"
    }
    
    private func getApproximateRegion(latitude: Double, longitude: Double) -> String {
        // Extremely simplified region determination
        if latitude > 30 && longitude > -30 && longitude < 60 {
            return "Europe"
        } else if latitude > 10 && longitude > 60 && longitude < 150 {
            return "Asia"
        } else if latitude < 0 && longitude > 110 && longitude < 180 {
            return "Australia"
        } else if latitude > 10 && longitude > -150 && longitude < -50 {
            return "North America"
        } else if latitude < 10 && latitude > -60 && longitude > -90 && longitude < -30 {
            return "South America"
        } else if latitude < 40 && latitude > -40 && longitude > -20 && longitude < 60 {
            return "Africa"
        } else {
            return "Ocean Region"
        }
    }
    
    private func estimateAffectedPopulation(category: String, coordinates: Coordinates) -> Int {
        // This would ideally use population density data
        // For now, use a simple estimation based on category and random variance
        
        let basePeople: Int
        switch category {
        case "Wildfires":
            basePeople = 5000 + Int.random(in: 0...10000)
        case "Volcanoes":
            basePeople = 15000 + Int.random(in: 0...50000)
        case "Severe Storms", "Floods":
            basePeople = 25000 + Int.random(in: 0...75000)
        case "Earthquakes":
            basePeople = 30000 + Int.random(in: 0...100000)
        case "Drought":
            basePeople = 50000 + Int.random(in: 0...150000)
        default:
            basePeople = 1000 + Int.random(in: 0...5000)
        }
        
        return basePeople
    }
    
    // Generate updates based on active crises
    func generateRecentUpdates() async {
        guard let crises = activeCrises, !crises.isEmpty else {
            // If no crises available, wait for them to load first
            if activeCrises == nil {
                await fetchActiveCrises()
                if let loadedCrises = activeCrises, !loadedCrises.isEmpty {
                    await generateRecentUpdatesFromCrises(loadedCrises)
                }
            }
            return
        }
        
        await generateRecentUpdatesFromCrises(crises)
    }
    
    private func generateRecentUpdatesFromCrises(_ crises: [Crisis]) async {
        // Get the 5 most recent crises based on startDate
        let recentCrises = Array(crises.sorted(by: { $0.startDate > $1.startDate }).prefix(5))
        
        var updates: [Update] = []
        
        for (index, crisis) in recentCrises.enumerated() {
            // Create 1-2 updates per crisis
            let updateCount = index < 2 ? 2 : 1
            
            for i in 0..<updateCount {
                let hoursAgo = Double(i * 4 + Int.random(in: 1...3))
                let timestamp = Date().addingTimeInterval(-3600 * hoursAgo)
                
                updates.append(Update(
                    id: "u\(UUID().uuidString.prefix(8))",
                    crisisId: crisis.id,
                    title: generateUpdateTitle(for: crisis, updateNumber: i),
                    content: generateUpdateContent(for: crisis, updateNumber: i),
                    timestamp: timestamp,
                    source: generateSource(for: crisis)
                ))
            }
        }
        
        // Sort by timestamp (most recent first)
        let sortedUpdates = updates.sorted(by: { $0.timestamp > $1.timestamp })
        
        DispatchQueue.main.async {
            self.recentUpdates = sortedUpdates
        }
    }
    
    private func generateUpdateTitle(for crisis: Crisis, updateNumber: Int) -> String {
        let titles = [
            ["Initial Assessment", "Situation Report", "Emergency Declaration"],
            ["Response Underway", "Aid Deployment", "Rescue Operations"],
            ["Status Update", "Situation Developing", "Continued Monitoring"]
        ]
        
        if updateNumber < titles.count {
            return titles[updateNumber][Int.random(in: 0..<titles[updateNumber].count)]
        } else {
            return "Ongoing Response"
        }
    }
    
    private func generateUpdateContent(for crisis: Crisis, updateNumber: Int) -> String {
        switch updateNumber {
        case 0:
            return "Initial assessment of the \(crisis.name.lowercased()) shows affected area of approximately \(Int.random(in: 5...50)) square kilometers. Local authorities are coordinating emergency response."
        case 1:
            return "Relief supplies being deployed to \(crisis.location). \(Int.random(in: 3...20)) emergency response teams active in the area. Local shelters established for displaced residents."
        default:
            return "Ongoing monitoring of \(crisis.name.lowercased()) continues. Weather conditions \(["improving", "stable", "worsening"][Int.random(in: 0...2)]) which may affect response efforts."
        }
    }
    
    private func generateSource(for crisis: Crisis) -> String {
        let sources = [
            "Emergency Response Team",
            "Global Aid Network",
            "Regional Coordination Center",
            "Humanitarian Aid Coalition",
            "Disaster Assessment Unit"
        ]
        
        return sources[Int.random(in: 0..<sources.count)]
    }
    
    /// Analyzes emergency situation text using AI to extract key information and generate structured analysis
    func analyzeEmergencySituation(
        inputText: String,
        location: CLLocationCoordinate2D?,
        useClaudeAI: Bool = true
    ) async -> SituationAnalysis? {
        
        // Set processing status
        DispatchQueue.main.async {
            self.isProcessingSituation = true
            self.situationError = nil
        }
        
        defer {
            DispatchQueue.main.async {
                self.isProcessingSituation = false
            }
        }
        
        do {
            // Prepare location context for the AI
            var locationContext = "Unknown location"
            if let location = location {
                locationContext = "Location coordinates: \(location.latitude), \(location.longitude)"
                
                // In a real implementation, we would do reverse geocoding here
                // For now, use our simplified region detection
                let region = getApproximateRegion(latitude: location.latitude, longitude: location.longitude)
                locationContext += " (approximately in \(region))"
            }
            
            // Construct prompt for the AI
            let prompt = """
            EMERGENCY SITUATION ANALYSIS:
            
            Emergency description: \(inputText)
            \(locationContext)
            
            Based on the above information, provide a structured analysis of this emergency situation.
            Analyze the type of emergency, severity (1-5 scale), urgency level (immediate, urgent, moderate, low),
            potential risks, recommended actions, and if possible estimate affected area radius in kilometers.
            
            Format your response as structured data that can be parsed as JSON. Example format:
            {
                "urgency": "immediate|urgent|moderate|low",
                "type": "Flooding|Fire|Medical Emergency|etc",
                "severity": 1-5,
                "locationHints": ["hint1", "hint2"],
                "recommendedActions": ["action1", "action2", "action3"],
                "potentialRisks": ["risk1", "risk2", "risk3"],
                "affectedArea": {
                    "radius": radius_in_km,
                    "estimatedPopulation": optional_population_estimate,
                    "terrainType": optional_terrain_type
                }
            }
            """
            
            // Choose AI model based on parameter
            let aiResponse: String
            if useClaudeAI {
                aiResponse = await sendMessageToClaude(
                    userMessage: prompt,
                    systemMessage: "You are an emergency response expert. Extract key information from emergency reports and provide structured analysis.",
                    parseResponse: true
                ) ?? ""
            } else {
                aiResponse = await sendMessageToGPT(
                    userMessage: prompt,
                    systemMessage: "You are an emergency response expert. Extract key information from emergency reports and provide structured analysis.",
                    parseJSON: true
                ) ?? ""
            }
            
            // Parse JSON response to create SituationAnalysis
            if let data = aiResponse.data(using: .utf8) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // Try to decode directly to SituationAnalysis
                do {
                    var analysis = try decoder.decode(SituationAnalysis.self, from: data)
                    
                    // Set timestamp to current time
                    analysis = SituationAnalysis(
                        urgency: analysis.urgency,
                        type: analysis.type,
                        severity: analysis.severity,
                        locationHints: analysis.locationHints,
                        recommendedActions: analysis.recommendedActions,
                        potentialRisks: analysis.potentialRisks,
                        affectedArea: analysis.affectedArea,
                        timestamp: Date()
                    )
                    
                    return analysis
                } catch {
                    print("Failed to parse AI response as SituationAnalysis: \(error)")
                    
                    // Fallback to manual parsing if direct decoding fails
                    // This would implement more robust JSON parsing and error handling
                    // For simplicity, we'll return nil in this implementation
                    DispatchQueue.main.async {
                        self.situationError = "Failed to analyze emergency situation: \(error.localizedDescription)"
                    }
                    return nil
                }
            }
            
            DispatchQueue.main.async {
                self.situationError = "Failed to process AI response"
            }
            return nil
            
        } catch {
            DispatchQueue.main.async {
                self.situationError = "Error analyzing emergency: \(error.localizedDescription)"
            }
            print("Emergency analysis error: \(error)")
            return nil
        }
    }

    /// Send a message to Claude AI with optional system message
    func sendMessageToClaude(
        userMessage: String,
        systemMessage: String? = nil,
        parseResponse: Bool = false
    ) async -> String? {
        
        DispatchQueue.main.async {
            self.isProcessingAI = true
            self.aiErrorMessage = nil
        }
        
        defer {
            DispatchQueue.main.async {
                self.isProcessingAI = false
            }
        }
        
        do {
            // Create message array
            var messages: [AIMessage] = []
            
            // Add system message if provided
            if let systemMsg = systemMessage {
                messages.append(AIMessage(role: "system", content: systemMsg))
            }
            
            // Add user message
            messages.append(AIMessage(role: "user", content: userMessage))
            
            // Add user message to conversation history if not in parsing mode
            if !parseResponse {
                DispatchQueue.main.async {
                    self.currentConversation.append(AIMessage(role: "user", content: userMessage))
                }
            }
            
            // Create request body
            let requestBody = ClaudeRequest(
                model: "claude-3-opus-20240229",  // Use appropriate model
                messages: messages,
                temperature: 0.0,  // Low temperature for more consistent responses
                maxTokens: 1000
            )
            
            // Convert request to JSON
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(requestBody)
            
            // Create and configure request
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("anthropic-version", forHTTPHeaderField: "anthropic-version")
            request.addValue("YOUR_API_KEY", forHTTPHeaderField: "x-api-key")  // Use environment variable in real app
            request.httpBody = jsonData
            
            // Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "ClaudeAPI", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Parse response
            let responseData = try JSONDecoder().decode(AIResponse.self, from: data)
            
            if let message = responseData.choices.first?.message {
                // If not in parsing mode, add to conversation history
                if !parseResponse {
                    DispatchQueue.main.async {
                        self.currentConversation.append(message)
                    }
                }
                
                return message.content
            }
            
            throw NSError(domain: "ClaudeAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            
        } catch {
            DispatchQueue.main.async {
                self.aiErrorMessage = "Error communicating with Claude AI: \(error.localizedDescription)"
            }
            print("Claude API error: \(error)")
            return nil
        }
    }

    /// Send a message to GPT with optional system message
    func sendMessageToGPT(
        userMessage: String,
        systemMessage: String? = nil,
        parseJSON: Bool = false
    ) async -> String? {
        
        DispatchQueue.main.async {
            self.isProcessingAI = true
            self.aiErrorMessage = nil
        }
        
        defer {
            DispatchQueue.main.async {
                self.isProcessingAI = false
            }
        }
        
        do {
            // Create message array
            var messages: [AIMessage] = []
            
            // Add system message if provided
            if let systemMsg = systemMessage {
                messages.append(AIMessage(role: "system", content: systemMsg))
            }
            
            // Add user message
            messages.append(AIMessage(role: "user", content: userMessage))
            
            // Add user message to conversation history if not in JSON parsing mode
            if !parseJSON {
                DispatchQueue.main.async {
                    self.currentConversation.append(AIMessage(role: "user", content: userMessage))
                }
            }
            
            // Configure response format if needed
            let responseFormat = parseJSON ? ResponseFormat(type: "json_object") : nil
            
            // Create request body
            let requestBody = GPTRequest(
                model: "gpt-4o",  // Use appropriate model
                messages: messages,
                temperature: 0.0,  // Low temperature for more consistent responses
                maxTokens: 1000,
                responseFormat: responseFormat
            )
            
            // Convert request to JSON
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(requestBody)
            
            // Create and configure request
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer YOUR_API_KEY", forHTTPHeaderField: "Authorization")  // Use environment variable in real app
            request.httpBody = jsonData
            
            // Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "GPTAPI", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Parse response
            let responseData = try JSONDecoder().decode(AIResponse.self, from: data)
            
            if let message = responseData.choices.first?.message {
                // If not in parsing mode, add to conversation history
                if !parseJSON {
                    DispatchQueue.main.async {
                        self.currentConversation.append(message)
                    }
                }
                
                return message.content
            }
            
            throw NSError(domain: "GPTAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            
        } catch {
            DispatchQueue.main.async {
                self.aiErrorMessage = "Error communicating with GPT: \(error.localizedDescription)"
            }
            print("GPT API error: \(error)")
            return nil
        }
    }

    /// Helper method to clear conversation history
    func clearConversation() {
        DispatchQueue.main.async {
            self.currentConversation = []
        }
    }
    
    // MARK: - Emergency Reporting Methods
    
    func submitEmergencyReport(message: String, location: CLLocationCoordinate2D?) async -> Bool {
        DispatchQueue.main.async {
            self.isProcessingEmergency = true
            self.currentEmergency = EmergencyReport(
                message: message,
                location: location,
                severity: nil,
                category: nil,
                isProcessed: false
            )
        }
        
        // First, analyze the emergency situation using AI
        if let analysis = await analyzeEmergencySituation(
            inputText: message,
            location: location,
            useClaudeAI: true
        ) {
            // Create an AI-based emergency analysis response
            let analysisResponse = EmergencyAnalysisResponse(
                severity: analysis.severity,
                category: analysis.type,
                urgency: analysis.urgency.description,
                recommendedActions: analysis.recommendedActions,
                estimatedAffectedArea: analysis.affectedArea?.radius
            )
            
            DispatchQueue.main.async {
                self.emergencyAnalysis = analysisResponse
                self.situationAnalysis = analysis // Store the full analysis
            }
            
            // Create and send the emergency message
            let emergencyMessage = await prepareEmergencyMessage(
                analysis: analysis,
                message: message,
                location: location
            )
            
            // Send the message to emergency services
            let serviceResponse = await sendEmergencyMessageToServices(emergencyMessage)
            
            DispatchQueue.main.async {
                self.isProcessingEmergency = false
            }
            
            return serviceResponse != nil
            
        } else {
            // If AI analysis fails, create a simple fallback response
            let fallbackResponse = EmergencyAnalysisResponse(
                severity: 3,
                category: "Unspecified Emergency",
                urgency: "Response Required Soon",
                recommendedActions: [
                    "Contact local emergency services",
                    "Follow safety protocols",
                    "Stay informed through official channels"
                ],
                estimatedAffectedArea: 1.0
            )
            
            DispatchQueue.main.async {
                self.emergencyAnalysis = fallbackResponse
                self.isProcessingEmergency = false
            }
            
            // Create a basic emergency message without detailed analysis
            let emergencyMessage = await prepareEmergencyMessage(
                analysis: nil,
                message: message,
                location: location
            )
            
            // Send the message to emergency services
            let serviceResponse = await sendEmergencyMessageToServices(emergencyMessage)
            
            return serviceResponse != nil
        }
    }
    
    // MARK: - Emergency Messaging Methods
    
    /// Prepares an emergency message based on AI analysis and user input
    func prepareEmergencyMessage(
        analysis: SituationAnalysis?,
        message: String,
        location: CLLocationCoordinate2D?
    ) async -> EmergencyMessage {
        // Create an emergency report from the input
        let report = EmergencyReport(
            message: message,
            location: location,
            severity: analysis?.severity,
            category: analysis?.type,
            isProcessed: false
        )
        
        // Convert coordinates to CLLocation for better handling
        let clLocation: CLLocation?
        if let location = location {
            clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        } else {
            clLocation = nil
        }
        
        // Use the EmergencyMessagingService to create a formatted message
        let emergencyMessage = EmergencyMessagingService.shared.createEmergencyMessage(
            from: analysis,
            report: report,
            location: clLocation
        )
        
        // Store the message for reference
        DispatchQueue.main.async {
            self.emergencyMessage = emergencyMessage
        }
        
        return emergencyMessage
    }
    
    /// Sends an emergency message to emergency services
    func sendEmergencyMessageToServices(_ message: EmergencyMessage) async -> EmergencyServiceResponse? {
        // Use the EmergencyMessagingService to send the message
        let result = await EmergencyMessagingService.shared.simulateSendEmergencyMessage(message)
        
        switch result {
        case .success(let response):
            DispatchQueue.main.async {
                self.emergencyServiceResponse = response
            }
            return response
            
        case .failure(let error):
            DispatchQueue.main.async {
                self.emergencyError = "Failed to contact emergency services: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Speech Recognition Methods
    
    func requestSpeechRecognitionPermission() async -> Bool {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return false
        }
        
        var isAuthorized = false
        
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            isAuthorized = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    continuation.resume(returning: authStatus == .authorized)
                }
            }
        } else {
            isAuthorized = (status == .authorized)
        }
        
        return isAuthorized
    }
    
    func startSpeechRecognition() {
        // Stop any ongoing recognition
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Set up the audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }
        
        // Set up recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create a speech recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Set up recognition task
        guard let speechRecognizer = speechRecognizer else {
            print("Speech recognizer not available")
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                // Update the recognized text
                DispatchQueue.main.async {
                    self.recognizedSpeech = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                // Stop audio engine
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isRecognizingSpeech = false
                }
            }
        }
        
        // Set up audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecognizingSpeech = true
            }
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }
    
    func stopSpeechRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        
        audioEngine.inputNode.removeTap(onBus: 0)
        
        DispatchQueue.main.async {
            self.isRecognizingSpeech = false
        }
    }
    
    // MARK: - Private Methods
    
    private func performRequest<T: Decodable>(endpoint: String, resultType: T.Type, completion: @escaping (Result<T, Error>) -> Void) async {
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "InvalidResponse", code: -2, userInfo: nil)))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let decodedData = try decoder.decode(T.self, from: data)
                    completion(.success(decodedData))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil)))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    private func handleError(error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = error.localizedDescription
            print("API Error: \(error.localizedDescription)")
        }
    }
    
    /// Process voice input and convert to text using on-device speech recognition
    func processVoiceToText(audioData: Data) async -> String? {
        // Since we cannot use a real speech-to-text API in this example,
        // we'll use a fallback simulated response to demonstrate the flow
        
        do {
            // In a real app, you would send the audioData to a service
            // For now, we'll simulate a successful transcription
            return "This is a simulated transcription of the audio recording for emergency reporting purposes."
        } catch {
            print("Voice transcription error: \(error)")
            return nil
        }
    }
    
    
}
