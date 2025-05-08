import SwiftUI
import Combine
import AVFoundation

struct HomeView: View {
    @EnvironmentObject var apiService: ApiService
    @State private var isLoading = false
    @State private var activeCard: String? = nil
    @State private var animateCards = false
    @State private var globeSize: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Background gradient
            Color.ui.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header section with 3D globe
                    headerSection
                    
                    // Active crises section
                    if isLoading {
                        loadingView
                    } else if let crises = apiService.activeCrises, !crises.isEmpty {
                        activeCrisesSection(crises: crises)
                    } else {
                        emptyStateView
                    }
                    
                    // Recent updates section
                    if let updates = apiService.recentUpdates, !updates.isEmpty {
                        recentUpdatesSection(updates: updates)
                    }
                    
                    // Quick access grid
                    quickAccessGrid
                }
                .padding(.bottom, 100) // Space for tab bar
            }
        }
        .navigationBarTitle("Dashboard", displayMode: .large)
        .refreshable {
            // Pull to refresh functionality
            await refreshData()
        }
        .onAppear {
            // Add a slight delay before showing content for smoother animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    animateCards = true
                }
            }
            
            Task {
                await refreshData()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Global Aid Connect")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.ui.primaryText)
                    .padding(.top, 8)
                
                Text("Connecting aid where it's needed most")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(Color.ui.secondaryText)
                    .offset(y: animateCards ? 0 : 20)
                    .opacity(animateCards ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateCards)
            }
            
            Spacer()
            
            // 3D Globe with animation
            ZStack {
                // Globe placeholder using SceneKit in a real app
                Circle()
                    .fill(Color.ui.accentGradient)
                    .frame(width: globeSize, height: globeSize)
                    .shadow(color: Color.ui.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                    .overlay(
                        Image(systemName: "globe")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.9))
                    )
                    .rotationEffect(Angle(degrees: animateCards ? 360 : 0))
                    .animation(Animation.linear(duration: 30).repeatForever(autoreverses: false), value: animateCards)
                
                // Orbiting dot effect
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                        .offset(x: globeSize/2)
                        .rotationEffect(Angle(degrees: Double(index) * 120 + (animateCards ? 360 : 0)))
                        .animation(
                            Animation.linear(duration: 10 + Double(index))
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                            value: animateCards
                        )
                }
            }
            .offset(y: animateCards ? 0 : 30)
            .opacity(animateCards ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animateCards)
        }
        .padding(.horizontal)
    }
    
    private var loadingView: some View {
        VStack {
            ForEach(0..<2, id: \.self) { index in
                ModernCardView {
                    VStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 200, height: 20)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 15)
                            .padding(.top, 8)
                            .shimmer(duration: 1.5)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 15)
                            .padding(.top, 4)
                            .shimmer(duration: 1.8)
                        
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 25)
                                .shimmer(duration: 1.5)
                            
                            Spacer()
                            
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 30, height: 30)
                                .shimmer(duration: 1.2)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
    
    private var emptyStateView: some View {
        ModernCardView(style: .glass) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.ui.accent.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(Color.ui.accent)
                }
                
                Text("No active crises")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                
                Text("There are currently no active crises requiring immediate attention.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(Color.ui.secondaryText)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        }
        .padding(.horizontal)
        .offset(y: animateCards ? 0 : 40)
        .opacity(animateCards ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: animateCards)
    }
    
    private func activeCrisesSection(crises: [Crisis]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Active Crises", systemImage: "exclamationmark.triangle")
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(crises.enumerated()), id: \.element.id) { index, crisis in
                        NavigationLink(destination: CrisisDetailView(crisis: crisis)) {
                            crisisCard(crisis: crisis, index: index)
                                .frame(width: 280)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func recentUpdatesSection(updates: [Update]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Recent Updates", systemImage: "arrow.clockwise")
                .padding(.horizontal)
            
            ForEach(Array(updates.enumerated()), id: \.element.id) { index, update in
                updateCard(update: update, index: index)
                    .padding(.horizontal)
            }
        }
    }
    
    private var quickAccessGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Quick Actions", systemImage: "bolt")
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                quickActionCard(title: "Report Emergency", icon: "exclamationmark.triangle.fill", color: Color.ui.severityCritical, index: 0, action: {
                    // Navigate to emergency reporting
                })
                
                quickActionCard(title: "Find Safe Zone", icon: "shield.checkmark.fill", color: Color.ui.severityLow, index: 1, action: {
                    // Navigate to safe zone finder
                })
                
                quickActionCard(title: "Volunteer", icon: "hand.raised.fill", color: Color.ui.categoryHumanitarian, index: 2, action: {
                    // Navigate to volunteer options
                })
                
                quickActionCard(title: "Resources", icon: "shippingbox.fill", color: Color.ui.categoryNatural, index: 3, action: {
                    // Navigate to resources
                })
            }
            .padding(.horizontal)
        }
    }
    
    private func crisisCard(crisis: Crisis, index: Int) -> some View {
        ModernCardView(style: index == 0 ? .accent : .regular) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(crisis.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(index == 0 ? .white : Color.ui.primaryText)
                        
                        Text(crisis.location)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(index == 0 ? .white.opacity(0.8) : Color.ui.secondaryText)
                    }
                    
                    Spacer()
                    
                    // 3D severity indicator
                    ZStack {
                        ForEach(0..<crisis.severity, id: \.self) { i in
                            Circle()
                                .fill(getSeverityColor(for: crisis.severity))
                                .frame(width: 30, height: 30)
                                .opacity(0.1 + Double(i) * 0.1)
                                .scaleEffect(1.0 + Double(i) * 0.1)
                        }
                        
                        Text("\(crisis.severity)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(index == 0 ? .white : getSeverityColor(for: crisis.severity))
                    }
                }
                
                Text(crisis.description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(index == 0 ? .white.opacity(0.9) : Color.ui.secondaryText)
                    .lineLimit(2)
                
                HStack {
                    Label("\(crisis.affectedPopulation.formatted()) affected", systemImage: "person.3")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(index == 0 ? .white.opacity(0.8) : Color.ui.secondaryText)
                    
                    Spacer()
                    
                    Text(timeAgo(from: crisis.startDate))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(index == 0 ? .white.opacity(0.8) : Color.ui.secondaryText)
                }
            }
            .padding(.vertical, 8)
        }
        .offset(y: animateCards ? 0 : 40)
        .opacity(animateCards ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1 + Double(index) * 0.1), value: animateCards)
    }
    
    private func updateCard(update: Update, index: Int) -> some View {
        ModernCardView(style: .glass) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(update.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    
                    Spacer()
                    
                    Text(timeAgo(from: update.timestamp))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color.ui.secondaryText)
                }
                
                Text(update.content)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(Color.ui.secondaryText)
                    .lineLimit(3)
                
                Text(update.source)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color.ui.accent)
            }
            .padding(.vertical, 8)
        }
        .offset(y: animateCards ? 0 : 40)
        .opacity(animateCards ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3 + Double(index) * 0.1), value: animateCards)
    }
    
    private func quickActionCard(title: String, icon: String, color: Color, index: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color.ui.primaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.ui.secondaryBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
        }
        .offset(y: animateCards ? 0 : 40)
        .opacity(animateCards ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5 + Double(index) * 0.1), value: animateCards)
    }
    
    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundColor(Color.ui.accent)
            
            Spacer()
            
            Button("See All") {
                // Navigate to full list
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(Color.ui.accent)
        }
        .offset(y: animateCards ? 0 : 20)
        .opacity(animateCards ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateCards)
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
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Data Methods
    
    private func refreshData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Call the actual API methods
        await apiService.fetchActiveCrises()
        await apiService.generateRecentUpdates()
    }
}

// MARK: - Crisis Detail View
struct CrisisDetailView: View {
    let crisis: Crisis
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            // Background gradient
            Color.ui.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with parallax effect
                    GeometryReader { geometry in
                        let minY = geometry.frame(in: .global).minY
                        let offset = minY > 0 ? -minY : 0
                        let opacity = min(1, (1 - (minY / 100)))
                        
                        ZStack(alignment: .bottom) {
                            // Hero background with parallax
                            ZStack {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                getSeverityColor(for: crisis.severity),
                                                getSeverityColor(for: crisis.severity).opacity(0.8)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(height: 250 + max(0, minY))
                                    .offset(y: offset)
                                
                                // Subtle pattern overlay
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.1),
                                                Color.clear
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(height: 250 + max(0, minY))
                                    .offset(y: offset)
                            }
                            
                            // Content overlay
                            VStack(alignment: .leading, spacing: 8) {
                                Text(crisis.name)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                HStack {
                                    Label(crisis.location, systemImage: "mappin.circle.fill")
                                        .font(.system(size: 16, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Spacer()
                                    
                                    Label(formatDate(crisis.startDate), systemImage: "calendar")
                                        .font(.system(size: 16, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                
                                // Severity indicator
                                HStack {
                                    Text("Severity")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    ForEach(1...5, id: \.self) { level in
                                        Image(systemName: level <= crisis.severity ? "circle.fill" : "circle")
                                            .foregroundColor(level <= crisis.severity ? .white : .white.opacity(0.4))
                                    }
                                    
                                    Spacer()
                                    
                                    Text(severityText(crisis.severity))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.black.opacity(0.2))
                                        )
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                // Gradient overlay at bottom of hero
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.black.opacity(0.7),
                                        Color.black.opacity(0)
                                    ]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                        }
                        .frame(height: 250)
                    }
                    .frame(height: 250)
                    
                    // Content sections
                    VStack(spacing: 24) {
                        // Overview
                        ModernCardView(title: "Overview", icon: "doc.text.magnifyingglass") {
                            Text(crisis.description)
                                .font(.system(size: 16, design: .rounded))
                                .fixedSize(horizontal: false, vertical: true)
                                .offset(y: animateContent ? 0 : 20)
                                .opacity(animateContent ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateContent)
                        }
                        
                        // Impact stats
                        ModernCardView(title: "Impact", icon: "chart.bar.xaxis") {
                            VStack(alignment: .leading, spacing: 16) {
                                impactStatRow(label: "Affected Population", value: "\(crisis.affectedPopulation.formatted())", icon: "person.3.fill")
                                
                                impactStatRow(label: "Area Affected", value: "Approx. 1,500 km²", icon: "map.fill")
                                
                                impactStatRow(label: "Duration", value: timeAgo(from: crisis.startDate), icon: "clock.fill")
                            }
                            .offset(y: animateContent ? 0 : 20)
                            .opacity(animateContent ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: animateContent)
                        }
                        
                        // Coordinator contact if available
                        if let contact = crisis.coordinatorContact {
                            ModernCardView(title: "Contact", icon: "person.fill.questionmark") {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(contact)
                                            .font(.system(size: 16, design: .rounded))
                                        
                                        Text("Lead Crisis Coordinator")
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundColor(Color.ui.secondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        // Call or message action
                                    }) {
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Circle().fill(Color.ui.accent))
                                            .shadow(color: Color.ui.accent.opacity(0.4), radius: 5, x: 0, y: 3)
                                    }
                                }
                                .offset(y: animateContent ? 0 : 20)
                                .opacity(animateContent ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: animateContent)
                            }
                        }
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button("Volunteer for This Crisis") {
                                // Action functionality
                            }
                            .buttonStyle(AccentButtonStyle(isWide: true))
                            
                            Button("Share Information") {
                                // Sharing functionality
                            }
                            .buttonStyle(AccentButtonStyle(isWide: true, height: 44))
                            
                            Button("View on Map") {
                                // Navigate to map with this crisis highlighted
                            }
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Color.ui.primaryText)
                            .padding(.top, 4)
                        }
                        .offset(y: animateContent ? 0 : 20)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: animateContent)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 100) // Space for tab bar
            }
        }
        .edgesIgnoringSafeArea(.top)
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Custom back button action
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.black.opacity(0.2)))
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Share action
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.black.opacity(0.2)))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                animateContent = true
            }
        }
    }
    
    private func impactStatRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color.ui.accent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(Color.ui.secondaryText)
                
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.ui.primaryText)
            }
            
            Spacer()
        }
    }
    
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
    
    private func severityText(_ severity: Int) -> String {
        switch severity {
        case 1:
            return "Low"
        case 2:
            return "Moderate"
        case 3:
            return "High"
        case 4:
            return "Critical"
        case 5:
            return "Extreme"
        default:
            return "Unknown"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
