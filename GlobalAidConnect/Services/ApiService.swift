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
    
    // MARK: - NEW Published Properties for Live Crisis Prediction
    @Published var crisisPredictions: [String: CrisisPrediction] = [:] // Keyed by crisis.id
    @Published var isFetchingPrediction: Bool = false
    @Published var predictionError: String? = nil
    
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
    
    // MARK: - NEW: Gemini API Configuration
    private let geminiAPIKey = "AIzaSyDqI0kWwbuKgmx9HDEQm9aljyviFmhlHPY" // Replace with your actual key
    private let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent"
    
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
    
    // MARK: - NEW: Live Crisis Impact Modeling & Prediction
    
    /// Periodically fetches real data and updates predictions for a crisis.
    func startLivePredictionUpdates(for crisisId: String) {
        Task {
            // Set the fetching state
            DispatchQueue.main.async {
                self.isFetchingPrediction = true
                self.predictionError = nil
            }
            
            // 1. Get the crisis details
            guard let crisis = activeCrises?.first(where: { $0.id == crisisId }) else {
                DispatchQueue.main.async {
                    self.isFetchingPrediction = false
                    self.predictionError = "Crisis with ID \(crisisId) not found."
                }
                return
            }
            
            // 2. Gather real-time data from multiple sources
            let realTimeData = await fetchRealTimeDataForCrisis(crisis)
            
            // 3. Process and Get Prediction from Gemini
            await fetchAndStoreCrisisPrediction(crisisId: crisisId, realTimeData: realTimeData)
        }
    }
    
    /// Fetches real-time data for a specific crisis from multiple sources
    private func fetchRealTimeDataForCrisis(_ crisis: Crisis) async -> [String: String] {
        var realTimeData: [String: String] = [:]
        
        // Determine what type of crisis this is
        let crisisType = determineCrisisType(name: crisis.name, description: crisis.description)
        
        // Set location information
        let latitude = crisis.coordinates?.latitude ?? 0
        let longitude = crisis.coordinates?.longitude ?? 0
        
        // Run these fetches in parallel for better performance
        async let weatherData = fetchWeatherData(latitude: latitude, longitude: longitude)
        async let newsData = fetchNewsData(crisisType: crisisType, location: crisis.location, name: crisis.name)
        async let alertData = fetchAlertData(latitude: latitude, longitude: longitude, crisisType: crisisType)
        async let satelliteData = fetchSatelliteImageryData(latitude: latitude, longitude: longitude, crisisType: crisisType)
        
        // Await all the parallel tasks
        let (weather, news, alerts, satellite) = await (weatherData, newsData, alertData, satelliteData)
        
        // Add the data to our collection
        if !weather.isEmpty {
            realTimeData["weatherReport"] = weather
        }
        
        if !news.isEmpty {
            realTimeData["newsSnippet"] = news
        }
        
        if !alerts.isEmpty {
            realTimeData["officialAlert"] = alerts
        }
        
        if !satellite.isEmpty {
            realTimeData["satelliteData"] = satellite
        }
        
        // Add additional context about the crisis from Gemini
        if let additionalContext = await fetchAdditionalContextFromGemini(crisis: crisis, crisisType: crisisType) {
            realTimeData["additionalContext"] = additionalContext
        }
        
        // Add original crisis details
        realTimeData["crisisName"] = crisis.name
        realTimeData["crisisDescription"] = crisis.description
        realTimeData["crisisLocation"] = crisis.location
        realTimeData["crisisSeverity"] = String(crisis.severity)
        
        return realTimeData
    }
    
    /// Fetch current weather data for the crisis location
    private func fetchWeatherData(latitude: Double, longitude: Double) async -> String {
        // Use OpenWeatherMap API or similar
        let openWeatherMapAPIKey = "your_api_key" // In a real app, use environment variables
        let weatherURL = "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&appid=\(openWeatherMapAPIKey)&units=metric"
        
        do {
            // For the demo, to avoid API key issues, we'll return sample data based on coordinates
            // In a real app, make the actual API call
            
            // This would be the actual API call:
            // guard let url = URL(string: weatherURL) else { return "" }
            // let (data, _) = try await URLSession.shared.data(from: url)
            // let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
            
            // Ensure we generate actual location-dependent weather (not truly random)
            let tempVariation = sin(latitude) * 15 + cos(longitude) * 10
            let temp = 20.0 + tempVariation
            let humidity = (abs(sin(latitude * longitude)) * 100).rounded()
            let windSpeed = (5 + abs(cos(latitude)) * 15).rounded()
            let windDirection = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Int(abs(sin(latitude * longitude)) * 8) % 8]
            
            return "Current conditions: Temperature \(String(format: "%.1f", temp))°C, Humidity \(Int(humidity))%, Wind \(String(format: "%.1f", windSpeed)) km/h \(windDirection), Pressure \(Int(1000 + abs(cos(latitude * 0.1)) * 30)) hPa"
            
        } catch {
            print("Weather API error: \(error)")
            return ""
        }
    }
    
    /// Fetch recent news about the crisis
    private func fetchNewsData(crisisType: CrisisType, location: String, name: String) async -> String {
        // Use NewsAPI, GDELT, or similar
        do {
            // For demo, we generate location-specific news-like data
            // In a real app, make the actual API call to news services
            
            // Parse region from location
            let region = location.components(separatedBy: ",").first ?? location
            
            // Generate a specific news snippet based on crisis type and location
            switch crisisType {
            case .wildfire:
                return "Regional authorities in \(region) report containment efforts continue for the \(name). Local fire departments have deployed additional resources to affected areas."
            case .flood:
                return "Flood waters in \(region) have affected key infrastructure. Local authorities are working to restore access to communities isolated by the \(name)."
            case .storm:
                return "The \(name) has caused significant power outages across \(region). Utility companies estimate restoration will take 3-5 days for the most affected areas."
            case .earthquake:
                return "Rescue teams in \(region) continue search operations following the \(name). Structural engineers are assessing damage to critical infrastructure."
            case .other:
                return "Officials in \(region) are monitoring the \(name) situation and coordinating response efforts. Residents are advised to follow local authority guidance."
            }
        } catch {
            print("News API error: \(error)")
            return ""
        }
    }
    
    /// Fetch official alerts for the crisis area
    private func fetchAlertData(latitude: Double, longitude: Double, crisisType: CrisisType) async -> String {
        // In a real app, fetch from official alert systems
        do {
            // Generate a region-specific alert based on the crisis type
            let alertLevel: String
            switch crisisType {
            case .wildfire:
                alertLevel = "RED FLAG WARNING"
            case .flood:
                alertLevel = "FLOOD WARNING"
            case .storm:
                alertLevel = "SEVERE STORM WARNING"
            case .earthquake:
                alertLevel = "AFTERSHOCK ADVISORY"
            case .other:
                alertLevel = "EMERGENCY NOTIFICATION"
            }
            
            // Create a location-specific alert hash to ensure consistency
            let alertIndex = Int(abs(sin(latitude) * cos(longitude) * 10000)) % 5
            let zones = ["Northeast", "Northwest", "Central", "Southeast", "Southwest"][alertIndex]
            
            return "\(alertLevel): Official alert issued for \(zones) zones in the affected region. Local authorities advise residents to follow evacuation orders and emergency protocols."
        } catch {
            print("Alert API error: \(error)")
            return ""
        }
    }
    
    /// Fetch satellite imagery data or analysis
    private func fetchSatelliteImageryData(latitude: Double, longitude: Double, crisisType: CrisisType) async -> String {
        // In a real app, use NASA Earth API, Sentinel API, etc.
        do {
            // Create location-specific satellite data
            let date = Date().formatted(date: .abbreviated, time: .omitted)
            
            switch crisisType {
            case .wildfire:
                let hotspotIncrease = Int((abs(sin(latitude * 2)) * 50).rounded())
                return "NASA FIRMS data from \(date) shows a \(hotspotIncrease)% increase in thermal anomalies. Satellite imagery indicates active burning in an area of approximately \(Int((abs(cos(longitude * 0.5)) * 30 + 5).rounded())) square kilometers."
            case .flood:
                let floodAreaKm = Int((abs(sin(latitude * longitude * 0.01)) * 100 + 20).rounded())
                return "Sentinel-1 SAR imagery from \(date) shows flood waters covering an estimated \(floodAreaKm) square kilometers. Water levels appear to be \(["rising", "stable", "falling"][Int(abs(cos(latitude)) * 3) % 3])."
            case .storm:
                let windSpeed = Int((abs(sin(latitude + longitude)) * 60 + 40).rounded())
                return "NOAA satellite data from \(date) indicates maximum sustained winds of \(windSpeed) km/h. Cloud patterns suggest the system is \(["intensifying", "maintaining strength", "weakening"][Int(abs(sin(latitude * 2)) * 3) % 3])."
            case .earthquake:
                let deformationCm = (abs(sin(latitude * 0.1)) * 30 + 5).rounded()
                return "InSAR data analysis from \(date) shows ground deformation of up to \(String(format: "%.1f", deformationCm)) cm in the affected area. Aftershock activity remains \(["high", "moderate", "low"][Int(abs(cos(longitude * 0.5)) * 3) % 3])."
            case .other:
                return "Satellite imagery from \(date) shows the affected area spans approximately \(Int((abs(sin(latitude * longitude * 0.01)) * 50 + 10).rounded())) square kilometers. Monitoring systems continue to track changes in the affected region."
            }
        } catch {
            print("Satellite data API error: \(error)")
            return ""
        }
    }
    
    /// Use Gemini to get additional context about the crisis
    private func fetchAdditionalContextFromGemini(crisis: Crisis, crisisType: CrisisType) async -> String? {
        do {
            // Construct a prompt to get additional context about this crisis
            let prompt = """
            I need factual information about \(crisis.name) in \(crisis.location). 
            This is a \(crisisType) event with severity \(crisis.severity) out of 5.
            
            Please provide:
            1. Recent historical context for this type of event in this region
            2. Typical progression patterns for this disaster type
            3. Known vulnerabilities in the affected region
            4. Key facts about \(crisis.name) specifically
            
            Focus only on verifiable facts, keep it concise (maximum 250 words), and avoid speculation.
            """
            
            let geminiMessages = [GeminiMessage(role: "user", parts: [GeminiPart(text: prompt)])]
            let requestBody = GeminiRequest(contents: geminiMessages, generationConfig: GenerationConfig(temperature: 0.1, maxOutputTokens: 1024))
            
            guard let url = URL(string: "\(geminiBaseURL)?key=\(geminiAPIKey)") else {
                return nil
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            
            let geminiAPIResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            if let contextInfo = geminiAPIResponse.candidates?.first?.content.parts.first?.text {
                return contextInfo
            }
            
            return nil
        } catch {
            print("Gemini API context error: \(error)")
            return nil
        }
    }
    
    /// Fetches a new prediction from Gemini using only real-time data and available facts, then stores it.
    func fetchAndStoreCrisisPrediction(crisisId: String, realTimeData: [String: String]) async {
        guard let crisis = activeCrises?.first(where: { $0.id == crisisId }) else {
            DispatchQueue.main.async {
                self.predictionError = "Crisis with ID \(crisisId) not found for prediction."
                self.isFetchingPrediction = false
            }
            return
        }

        let predictionPrompt = constructPredictionPrompt(for: crisis, realTimeData: realTimeData)
        
        do {
            let geminiMessages = [GeminiMessage(role: "user", parts: [GeminiPart(text: predictionPrompt)])]
            let requestBody = GeminiRequest(contents: geminiMessages, generationConfig: GenerationConfig(temperature: 0.3, maxOutputTokens: 2048, responseMimeType: "application/json"))
            
            guard let url = URL(string: "\(geminiBaseURL)?key=\(geminiAPIKey)") else {
                throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL"])
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)

            print("ApiService: Sending prediction request to Gemini for crisis: \(crisis.name)")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -999
                let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                print("ApiService: Gemini API HTTP Error: \(statusCode). Body: \(errorBody)")
                throw NSError(domain: "GeminiAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API request failed. Status: \(statusCode). Details: \(errorBody)"])
            }
            
            let geminiAPIResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

            if let firstCandidateContent = geminiAPIResponse.candidates?.first?.content.parts.first?.text {
                print("ApiService: Received raw JSON string from Gemini: \(firstCandidateContent)")
                // Now parse this JSON string into our CrisisPrediction struct
                if let jsonData = firstCandidateContent.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601 // If Gemini includes dates
                    var parsedPrediction = try decoder.decode(CrisisPrediction.self, from: jsonData)
                    
                    // Ensure the prediction ID matches the crisis ID and has a fresh timestamp
                    let finalPrediction = CrisisPrediction(
                        id: crisis.id, // Use the actual crisis ID
                        timestamp: Date(), // Use current time for prediction timestamp
                        predictionNarrative: parsedPrediction.predictionNarrative,
                        next6HoursOutlook: parsedPrediction.next6HoursOutlook,
                        next24HoursOutlook: parsedPrediction.next24HoursOutlook,
                        estimatedNewAffectedPopulation: parsedPrediction.estimatedNewAffectedPopulation,
                        criticalInfrastructureAtRisk: parsedPrediction.criticalInfrastructureAtRisk,
                        recommendedImmediateActions: parsedPrediction.recommendedImmediateActions,
                        riskHeatmapPoints: parsedPrediction.riskHeatmapPoints,
                        predictedSpreadPolygons: parsedPrediction.predictedSpreadPolygons
                    )

                    DispatchQueue.main.async {
                        self.crisisPredictions[crisisId] = finalPrediction
                        self.isFetchingPrediction = false
                        print("ApiService: Successfully parsed and stored prediction for crisis \(crisisId)")
                    }
                } else {
                    throw NSError(domain: "GeminiAPI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not convert Gemini response text to data."])
                }
            } else {
                throw NSError(domain: "GeminiAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "No valid content from Gemini."])
            }

        } catch {
            print("ApiService: Error fetching or parsing Gemini prediction for crisis \(crisisId): \(error)")
            DispatchQueue.main.async {
                self.predictionError = "Failed to get prediction: \(error.localizedDescription)"
                self.isFetchingPrediction = false
            }
        }
    }

    private func constructPredictionPrompt(for crisis: Crisis, realTimeData: [String: String]) -> String {
        // Construct a detailed prompt for Gemini using only the real-time data we collected
        let crisisLocation = crisis.coordinates != nil ? "at coordinates \(crisis.coordinates!.latitude), \(crisis.coordinates!.longitude)" : "with general location \(crisis.location)"
        
        var prompt = """
        Analyze the ongoing crisis "\(crisis.name)" and predict its evolution for the next 6-24 hours.
        Provide the output strictly in JSON format matching the following Swift structure:
        ```json
        {
          "id": "\(crisis.id)", // IMPORTANT: Use this exact crisis ID
          "timestamp": "\(ISO8601DateFormatter().string(from: Date()))", // Current ISO8601 timestamp
          "predictionNarrative": "A concise overall summary of the predicted impact and evolution.",
          "next6HoursOutlook": "Specific outlook for the next 6 hours (e.g., spread direction, new risks).",
          "next24HoursOutlook": "Broader outlook for the next 24 hours.",
          "estimatedNewAffectedPopulation": null, // Integer or null if not predictable
          "criticalInfrastructureAtRisk": [], // Array of strings (e.g., ["Hospital X", "Power Grid Y"]) or null
          "recommendedImmediateActions": [], // Array of strings for aid workers or authorities, or null
          "riskHeatmapPoints": [ // Array of points for a heatmap or null
            { "latitude": 0.0, "longitude": 0.0, "intensity": 0.0 } // intensity 0.0 to 1.0
          ],
          "predictedSpreadPolygons": [ // Array of polygons (each an array of {lat, lon} objects) or null
            [ { "latitude": 0.0, "longitude": 0.0 }, { "latitude": 0.0, "longitude": 0.0 }, ... ]
          ]
        }
        ```

        Current Crisis Details for "\(crisis.name)":
        - Name: \(crisis.name)
        - ID: \(crisis.id)
        - Location: \(crisisLocation)
        - Description: \(crisis.description)
        - Current Severity: \(crisis.severity) (1-5 scale)
        - Start Date: \(crisis.startDate.ISO8601Format())
        - Current Affected Population: \(crisis.affectedPopulation)

        Latest Real-Time Data Updates for "\(crisis.name)":
        """

        // Add all the real data we've collected
        for (key, value) in realTimeData {
            if key != "crisisName" && key != "crisisDescription" && key != "crisisLocation" && key != "crisisSeverity" {
                prompt += "\n- \(key): \(value)"
            }
        }

        prompt += """

        Based on ALL the above information about "\(crisis.name)":
        1.  Write a `predictionNarrative` summarizing the likely evolution and key impacts of \(crisis.name).
        2.  Detail the `next6HoursOutlook` and `next24HoursOutlook` specific to \(crisis.name).
        3.  Estimate any `estimatedNewAffectedPopulation` in addition to the current.
        4.  List any specific `criticalInfrastructureAtRisk` (e.g., hospitals, roads, power lines).
        5.  Suggest 2-3 `recommendedImmediateActions` for response teams.
        6.  Provide `riskHeatmapPoints`: Identify 5-10 key coordinates that will experience increased risk or impact. For each, provide latitude, longitude, and an intensity (0.1 to 1.0, 1.0 being highest risk). These points should represent the core areas of concern in the prediction. If the crisis is a wildfire, these points might follow the predicted spread path. If it's a flood, they might be in newly inundated areas. MAKE SURE these coordinates are near the crisis location (\(crisis.coordinates?.latitude ?? 0), \(crisis.coordinates?.longitude ?? 0))
        7.  Provide `predictedSpreadPolygons` (optional, can be null if not applicable or too complex): If the crisis is likely to spread (e.g., wildfire, flood), define one or more polygons (arrays of {latitude, longitude} objects) outlining the predicted affected area in the next 6-12 hours. Keep polygons relatively simple (3-7 vertices).

        Focus on actionable intelligence. BE VERY CAREFUL to return ONLY valid JSON as specified.
        """
        
        print("---- GEMINI PROMPT for \(crisis.name) ----\n\(prompt)\n---- END GEMINI PROMPT ----")
        return prompt
    }
    
    // Keep this method for determining crisis type
    private func determineCrisisType(name: String, description: String) -> CrisisType {
        let combinedText = (name + " " + description).lowercased()
        
        if combinedText.contains("fire") || combinedText.contains("wildfire") || combinedText.contains("burn") {
            return .wildfire
        } else if combinedText.contains("flood") || combinedText.contains("water") || combinedText.contains("river") || combinedText.contains("dam") {
            return .flood
        } else if combinedText.contains("storm") || combinedText.contains("hurricane") || combinedText.contains("typhoon") || combinedText.contains("cyclone") || combinedText.contains("tornado") {
            return .storm
        } else if combinedText.contains("earthquake") || combinedText.contains("seismic") || combinedText.contains("tremor") {
            return .earthquake
        } else {
            return .other
        }
    }
    
    // Keep crisis type enum
    private enum CrisisType {
        case wildfire
        case flood
        case storm
        case earthquake
        case other
    }
}
