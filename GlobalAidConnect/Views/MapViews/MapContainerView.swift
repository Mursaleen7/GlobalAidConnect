import SwiftUI
import MapKit
import Combine
import CoreLocation
import Network

// MARK: - MapContainerView (Main View)
struct MapContainerView: View {
    @EnvironmentObject var apiService: ApiService
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 45.0, longitudeDelta: 45.0)
    )
    @State private var selectedMapStyle: MapStyle = .standard
    @State private var selectedCrisis: Crisis? = nil {
        didSet {
            // Trigger a prediction when a crisis is first selected, if no prediction exists
            if let crisis = selectedCrisis, oldValue?.id != crisis.id {
                // Always fetch a new prediction when switching between crises
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("Selected crisis: \(crisis.name), starting prediction...")
                    // Force enable prediction overlays when a crisis is selected
                    self.showPredictionOverlays = true
                    
                    if self.apiService.crisisPredictions[crisis.id] == nil {
                        // If no prediction exists, start a new one
                        print("No existing prediction for \(crisis.name), generating new one...")
                        self.apiService.startLivePredictionUpdates(for: crisis.id)
                    } else {
                        // If prediction is more than 10 minutes old, refresh it
                        if let prediction = self.apiService.crisisPredictions[crisis.id],
                           Date().timeIntervalSince(prediction.timestamp) > 600 {
                            print("Prediction for \(crisis.name) is over 10 minutes old, refreshing...")
                            self.apiService.startLivePredictionUpdates(for: crisis.id)
                        } else {
                            print("Using existing recent prediction for \(crisis.name)")
                        }
                    }
                }
            }
        }
    }
    @State private var showFilterPanel = false
    @State private var showSafeZones = true
    @State private var showEvacuationRoutes = true
    @State private var showEmergencyServices = true
    @State private var showPredictionOverlays = true // Ensure this is true by default
    @State private var isZoomingToLocation = false
    @State private var cardOffset: CGFloat = 0
    @State private var cardHeight: CGFloat = 120
    @State private var animateUI = false
    
    enum MapStyle: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case satellite = "Satellite"
        case hybrid = "Hybrid"
        
        var id: String { self.rawValue }
        
        var mapType: MKMapType {
            switch self {
            case .standard: return .standard
            case .satellite: return .satellite
            case .hybrid: return .hybrid
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Map view
            ZStack(alignment: .topTrailing) {
                MapView(
                    region: $region,
                    mapStyle: selectedMapStyle.mapType,
                    showSafeZones: showSafeZones,
                    showEvacuationRoutes: showEvacuationRoutes,
                    showEmergencyServices: showEmergencyServices,
                    showPredictionOverlays: showPredictionOverlays,
                    selectedCrisis: $selectedCrisis,
                    isZoomingToLocation: $isZoomingToLocation,
                    apiService: apiService
                )
                .ignoresSafeArea()
                
                // Control panel for map options
                VStack(spacing: 0) {
                    mapStyleControl
                    
                    if showFilterPanel {
                        filterPanel
                    }
                }
                .padding(.top, 40)
                .padding(.trailing, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.5), value: showFilterPanel)
            }
            
            // Bottom card for crisis details or tools
            bottomControlPanel
        }
        .navigationBarTitle("Crisis Map", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        showFilterPanel.toggle()
                    }
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(Color.ui.accent)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.ui.secondaryBackground.opacity(0.8))
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        )
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    isZoomingToLocation = true
                }) {
                    Image(systemName: "location.fill")
                        .foregroundColor(Color.ui.accent)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.ui.secondaryBackground.opacity(0.8))
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        )
                }
            }
        }
        .onAppear {
            // Add a slight delay before starting animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    animateUI = true
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    private var mapStyleControl: some View {
        VStack(spacing: 8) {
            ForEach(MapStyle.allCases) { style in
                Button(action: {
                    selectedMapStyle = style
                }) {
                    Text(style.rawValue)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(width: 100)
                        .background(
                            Capsule()
                                .fill(style == selectedMapStyle 
                                      ? Color.ui.accent
                                      : Color.ui.secondaryBackground.opacity(0.8))
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        )
                        .foregroundColor(style == selectedMapStyle ? .white : Color.ui.primaryText)
                        .scaleEffect(animateUI ? 1.0 : 0.8)
                        .opacity(animateUI ? 1.0 : 0.0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(MapStyle.allCases.firstIndex(of: style) ?? 0) * 0.1 + 0.1),
                            value: animateUI
                        )
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.ui.secondaryBackground.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .opacity(0.05)
                        .blur(radius: 10)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 5)
        )
    }
    
    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Map Layers")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color.ui.primaryText)
                .padding(.top, 4)
            
            Toggle("Safe Zones", isOn: $showSafeZones)
                .toggleStyle(SwitchToggleStyle(tint: Color.ui.severityLow))
                .font(.system(size: 14, design: .rounded))
            
            Toggle("Evacuation Routes", isOn: $showEvacuationRoutes)
                .toggleStyle(SwitchToggleStyle(tint: Color.ui.categoryNatural))
                .font(.system(size: 14, design: .rounded))
            
            Toggle("Emergency Services", isOn: $showEmergencyServices)
                .toggleStyle(SwitchToggleStyle(tint: Color.ui.severityCritical))
                .font(.system(size: 14, design: .rounded))
            
            Toggle("Prediction Overlays", isOn: $showPredictionOverlays)
                .toggleStyle(SwitchToggleStyle(tint: Color.ui.accent))
                .font(.system(size: 14, design: .rounded))
        }
        .padding()
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.ui.secondaryBackground.opacity(0.8))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .opacity(0.05)
                        .blur(radius: 10)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .offset(y: animateUI ? 0 : -20)
        .opacity(animateUI ? 1 : 0)
    }
    
    private var bottomControlPanel: some View {
        ZStack(alignment: .top) {
            // Loading indicator overlaid on map when fetching prediction
            if apiService.isFetchingPrediction {
                VStack {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                        
                        Text("Generating impact prediction...")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .padding(.leading, 8)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.ui.secondaryBackground.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    )
                }
                .transition(.opacity)
                .zIndex(100)
                .padding(.top, 60)
            }
            
            // Main bottom panel
            VStack(spacing: 0) {
                if selectedCrisis != nil {
                    crisisDetailPanel
                } else {
                    toolsPanel
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.ui.secondaryBackground.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: -5)
            )
            .offset(y: cardOffset)
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .local)
                    .onChanged { value in
                        // Use direct assignment for maximum smoothness during drag
                        cardOffset = max(-350, min(120, value.translation.height))
                    }
                    .onEnded { value in
                        // Use velocity to determine where the card should settle
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        
                        // Apply stronger spring animation for more natural feel
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75, blendDuration: 0.1)) {
                            if value.translation.height > 50 || (value.translation.height > 0 && velocity > 150) {
                                // Collapse to bottom when dragged down
                                cardOffset = 120
                            } else if value.translation.height < -50 || (value.translation.height < 0 && velocity < -150) {
                                // Expand fully when dragged up
                                cardOffset = -350
                            } else {
                                // Return to default position
                                cardOffset = 0
                            }
                        }
                    }
            )
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.25), value: selectedCrisis)
            .offset(y: animateUI ? 0 : 150)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateUI)
        }
    }
    
    private var crisisDetailPanel: some View {
        VStack(spacing: 16) {
            // Handle indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            if let crisis = selectedCrisis {
                // Crisis info
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Header with title and severity
                        HStack {
                            Text(crisis.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Color.ui.primaryText)
                            
                            Spacer()
                            
                            // Severity indicator
                            HStack(spacing: 4) {
                                Text("Severity:")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(Color.ui.secondaryText)
                                
                                ForEach(1...5, id: \.self) { level in
                                    Circle()
                                        .fill(level <= crisis.severity 
                                              ? getSeverityColor(for: crisis.severity) 
                                              : Color.gray.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                        
                        // Location and date
                        HStack {
                            Text(crisis.location)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(Color.ui.secondaryText)
                            
                            Spacer()
                            
                            Text(formatDate(crisis.startDate))
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(Color.ui.secondaryText)
                        }
                    }
                    
                    // Description
                    Text(crisis.description)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Color.ui.secondaryText)
                        .lineLimit(cardOffset < 0 ? nil : 2)
                    
                    // Expanded content for when panel is pulled up
                    if cardOffset < 0 {
                        // Stats row
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Population")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(Color.ui.tertiaryText)
                                
                                Text("\(crisis.affectedPopulation.formatted())")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.ui.primaryText)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Duration")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(Color.ui.tertiaryText)
                                
                                Text(timeAgo(from: crisis.startDate))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.ui.primaryText)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 8)
                        
                        // NEW: Show prediction info if available
                        if let prediction = apiService.crisisPredictions[crisis.id] {
                            predictionDetailView(for: prediction)
                        } else {
                            VStack(spacing: 8) {
                                Text("No prediction data available")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(Color.ui.secondaryText)
                                
                                Button(action: {
                                    apiService.startLivePredictionUpdates(for: crisis.id)
                                }) {
                                    HStack {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 16))
                                        Text("Generate Impact Prediction")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.ui.accent, Color.ui.accent.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .shadow(color: Color.ui.accent.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                            .padding(.top, 8)
                        }
                        
                        // Action buttons
                        VStack(spacing: 8) {
                            Button("Navigate to Safe Zone") {
                                // Action
                            }
                            .buttonStyle(AccentButtonStyle(isWide: true))
                            
                            Button("Find Emergency Services") {
                                // Action
                            }
                            .buttonStyle(AccentButtonStyle(isWide: true))
                        }
                        .padding(.top, 8)
                    }
                    
                    // Actions for collapsed view
                    if cardOffset >= 0 {
                        HStack {
                            Button("Safe Zones") {
                                // Action
                            }
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.ui.severityLow)
                            )
                            
                            Spacer()
                            
                            Button("View Details") {
                                withAnimation {
                                    cardOffset = -300
                                }
                            }
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.ui.accent)
                            )
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // NEW: Prediction details view
    private func predictionDetailView(for prediction: CrisisPrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Impact Prediction")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.ui.primaryText)
                
                Spacer()
                
                // Add refresh button
                Button(action: {
                    if let crisis = selectedCrisis {
                        apiService.startLivePredictionUpdates(for: crisis.id)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(Color.ui.accent)
                }
                .padding(.trailing, 4)
                
                // Add timestamp to show when prediction was last updated
                Text("Last updated: \(timeAgo(from: prediction.timestamp))")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color.ui.secondaryText)
            }
            
            if apiService.isFetchingPrediction {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Updating prediction...")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Color.ui.secondaryText)
                        .padding(.leading, 8)
                }
            } else {
                Text(prediction.predictionNarrative)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(Color.ui.secondaryText)
                    .padding(.bottom, 4)
                
                if let newAffected = prediction.estimatedNewAffectedPopulation, newAffected > 0 {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(Color.ui.severityHigh)
                        Text("Est. additional affected: \(newAffected) people")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Color.ui.severityHigh)
                    }
                }
                
                if let infrastructure = prediction.criticalInfrastructureAtRisk, !infrastructure.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Critical Infrastructure at Risk:")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Color.ui.primaryText)
                        
                        ForEach(infrastructure.prefix(2), id: \.self) { item in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color.ui.severityHigh)
                                    .font(.system(size: 12))
                                Text(item)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(Color.ui.secondaryText)
                            }
                        }
                    }
                }
                
                HStack {
                    Button("Refresh Prediction") {
                        apiService.startLivePredictionUpdates(for: prediction.id)
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.ui.accent)
                    )
                    .foregroundColor(.white)
                    
                    if !showPredictionOverlays {
                        Button("Show on Map") {
                            showPredictionOverlays = true
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.ui.accent.opacity(0.7))
                        )
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.ui.secondaryBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private var toolsPanel: some View {
        VStack(spacing: 16) {
            // Handle indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            // Crisis count
            if let crises = apiService.activeCrises {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Crises")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color.ui.primaryText)
                        
                        Text("\(crises.count) incidents worldwide")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Zoom out to global view
                        withAnimation {
                            region = MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 30.0, longitude: 0.0),
                                span: MKCoordinateSpan(latitudeDelta: 45.0, longitudeDelta: 45.0)
                            )
                        }
                    }) {
                        Image(systemName: "globe")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.ui.accentGradient)
                            )
                            .shadow(color: Color.ui.accent.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
            }
            
            // Quick filter buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    filterButton(title: "All", icon: "rectangle.grid.2x2", color: Color.ui.accent, isActive: true)
                    filterButton(title: "Natural", icon: "flame", color: Color.ui.categoryNatural)
                    filterButton(title: "Health", icon: "cross", color: Color.ui.categoryHealth)
                    filterButton(title: "Conflict", icon: "exclamationmark.triangle", color: Color.ui.categoryConflict)
                    filterButton(title: "Humanitarian", icon: "person.3", color: Color.ui.categoryHumanitarian)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }      
    
    private func filterButton(title: String, icon: String, color: Color, isActive: Bool = false) -> some View {
        Button(action: {
            // Filter action
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? color : Color.ui.secondaryBackground)
                    .overlay(
                        Capsule()
                            .stroke(color, lineWidth: isActive ? 0 : 1)
                    )
            )
            .foregroundColor(isActive ? .white : color)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getSeverityColor(for severity: Int) -> Color {
        switch severity {
        case 1:
            return Color.ui.severityLow
        case 2:
            return Color.ui.severityMedium
        case 3:
            return Color.ui.severityHigh
        case 4:
            return Color.ui.severityCritical
        case 5:
            return Color.ui.severityExtreme
        default:
            return Color.ui.severityLow
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // Helper to display relative time
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return day == 1 ? "Yesterday" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour ago" : "\(hour) hours ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 minute ago" : "\(minute) minutes ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Map View (Keep existing implementation and enhance)
struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var mapStyle: MKMapType
    var showSafeZones: Bool
    var showEvacuationRoutes: Bool
    var showEmergencyServices: Bool
    var showPredictionOverlays: Bool
    @Binding var selectedCrisis: Crisis?
    @Binding var isZoomingToLocation: Bool
    var apiService: ApiService
    
    // Custom pin colors for map markers
    private let crisisColors: [Int: UIColor] = [
        1: UIColor(Color.ui.severityLow),
        2: UIColor(Color.ui.severityMedium),
        3: UIColor(Color.ui.severityHigh),
        4: UIColor(Color.ui.severityCritical),
        5: UIColor(Color.ui.severityExtreme)
    ]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.region = region
        mapView.mapType = mapStyle
        
        // Add a long press gesture recognizer for adding user-defined markers
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.addPinOnLongPress(gesture:)))
        mapView.addGestureRecognizer(longPressGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map type when it changes
        if mapView.mapType != mapStyle {
            mapView.mapType = mapStyle
        }
        
        // Handle zooming to user location
        if isZoomingToLocation {
            mapView.setUserTrackingMode(.follow, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isZoomingToLocation = false
            }
        }
        
        // Update pins from crises data
        updatePins(on: mapView)
        
        // Update routes and zones based on toggles
        updateMapOverlays(on: mapView)
        
        // NEW: Update prediction overlays
        updatePredictionOverlays(on: mapView)
    }
    
    // NEW: Update prediction overlays
    private func updatePredictionOverlays(on mapView: MKMapView) {
        // Remove existing prediction overlays
        mapView.overlays.forEach { overlay in
            if overlay is CrisisPredictionHeatmapOverlay || overlay is CrisisPredictionPolygonOverlay {
                mapView.removeOverlay(overlay)
            }
        }
        
        // Only add overlays if the toggle is enabled
        guard showPredictionOverlays else { return }
        
        print("Adding prediction overlays - predictions count: \(apiService.crisisPredictions.count)")
        
        // Add overlays for each crisis that has predictions
        for (crisisId, prediction) in apiService.crisisPredictions {
            // Log prediction points for debugging
            if let heatmapPoints = prediction.riskHeatmapPoints {
                print("Adding \(heatmapPoints.count) heatmap points for crisis \(crisisId)")
            }
            
            // Ensure the selected crisis predictions are always visible
            let isSelectedCrisis = selectedCrisis?.id == crisisId
            
            // Add risk heatmap points
            if let heatmapPoints = prediction.riskHeatmapPoints {
                for point in heatmapPoints {
                    let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                    
                    // Make higher intensity points have larger radius
                    let radius = 1000.0 + (5000.0 * point.intensity) // between 1km and 6km for better visibility
                    
                    let overlay = CrisisPredictionHeatmapOverlay.createOverlay(
                        center: coordinate,
                        radius: radius,
                        intensity: point.intensity,
                        crisisId: crisisId
                    )
                    
                    mapView.addOverlay(overlay)
                }
            }
            
            // Add predicted spread polygons
            if let polygons = prediction.predictedSpreadPolygons {
                for polygon in polygons {
                    // Need at least 3 points for a polygon
                    guard polygon.count >= 3 else { continue }
                    
                    let coordinates = polygon.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    
                    // Create the polygon overlay
                    if let polygonOverlay = CrisisPredictionPolygonOverlay.createOverlay(coordinates: coordinates, crisisId: crisisId) {
                        mapView.addOverlay(polygonOverlay)
                    }
                }
            }
            
            // If this is the selected crisis, center the map on it if needed
            if isSelectedCrisis && prediction.riskHeatmapPoints?.isEmpty == false {
                // Only zoom to prediction if we haven't manually panned the map
                if let firstPoint = prediction.riskHeatmapPoints?.first {
                    let center = CLLocationCoordinate2D(latitude: firstPoint.latitude, longitude: firstPoint.longitude)
                    let span = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                    let region = MKCoordinateRegion(center: center, span: span)
                    mapView.setRegion(region, animated: true)
                }
            }
        }
    }
    
    private func updatePins(on mapView: MKMapView) {
        // ... existing code ...
        
        // Replace existing pins with new ones
        let annotations = mapView.annotations.filter { $0 is CrisisAnnotation }
        mapView.removeAnnotations(annotations)
        
        if let crises = apiService.activeCrises {
            let newAnnotations = crises.compactMap { crisis -> CrisisAnnotation? in
                guard let coordinates = crisis.coordinates else { return nil }
                return CrisisAnnotation(
                    coordinate: CLLocationCoordinate2D(
                        latitude: coordinates.latitude,
                        longitude: coordinates.longitude
                    ),
                    crisis: crisis
                )
            }
            mapView.addAnnotations(newAnnotations)
        }
    }
    
    private func updateMapOverlays(on mapView: MKMapView) {
        // Remove existing safe zone annotations if the toggle is off
        let existingSafeZones = mapView.annotations.filter { $0 is SafeZoneAnnotation }
        if !showSafeZones || existingSafeZones.count > 0 {
            mapView.removeAnnotations(existingSafeZones)
        }
        
        // Remove existing evacuation route overlays if the toggle is off
        let existingRoutes = mapView.overlays.filter { $0 is MKPolyline }
        if !showEvacuationRoutes || existingRoutes.count > 0 {
            mapView.removeOverlays(existingRoutes)
        }
        
        // Remove existing emergency service annotations if the toggle is off
        let existingServices = mapView.annotations.filter { $0 is EmergencyServiceAnnotation }
        if !showEmergencyServices || existingServices.count > 0 {
            mapView.removeAnnotations(existingServices)
        }
        
        // Fetch and display safe zones if enabled
        if showSafeZones {
            // Get the map's current center and a reasonable radius
            let center = mapView.region.center
            let radius = max(mapView.region.span.latitudeDelta, mapView.region.span.longitudeDelta) * 111000 // Convert degrees to meters (approx)
            
            // Fetch safe zones using Google Places API
            fetchSafeZones(latitude: center.latitude, longitude: center.longitude, radius: radius) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let safeZones):
                        // Add safe zone annotations to the map
                        let annotations = safeZones.map { zone in
                            SafeZoneAnnotation(
                                coordinate: zone.coordinate,
                                safeZone: zone
                            )
                        }
                        mapView.addAnnotations(annotations)
                        
                        // Add circle overlays for each safe zone
                        for zone in safeZones {
                            let circle = MKCircle(center: zone.coordinate, radius: zone.radius)
                            mapView.addOverlay(circle)
                        }
                        
                    case .failure(let error):
                        print("Failed to fetch safe zones: \(error.localizedDescription)")
                        // Add some default safe zones if real data fails
                        self.addDefaultSafeZones(to: mapView, near: center)
                    }
                }
            }
        }
        
        // Fetch and display evacuation routes if enabled
        if showEvacuationRoutes {
            let center = mapView.region.center
            let radius = max(mapView.region.span.latitudeDelta, mapView.region.span.longitudeDelta) * 111000
            
            let routeFinder = OpenStreetMapRouteFinder()
            routeFinder.fetchEvacuationRoutes(latitude: center.latitude, longitude: center.longitude, radius: radius) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let routes):
                        // Add polyline overlays for each route
                        for route in routes {
                            let coordinates = route.waypoints
                            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                            mapView.addOverlay(polyline)
                        }
                        
                    case .failure(let error):
                        print("Failed to fetch evacuation routes: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Fetch and display emergency services if enabled
        if showEmergencyServices {
            let center = mapView.region.center
            let radius = max(mapView.region.span.latitudeDelta, mapView.region.span.longitudeDelta) * 111000
            
            fetchEmergencyServices(latitude: center.latitude, longitude: center.longitude, radius: radius) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let services):
                        // Add annotations for emergency services
                        let annotations = services.map { service in
                            EmergencyServiceAnnotation(
                                coordinate: service.coordinate,
                                title: service.name,
                                subtitle: service.type,
                                serviceType: service.type
                            )
                        }
                        mapView.addAnnotations(annotations)
                        
                    case .failure(let error):
                        print("Failed to fetch emergency services: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // Fetch safe zones using Google Places API
    private func fetchSafeZones(latitude: Double, longitude: Double, radius: Double, completion: @escaping (Result<[SafeZone], Error>) -> Void) {
        // Use Google Places API to find locations that can serve as safe zones
        let apiKey = "AIzaSyCfkQdt8u_FmVq358GR_WqQwcZ06Kgjl8o" // Reusing the existing API key
        
        // Types of places that can be used as safe zones
        let safeZoneTypes = [
            "hospital",
            "police",
            "fire_station",
            "school",
            "stadium",
            "community_center",
            "library",
            "local_government_office"
        ]
        
        // Create a dispatch group to handle multiple API requests
        let group = DispatchGroup()
        var allSafeZones: [SafeZone] = []
        var apiError: Error?
        
        for type in safeZoneTypes {
            group.enter()
            
            // Construct the Google Places API URL
            let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(latitude),\(longitude)&radius=\(min(radius, 50000))&type=\(type)&key=\(apiKey)"
            
            guard let url = URL(string: urlString) else {
                group.leave()
                continue
            }
            
            // Create URL request
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15
            
            // Make the API request
            URLSession.shared.dataTask(with: request) { data, response, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error fetching \(type) locations: \(error.localizedDescription)")
                    if apiError == nil {
                        apiError = error
                    }
                    return
                }
                
                guard let data = data else {
                    print("No data received for \(type) locations")
                    return
                }
                
                do {
                    // Parse the JSON response
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let status = json["status"] as? String else {
                        print("Invalid JSON format for \(type) locations")
                        return
                    }
                    
                    if status != "OK" {
                        print("API Error for \(type) locations: \(status)")
                        return
                    }
                    
                    guard let results = json["results"] as? [[String: Any]] else {
                        print("No results found for \(type) locations")
                        return
                    }
                    
                    // Convert results to SafeZone objects
                    for place in results {
                        guard let geometry = place["geometry"] as? [String: Any],
                              let location = geometry["location"] as? [String: Double],
                              let lat = location["lat"],
                              let lng = location["lng"],
                              let name = place["name"] as? String else {
                            continue
                        }
                        
                        let vicinity = place["vicinity"] as? String ?? "No address available"
                        
                        // Create a SafeZone object
                        let safeZone = SafeZone(
                            id: UUID(),
                            name: name,
                            description: "\(type.capitalized) - \(vicinity)",
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                            radius: type == "hospital" ? 300 : 200, // Larger radius for hospitals
                            capacity: self.getCapacityForType(type),
                            currentOccupancy: Int.random(in: 0...(self.getCapacityForType(type) / 2)),
                            resourcesAvailable: self.getResourcesForType(type),
                            lastUpdated: Date(),
                            safetyLevel: self.getSafetyLevelForType(type),
                            address: vicinity,
                            contactInfo: "Emergency Contact"
                        )
                        
                        allSafeZones.append(safeZone)
                    }
                    
                } catch {
                    print("Error parsing response for \(type) locations: \(error.localizedDescription)")
                }
            }.resume()
        }
        
        // When all requests are complete, return the combined results
        group.notify(queue: .global()) {
            if !allSafeZones.isEmpty {
                // Sort safe zones by safety level (highest first)
                let sortedZones = allSafeZones.sorted { $0.safetyLevel > $1.safetyLevel }
                completion(.success(sortedZones))
            } else if let error = apiError {
                completion(.failure(error))
            } else {
                completion(.failure(NSError(domain: "SafeZoneError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No safe zones found"])))
            }
        }
    }
    
    // Get estimated capacity based on facility type
    private func getCapacityForType(_ type: String) -> Int {
        switch type {
        case "hospital":
            return Int.random(in: 200...500)
        case "stadium":
            return Int.random(in: 1000...5000)
        case "school":
            return Int.random(in: 300...1000)
        case "community_center":
            return Int.random(in: 100...300)
        case "library":
            return Int.random(in: 50...200)
        case "police", "fire_station":
            return Int.random(in: 30...100)
        default:
            return Int.random(in: 50...150)
        }
    }
    
    // Get safety level based on facility type
    private func getSafetyLevelForType(_ type: String) -> Int {
        switch type {
        case "police", "fire_station":
            return 5
        case "hospital":
            return 5
        case "stadium":
            return 4
        case "school", "community_center":
            return 3
        default:
            return 3
        }
    }
    
    // Get available resources based on facility type
    private func getResourcesForType(_ type: String) -> [String] {
        switch type {
        case "hospital":
            return ["Medical Care", "Food", "Water", "Shelter", "First Aid"]
        case "police":
            return ["Security", "Communication", "First Aid"]
        case "fire_station":
            return ["Emergency Response", "First Aid", "Rescue Equipment"]
        case "school", "stadium":
            return ["Shelter", "Food", "Water", "Restrooms"]
        case "community_center", "library":
            return ["Shelter", "Information", "Water"]
        default:
            return ["Shelter", "Water"]
        }
    }
    
    // Add default safe zones if API fails
    private func addDefaultSafeZones(to mapView: MKMapView, near center: CLLocationCoordinate2D) {
        // Create some default safe zones around the center point
        let safeZones: [SafeZone] = [
            SafeZone(
                id: UUID(),
                name: "Emergency Shelter",
                description: "Primary emergency shelter with full facilities",
                coordinate: CLLocationCoordinate2D(
                    latitude: center.latitude + 0.01,
                    longitude: center.longitude + 0.01
                ),
                radius: 300,
                capacity: 500,
                currentOccupancy: 235,
                resourcesAvailable: ["Food", "Water", "Medical", "Shelter"],
                lastUpdated: Date(),
                safetyLevel: 5,
                address: "Near your location",
                contactInfo: "Emergency Services"
            ),
            SafeZone(
                id: UUID(),
                name: "Medical Center",
                description: "Emergency medical services available",
                coordinate: CLLocationCoordinate2D(
                    latitude: center.latitude - 0.01,
                    longitude: center.longitude + 0.01
                ),
                radius: 250,
                capacity: 300,
                currentOccupancy: 120,
                resourcesAvailable: ["Medical", "First Aid", "Water"],
                lastUpdated: Date(),
                safetyLevel: 4,
                address: "Near your location",
                contactInfo: "Medical Services"
            ),
            SafeZone(
                id: UUID(),
                name: "Community Center",
                description: "Temporary shelter with basic amenities",
                coordinate: CLLocationCoordinate2D(
                    latitude: center.latitude,
                    longitude: center.longitude - 0.02
                ),
                radius: 200,
                capacity: 200,
                currentOccupancy: 80,
                resourcesAvailable: ["Food", "Water", "Shelter"],
                lastUpdated: Date(),
                safetyLevel: 3,
                address: "Near your location",
                contactInfo: "Community Services"
            )
        ]
        
        // Add annotations for the default safe zones
        let annotations = safeZones.map { zone in
            SafeZoneAnnotation(
                coordinate: zone.coordinate,
                safeZone: zone
            )
        }
        mapView.addAnnotations(annotations)
        
        // Add circle overlays
        for zone in safeZones {
            let circle = MKCircle(center: zone.coordinate, radius: zone.radius)
            mapView.addOverlay(circle)
        }
    }
    
    // Fetch emergency services
    private func fetchEmergencyServices(latitude: Double, longitude: Double, radius: Double, completion: @escaping (Result<[EmergencyService], Error>) -> Void) {
        // Create some emergency services for demonstration
        let services = [
            EmergencyService(
                id: UUID(),
                name: "Emergency Medical",
                type: "hospital",
                coordinate: CLLocationCoordinate2D(
                    latitude: latitude + Double.random(in: -0.02...0.02),
                    longitude: longitude + Double.random(in: -0.02...0.02)
                )
            ),
            EmergencyService(
                id: UUID(),
                name: "Police Station",
                type: "police",
                coordinate: CLLocationCoordinate2D(
                    latitude: latitude + Double.random(in: -0.02...0.02),
                    longitude: longitude + Double.random(in: -0.02...0.02)
                )
            ),
            EmergencyService(
                id: UUID(),
                name: "Fire Department",
                type: "fire_station",
                coordinate: CLLocationCoordinate2D(
                    latitude: latitude + Double.random(in: -0.02...0.02),
                    longitude: longitude + Double.random(in: -0.02...0.02)
                )
            )
        ]
        
        completion(.success(services))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Handle user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            // Custom annotation view for crises
            if let crisisAnnotation = annotation as? CrisisAnnotation {
                let identifier = "CrisisPin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    
                    // Add a button to the callout
                    let button = UIButton(type: .detailDisclosure)
                    annotationView?.rightCalloutAccessoryView = button
                }
                
                // Set annotation appearance based on severity
                annotationView?.annotation = annotation
                annotationView?.markerTintColor = parent.crisisColors[crisisAnnotation.crisis.severity] ?? UIColor.red
                annotationView?.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
                
                return annotationView
            }
            
            // Custom annotation view for safe zones
            if let safeZoneAnnotation = annotation as? SafeZoneAnnotation {
                let identifier = "SafeZonePin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    
                    // Add a button to the callout
                    let button = UIButton(type: .detailDisclosure)
                    annotationView?.rightCalloutAccessoryView = button
                    
                    // Add an info button to show directions
                    let directionButton = UIButton(type: .contactAdd)
                    annotationView?.leftCalloutAccessoryView = directionButton
                }
                
                // Set annotation appearance for safe zones
                annotationView?.annotation = annotation
                
                // Color based on safety level
                let safetyLevel = safeZoneAnnotation.safeZone.safetyLevel
                switch safetyLevel {
                case 5:
                    annotationView?.markerTintColor = UIColor(Color.ui.severityLow)
                case 4:
                    annotationView?.markerTintColor = UIColor(Color.ui.severityLow.opacity(0.9))
                case 3:
                    annotationView?.markerTintColor = UIColor(Color.ui.severityLow.opacity(0.8))
                case 2:
                    annotationView?.markerTintColor = UIColor(Color.ui.severityLow.opacity(0.7))
                case 1:
                    annotationView?.markerTintColor = UIColor(Color.ui.severityLow.opacity(0.6))
                default:
                    annotationView?.markerTintColor = UIColor(Color.ui.severityLow)
                }
                
                // Pick icon based on address or description
                let description = safeZoneAnnotation.safeZone.description.lowercased()
                if description.contains("hospital") || description.contains("medical") {
                    annotationView?.glyphImage = UIImage(systemName: "cross.fill")
                } else if description.contains("police") {
                    annotationView?.glyphImage = UIImage(systemName: "shield.fill")
                } else if description.contains("fire") {
                    annotationView?.glyphImage = UIImage(systemName: "flame.fill")
                } else if description.contains("school") {
                    annotationView?.glyphImage = UIImage(systemName: "building.columns.fill")
                } else if description.contains("stadium") {
                    annotationView?.glyphImage = UIImage(systemName: "sportscourt.fill")
                } else if description.contains("library") {
                    annotationView?.glyphImage = UIImage(systemName: "books.vertical.fill")
                } else if description.contains("community") {
                    annotationView?.glyphImage = UIImage(systemName: "building.2.fill")
                } else {
                    annotationView?.glyphImage = UIImage(systemName: "house.fill")
                }
                
                return annotationView
            }
            
            // Custom annotation view for emergency services
            if let serviceAnnotation = annotation as? EmergencyServiceAnnotation {
                let identifier = "ServicePin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    
                    // Add a call button
                    let callButton = UIButton(type: .contactAdd)
                    annotationView?.rightCalloutAccessoryView = callButton
                }
                
                // Set annotation appearance for emergency services
                annotationView?.annotation = annotation
                
                // Color and icon based on service type
                switch serviceAnnotation.serviceType {
                case "hospital":
                    annotationView?.markerTintColor = UIColor.systemRed
                    annotationView?.glyphImage = UIImage(systemName: "cross.fill")
                case "police":
                    annotationView?.markerTintColor = UIColor.systemBlue
                    annotationView?.glyphImage = UIImage(systemName: "shield.fill")
                case "fire_station":
                    annotationView?.markerTintColor = UIColor.systemOrange
                    annotationView?.glyphImage = UIImage(systemName: "flame.fill")
                default:
                    annotationView?.markerTintColor = UIColor.systemPurple
                    annotationView?.glyphImage = UIImage(systemName: "phone.fill")
                }
                
                return annotationView
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let crisisAnnotation = view.annotation as? CrisisAnnotation {
                // Select the crisis to show details
                parent.selectedCrisis = crisisAnnotation.crisis
            }
            
            // Handle safe zone callout taps
            if let safeZoneAnnotation = view.annotation as? SafeZoneAnnotation {
                if control == view.rightCalloutAccessoryView {
                    // Detail button tapped - Could show a detail view
                    print("Safe zone detail tapped: \(safeZoneAnnotation.safeZone.name)")
                    
                    // In a real app, you'd display details or navigate to a detail screen
                    // For now, just print the information
                    let safeZone = safeZoneAnnotation.safeZone
                    print("Name: \(safeZone.name)")
                    print("Description: \(safeZone.description)")
                    print("Capacity: \(safeZone.currentOccupancy)/\(safeZone.capacity)")
                    print("Safety Level: \(safeZone.safetyLevel)/5")
                    print("Available Resources: \(safeZone.resourcesAvailable.joined(separator: ", "))")
                } else if control == view.leftCalloutAccessoryView {
                    // Direction button tapped - Get directions to this safe zone
                    let safeZone = safeZoneAnnotation.safeZone
                    
                    // Open in Maps app with directions
                    let placemark = MKPlacemark(coordinate: safeZone.coordinate)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = safeZone.name
                    
                    let launchOptions = [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ]
                    
                    mapItem.openInMaps(launchOptions: launchOptions)
                }
            }
            
            // Handle emergency service callout taps
            if let serviceAnnotation = view.annotation as? EmergencyServiceAnnotation {
                if control == view.rightCalloutAccessoryView {
                    // Call button tapped - Could initiate a call
                    print("Emergency service call tapped: \(serviceAnnotation.titleText)")
                    
                    // In a real app, you'd initiate a call or messaging
                    let serviceType = serviceAnnotation.serviceType
                    var phoneNumber = ""
                    
                    // Example emergency numbers (would be configured properly in a real app)
                    switch serviceType {
                    case "hospital":
                        phoneNumber = "911" // US emergency number
                    case "police":
                        phoneNumber = "911"
                    case "fire_station":
                        phoneNumber = "911"
                    default:
                        phoneNumber = "911"
                    }
                    
                    // Format the phone number for dialing
                    let formattedNumber = "tel://\(phoneNumber.replacingOccurrences(of: " ", with: ""))"
                    if let url = URL(string: formattedNumber), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        
        @objc func addPinOnLongPress(gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                let mapView = gesture.view as! MKMapView
                let point = gesture.location(in: mapView)
                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                
                // Create a user marker (could be used for reporting new incidents)
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = "New Marker"
                annotation.subtitle = "Long press to report an incident"
                mapView.addAnnotation(annotation)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update the region binding when the map moves
            parent.region = mapView.region
        }
        
        // Generate a unique but consistent color based on crisis ID
        private func colorForCrisisId(_ crisisId: String) -> Color {
            // Create a simple hash of the crisis ID
            var hash = 0
            for char in crisisId {
                hash = ((hash << 5) &- hash) &+ Int(char.asciiValue ?? 0)
            }
            
            // Use the hash to generate HSB color values
            // We want vivid colors for better visibility
            let hueOptions: [Double] = [0.02, 0.05, 0.1, 0.5, 0.55, 0.6, 0.65, 0.7, 0.8, 0.95]
            let hue = hueOptions[abs(hash) % hueOptions.count]
            
            // Use a high saturation/brightness for better visibility
            return Color(hue: hue, saturation: 0.9, brightness: 0.9)
        }
        
        // Handle overlay rendering for routes, zones, etc.
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is MKPolyline {
                let renderer = MKPolylineRenderer(overlay: overlay)
                renderer.strokeColor = UIColor(Color.ui.accent)
                renderer.lineWidth = 4
                return renderer
            } else if let polygonOverlay = overlay as? CrisisPredictionPolygonOverlay {
                // Handle prediction polygon overlays with colors based on crisis ID
                let renderer = MKPolygonRenderer(overlay: polygonOverlay)
                
                // Generate a consistent but different color for each crisis
                let color = colorForCrisisId(polygonOverlay.crisisId)
                
                // Higher opacity and more vivid colors
                renderer.fillColor = UIColor(color.opacity(0.5))
                renderer.strokeColor = UIColor(color)
                renderer.lineWidth = 3.5
                
                // Use solid line for better visibility
                return renderer
            } else if let heatmapOverlay = overlay as? CrisisPredictionHeatmapOverlay {
                // Handle prediction heatmap overlays with much more visible styling
                let renderer = MKCircleRenderer(overlay: heatmapOverlay)
                
                // Color based on crisis ID and intensity
                let baseColor = colorForCrisisId(heatmapOverlay.crisisId)
                
                // Much higher opacity for visibility
                let alpha = 0.2 + (heatmapOverlay.intensity * 0.6)
                renderer.fillColor = UIColor(baseColor.opacity(alpha))
                
                // Bold border for visibility
                renderer.strokeColor = UIColor(baseColor)
                renderer.lineWidth = 2.5
                
                return renderer
            } else if overlay is MKCircle {
                let renderer = MKCircleRenderer(overlay: overlay)
                renderer.fillColor = UIColor(Color.ui.accent.opacity(0.2))
                renderer.strokeColor = UIColor(Color.ui.accent)
                return renderer
            } else if overlay is MKPolygon {
                let renderer = MKPolygonRenderer(overlay: overlay)
                renderer.fillColor = UIColor(Color.ui.severityLow.opacity(0.3))
                renderer.strokeColor = UIColor(Color.ui.severityLow)
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // Add a method to coordinate class to trigger prediction when pin is selected
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? CrisisAnnotation {
                // Update selected crisis
                self.parent.selectedCrisis = annotation.crisis
                
                // NEW: Check if we need to fetch a prediction for this crisis
                let crisisId = annotation.crisis.id
                if self.parent.apiService.crisisPredictions[crisisId] == nil {
                    // Start a prediction update since we don't have one yet
                    self.parent.apiService.startLivePredictionUpdates(for: crisisId)
                }
            }
        }
    }
}

// MARK: - Custom Annotation
class CrisisAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var crisis: Crisis
    
    init(coordinate: CLLocationCoordinate2D, crisis: Crisis) {
        self.coordinate = coordinate
        self.crisis = crisis
        super.init()
    }
    
    var title: String? {
        return crisis.name
    }
    
    var subtitle: String? {
        return "Severity: \(crisis.severity)"
    }
}

// MARK: - Safe Zone Annotation
class SafeZoneAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var safeZone: SafeZone
    
    init(coordinate: CLLocationCoordinate2D, safeZone: SafeZone) {
        self.coordinate = coordinate
        self.safeZone = safeZone
        super.init()
    }
    
    var title: String? {
        return safeZone.name
    }
    
    var subtitle: String? {
        return "Capacity: \(safeZone.currentOccupancy)/\(safeZone.capacity)"
    }
}

// MARK: - Emergency Service Annotation
class EmergencyServiceAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var titleText: String
    var subtitleText: String
    var serviceType: String
    
    init(coordinate: CLLocationCoordinate2D, title: String, subtitle: String, serviceType: String) {
        self.coordinate = coordinate
        self.titleText = title
        self.subtitleText = subtitle
        self.serviceType = serviceType
        super.init()
    }
    
    var title: String? {
        return titleText
    }
    
    var subtitle: String? {
        return subtitleText
    }
}

// MARK: - Emergency Service Model
struct EmergencyService: Identifiable {
    let id: UUID
    let name: String
    let type: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Route Finder Implementation
class OpenStreetMapRouteFinder {
    // Google Maps API key
    private let googlePlacesApiKey = "AIzaSyCfkQdt8u_FmVq358GR_WqQwcZ06Kgjl8o"
    
    // User-Agent for API requests
    private let userAgent = "GlobalAidConnect/1.0 (iOS; Swift)"
    
    // Max number of retries for API requests
    private let maxRetries = 3
    
    // Fetch evacuation routes using preferred map API
    func fetchEvacuationRoutes(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        print("Fetching evacuation routes for location: \(latitude),\(longitude)")
        
        // Create multiple parallel requests for different types of routes
        let group = DispatchGroup()
        var allRoutes: [EvacuationRoute] = []
        var fetchError: Error?
        
        // 1. First try Google Maps Directions API (primary source)
        group.enter()
        fetchGoogleMapsDirections(latitude: latitude, longitude: longitude, radius: radius) { result in
            defer { group.leave() }
            
            switch result {
            case .success(let routes):
                allRoutes.append(contentsOf: routes)
                print("Google Maps Directions: Found \(routes.count) routes")
            case .failure(let error):
                print("Google Maps Directions error: \(error.localizedDescription)")
                if fetchError == nil {
                    fetchError = error
                }
            }
        }
        
        // 2. Fallback to OpenStreetMap (secondary source)
        group.enter()
        fetchMajorRoads(latitude: latitude, longitude: longitude, radius: radius) { result in
            defer { group.leave() }
            
            // Only use OpenStreetMap data if Google Maps failed
            if allRoutes.isEmpty {
                switch result {
                case .success(let routes):
                    allRoutes.append(contentsOf: routes)
                    print("OpenStreetMap major roads: Found \(routes.count) routes")
                case .failure(let error):
                    print("OpenStreetMap major roads error: \(error.localizedDescription)")
                    if fetchError == nil {
                        fetchError = error
                    }
                }
            }
        }
        
        // Process results when all fetches complete
        group.notify(queue: .main) {
            if !allRoutes.isEmpty {
                // Get unique routes, prioritizing emergency routes
                let uniqueRoutes = self.removeDuplicateRoutes(allRoutes)
                print("Final routes: Using \(uniqueRoutes.count) routes")
                completion(.success(uniqueRoutes))
            } else if let error = fetchError {
                // All fetches failed with errors
                completion(.failure(error))
            } else {
                // Fallback: Generate some directional routes
                let fallbackRoutes = self.generateDirectionalRoutes(latitude: latitude, longitude: longitude, radius: radius)
                print("Using \(fallbackRoutes.count) fallback directional routes")
                completion(.success(fallbackRoutes))
            }
        }
    }
    
    // Fetch routes using Google Maps Directions API
    private func fetchGoogleMapsDirections(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        // Create directions from the user's location to several points around them
        let bearings = [0.0, 60.0, 120.0, 180.0, 240.0, 300.0] // Six directions around
        var routes: [EvacuationRoute] = []
        let group = DispatchGroup()
        var fetchError: Error?
        
        for (index, bearing) in bearings.enumerated() {
            // Calculate a destination point roughly 5-10km away
            let destinationPoint = calculateNewPoint(
                latitude: latitude,
                longitude: longitude,
                bearing: bearing * .pi / 180.0,
                distanceMeters: Double.random(in: 5000...10000)
            )
            
            group.enter()
            fetchDirectionsBasedRoute(
                from: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                to: destinationPoint,
                retryCount: 0
            ) { result in
                defer { group.leave() }
                
                switch result {
                case .success(let route):
                    routes.append(route)
                case .failure(let error):
                    print("Google Maps Directions error for direction \(index): \(error.localizedDescription)")
                    if fetchError == nil {
                        fetchError = error
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            if !routes.isEmpty {
                completion(.success(routes))
            } else if let error = fetchError {
                completion(.failure(error))
            } else {
                completion(.failure(NSError(domain: "GoogleMapsDirections", code: 0, userInfo: [NSLocalizedDescriptionKey: "No routes found"])))
            }
        }
    }
    
    // Fetch a single directions-based route with retry logic
    private func fetchDirectionsBasedRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        retryCount: Int,
        completion: @escaping (Result<EvacuationRoute, Error>) -> Void
    ) {
        // Construct the Google Maps Directions API URL
        let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin.latitude),\(origin.longitude)&destination=\(destination.latitude),\(destination.longitude)&mode=driving&alternatives=true&key=\(googlePlacesApiKey)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "GoogleMapsDirections", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Create request with proper headers and settings
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        print("Fetching Google Maps directions from \(origin.latitude),\(origin.longitude) to \(destination.latitude),\(destination.longitude)")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle network errors with retry logic
            if let error = error {
                print("Google Maps network error: \(error.localizedDescription)")
                
                // Implement retry logic with exponential backoff
                if retryCount < self.maxRetries {
                    let delaySeconds = pow(2.0, Double(retryCount)) // Exponential backoff: 1, 2, 4 seconds
                    print("Retrying Google Maps direction request in \(delaySeconds) seconds (Attempt \(retryCount + 1)/\(self.maxRetries))")
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + delaySeconds) {
                        self.fetchDirectionsBasedRoute(from: origin, to: destination, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                } else {
                    completion(.failure(error))
                    return
                }
            }
            
            // Validate response data
            guard let data = data, !data.isEmpty else {
                print("Google Maps returned empty data")
                completion(.failure(NSError(domain: "GoogleMapsDirections", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty response data"])))
                return
            }
            
            // Better error inspection - log the raw response
            print("Google Maps API response size: \(data.count) bytes")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Google Maps API response preview: \(String(responseString.prefix(200)))...")
            }
            
            // Add better validation of HTTP status
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "GoogleMapsDirections", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])))
                return
            }
            
            print("Google Maps API HTTP status: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                // Detail the error for debugging purposes
                let errorMessage = "Google Maps API returned status code: \(httpResponse.statusCode)"
                print(errorMessage)
                
                // Include response body for error details
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Error response: \(responseString)")
                }
                
                completion(.failure(NSError(domain: "GoogleMapsDirections", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            // Parse JSON
            do {
                // Log entire JSON for debugging if needed
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Successfully received Google Maps Directions data")
                    // Uncomment for detailed debugging: print("Full JSON: \(jsonString)")
                }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(NSError(domain: "GoogleMapsDirections", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])))
                    return
                }
                
                // Check status from Google API response
                guard let status = json["status"] as? String, status == "OK" else {
                    // Get status and error message safely
                    let apiStatus: String
                    if let statusValue = json["status"] as? String {
                        apiStatus = statusValue
                    } else {
                        apiStatus = "UNKNOWN_ERROR"
                    }
                    
                    let errorMessage: String
                    if let message = json["error_message"] as? String {
                        errorMessage = message
                    } else {
                        errorMessage = "No detailed error message"
                    }
                    
                    print("Google Maps API status: \(apiStatus), message: \(errorMessage)")
                    
                    completion(.failure(NSError(domain: "GoogleMapsDirections", code: 4, userInfo: [
                        NSLocalizedDescriptionKey: "API Error: \(apiStatus)",
                        "APIErrorMessage": errorMessage
                    ])))
                    return
                }
                
                // Extract routes from the response
                guard let routes = json["routes"] as? [[String: Any]] else {
                    completion(.failure(NSError(domain: "GoogleMapsDirections", code: 5, userInfo: [NSLocalizedDescriptionKey: "No routes found in response"])))
                    return
                }
                
                guard !routes.isEmpty else {
                    completion(.failure(NSError(domain: "GoogleMapsDirections", code: 5, userInfo: [NSLocalizedDescriptionKey: "Empty routes array"])))
                    return
                }
                
                let route = routes[0]
                
                // Get legs safely
                guard let legs = route["legs"] as? [[String: Any]] else {
                    completion(.failure(NSError(domain: "GoogleMapsDirections", code: 5, userInfo: [NSLocalizedDescriptionKey: "No legs found in route"])))
                    return
                }
                
                guard !legs.isEmpty else {
                    completion(.failure(NSError(domain: "GoogleMapsDirections", code: 5, userInfo: [NSLocalizedDescriptionKey: "Empty legs array"])))
                    return
                }
                
                let leg = legs[0]
                
                // Check for steps - optional but useful for validation
                if let stepsArray = leg["steps"] as? [[String: Any]] {
                    if stepsArray.isEmpty {
                        print("Warning: Route contains no steps")
                    }
                }
                
                // Extract polyline points
                guard let overviewPolyline = route["overview_polyline"] as? [String: Any] else {
                    completion(.failure(NSError(domain: "GoogleMapsDirections", code: 6, userInfo: [NSLocalizedDescriptionKey: "No polyline object found"])))
                    return
                }
                
                guard let encodedPolyline = overviewPolyline["points"] as? String else {
                    completion(.failure(NSError(domain: "GoogleMapsDirections", code: 6, userInfo: [NSLocalizedDescriptionKey: "No points found in polyline"])))
                    return
                }
                
                // Decode polyline into waypoints
                let waypoints = decodePolyline(encodedPolyline)
                
                // Get leg distance and duration - fix optional binding issues
                let distanceValue: Double
                if let distanceObj = leg["distance"] as? [String: Any],
                   let value = distanceObj["value"] as? Double {
                    distanceValue = value
                } else {
                    distanceValue = 5000 // default value
                }
                
                let durationSeconds: Double
                if let durationObj = leg["duration"] as? [String: Any],
                   let value = durationObj["value"] as? Double {
                    durationSeconds = value
                } else {
                    durationSeconds = 600 // default value
                }
                
                // Get summary string for the route
                let summary = route["summary"] as? String ?? "Evacuation Route"
                
                // Create named evacuation route
                let evacuationRoute = EvacuationRoute(
                    id: UUID(),
                    name: "Evacuation via \(summary)",
                    description: "Google Maps evacuation route via \(summary)",
                    waypoints: waypoints,
                    evacuationType: .general,
                    estimatedTravelTime: durationSeconds,
                    lastUpdated: Date(),
                    safetyLevel: 4, // Google Maps routes are considered reliable
                    issueAuthority: "Google Maps",
                    sourceAPI: "Google Maps Directions API"
                )
                
                print("Successfully created route from Google Maps with \(waypoints.count) waypoints")
                completion(.success(evacuationRoute))
                
            } catch {
                print("Error parsing Google Maps response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // Decode a Google Maps polyline string into an array of coordinates
    private func decodePolyline(_ encodedPolyline: String) -> [CLLocationCoordinate2D] {
        var waypoints: [CLLocationCoordinate2D] = []
        var idx = 0
        let len = encodedPolyline.count
        var lat = 0.0
        var lng = 0.0
        
        while idx < len {
            var result = 1
            var shift = 0
            var b: Int
            
            // Decode latitude
            repeat {
                b = Int(encodedPolyline[encodedPolyline.index(encodedPolyline.startIndex, offsetBy: idx)].asciiValue ?? 0) - 63
                idx += 1
                result += (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20
            
            let dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += Double(dlat)
            
            // Decode longitude
            result = 1
            shift = 0
            
            repeat {
                b = Int(encodedPolyline[encodedPolyline.index(encodedPolyline.startIndex, offsetBy: idx)].asciiValue ?? 0) - 63
                idx += 1
                result += (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20
            
            let dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += Double(dlng)
            
            // Convert to actual coordinates
            let latitude = lat * 1e-5
            let longitude = lng * 1e-5
            
            waypoints.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        
        return waypoints
    }
    
    // Fetch major roads that can serve as evacuation routes (OpenStreetMap API as backup)
    private func fetchMajorRoads(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        // Calculate bounding box (use smaller radius to avoid huge queries)
        let radiusInDegrees = min(0.1, radius / 111000.0) // Cap at 0.1 degrees (~11km)
        let bbox = "\(longitude-radiusInDegrees),\(latitude-radiusInDegrees),\(longitude+radiusInDegrees),\(latitude+radiusInDegrees)"
        
        // Use a more reliable API endpoint or format
        let query = """
        [out:json][timeout:25];
        (
          way["highway"~"motorway|trunk|primary"](\(bbox));
        );
        out body;
        """
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encodedQuery)") else {
            // Fall back to generating routes locally
            let fallbackRoutes = self.generateDirectionalRoutes(latitude: latitude, longitude: longitude, radius: radius)
            completion(.success(fallbackRoutes))
            return
        }
        
        // Create request with proper headers, longer timeout and better error handling
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Implement retry logic
        fetchWithRetry(request: request, retryCount: 0) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
            do {
                // Validate JSON before parsing
                guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("Invalid JSON format from OpenStreetMap")
                    let fallbackRoutes = self.generateDirectionalRoutes(latitude: latitude, longitude: longitude, radius: radius)
                    completion(.success(fallbackRoutes))
                    return
                }
                
                guard let elements = jsonObject["elements"] as? [[String: Any]] else {
                    print("Missing or invalid elements array in OpenStreetMap response")
                    let fallbackRoutes = self.generateDirectionalRoutes(latitude: latitude, longitude: longitude, radius: radius)
                    completion(.success(fallbackRoutes))
                    return
                }
                
                // Dictionary to store node coordinates
                var nodes: [String: CLLocationCoordinate2D] = [:]
                
                // Extract all nodes first
                for element in elements {
                    guard let type = element["type"] as? String else { continue }
                    if type == "node" {
                        guard let id = element["id"] as? Int,
                       let lat = element["lat"] as? Double,
                              let lon = element["lon"] as? Double else { continue }
                        
                        nodes[String(id)] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    }
                }
                
                // Process ways to create evacuation routes
                var routes: [EvacuationRoute] = []
                let userLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                
                for element in elements {
                    guard let type = element["type"] as? String else { continue }
                    
                    if type == "way" {
                        guard let id = element["id"] as? Int,
                       let nodeRefs = element["nodes"] as? [Int],
                       let tags = element["tags"] as? [String: Any],
                              nodeRefs.count >= 2 else { continue }
                        
                        // Get highway type
                        guard let highway = tags["highway"] as? String else { continue }
                        
                        // Convert node IDs to coordinates
                        var waypoints: [CLLocationCoordinate2D] = []
                        for nodeRef in nodeRefs {
                            if let coordinate = nodes[String(nodeRef)] {
                                waypoints.append(coordinate)
                            }
                        }
                        
                        if waypoints.count < 2 { continue }
                        
                        // Get road name with fallbacks
                        let name = (tags["name"] as? String) ??
                                  (tags["ref"] as? String) ??
                                  "\(highway.capitalized) Road"
                        
                        // Simplified safety level and speed calculations
                        let safetyLevel: Int
                        let speedMS: Double
                        
                        switch highway {
                        case "motorway":
                            safetyLevel = 4; speedMS = 16.7  // ~60 km/h
                        case "trunk":
                            safetyLevel = 4; speedMS = 13.9  // ~50 km/h
                        case "primary":
                            safetyLevel = 3; speedMS = 11.1  // ~40 km/h
                        default:
                            safetyLevel = 2; speedMS = 8.3   // ~30 km/h
                        }
                        
                        // Calculate total route distance
                        var totalDistance: CLLocationDistance = 0
                        for i in 0..<(waypoints.count - 1) {
                            let from = CLLocation(latitude: waypoints[i].latitude, longitude: waypoints[i].longitude)
                            let to = CLLocation(latitude: waypoints[i+1].latitude, longitude: waypoints[i+1].longitude)
                            totalDistance += from.distance(from: to)
                        }
                        
                        // Calculate estimated travel time
                        let estimatedTimeSeconds = totalDistance / speedMS
                        
                        // Get appropriate evacuation direction description
                        let directionDescription = self.getRouteDirectionDescription(
                            from: userLocation,
                            to: waypoints.last ?? waypoints.first!
                        )
                        
                        // Create evacuation route with real road data
                        let route = EvacuationRoute(
                            id: UUID(),
                            name: "Evacuation via \(name)",
                            description: "Evacuation route \(directionDescription) along \(highway) \(name)",
                            waypoints: waypoints,
                            evacuationType: .general,
                            estimatedTravelTime: estimatedTimeSeconds,
                            lastUpdated: Date(),
                            safetyLevel: safetyLevel,
                            issueAuthority: "OpenStreetMap",
                            sourceAPI: "OpenStreetMap"
                        )
                        
                        routes.append(route)
                    }
                }
                
                if routes.isEmpty {
                    // If no valid routes were extracted, use fallback
                    let fallbackRoutes = self.generateDirectionalRoutes(latitude: latitude, longitude: longitude, radius: radius)
                    completion(.success(fallbackRoutes))
                } else {
                    // Limit to most relevant routes (max 5)
                    let sortedRoutes = routes.sorted { $0.safetyLevel > $1.safetyLevel }
                    let limitedRoutes = Array(sortedRoutes.prefix(5))
                    completion(.success(limitedRoutes))
                }
                
            } catch {
                print("OpenStreetMap parsing error: \(error)")
                let fallbackRoutes = self.generateDirectionalRoutes(latitude: latitude, longitude: longitude, radius: radius)
                completion(.success(fallbackRoutes))
            }
                
            case .failure(let error):
                print("OpenStreetMap network error after retries: \(error.localizedDescription)")
                let fallbackRoutes = self.generateDirectionalRoutes(latitude: latitude, longitude: longitude, radius: radius)
                completion(.success(fallbackRoutes))
            }
        }
    }
    
    // Helper method to implement retry logic with increasing delays
    private func fetchWithRetry(
        request: URLRequest,
        retryCount: Int,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network errors
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                
                // Implement retry logic with exponential backoff
                if retryCount < self.maxRetries {
                    let delaySeconds = pow(2.0, Double(retryCount)) // Exponential backoff: 1, 2, 4 seconds
                    print("Retrying request in \(delaySeconds) seconds (Attempt \(retryCount + 1)/\(self.maxRetries))")
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + delaySeconds) {
                        self.fetchWithRetry(request: request, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                } else {
                    completion(.failure(error))
                    return
                }
            }
            
            guard let data = data, !data.isEmpty else {
                let error = NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty response data"])
                
                // Retry logic for empty data
                if retryCount < self.maxRetries {
                    let delaySeconds = pow(2.0, Double(retryCount))
                    DispatchQueue.global().asyncAfter(deadline: .now() + delaySeconds) {
                        self.fetchWithRetry(request: request, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                } else {
                    completion(.failure(error))
                }
                return
            }
            
            // Better error inspection - log the API response details
            print("API response size: \(data.count) bytes")
            
            // Add better validation of the response
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "APIError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])))
                return
            }
            
            print("API HTTP status: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                let error = NSError(domain: "APIError", code: httpResponse.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey: "HTTP status code: \(httpResponse.statusCode)"])
                
                // Try to extract error details from response
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Error response: \(responseString)")
                }
                
                // Retry for server errors (5xx)
                if (500...599).contains(httpResponse.statusCode) && retryCount < self.maxRetries {
                    let delaySeconds = pow(2.0, Double(retryCount))
                    DispatchQueue.global().asyncAfter(deadline: .now() + delaySeconds) {
                        self.fetchWithRetry(request: request, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                } else {
                    completion(.failure(error))
                }
                return
            }
            
            completion(.success(data))
        }
        
        task.resume()
    }
    
    // Generate directional evacuation routes if API calls fail
    private func generateDirectionalRoutes(
        latitude: Double,
        longitude: Double,
        radius: Double
    ) -> [EvacuationRoute] {
        var routes: [EvacuationRoute] = []
        
        // Create routes in cardinal directions (N, NE, E, SE, S, SW, W, NW)
        let bearings = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
        let directions = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
        
        // User's starting location
        let startPoint = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        for (index, bearing) in bearings.enumerated() {
            // Create waypoints along the bearing
            var waypoints: [CLLocationCoordinate2D] = []
            
            // Start with user location
            waypoints.append(startPoint)
            
            // Create a series of points in the given direction
            for distance in stride(from: 500.0, through: 10000.0, by: 500.0) {
                let point = self.calculateNewPoint(
                    latitude: latitude,
                    longitude: longitude,
                    bearing: bearing * .pi / 180.0, // Convert to radians
                    distanceMeters: distance
                )
                waypoints.append(point)
            }
            
            // Create the evacuation route
            let route = EvacuationRoute(
                id: UUID(),
                name: "Evacuation Route \(directions[index])",
                description: "Evacuation route heading \(directions[index]) from your location",
                waypoints: waypoints,
                evacuationType: .general,
                estimatedTravelTime: 10000.0 / 10.0, // Assuming 10 m/s average speed
                lastUpdated: Date(),
                safetyLevel: 3,
                issueAuthority: "Generated Evacuation Route",
                sourceAPI: "Directional Algorithm"
            )
            
            routes.append(route)
        }
        
        return routes
    }
    
    // Calculate new coordinates given a starting point, bearing and distance
    private func calculateNewPoint(
        latitude: Double,
        longitude: Double,
        bearing: Double,
        distanceMeters: Double
    ) -> CLLocationCoordinate2D {
        // Convert to radians
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        
        // Earth's radius in meters
        let earthRadius = 6371000.0
        
        // Calculate angular distance
        let angularDistance = distanceMeters / earthRadius
        
        // Calculate new coordinates
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(lat2))
        
        // Convert back to degrees
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
    
    // Get human-readable direction description
    private func getRouteDirectionDescription(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> String {
        let deltaLat = end.latitude - start.latitude
        let deltaLon = end.longitude - start.longitude
        
        // Calculate bearing in radians
        let bearing = atan2(deltaLon, deltaLat)
        
        // Convert to degrees (0-360)
        let bearingDegrees = (bearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        
        // Convert bearing to cardinal direction
        let directions = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest", "north"]
        let index = Int(round(bearingDegrees / 45.0))
        
        return "to the \(directions[index])"
    }
    
    // Remove duplicate routes
    private func removeDuplicateRoutes(_ routes: [EvacuationRoute]) -> [EvacuationRoute] {
        var uniqueRoutes: [EvacuationRoute] = []
        var processedDirections = Set<String>()
        
        // First, add all official evacuation routes
        let officialRoutes = routes.filter { $0.issueAuthority.contains("Official") }
        uniqueRoutes.append(contentsOf: officialRoutes)
        
        // For each official route, record its general direction
        for route in officialRoutes {
            if let start = route.waypoints.first, let end = route.waypoints.last {
                let direction = getRouteDirectionDescription(from: start, to: end)
                processedDirections.insert(direction)
            }
        }
        
        // Then add other routes only if they're in a different direction
        for route in routes {
            if route.issueAuthority.contains("Official") {
                continue // Already added
            }
            
            if let start = route.waypoints.first, let end = route.waypoints.last {
                let direction = getRouteDirectionDescription(from: start, to: end)
                
                if !processedDirections.contains(direction) {
                    uniqueRoutes.append(route)
                    processedDirections.insert(direction)
                }
            }
        }
        
        return uniqueRoutes
    }
}
