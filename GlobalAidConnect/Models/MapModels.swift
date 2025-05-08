import Foundation
import CoreLocation
import SwiftUI
import MapKit

// MARK: - Map Annotation Model
struct EmergencyMapAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let type: AnnotationType
    
    enum AnnotationType {
        case evacuationRoute
        case safeZone
    }
}

// MARK: - Alert Item Model
struct EmergencyAlertItem: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - Crisis Annotation Item
struct CrisisAnnotationItem: Identifiable {
    let id: String
    let crisis: Crisis
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Crisis Annotation View
struct CrisisAnnotationView: View {
    let crisis: Crisis
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(getSeverityColor())
                    .frame(width: 30, height: 30)
                
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
            }
            
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12))
                .foregroundColor(getSeverityColor())
                .offset(y: -5)
        }
    }
    
    private func getSeverityColor() -> Color {
        switch crisis.severity {
        case 5:
            return .red
        case 4:
            return .orange
        case 3:
            return .yellow
        case 2:
            return .blue
        default:
            return .green
        }
    }
}

// MARK: - Evacuation Route Model
struct EvacuationRoute: Identifiable, Decodable {
    let id: UUID
    let name: String
    let description: String
    let waypoints: [CLLocationCoordinate2D]
    let evacuationType: EvacuationType
    let estimatedTravelTime: TimeInterval
    let lastUpdated: Date
    let safetyLevel: Int // 1-5, with 5 being the safest
    let issueAuthority: String
    let sourceAPI: String
    
    enum EvacuationType: String, Codable, CaseIterable {
        case fire = "Fire"
        case flood = "Flood"
        case earthquake = "Earthquake"
        case hurricane = "Hurricane"
        case tsunami = "Tsunami"
        case chemical = "Chemical Spill"
        case general = "General"
    }
    
    // Standard initializer for programmatically creating routes
    init(id: UUID = UUID(),
         name: String,
         description: String,
         waypoints: [CLLocationCoordinate2D],
         evacuationType: EvacuationType,
         estimatedTravelTime: TimeInterval,
         lastUpdated: Date = Date(),
         safetyLevel: Int,
         issueAuthority: String,
         sourceAPI: String) {
        self.id = id
        self.name = name
        self.description = description
        self.waypoints = waypoints
        self.evacuationType = evacuationType
        self.estimatedTravelTime = estimatedTravelTime
        self.lastUpdated = lastUpdated
        self.safetyLevel = safetyLevel
        self.issueAuthority = issueAuthority
        self.sourceAPI = sourceAPI
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, waypoints, evacuationType
        case estimatedTravelTime, lastUpdated, safetyLevel
        case issueAuthority, sourceAPI
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        // Decode waypoints from array of [longitude, latitude] arrays
        let waypointsData = try container.decode([[Double]].self, forKey: .waypoints)
        waypoints = waypointsData.compactMap { point in
            guard point.count >= 2 else { return nil }
            // Convert [longitude, latitude] to CLLocationCoordinate2D
            return CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
        }
        
        evacuationType = try container.decode(EvacuationType.self, forKey: .evacuationType)
        estimatedTravelTime = try container.decode(TimeInterval.self, forKey: .estimatedTravelTime)
        
        let dateFormatter = ISO8601DateFormatter()
        let dateString = try container.decode(String.self, forKey: .lastUpdated)
        lastUpdated = dateFormatter.date(from: dateString) ?? Date()
        
        safetyLevel = try container.decode(Int.self, forKey: .safetyLevel)
        issueAuthority = try container.decode(String.self, forKey: .issueAuthority)
        sourceAPI = try container.decode(String.self, forKey: .sourceAPI)
    }
}
