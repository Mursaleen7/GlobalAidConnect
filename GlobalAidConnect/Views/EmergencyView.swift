import SwiftUI
import Combine
import AVFoundation
import MapKit
import CoreLocation

// MARK: - Emergency Input View
struct EmergencyInputView: View {
    @EnvironmentObject var apiService: ApiService
    @State private var emergencyMessage: String = ""
    @State private var isRecordingVoice: Bool = false
    @State private var showLocationPermissionAlert: Bool = false
    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var showAnalysisResult: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var showLocationError: Bool = false
    @State private var showMessageStatus: Bool = false
    
    // Location manager
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                emergencyHeader
                
                // Message Status View (shown when sending messages)
                if showMessageStatus {
                    EmergencyMessageStatusView()
                        .environmentObject(apiService)
                        .transition(.opacity)
                }
                
                // Input Section (hidden when showing status)
                if !showMessageStatus {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Describe the Emergency")
                            .font(.headline)
                        
                        ZStack(alignment: .topLeading) {
                            if emergencyMessage.isEmpty && !apiService.isRecognizingSpeech {
                                Text("Provide details about the emergency situation...")
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                            
                            TextEditor(text: $emergencyMessage)
                                .frame(minHeight: 150)
                                .padding(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        if apiService.isRecognizingSpeech {
                            Text("Listening: \(apiService.recognizedSpeech)")
                                .foregroundColor(.blue)
                                .padding(.vertical, 5)
                        }
                        
                        // Input Controls
                        HStack {
                            Button(action: {
                                toggleVoiceRecording()
                            }) {
                                HStack {
                                    Image(systemName: isRecordingVoice ? "stop.circle.fill" : "mic.circle.fill")
                                    Text(isRecordingVoice ? "Stop Recording" : "Voice Input")
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                                .background(isRecordingVoice ? Color.red.opacity(0.8) : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                clearInputs()
                            }) {
                                Text("Clear")
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 15)
                                    .background(Color.gray.opacity(0.3))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // Location Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Location")
                            .font(.headline)
                        
                        if let errorMessage = locationManager.locationError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(errorMessage)
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                // Add a help button
                                Button(action: {
                                    requestLocationPermission()
                                }) {
                                    Text("Fix")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        if let location = locationManager.lastLocation?.coordinate {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text(locationManager.locationError == nil ? "Location available" : "Using approximate location")
                                    .foregroundColor(locationManager.locationError == nil ? .green : .orange)
                                Spacer()
                            }
                            
                            // Updated Map implementation for iOS 17+
                            Group {
                                if #available(iOS 17.0, *) {
                                    Map {
                                        UserAnnotation()
                                        Marker("Your Location", coordinate: location)
                                            .tint(.blue)
                                    }
                                    .mapStyle(.standard)
                                    .mapControls {
                                        MapUserLocationButton()
                                        MapCompass()
                                    }
                                    .frame(height: 150)
                                    .cornerRadius(8)
                                } else {
                                    // Fallback for older iOS versions
                                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                                        center: location,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )), showsUserLocation: true, userTrackingMode: .constant(.follow))
                                    .frame(height: 150)
                                    .cornerRadius(8)
                                }
                            }
                            .onAppear {
                                currentLocation = location
                            }
                        } else {
                            HStack {
                                Image(systemName: "location.slash.fill")
                                    .foregroundColor(.orange)
                                Text("Location not available")
                                    .foregroundColor(.orange)
                                Spacer()
                                
                                Button(action: {
                                    requestLocationPermission()
                                }) {
                                    Text("Enable")
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(5)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // Submit Button
                    Button(action: {
                        submitEmergencyReport()
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Submit Emergency Report")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            emergencyMessage.isEmpty ? Color.gray : Color.red
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                    }
                    .disabled(emergencyMessage.isEmpty || isSubmitting)
                    .padding(.top, 10)
                    
                    if isSubmitting {
                        ProgressView("Processing emergency report...")
                            .padding()
                    }
                }
                
                // Analysis Results
                if showAnalysisResult, let analysis = apiService.emergencyAnalysis {
                    EmergencyResultView(
                        analysis: analysis,
                        messageResponse: apiService.emergencyServiceResponse
                    )
                    .environmentObject(apiService)
                    .transition(.opacity)
                    
                    // Done & New Report buttons
                    HStack {
                        Button(action: {
                            // Return to dashboard
                            clearInputs()
                        }) {
                            Text("Done")
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            // Clear form for new report
                            resetForm()
                        }) {
                            Text("New Report")
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .padding()
        }
        .onAppear {
            // Request location and speech permissions on view appear
            locationManager.requestAuthorization()
            Task {
                _ = await apiService.requestSpeechRecognitionPermission()
            }
        }
        .onChange(of: locationManager.lastLocation) { newLocation in
            if let location = newLocation?.coordinate {
                currentLocation = location
            }
        }
        // Fix: Use onChange with a value that's not optional and properly observe messageStatus changes
        .onChange(of: apiService.isMessageSending) { isMessageSending in
            if let status = apiService.messageStatus {
                switch status {
                case .delivered:
                    // When message is delivered, show the analysis results
                    withAnimation {
                        showMessageStatus = false
                        showAnalysisResult = true
                    }
                case .failed:
                    // If message fails, show error and reset
                    withAnimation {
                        showMessageStatus = false
                        isSubmitting = false
                    }
                default:
                    break
                }
            }
        }
        .alert(isPresented: $showLocationPermissionAlert) {
            Alert(
                title: Text("Location Access"),
                message: Text("Location access is important for emergency services to reach you. Please enable location services in your device settings."),
                primaryButton: .default(Text("Settings"), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
        .alert(item: alertItem) { alertItem in
            Alert(
                title: Text("Error"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var alertItem: Binding<AlertItem?> {
        Binding<AlertItem?>(
            get: {
                if let error = apiService.emergencyError {
                    return AlertItem(message: error)
                }
                return nil
            },
            set: { _ in
                apiService.emergencyError = nil
            }
        )
    }
    
    private var emergencyHeader: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Emergency Report")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Report an emergency situation for immediate assistance")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func requestLocationPermission() {
        locationManager.requestAuthorization()
        
        // Check if we need to show settings alert
        if locationManager.authorizationStatus == .denied ||
           locationManager.authorizationStatus == .restricted {
            showLocationPermissionAlert = true
        }
    }
    
    private func toggleVoiceRecording() {
        if isRecordingVoice {
            // Stop recording
            apiService.stopSpeechRecognition()
            isRecordingVoice = false
            
            // Update text field with recognized speech
            if !apiService.recognizedSpeech.isEmpty {
                emergencyMessage = apiService.recognizedSpeech
                apiService.recognizedSpeech = ""
            }
        } else {
            // Start recording
            apiService.startSpeechRecognition()
            isRecordingVoice = true
        }
    }
    
    private func clearInputs() {
        emergencyMessage = ""
        apiService.recognizedSpeech = ""
        showAnalysisResult = false
        showMessageStatus = false
    }
    
    private func resetForm() {
        clearInputs()
        // Reset the API service state for a new report
        apiService.emergencyAnalysis = nil
        apiService.situationAnalysis = nil
        apiService.emergencyMessage = nil
        apiService.emergencyServiceResponse = nil
    }
    
    private func submitEmergencyReport() {
        guard !emergencyMessage.isEmpty else { return }
        
        isSubmitting = true
        
        Task {
            // This will analyze the emergency, create a formatted message, and send it to services
            let success = await apiService.submitEmergencyReport(
                message: emergencyMessage,
                location: currentLocation
            )
            
            // Show the message sending status
            DispatchQueue.main.async {
                withAnimation {
                    showMessageStatus = true
                    isSubmitting = false
                }
            }
        }
    }
}

// MARK: - Emergency Result View
struct EmergencyResultView: View {
    @EnvironmentObject var apiService: ApiService
    let analysis: EmergencyAnalysisResponse
    let messageResponse: EmergencyServiceResponse?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Analysis Header
            HStack {
                Text("Emergency Analysis")
                    .font(.headline)
                
                Spacer()
                
                // Urgency badge
                Text(analysis.urgency)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(urgencyColor(for: analysis.urgency).opacity(0.2))
                    .foregroundColor(urgencyColor(for: analysis.urgency))
                    .cornerRadius(4)
            }
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            // Severity rating
            HStack {
                Text("Severity:")
                    .fontWeight(.medium)
                
                Spacer()
                
                // Star rating
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { level in
                        Image(systemName: level <= analysis.severity ? "circle.fill" : "circle")
                            .foregroundColor(level <= analysis.severity ? .red : .gray)
                    }
                }
            }
            
            // Emergency type
            HStack {
                Text("Type:")
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(analysis.category)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            
            // Recommended actions
            if !analysis.recommendedActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended Actions:")
                        .fontWeight(.medium)
                    
                    ForEach(analysis.recommendedActions, id: \.self) { action in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .padding(.top, 2)
                            
                            Text(action)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            
            // Affected area
            if let area = analysis.estimatedAffectedArea {
                HStack {
                    Text("Estimated Affected Area:")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(String(format: "%.2f sq km", area))
                        .font(.body)
                }
            }
            
            // Emergency Services Response
            if let response = messageResponse {
                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Emergency Services Notified")
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                    
                    Text(response.message)
                        .font(.subheadline)
                    
                    if let eta = response.estimatedResponseTime {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            
                            Text("Estimated Response Time: \(eta) minutes")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let actions = response.actions, !actions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Instructions:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(actions, id: \.self) { action in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(.blue)
                                        .padding(.top, 2)
                                    
                                    Text(action)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                    
                    // Reference ID
                    HStack {
                        Text("Reference ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(response.messageId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 1)
                )
            }
            
            // Call emergency services button
            Button(action: {
                callEmergencyServices()
            }) {
                HStack {
                    Image(systemName: "phone.fill")
                    Text("Call Emergency Services")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Helper Methods
    
    private func urgencyColor(for urgency: String) -> Color {
        switch urgency.lowercased() {
        case _ where urgency.contains("immediate"):
            return .red
        case _ where urgency.contains("urgent"):
            return .orange
        case _ where urgency.contains("soon"):
            return .yellow
        default:
            return .blue
        }
    }
    
    private func callEmergencyServices() {
        // In a real app, this would use the appropriate emergency number based on location
        guard let url = URL(string: "tel://911") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Emergency Message Status View
struct EmergencyMessageStatusView: View {
    @EnvironmentObject var apiService: ApiService
    
    var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                if apiService.isMessageSending {
                    // Show spinner when sending
                    ProgressView()
                        .scaleEffect(1.5)
                } else if case .delivered = apiService.messageStatus {
                    // Show checkmark when delivered
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                } else if case .failed = apiService.messageStatus {
                    // Show error when failed
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                }
            }
            
            // Status text
            Text(statusText)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // Details
            Text(statusDetails)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // Status text based on current status
    private var statusText: String {
        guard let status = apiService.messageStatus else {
            return "Preparing message..."
        }
        
        switch status {
        case .preparing:
            return "Preparing emergency message..."
        case .sending:
            return "Contacting emergency services..."
        case .delivered:
            return "Emergency services notified!"
        case .failed:
            return "Failed to contact emergency services"
        }
    }
    
    // More detailed explanation based on status
    private var statusDetails: String {
        guard let status = apiService.messageStatus else {
            return "Your emergency information is being formatted for services."
        }
        
        switch status {
        case .preparing:
            return "Your emergency details are being prepared for submission to emergency services."
        case .sending:
            return "Your emergency report is being securely transmitted to emergency services."
        case .delivered(let messageId, let timestamp):
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            return "Emergency services received your report at \(formatter.string(from: timestamp)). Reference ID: \(messageId)"
        case .failed(let error):
            return "Error: \(error.localizedDescription). Please try again or call emergency services directly."
        }
    }
}

// MARK: - Audio Recorder Manager
// This class handles audio recording and implements AVAudioRecorderDelegate
class AudioRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording: Bool = false
    @Published var transcribedText: String = ""
    @Published var errorMessage: String? = nil
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL? = nil
    
    func startRecording() {
        // Reset state
        transcribedText = ""
        errorMessage = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            
            // Configure audio settings
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // Get the documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            audioFileURL = documentsPath.appendingPathComponent("recording.m4a")
            
            guard let fileURL = audioFileURL else {
                setError("Could not create audio file URL")
                return
            }
            
            // Create and configure the audio recorder
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            
            if audioRecorder?.record() == true {
                DispatchQueue.main.async {
                    self.isRecording = true
                }
            } else {
                setError("Failed to start recording")
            }
        } catch {
            setError("Recording error: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    func processAudioToText(with apiService: ApiService) async {
        guard let fileURL = audioFileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            setError("No recording found")
            return
        }
        
        do {
            // Read the audio data
            let audioData = try Data(contentsOf: fileURL)
            
            // Send to speech-to-text service
            if let transcribedText = await apiService.processVoiceToText(audioData: audioData) {
                DispatchQueue.main.async {
                    self.transcribedText = transcribedText
                }
            } else {
                setError("Failed to transcribe audio")
            }
        } catch {
            setError("Error processing audio: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AVAudioRecorderDelegate methods
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            setError("Recording failed to complete successfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        setError("Recording error: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    // MARK: - Helper methods
    
    private func setError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isRecording = false
        }
    }
}

// MARK: - Communication View
struct CommunicationView: View {
    @EnvironmentObject var apiService: ApiService
    @State private var messageText: String = ""
    @State private var isRecording: Bool = false
    @State private var showAISelector: Bool = false
    @State private var selectedAI: AIType = .claude
    @State private var isTranslating: Bool = false
    @State private var isProcessing: Bool = false
    
    // Add AudioRecorderManager to handle recording functionality
    @StateObject private var audioRecorderManager = AudioRecorderManager()
    
    enum AIType {
        case claude, gpt
    }
    
    var body: some View {
        VStack {
            // AI Selection Header
            HStack {
                Text("Current AI: ")
                    .foregroundColor(.secondary)
                
                Button(action: {
                    showAISelector.toggle()
                }) {
                    HStack {
                        Text(selectedAI == .claude ? "Claude" : "GPT")
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .actionSheet(isPresented: $showAISelector) {
                    ActionSheet(
                        title: Text("Select AI Assistant"),
                        buttons: [
                            .default(Text("Claude")) { selectedAI = .claude },
                            .default(Text("GPT")) { selectedAI = .gpt },
                            .cancel()
                        ]
                    )
                }
                
                Spacer()
                
                Button(action: {
                    apiService.clearConversation()
                }) {
                    Text("Clear Chat")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Chat Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(apiService.currentConversation.indices, id: \.self) { index in
                        let message = apiService.currentConversation[index]
                        MessageBubble(message: message)
                    }
                    
                    if apiService.isProcessingAI {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
                .padding()
            }
            
            // Input Controls
            VStack(spacing: 8) {
                if isTranslating {
                    HStack {
                        Text("Translating...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            isTranslating = false
                        }) {
                            Text("Cancel")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                }
                
                HStack {
                    // Voice Input Button
                    Button(action: {
                        toggleVoiceRecording()
                    }) {
                        Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isRecording ? .red : .blue)
                            .padding(8)
                    }
                    
                    // Text Input Field
                    TextField("Message", text: $messageText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    
                    // Send Button
                    Button(action: {
                        sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiService.isProcessingAI)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 2)
        }
        .alert(item: aiAlertItem) { alertItem in
            Alert(
                title: Text("Error"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: audioRecorderManager.transcribedText) { newValue in
            if !newValue.isEmpty {
                messageText = newValue
            }
        }
        .onChange(of: audioRecorderManager.errorMessage) { newValue in
            if let error = newValue {
                apiService.aiErrorMessage = error
            }
        }
        .onChange(of: audioRecorderManager.isRecording) { newValue in
            isRecording = newValue
        }
    }
    
    private var aiAlertItem: Binding<AlertItem?> {
        Binding<AlertItem?>(
            get: {
                if let error = apiService.aiErrorMessage {
                    return AlertItem(message: error)
                }
                return nil
            },
            set: { _ in
                apiService.aiErrorMessage = nil
            }
        )
    }
    
    // MARK: - Helper Methods
    
    private func toggleVoiceRecording() {
        if isRecording {
            audioRecorderManager.stopRecording()
            isProcessing = true
            
            // Process the recorded audio
            Task {
                await audioRecorderManager.processAudioToText(with: apiService)
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        } else {
            audioRecorderManager.startRecording()
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedMessage.isEmpty {
            Task {
                // Send to appropriate AI service
                let response: String?
                
                if selectedAI == .claude {
                    response = await apiService.sendMessageToClaude(userMessage: trimmedMessage)
                } else {
                    response = await apiService.sendMessageToGPT(userMessage: trimmedMessage)
                }
                
                // Clear message field
                DispatchQueue.main.async {
                    self.messageText = ""
                }
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: AIMessage
    
    var isUser: Bool {
        message.role == "user"
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            Text(message.content)
                .padding(12)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isUser ? .white : .primary)
                .cornerRadius(16)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
            
            if !isUser { Spacer() }
        }
    }
}
