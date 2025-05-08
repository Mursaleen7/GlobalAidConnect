import Foundation
import CoreLocation
import Combine
import UIKit

// MARK: - Emergency Messaging Service
class EmergencyMessagingService {
    static let shared = EmergencyMessagingService()
    
    // Status publisher
    private let messageStatusSubject = PassthroughSubject<MessageStatus, Never>()
    var messageSendingStatus: AnyPublisher<MessageStatus, Never> {
        messageStatusSubject.eraseToAnyPublisher()
    }
    
    // Message status enum
    enum MessageStatus {
        case preparing
        case sending
        case delivered(messageId: String, timestamp: Date)
        case failed(error: Error)
    }
    
    // Private properties
    private var timer: Timer?
    private var currentlyProcessingMessage: EmergencyMessage?
    
    private init() {}
    
    /// Creates a formatted emergency message based on analysis and user report
    func createEmergencyMessage(
        from analysis: SituationAnalysis?,
        report: EmergencyReport,
        location: CLLocation?
    ) -> EmergencyMessage {
        
        // Publish preparing status
        messageStatusSubject.send(.preparing)
        
        // Prepare location data
        let locationData = LocationData(
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            address: nil,
            regionName: extractRegionFromCoordinates(location?.coordinate)
        )
        
        // Create user info (in a real app, this would come from saved profile)
        let userInfo = UserInfo(
            id: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        )
        
        // Determine emergency type and severity from analysis or fallback to defaults
        let emergencyType = analysis?.type ?? "Unspecified Emergency"
        let urgency = analysis?.urgency.rawValue ?? "moderate"
        let severity = analysis?.severity ?? 3
        
        // Extract recommended actions
        let actions = analysis?.recommendedActions ?? [
            "Contact local emergency services",
            "Follow safety protocols",
            "Stay informed through official channels"
        ]
        
        // Create the emergency message
        let message = EmergencyMessage(
            emergencyType: emergencyType,
            urgency: urgency,
            severity: severity,
            description: report.message,
            location: locationData,
            userInfo: userInfo,
            actions: actions
        )
        
        return message
    }
    
    /// Simulates sending an emergency message to services
    func simulateSendEmergencyMessage(_ message: EmergencyMessage) async -> Result<EmergencyServiceResponse, Error> {
        // Update status
        self.currentlyProcessingMessage = message
        messageStatusSubject.send(.sending)
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simulate success (90% of the time)
        if Double.random(in: 0...1) < 0.9 {
            // Generate a response
            let response = EmergencyServiceResponse(
                success: true,
                messageId: "ER-\(Int.random(in: 100000...999999))",
                responseCode: "MSG_RECEIVED",
                estimatedResponseTime: Int.random(in: 5...20),
                message: "Your emergency has been received and responders have been notified.",
                actions: [
                    "Stay in a safe location",
                    "Keep your phone accessible",
                    "Responders will contact you shortly"
                ]
            )
            
            // Publish delivered status
            messageStatusSubject.send(.delivered(messageId: response.messageId, timestamp: Date()))
            
            return .success(response)
        } else {
            // Simulate failure
            let error = NSError(
                domain: "EmergencyMessaging",
                code: 408,
                userInfo: [NSLocalizedDescriptionKey: "Connection timeout. Emergency services could not be reached."]
            )
            
            // Publish failure status
            messageStatusSubject.send(.failed(error: error))
            
            return .failure(error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Extracts region name from coordinates
    private func extractRegionFromCoordinates(_ coordinates: CLLocationCoordinate2D?) -> String? {
        guard let coordinates = coordinates else {
            return nil
        }
        
        // In a real app, this would use reverse geocoding
        // For this demo, we'll use a simplified approach based on coordinates
        
        // Example implementation
        if coordinates.latitude > 30 && coordinates.longitude > -30 && coordinates.longitude < 60 {
            return "Europe"
        } else if coordinates.latitude > 10 && coordinates.longitude > 60 && coordinates.longitude < 150 {
            return "Asia"
        } else if coordinates.latitude < 0 && coordinates.longitude > 110 && coordinates.longitude < 180 {
            return "Australia"
        } else if coordinates.latitude > 10 && coordinates.longitude > -150 && coordinates.longitude < -50 {
            return "North America"
        } else if coordinates.latitude < 10 && coordinates.latitude > -60 && coordinates.longitude > -90 && coordinates.longitude < -30 {
            return "South America"
        } else if coordinates.latitude < 40 && coordinates.latitude > -40 && coordinates.longitude > -20 && coordinates.longitude < 60 {
            return "Africa"
        } else {
            return "Unknown Region"
        }
    }
}
