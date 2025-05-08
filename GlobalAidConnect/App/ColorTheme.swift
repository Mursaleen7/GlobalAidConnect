import SwiftUI

// MARK: - Color Extensions
extension Color {
    static let theme = ColorTheme()
    static let ui = UIColors()
}

// MARK: - Color Theme
struct ColorTheme {
    let accent = Color("AccentColor")
    let background = Color("BackgroundColor")
    let primaryText = Color("PrimaryTextColor")
    let secondaryText = Color("SecondaryTextColor")
    let tertiaryText = Color("TertiaryTextColor")
    
    // Severity colors
    let severityLow = Color("SeverityLow")
    let severityMedium = Color("SeverityMedium")
    let severityHigh = Color("SeverityHigh")
    let severityCritical = Color("SeverityCritical")
    let severityExtreme = Color("SeverityExtreme")
    
    // Crisis category colors
    let categoryNatural = Color("CategoryNatural")
    let categoryHumanitarian = Color("CategoryHumanitarian")
    let categoryHealth = Color("CategoryHealth")
    let categoryConflict = Color("CategoryConflict")
}

// MARK: - UI Colors (Fallback colors if assets not loaded)
struct UIColors {
    // Main colors
    let accent = Color(red: 0.2, green: 0.549, blue: 0.98)
    let background = Color(red: 0.95, green: 0.97, blue: 0.99)
    let secondaryBackground = Color(red: 0.97, green: 0.97, blue: 0.99)
    
    // Text colors
    let primaryText = Color(red: 0.11, green: 0.18, blue: 0.26)
    let secondaryText = Color(red: 0.45, green: 0.52, blue: 0.58)
    let tertiaryText = Color(red: 0.65, green: 0.70, blue: 0.75)
    
    // Severity colors
    let severityLow = Color(red: 0.35, green: 0.88, blue: 0.64)
    let severityMedium = Color(red: 0.95, green: 0.77, blue: 0.36)
    let severityHigh = Color(red: 0.98, green: 0.51, blue: 0.36)
    let severityCritical = Color(red: 0.95, green: 0.26, blue: 0.21)
    let severityExtreme = Color(red: 0.69, green: 0.15, blue: 0.38)
    
    // Crisis category colors
    let categoryNatural = Color(red: 0.23, green: 0.6, blue: 0.85)
    let categoryHumanitarian = Color(red: 0.83, green: 0.38, blue: 0.72)
    let categoryHealth = Color(red: 0.35, green: 0.76, blue: 0.54)
    let categoryConflict = Color(red: 0.85, green: 0.35, blue: 0.35)
    
    // Gradients
    let accentGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.2, green: 0.549, blue: 0.98),
            Color(red: 0.15, green: 0.8, blue: 0.88)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.95, green: 0.97, blue: 0.99),
            Color(red: 0.92, green: 0.94, blue: 0.98)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Card gradients
    let alertCardGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.98, green: 0.41, blue: 0.31),
            Color(red: 0.85, green: 0.35, blue: 0.35)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
} 