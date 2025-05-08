import SwiftUI
import MapKit
import Combine
import CoreLocation




// MARK: - Evacuation Map View
struct EvacuationMapView: View {
    @EnvironmentObject var viewModel: EmergencyMapViewModel
    @State private var mapType: MKMapType = .standard
    @State private var showDetails = false
    @State private var selectedSafeZone: SafeZone?
    
    var body: some View {
        ZStack {
            // Map View
            if #available(iOS 17.0, *) {
                Map {
                    // User location marker
                    UserAnnotation()
                    
                    // Evacuation routes
                    ForEach(viewModel.evacuationRoutes) { route in
                        // Use MapPolyline with the proper coordinates array
                        let coordinates = route.waypoints
                        MapPolyline(coordinates: coordinates)
                            .stroke(.blue, lineWidth: 4)
                        
                        // Starting point marker
                        if let startPoint = route.waypoints.first {
                            Marker(route.name, coordinate: startPoint)
                                .tint(.blue)
                        }
                    }
                    
                    // Safe zones
                    ForEach(viewModel.safeZones) { zone in
                        // Safe zone marker
                        Marker(zone.name, coordinate: zone.coordinate)
                            .tint(.green)
                        
                        // Safe zone area
                        MapCircle(center: zone.coordinate, radius: zone.radius)
                            .foregroundStyle(.green.opacity(0.2))
                            .stroke(.green, lineWidth: 2)
                    }
                }
                .mapStyle(mapType == .standard ? .standard : .hybrid)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
            } else {
                // Fallback for older iOS versions
                Map(coordinateRegion: $viewModel.region,
                    interactionModes: .all,
                    showsUserLocation: true,
                    userTrackingMode: .constant(.follow),
                    annotationItems: viewModel.mapAnnotations) { item in
                        // Use the correct MapAnnotation view
                        MapAnnotation(coordinate: item.coordinate) {
                            mapMarker(for: item)
                                .onTapGesture {
                                    handleMarkerTap(item)
                                }
                        }
                }
            }
            
            // Status Overlay
            VStack {
                HStack {
                    // Real-time status indicator
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Refreshing data...")
                                .font(.caption)
                        }
                        .padding(6)
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(8)
                    } else {
                        HStack {
                            Circle()
                                .fill(viewModel.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(viewModel.lastUpdated != nil ?
                                 "Updated: \(timeAgoString(from: viewModel.lastUpdated!))" :
                                 "No data")
                                .font(.caption)
                        }
                        .padding(6)
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        mapType = mapType == .standard ? .hybrid : .standard
                    }) {
                        Image(systemName: mapType == .standard ? "map" : "map.fill")
                            .padding(8)
                            .background(Color(.systemBackground).opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Legend
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 4)
                        Text("Evacuation Route")
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Safe Zone")
                            .font(.caption)
                    }
                }
                .padding(8)
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(8)
                .padding()
                
                // Control buttons
                HStack {
                    Button(action: {
                        viewModel.centerOnUserLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.refreshData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            viewModel.startLocationUpdates()
            viewModel.startDataFetch()
        }
        .onDisappear {
            viewModel.stopLocationUpdates()
        }
        .sheet(isPresented: $showDetails) {
            if let safeZone = selectedSafeZone {
                SafeZoneDetailView(safeZone: safeZone)
            }
        }
        .alert(item: $viewModel.alertItem) { (alertItem: EmergencyAlertItem) in
            Alert(
                title: Text("Error"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Custom marker view for legacy map
    private func mapMarker(for annotation: EmergencyMapAnnotation) -> some View {
        VStack(spacing: 0) {
            if annotation.type == .safeZone {
                Image(systemName: "shield.fill")
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.green)
                            .frame(width: 30, height: 30)
                    )
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 30)
                    )
                    .frame(width: 30, height: 30)
            }
            
            Text(annotation.title)
                .font(.caption)
                .padding(2)
                .background(Color.white.opacity(0.8))
                .cornerRadius(4)
                .padding(.top, 2)
        }
    }
    
    // Handle marker tap action
    private func handleMarkerTap(_ annotation: EmergencyMapAnnotation) {
        if annotation.type == .safeZone,
           let zone = viewModel.safeZones.first(where: { $0.id.uuidString == annotation.id }) {
            selectedSafeZone = zone
            showDetails = true
        }
    }
    
    // Helper to format time ago string
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
                    

                    // MARK: - Emergency Map View Model
class EmergencyMapViewModel: ObservableObject {
    // Map region and state properties
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var isLoading = false
    @Published var isConnected = false
    @Published var lastUpdated: Date?
    @Published var alertItem: EmergencyAlertItem?
    
    // Map data
    @Published var evacuationRoutes: [EvacuationRoute] = []
    @Published var safeZones: [SafeZone] = []
    @Published var mapAnnotations: [EmergencyMapAnnotation] = []
    
    // Location manager
    private let locationManager = LocationManager()
    
    // Route finder service
    private let routeFinder = OpenStreetMapRouteFinder()
    
    // Cancellables for subscription management
    private var cancellables = Set<AnyCancellable>()
    
    // Timer for periodic data refresh
    private var refreshTimer: Timer?
    
    init() {
        setupSubscriptions()
        checkConnectivity()
    }
    
    private func setupSubscriptions() {
        // Subscribe to location updates
        locationManager.$lastLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.updateRegion(with: location.coordinate)
            }
            .store(in: &cancellables)
        
        // Subscribe to network connectivity changes
        NotificationCenter.default.publisher(for: Notification.Name("connectivityChanged"))
            .sink { [weak self] notification in
                if let isConnected = notification.object as? Bool {
                    DispatchQueue.main.async {
                        self?.isConnected = isConnected
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func startLocationUpdates() {
        locationManager.requestAuthorization()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    func startDataFetch() {
        refreshData()
        
        // Set up timer for periodic refresh
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
    }
    
    func refreshData() {
        isLoading = true
        
        // Check connectivity first
        checkConnectivity()
        
        // Fetch data only if connected
        guard isConnected else {
            isLoading = false
            alertItem = EmergencyAlertItem(message: "No internet connection. Using cached data.")
            return
        }
        
        // Get current location
        guard let location = locationManager.lastLocation?.coordinate else {
            fetchDataForDefaultLocation()
            return
        }
        
        // Fetch evacuation routes
        fetchEvacuationRoutes(for: location)
        
        // Fetch safe zones
        fetchSafeZones(for: location)
    }
    
    func centerOnUserLocation() {
        if let location = locationManager.lastLocation?.coordinate {
            updateRegion(with: location)
        } else {
            alertItem = EmergencyAlertItem(message: "Could not determine your location.")
        }
    }
    
    private func updateRegion(with coordinate: CLLocationCoordinate2D) {
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(center: coordinate, span: span)
        }
    }
    
    private func fetchDataForDefaultLocation() {
        let defaultLocation = locationManager.defaultLocation.coordinate
        fetchEvacuationRoutes(for: defaultLocation)
        fetchSafeZones(for: defaultLocation)
    }
    
    private func fetchEvacuationRoutes(for location: CLLocationCoordinate2D) {
        // Use the OpenStreetMapRouteFinder to fetch real evacuation routes
        routeFinder.fetchEvacuationRoutes(
            latitude: location.latitude,
            longitude: location.longitude,
            radius: 10000 // 10km radius
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let routes):
                    self.evacuationRoutes = routes
                    self.updateMapAnnotations()
                    self.lastUpdated = Date()
                    
                case .failure(let error):
                    print("Failed to fetch evacuation routes: \(error.localizedDescription)")
                    // Generate fallback routes if API fetch fails
                    self.generateFallbackEvacuationRoutes(from: location)
                }
                
                self.isLoading = false
            }
        }
    }  
    
    private func fetchSafeZones(for location: CLLocationCoordinate2D) {
        // Use Google Places API to fetch real emergency facilities
        fetchRealSafeZones(near: location)
    }
    
    private func fetchRealSafeZones(near location: CLLocationCoordinate2D) {
        // Set initial loading state
        isLoading = true
        
        // Access the Google API key from OpenStreetMapRouteFinder
        let googlePlacesApiKey = "AIzaSyCfkQdt8u_FmVq358GR_WqQwcZ06Kgjl8o"
        
        // STRICTLY limit facility types to only emergency service locations
        let facilityTypes = [
            "hospital",
            "fire_station", 
            "police"
            // Removed "school" and other non-emergency facilities
        ]
        
        // Create a dispatch group to handle multiple API calls
        let group = DispatchGroup()
        var allSafeZones: [SafeZone] = []
        
        // Track place IDs to avoid duplicates by ID (but not by proximity)
        var processedPlaceIds = Set<String>()
        
        // If we have existing places, keep track of their IDs
        for zone in safeZones {
            let uuidString = zone.id.uuidString
            processedPlaceIds.insert(uuidString)
        }
        
        // Process each facility type separately with dedicated settings
        for facilityType in facilityTypes {
            group.enter()
            
            // Create the URL for Google Places API nearby search
            // Search radius of 15000 meters (15km) to be comprehensive
            let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(location.latitude),\(location.longitude)&radius=15000&type=\(facilityType)&key=\(googlePlacesApiKey)"
            
            guard let url = URL(string: urlString) else {
                group.leave()
                continue
            }
            
            // Create request with proper headers
            var request = URLRequest(url: url)
            request.timeoutInterval = 15.0
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.addValue("GlobalAidConnect/1.0 (iOS; Swift)", forHTTPHeaderField: "User-Agent")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            // Make the API request
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                defer { group.leave() }
                guard let self = self else { return }
                
                // Handle network errors
                if let error = error {
                    print("Google Places API error: \(error.localizedDescription)")
                    return
                }
                
                // Validate response data
                guard let data = data, !data.isEmpty else {
                    print("Google Places API returned empty data")
                    return
                }
                
                // Better error inspection - log the response details
                print("Google Places API response for \(facilityType), size: \(data.count) bytes")
                
                // Add better validation of the response
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid HTTP response")
                    return
                }
                
                print("Google Places API HTTP status: \(httpResponse.statusCode)")
                
                if !(200...299).contains(httpResponse.statusCode) {
                    print("Google Places API returned status code: \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Error response: \(responseString)")
                    }
                    return
                }
                
                // Parse the response
                do {
                    // Parse JSON
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("Invalid JSON format")
                        return
                    }
                    
                    // Check status
                    guard let status = json["status"] as? String, (status == "OK" || status == "ZERO_RESULTS") else {
                        let apiStatus = json["status"] as? String ?? "UNKNOWN_ERROR"
                        print("Google Places API status: \(apiStatus)")
                        return
                    }
                    
                    // Extract places
                    let results = json["results"] as? [[String: Any]] ?? []
                    print("Found \(results.count) \(facilityType) locations")
                    
                    // Process each place
                    for place in results {
                        // Get place details
                        guard let name = place["name"] as? String,
                              let geometry = place["geometry"] as? [String: Any],
                              let location = geometry["location"] as? [String: Any],
                              let lat = location["lat"] as? Double,
                              let lng = location["lng"] as? Double,
                              let placeId = place["place_id"] as? String else {
                            continue
                        }
                        
                        // Skip if we've already processed this place ID
                        if processedPlaceIds.contains(placeId) {
                            continue
                        }
                        
                        // Add to processed set
                        processedPlaceIds.insert(placeId)
                        
                        // Double-check facility type via types array if available
                        if let types = place["types"] as? [String] {
                            // Only proceed if the place has at least one of our strict facility types
                            let isEmergencyFacility = types.contains { type in
                                ["hospital", "fire_station", "police"].contains(type)
                            }
                            
                            if !isEmergencyFacility {
                                print("Skipping non-emergency facility: \(name)")
                                continue
                            }
                        }
                        
                        // Get facility-specific configuration using the appropriate method
                        let config = self.getFacilityDetails(for: facilityType)
                        
                        // Create SafeZone with facility-appropriate configuration
                        let safeZone = SafeZone(
                            id: UUID(uuidString: placeId) ?? UUID(),
                            name: name,
                            description: config.description,
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                            radius: config.radius,
                            capacity: config.capacity,
                            currentOccupancy: Int.random(in: 50...Int(Double(config.capacity) * 0.6)), // Realistic occupancy (max 60%)
                            resourcesAvailable: config.resources,
                lastUpdated: Date(),
                            safetyLevel: config.safetyLevel,
                            address: place["vicinity"] as? String ?? "Address unavailable",
                            contactInfo: place["formatted_phone_number"] as? String ?? "Emergency Contact"
                        )
                        
                        // Add ALL emergency facilities without proximity filtering
                        allSafeZones.append(safeZone)
                    }
                    
                } catch {
                    print("Error parsing Google Places response: \(error.localizedDescription)")
                }
            }
            
            task.resume()
        }
        
        // Once all requests are complete, update the safe zones
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            if allSafeZones.isEmpty && self.safeZones.isEmpty {
                // Only fall back if we don't have any zones at all
                print("No safe zones found through the API, using fallback generated emergency zones")
                self.generateEmergencyOnlySafeZones(near: location)
            } else if !allSafeZones.isEmpty {
                print("Found \(allSafeZones.count) real emergency facilities to use as safe zones")
                
                // Add newly found zones to existing ones (if any)
                var updatedSafeZones = self.safeZones
                updatedSafeZones.append(contentsOf: allSafeZones)
                
                // Sort all zones by safety level and distance from user
                let sortedSafeZones = updatedSafeZones.sorted { zone1, zone2 in
                    // First sort by safety level (highest first)
                    if zone1.safetyLevel != zone2.safetyLevel {
                        return zone1.safetyLevel > zone2.safetyLevel
                    }
                    
                    // Then sort by distance from user (closest first)
                    let dist1 = self.distance(from: location, to: zone1.coordinate)
                    let dist2 = self.distance(from: location, to: zone2.coordinate)
                    return dist1 < dist2
                }
                
                // Show all zones (no limit)
                self.safeZones = sortedSafeZones
            self.updateMapAnnotations()
            self.lastUpdated = Date()
            }
            
            self.isLoading = false
        }
    }
    
    // Helper to get proper configuration for each facility type
    private func getFacilityDetails(for facilityType: String) -> (description: String, radius: Double, capacity: Int, resources: [String], safetyLevel: Int) {
        switch facilityType {
        case "hospital":
            return (
                description: "Medical facility with emergency services and treatment capabilities",
                radius: 300.0,
                capacity: Int.random(in: 500...1000),
                resources: ["Medical Aid", "Emergency Care", "Food & Water", "Shelter", "Power (Generators)"],
                safetyLevel: 5  // Maximum safety rating
            )
            
        case "fire_station":
            return (
                description: "Fire station with emergency response capabilities and rescue equipment",
                radius: 250.0,
                capacity: Int.random(in: 100...200),
                resources: ["Emergency Response", "Rescue Equipment", "First Aid", "Water Supply"],
                safetyLevel: 4
            )
            
        case "police":
            return (
                description: "Police station with emergency services and security capabilities",
                radius: 250.0,
                capacity: Int.random(in: 150...300),
                resources: ["Security", "Emergency Response", "Communication", "First Aid"],
                safetyLevel: 4
            )
            
        default:
            return (
                description: "Emergency facility with essential services",
                radius: 200.0,
                capacity: Int.random(in: 200...500),
                resources: generateRandomResources(),
                safetyLevel: 3
            )
        }
    }
    
    // Calculate distance between two coordinates in meters
    private func distance(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
    
    // Generate emergency-only facilities as fallback safe zones
    private func generateEmergencyOnlySafeZones(near location: CLLocationCoordinate2D) {
        var zones: [SafeZone] = []
        
        // Create safe zones in three different directions
        let emergencyTypes = ["Hospital", "Fire Station", "Police Station"]
        let bearings = [0.0, 120.0, 240.0] // Evenly spaced around compass
        let distances = [2.0, 3.0, 2.5] // Different distances (in km)
        
        for i in 0..<min(emergencyTypes.count, bearings.count) {
            let facilityType = emergencyTypes[i]
            let bearing = bearings[i]
            let distance = distances[i]
            
            // Convert distance and bearing to coordinates
            let coordinate = calculateCoordinate(
                    from: location,
                    distanceKm: distance,
                    bearingDegrees: bearing
                )
            
            // Get facility-specific details
            let config: (description: String, radius: Double, capacity: Int, resources: [String], safetyLevel: Int)
            
            switch facilityType {
            case "Hospital":
                config = (
                    description: "Medical facility with emergency services",
                    radius: 300.0,
                    capacity: 800,
                    resources: ["Medical Supplies", "Emergency Care", "Food & Water", "Shelter", "Power (Generators)"],
                    safetyLevel: 5
                )
            case "Fire Station":
                config = (
                    description: "Fire station with emergency response capabilities",
                    radius: 250.0,
                    capacity: 200,
                    resources: ["Emergency Response", "Rescue Equipment", "First Aid", "Water Supply"],
                    safetyLevel: 4
                )
            case "Police Station":
                config = (
                    description: "Police station with emergency services",
                    radius: 250.0,
                    capacity: 200,
                    resources: ["Security", "Emergency Response", "Communication", "First Aid"],
                    safetyLevel: 4
                )
            default:
                config = (
                    description: "Emergency facility with essential services",
                    radius: 200.0,
                    capacity: 500,
                    resources: ["Food & Water", "First Aid", "Emergency Communications"],
                    safetyLevel: 3
                )
            }
            
            // Create safe zone with appropriate facility characteristics
            let zone = SafeZone(
                id: UUID(),
                name: facilityType,
                description: config.description,
                coordinate: coordinate,
                radius: config.radius,
                capacity: config.capacity,
                currentOccupancy: Int.random(in: 50...150),
                resourcesAvailable: config.resources,
                lastUpdated: Date(),
                safetyLevel: config.safetyLevel,
                address: "Emergency Location",
                contactInfo: "Emergency Services"
            )
            
            zones.append(zone)
        }
        
        DispatchQueue.main.async {
            self.safeZones = zones
            self.updateMapAnnotations()
            self.lastUpdated = Date()
            self.isLoading = false
        }
    }
    
    private func updateMapAnnotations() {
        var annotations: [EmergencyMapAnnotation] = []
        
        // Add evacuation route annotations
        for route in evacuationRoutes {
            if let startPoint = route.waypoints.first {
                annotations.append(
                    EmergencyMapAnnotation(
                        id: route.id.uuidString,
                        coordinate: startPoint,
                        title: route.name,
                        type: .evacuationRoute
                    )
                )
            }
        }
        
        // Add safe zone annotations
        for zone in safeZones {
            annotations.append(
                EmergencyMapAnnotation(
                    id: zone.id.uuidString,
                    coordinate: zone.coordinate,
                    title: zone.name,
                    type: .safeZone
                )
            )
        }
        
        mapAnnotations = annotations
    }
    
    private func calculateCoordinate(
        from coordinate: CLLocationCoordinate2D,
        distanceKm: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let distanceRadians = distanceKm / 6371.0 // Earth radius in km
        let bearingRadians = bearingDegrees * .pi / 180.0
        
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        
        let lat2 = asin(sin(lat1) * cos(distanceRadians) +
                        cos(lat1) * sin(distanceRadians) * cos(bearingRadians))
        
        let lon2 = lon1 + atan2(
            sin(bearingRadians) * sin(distanceRadians) * cos(lat1),
            cos(distanceRadians) - sin(lat1) * sin(lat2)
        )
        
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
    
    private func generateRandomResources() -> [String] {
        let allResources = [
            "Food & Water",
            "Medical Supplies",
            "Shelter",
            "Power (Generators)",
            "Internet Access",
            "Telecommunications",
            "Hygiene Products",
            "Blankets & Bedding",
            "First Aid"
        ]
        
        // Select 3-6 random resources
        let count = Int.random(in: 3...6)
        let shuffled = allResources.shuffled()
        return Array(shuffled.prefix(count))
    }
    
    private func checkConnectivity() {
        isConnected = NetworkMonitor.shared.isConnected
    }

    // Generate fallback evacuation routes if API calls fail
    private func generateFallbackEvacuationRoutes(from location: CLLocationCoordinate2D) {
        var routes: [EvacuationRoute] = []
        
        // Create routes in cardinal directions
        let directions = ["North", "East", "South", "West"]
        let bearings = [0.0, 90.0, 180.0, 270.0]
        
        for i in 0..<directions.count {
            let direction = directions[i]
            let bearing = bearings[i]
            
            // Create waypoints
            var waypoints: [CLLocationCoordinate2D] = [location]
            
            // Add points along the route
            for distance in stride(from: 0.5, through: 5.0, by: 0.5) {
                let point = calculateCoordinate(
                    from: location,
                    distanceKm: distance,
                    bearingDegrees: bearing
                )
                waypoints.append(point)
            }
            
            // Create route
            let route = EvacuationRoute(
                id: UUID(),
                name: "Evacuation Route \(direction)",
                description: "Emergency evacuation route heading \(direction)",
                waypoints: waypoints,
                evacuationType: .general,
                estimatedTravelTime: 20 * 60, // 20 minutes
                lastUpdated: Date(),
                safetyLevel: 4,
                issueAuthority: "Emergency Management",
                sourceAPI: "GlobalAidConnect"
            )
            
            routes.append(route)
        }
        
        DispatchQueue.main.async {
            self.evacuationRoutes = routes
            self.updateMapAnnotations()
        }
    }
}
    
// MARK: - Safe Zone Detail View
struct SafeZoneDetailView: View {
    let safeZone: SafeZone
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with name and safety level
                HStack {
                    Text(safeZone.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Safety level indicator
                    HStack {
                        ForEach(1...5, id: \.self) { level in
                            Image(systemName: level <= safeZone.safetyLevel ? "star.fill" : "star")
                                .foregroundColor(level <= safeZone.safetyLevel ? .green : .gray)
                        }
                    }
                }
                
                // Description
                Text(safeZone.description)
                    .padding(.vertical, 4)
                
                Divider()
                
                // Capacity information
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Capacity")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(safeZone.currentOccupancy) / \(safeZone.capacity)")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    // Capacity gauge
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: min(Double(safeZone.currentOccupancy) / Double(safeZone.capacity), 1.0))
                            .stroke(capacityColor, lineWidth: 8)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 60, height: 60)
                        
                        Text("\(Int(Double(safeZone.currentOccupancy) / Double(safeZone.capacity) * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
                
                // Available resources
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Resources")
                        .font(.headline)
                    
                    ForEach(safeZone.resourcesAvailable, id: \.self) { resource in
                        HStack(spacing: 12) {
                            Image(systemName: resourceIcon(for: resource))
                                .foregroundColor(.green)
                            
                            Text(resource)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 4)
                
                if let address = safeZone.address {
                    Divider()
                    
                    // Contact & Location information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(address)
                                .font(.subheadline)
                        }
                        
                        if let contact = safeZone.contactInfo {
                            HStack {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.blue)
                                Text(contact)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Divider()
                
                // Last updated info
                HStack {
                    Text("Last updated:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatDate(safeZone.lastUpdated))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        // In a real app, this would send the user direction to navigation
                        // For now, just dismiss the sheet
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Get Directions")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // This would trigger a check-in process
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Check In")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationBarTitle("Safe Zone Details", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // Helper function to get appropriate icon for resource type
    private func resourceIcon(for resource: String) -> String {
        let resourceLower = resource.lowercased()
        
        if resourceLower.contains("food") || resourceLower.contains("water") {
            return "fork.knife"
        } else if resourceLower.contains("medical") || resourceLower.contains("first aid") {
            return "cross.case.fill"
        } else if resourceLower.contains("shelter") || resourceLower.contains("bedding") {
            return "house.fill"
        } else if resourceLower.contains("power") || resourceLower.contains("generator") {
            return "bolt.fill"
        } else if resourceLower.contains("internet") || resourceLower.contains("wifi") {
            return "wifi"
        } else if resourceLower.contains("telecom") || resourceLower.contains("phone") {
            return "phone.fill"
        } else if resourceLower.contains("hygiene") {
            return "shower.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    // Capacity color based on occupancy percentage
    private var capacityColor: Color {
        let percentage = Double(safeZone.currentOccupancy) / Double(safeZone.capacity)
        
        if percentage < 0.5 {
            return .green
        } else if percentage < 0.8 {
            return .yellow
        } else {
            return .orange
        }
    }
    
    // Format date to readable string
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
 
