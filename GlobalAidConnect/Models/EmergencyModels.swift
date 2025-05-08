import Foundation
import CoreLocation
import SwiftUI

// MARK: - Emergency Models
struct EmergencyReport {
    let id: String = UUID().uuidString
    let timestamp: Date = Date()
    let message: String
    let location: CLLocationCoordinate2D?
    let severity: Int?
    let category: String?
    let isProcessed: Bool
}

struct EmergencyAnalysisResponse: Codable {
    let severity: Int
    let category: String
    let urgency: String
    let recommendedActions: [String]
    let estimatedAffectedArea: Double?
}

// MARK: - Situation Analysis Models
struct SituationAnalysis: Codable {
    let urgency: EmergencyUrgency
    let type: String
    let severity: Int
    let locationHints: [String]
    let recommendedActions: [String]
    let potentialRisks: [String]
    let affectedArea: AffectedArea?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case urgency, type, severity, locationHints, recommendedActions, potentialRisks, affectedArea
        case timestamp
    }
}

enum EmergencyUrgency: String, Codable {
    case immediate = "immediate"
    case urgent = "urgent"
    case moderate = "moderate"
    case low = "low"
    
    var description: String {
        switch self {
        case .immediate: return "Immediate Response Required"
        case .urgent: return "Urgent Response Required"
        case .moderate: return "Response Required Soon"
        case .low: return "Response Can Be Scheduled"
        }
    }
    
    var color: Color {
        switch self {
        case .immediate: return .red
        case .urgent: return .orange
        case .moderate: return .yellow
        case .low: return .blue
        }
    }
}

struct AffectedArea: Codable {
    let radius: Double // in kilometers
    let estimatedPopulation: Int?
    let terrainType: String?
}

// MARK: - Emergency Messaging Models
struct LocationData: Codable {
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let regionName: String?
    
    init(latitude: Double? = nil,
         longitude: Double? = nil,
         address: String? = nil,
         regionName: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.regionName = regionName
    }
}

struct UserInfo: Codable {
    let id: String
    let name: String?
    let contactPhone: String?
    let medicalNeeds: String?
    
    init(id: String = UUID().uuidString,
         name: String? = nil,
         contactPhone: String? = nil,
         medicalNeeds: String? = nil) {
        self.id = id
        self.name = name
        self.contactPhone = contactPhone
        self.medicalNeeds = medicalNeeds
    }
}

struct AppInfo: Codable {
    let appId: String
    let version: String
    let platform: String
    
    init(appId: String = "com.globalaidconnect.app",
         version: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
         platform: String = "iOS") {
        self.appId = appId
        self.version = version
        self.platform = platform
    }
}

struct EmergencyMessage: Codable {
    let id: String
    let timestamp: Date
    let emergencyType: String
    let urgency: String
    let severity: Int
    let description: String
    let location: LocationData
    let userInfo: UserInfo
    let actions: [String]
    let appInfo: AppInfo
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, emergencyType, urgency, severity, description, location, userInfo, actions, appInfo
    }
    
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        emergencyType: String,
        urgency: String,
        severity: Int,
        description: String,
        location: LocationData,
        userInfo: UserInfo,
        actions: [String],
        appInfo: AppInfo = AppInfo()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.emergencyType = emergencyType
        self.urgency = urgency
        self.severity = severity
        self.description = description
        self.location = location
        self.userInfo = userInfo
        self.actions = actions
        self.appInfo = appInfo
    }
}

struct EmergencyServiceResponse: Codable {
    let success: Bool
    let messageId: String
    let responseCode: String
    let estimatedResponseTime: Int?
    let message: String
    let actions: [String]?
}
