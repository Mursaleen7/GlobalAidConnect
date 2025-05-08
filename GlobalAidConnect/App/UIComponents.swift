import SwiftUI

// MARK: - Modern Button Style
struct AccentButtonStyle: ButtonStyle {
    var isWide: Bool = false
    var height: CGFloat = 50
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, isWide ? 24 : 16)
            .frame(height: height)
            .frame(maxWidth: isWide ? .infinity : nil)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: height/2)
                        .fill(Color.ui.accentGradient)
                    
                    // Highlight effect when pressed
                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: height/2)
                            .fill(Color.white.opacity(0.3))
                    }
                }
            )
            .shadow(color: Color.ui.accent.opacity(0.5), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.quickSpring, value: configuration.isPressed)
    }
}

// MARK: - Alert Button Style
struct AlertButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.ui.alertCardGradient)
                    
                    // Highlight effect when pressed
                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.white.opacity(0.3))
                    }
                }
            )
            .shadow(color: Color.ui.severityHigh.opacity(0.5), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.quickSpring, value: configuration.isPressed)
    }
}

// MARK: - Modern Text Field
struct ModernTextField: View {
    var placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(Color.ui.secondaryText)
                    .frame(width: 24)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 16, design: .rounded))
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16, design: .rounded))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.ui.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Modern Progress Bar
struct ModernProgressBar: View {
    var progress: Double
    var color: Color = Color.ui.accent
    var height: CGFloat = 8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.ui.secondaryBackground)
                    .frame(height: height)
                
                // Progress
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color, color.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)), height: height)
                
                // Shine effect
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)), height: height / 2)
                    .offset(y: -height / 4)
                    .blendMode(.plusLighter)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Modern Card View
struct ModernCardView<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    var style: CardStyle = .regular
    var content: () -> Content
    
    enum CardStyle {
        case regular, accent, alert, glass
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                HStack {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(cardTitleColor)
                    }
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(cardTitleColor)
                }
                .padding([.horizontal, .top])
            }
            
            content()
                .padding([.horizontal, .bottom])
                .padding(.top, title == nil ? 16 : 0)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: shadowColor, radius: 15, x: 0, y: 5)
    }
    
    // Card styling based on type
    private var cardBackground: some View {
        Group {
            switch style {
            case .regular:
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.ui.secondaryBackground)
            case .accent:
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.ui.accentGradient)
            case .alert:
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.ui.alertCardGradient)
            case .glass:
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.ui.secondaryBackground.opacity(0.7))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .opacity(0.05)
                            .blur(radius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.2),
                                        Color.clear,
                                        Color.clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            }
        }
    }
    
    private var cardTitleColor: Color {
        switch style {
        case .accent, .alert:
            return .white
        case .regular, .glass:
            return Color.ui.primaryText
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .accent:
            return Color.ui.accent.opacity(0.3)
        case .alert:
            return Color.ui.severityHigh.opacity(0.3)
        case .regular, .glass:
            return Color.black.opacity(0.1)
        }
    }
}

// MARK: - Animated List Appearance Modifier
struct AnimatedListItemModifier: ViewModifier {
    let index: Int
    
    func body(content: Content) -> some View {
        content
            .offset(y: 20)
            .opacity(0)
            .animation(
                Animation.spring(response: 0.4, dampingFraction: 0.8)
                    .delay(Double(index) * 0.05),
                value: index
            )
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05)) {
                    content.offset(y: 0).opacity(1)
                }
            }
    }
}

extension View {
    func animatedListItem(index: Int) -> some View {
        modifier(AnimatedListItemModifier(index: index))
    }
}

// MARK: - Animated Tab Indicator
struct AnimatedTabIndicator: View {
    var tabCount: Int
    @Binding var selectedTab: Int
    
    var body: some View {
        GeometryReader { geometry in
            let tabWidth = geometry.size.width / CGFloat(tabCount)
            
            Rectangle()
                .fill(Color.ui.accent)
                .frame(width: tabWidth - 20, height: 3)
                .cornerRadius(1.5)
                .offset(x: CGFloat(selectedTab) * tabWidth + 10, y: 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
        }
        .frame(height: 3)
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    var icon: String
    var action: () -> Void
    var color: Color = Color.ui.accent
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color, color.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
} 