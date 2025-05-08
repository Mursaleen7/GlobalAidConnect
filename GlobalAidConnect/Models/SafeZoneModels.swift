import Foundation
import CoreLocation

// Safe Zone Model
struct SafeZone: Identifiable, Decodable {
    let id: UUID
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let radius: CLLocationDistance
    let capacity: Int
    let currentOccupancy: Int
    let resourcesAvailable: [String]
    let lastUpdated: Date
    let safetyLevel: Int // 1-5, with 5 being the safest
    let address: String?
    let contactInfo: String?
    
    // Standard initializer for programmatically creating safe zones
    init(id: UUID = UUID(),
         name: String,
         description: String,
         coordinate: CLLocationCoordinate2D,
         radius: CLLocationDistance,
         capacity: Int,
         currentOccupancy: Int,
         resourcesAvailable: [String],
         lastUpdated: Date = Date(),
         safetyLevel: Int,
         address: String? = nil,
         contactInfo: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.coordinate = coordinate
        self.radius = radius
        self.capacity = capacity
        self.currentOccupancy = currentOccupancy
        self.resourcesAvailable = resourcesAvailable
        self.lastUpdated = lastUpdated
        self.safetyLevel = safetyLevel
        self.address = address
        self.contactInfo = contactInfo
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, coordinates, radius
        case capacity, currentOccupancy, resourcesAvailable
        case lastUpdated, safetyLevel, address, contactInfo
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        // Decode coordinates as [longitude, latitude]
        let coordinates = try container.decode([Double].self, forKey: .coordinates)
        guard coordinates.count >= 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .coordinates,
                in: container,
                debugDescription: "Coordinates must contain longitude and latitude"
            )
        }
        coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
        
        radius = try container.decode(CLLocationDistance.self, forKey: .radius)
        capacity = try container.decode(Int.self, forKey: .capacity)
        currentOccupancy = try container.decode(Int.self, forKey: .currentOccupancy)
        resourcesAvailable = try container.decode([String].self, forKey: .resourcesAvailable)
        
        // Parse date
        let dateFormatter = ISO8601DateFormatter()
        let dateString = try container.decode(String.self, forKey: .lastUpdated)
        lastUpdated = dateFormatter.date(from: dateString) ?? Date()
        
        safetyLevel = try container.decode(Int.self, forKey: .safetyLevel)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        contactInfo = try container.decodeIfPresent(String.self, forKey: .contactInfo)
    }
}

// Supporting Models for API responses
struct DisasterInfo {
    let id: String
    let title: String
    let type: String
}

struct WeatherAlert {
    let id: String
    let event: String
    let headline: String
    let description: String
    let severity: String
}
