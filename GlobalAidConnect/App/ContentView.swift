import SwiftUI
import Combine
import AVFoundation
import MapKit
import CoreLocation
import UIKit

// MARK: - Alert Item
struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}

struct ContentView: View {
    @EnvironmentObject var apiService: ApiService
    @State private var selectedTab: Int = 0
    @State private var tabBarOffset: CGFloat = 0
    @State private var previousScrollOffset: CGFloat = 0
    @State private var showTabBar: Bool = true
    @State private var isAnimatingTabs: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Home Tab
                NavigationView {
                    HomeView()
                }
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }
                .tag(0)
                
                // Map Tab
                NavigationView {
                    MapContainerView()
                }
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(1)
                
                // Emergency Report Tab
                NavigationView {
                    EmergencyInputView()
                }
                .tabItem {
                    Label("Emergency", systemImage: "exclamationmark.triangle.fill")
                }
                .tag(2)
                
                // Communication Tab
                NavigationView {
                    CommunicationView()
                }
                .tabItem {
                    Label("Assistant", systemImage: "message.fill")
                }
                .tag(3)
                
                // Alerts Tab
                NavigationView {
                    AlertsView()
                }
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }
                .tag(4)
                
                // Profile Tab
                NavigationView {
                    ProfileView()
                }
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(5)
            }
            .accentColor(Color.ui.accent)
            .onAppear {
                // Set tab bar appearance
                let appearance = UITabBarAppearance()
                appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
                appearance.backgroundColor = UIColor(Color.ui.secondaryBackground.opacity(0.5))
                
                // Hide built-in separator
                appearance.shadowColor = .clear
                
                // Apply the appearance
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
                
                // Set the tint color for the selected tab item
                UITabBar.appearance().tintColor = UIColor(Color.ui.accent)
                
                // Customize navigation bar
                let navAppearance = UINavigationBarAppearance()
                navAppearance.configureWithTransparentBackground()
                navAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
                navAppearance.backgroundColor = UIColor(Color.ui.secondaryBackground.opacity(0.5))
                navAppearance.titleTextAttributes = [
                    .foregroundColor: UIColor(Color.ui.primaryText),
                    .font: UIFont.rounded(ofSize: 18, weight: .semibold)
                ]
                navAppearance.largeTitleTextAttributes = [
                    .foregroundColor: UIColor(Color.ui.primaryText),
                    .font: UIFont.rounded(ofSize: 34, weight: .bold)
                ]
                
                UINavigationBar.appearance().standardAppearance = navAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
                
                // Fetch initial data when app appears
                apiService.fetchInitialData()
                
                // Start tab animation
                withAnimation(.easeInOut(duration: 0.3).delay(0.2)) {
                    isAnimatingTabs = true
                }
            }
            
            // Custom floating emergency button for quick access
            FloatingActionButton(icon: "exclamationmark.triangle.fill", action: {
                withAnimation(.springyAppear) {
                    selectedTab = 2
                }
            }, color: Color.ui.severityHigh)
                .offset(x: 0, y: -80)
                .opacity(selectedTab == 2 ? 0 : 1)
                .scaleEffect(selectedTab == 2 ? 0.5 : 1)
                .animation(.springyAppear, value: selectedTab)
                .shadow(color: Color.ui.severityHigh.opacity(0.4), radius: 15, x: 0, y: 8)
        }
    }
}

// MARK: - Alert View
struct AlertsView: View {
    @State private var isLoading = false
    @State private var animateCards = false
    
    var body: some View {
        ZStack {
            // Background gradient
            Color.ui.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header section with 3D-like effect
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alerts")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(Color.ui.primaryText)
                            
                            Text("Get notified about important events")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(Color.ui.secondaryText)
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(Color.ui.accent.opacity(0.1))
                                .frame(width: 50, height: 50)
                            
                            Circle()
                                .stroke(Color.ui.accent.opacity(0.3), lineWidth: 1)
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "bell.badge")
                                .font(.system(size: 24))
                                .foregroundColor(Color.ui.accent)
                                .symbolEffect(.pulse)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Divider()
                        .padding(.horizontal)
                        .opacity(0.5)
                    
                    if isLoading {
                        // Stylish loading view
                        ForEach(0..<3, id: \.self) { index in
                            ModernCardView {
                                VStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 120, height: 20)
                                        .shimmer()
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 20)
                                        .padding(.top, 8)
                                        .shimmer(duration: 1.8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 20)
                                        .padding(.top, 4)
                                        .shimmer(duration: 2.0)
                                }
                                .padding(.vertical, 8)
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Sample alerts with animated appearance
                        ForEach(0..<3, id: \.self) { index in
                            alertCard(for: index)
                                .padding(.horizontal)
                                .offset(y: animateCards ? 0 : 50)
                                .opacity(animateCards ? 1 : 0)
                                .animation(
                                    Animation.spring(
                                        response: 0.6,
                                        dampingFraction: 0.8,
                                        blendDuration: 0.6
                                    )
                                    .delay(Double(index) * 0.1),
                                    value: animateCards
                                )
                        }
                        
                        // Settings section
                        ModernCardView(title: "Alert Settings", icon: "gear") {
                            VStack(alignment: .leading, spacing: 16) {
                                Toggle("Push Notifications", isOn: .constant(true))
                                    .toggleStyle(SwitchToggleStyle(tint: Color.ui.accent))
                                    .font(.system(size: 16, design: .rounded))
                                
                                Toggle("Emergency Alerts", isOn: .constant(true))
                                    .toggleStyle(SwitchToggleStyle(tint: Color.ui.severityHigh))
                                    .font(.system(size: 16, design: .rounded))
                                
                                Toggle("Crisis Updates", isOn: .constant(true))
                                    .toggleStyle(SwitchToggleStyle(tint: Color.ui.accent))
                                    .font(.system(size: 16, design: .rounded))
                                
                                Toggle("Local Alerts", isOn: .constant(false))
                                    .toggleStyle(SwitchToggleStyle(tint: Color.ui.accent))
                                    .font(.system(size: 16, design: .rounded))
                            }
                        }
                        .padding(.horizontal)
                        .offset(y: animateCards ? 0 : 50)
                        .opacity(animateCards ? 1 : 0)
                        .animation(
                            Animation.spring(
                                response: 0.6,
                                dampingFraction: 0.8,
                                blendDuration: 0.6
                            )
                            .delay(0.4),
                            value: animateCards
                        )
                    }
                }
                .padding(.bottom, 120) // Space for floating button
            }
        }
        .onAppear {
            // Simulate loading
            isLoading = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isLoading = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animateCards = true
                }
            }
        }
        .navigationBarTitle("Alerts", displayMode: .large)
    }
    
    private func alertCard(for index: Int) -> some View {
        ModernCardView(style: index == 0 ? .alert : .regular) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sampleAlerts[index].title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(index == 0 ? .white : Color.ui.primaryText)
                        
                        Text(sampleAlerts[index].time)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(index == 0 ? .white.opacity(0.8) : Color.ui.secondaryText)
                    }
                    
                    Spacer()
                    
                    if index == 0 {
                        PulseEffect(color: .white.opacity(0.7))
                    }
                }
                
                Text(sampleAlerts[index].message)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(index == 0 ? .white.opacity(0.9) : Color.ui.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                
                if index == 0 {
                    Button("View Details") {
                        // Action
                    }
                    .buttonStyle(AlertButtonStyle())
                    .padding(.top, 8)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private struct AlertSample {
        let title: String
        let message: String
        let time: String
    }
    
    private let sampleAlerts = [
        AlertSample(
            title: "Wildfire Warning",
            message: "A wildfire has been reported near Southern California. Please stay updated with local authorities and prepare for possible evacuation.",
            time: "10 minutes ago"
        ),
        AlertSample(
            title: "Relief Supply Delivery",
            message: "Relief supplies for North Africa drought response will be delivered tomorrow. Volunteers needed at distribution centers.",
            time: "2 hours ago"
        ),
        AlertSample(
            title: "Situation Update",
            message: "The flooding in Southeast Asia has begun to recede. Recovery efforts are now underway in affected communities.",
            time: "Yesterday"
        )
    ]
}

// MARK: - Profile View
struct ProfileView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background gradient
            Color.ui.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile header with 3D effect
                    VStack {
                        ZStack {
                            // Background shape with 3D effect
                            Circle()
                                .fill(Color.ui.accentGradient)
                                .frame(width: 120, height: 120)
                                .shadow(color: Color.ui.accent.opacity(0.5), radius: 15, x: 0, y: 10)
                            
                            // Profile image
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                        .rotation3DEffect(
                            .degrees(isAnimating ? 5 : 0),
                            axis: (x: 0.0, y: 1.0, z: 0.0)
                        )
                        .rotation3DEffect(
                            .degrees(isAnimating ? 5 : 0),
                            axis: (x: 1.0, y: 0.0, z: 0.0)
                        )
                        .onAppear {
                            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                                isAnimating = true
                            }
                        }
                        
                        Text("User Profile")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .padding(.top, 8)
                        
                        Text("Humanitarian Aid Worker")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    .padding()
                    
                    // User info section
                    ModernCardView(title: "Account Information", icon: "person.text.rectangle") {
                        VStack(spacing: 16) {
                            ModernTextField(placeholder: "Full Name", text: .constant("John Doe"), icon: "person")
                            ModernTextField(placeholder: "Email", text: .constant("john.doe@example.org"), icon: "envelope")
                            ModernTextField(placeholder: "Phone", text: .constant("+1 555-123-4567"), icon: "phone")
                            ModernTextField(placeholder: "Organization", text: .constant("Global Relief Initiative"), icon: "building.2")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Skills section with animated bars
                    ModernCardView(title: "Skills & Certifications", icon: "star") {
                        VStack(alignment: .leading, spacing: 16) {
                            skillBar(label: "First Aid", progress: 0.9)
                            skillBar(label: "Crisis Management", progress: 0.75)
                            skillBar(label: "Logistics", progress: 0.6)
                            skillBar(label: "Communications", progress: 0.8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button("Edit Profile") {
                            // Edit profile action
                        }
                        .buttonStyle(AccentButtonStyle(isWide: true))
                        
                        Button("Sign Out") {
                            // Sign out action
                        }
                        .foregroundColor(Color.ui.primaryText)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitle("Profile", displayMode: .large)
    }
    
    private func skillBar(label: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color.ui.accent)
            }
            
            ModernProgressBar(progress: progress)
        }
    }
}

// MARK: - Font Extension
extension UIFont {
    static func rounded(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        } else {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ApiService())
    }
}
