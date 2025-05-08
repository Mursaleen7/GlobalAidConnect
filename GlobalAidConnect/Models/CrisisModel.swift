import Foundation
import CoreLocation

// MARK: - Data Models
struct Crisis: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let location: String
    let severity: Int // 1-5
    let startDate: Date
    let description: String
    let affectedPopulation: Int
    let coordinatorContact: String?
    let coordinates: Coordinates?
    
    // Implement Equatable
    static func == (lhs: Crisis, rhs: Crisis) -> Bool {
        lhs.id == rhs.id
    }
}

struct Coordinates: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct Update: Identifiable, Codable {
    let id: String
    let crisisId: String
    let title: String
    let content: String
    let timestamp: Date
    let source: String
}

// MARK: - NASA EONET API Models
struct EONETResponse: Codable {
    let title: String
    let description: String
    let events: [EONETEvent]
}

struct EONETEvent: Codable {
    let id: String
    let title: String
    let description: String?
    let closed: String?
    let categories: [EONETCategory]
    let sources: [EONETSource]
    let geometry: [EONETGeometry]
}

struct EONETCategory: Codable {
    let id: String
    let title: String
}

struct EONETSource: Codable {
    let id: String
    let url: String
}

struct EONETGeometry: Codable {
    let date: String
    let type: String
    let coordinates: [Double]
}
