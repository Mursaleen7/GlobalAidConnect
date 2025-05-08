import SwiftUI
import SceneKit

// MARK: - Animation Extensions
extension Animation {
    static let springyAppear = Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.5)
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.3)
    static let gentleSpring = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.5)
    
    static let pulseAnimation = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    static let rotationAnimation = Animation.linear(duration: 10).repeatForever(autoreverses: false)
    static let waveAnimation = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
}

// MARK: - 3D Globe Component
struct Globe3DView: View {
    let size: CGFloat
    @State private var rotation: Double = 0
    
    var body: some View {
        SceneView(
            scene: createGlobeScene(),
            options: [.allowsCameraControl, .autoenablesDefaultLighting]
        )
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
    
    private func createGlobeScene() -> SCNScene {
        let scene = SCNScene()
        
        // Create sphere with Earth texture
        let sphere = SCNSphere(radius: 5)
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "earth-texture")
        material.specular.contents = UIColor.white
        material.emission.contents = UIColor(white: 0.1, alpha: 1)
        material.shininess = 0.7
        sphere.materials = [material]
        
        // Create node for the sphere
        let sphereNode = SCNNode(geometry: sphere)
        
        // Animate rotation
        let rotationAction = SCNAction.rotate(by: .pi * 2, around: SCNVector3(0, 1, 0), duration: 20)
        let repeatAction = SCNAction.repeatForever(rotationAction)
        sphereNode.runAction(repeatAction)
        
        // Add to scene
        scene.rootNode.addChildNode(sphereNode)
        
        return scene
    }
}

// MARK: - Crisis Severity 3D Indicator
struct SeverityIndicator3D: View {
    let severity: Int
    let size: CGFloat
    
    var body: some View {
        ZStack {
            ForEach(0..<severity, id: \.self) { index in
                Circle()
                    .fill(getSeverityColor(for: severity))
                    .frame(width: size * 0.7, height: size * 0.7)
                    .scaleEffect(1.0 + Double(index) * 0.1)
                    .opacity(0.15 + (Double(index) * 0.15))
                    .blur(radius: size * 0.05)
            }
            
            Circle()
                .fill(getSeverityColor(for: severity))
                .frame(width: size * 0.7, height: size * 0.7)
                .shadow(color: getSeverityColor(for: severity).opacity(0.5), radius: size * 0.1, x: 0, y: size * 0.05)
            
            Text("\(severity)")
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
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
}

// MARK: - Pulse Effect View
struct PulseEffect: View {
    @State private var pulsate = false
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 20, height: 20)
            .scaleEffect(pulsate ? 1.2 : 0.8)
            .opacity(pulsate ? 0.6 : 1.0)
            .animation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true))
            .onAppear {
                self.pulsate = true
            }
    }
}

// MARK: - Shimmer Effect Modifier
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    var duration: Double = 1.5
    var bounce: Bool = false
    
    func body(content: Content) -> some View {
        content
            .modifier(
                AnimatedMask(phase: phase).animation(
                    Animation.linear(duration: duration)
                        .repeatForever(autoreverses: bounce)
                )
            )
            .onAppear {
                phase = 0.8
            }
    }
    
    struct AnimatedMask: AnimatableModifier {
        var phase: CGFloat = 0
        
        var animatableData: CGFloat {
            get { phase }
            set { phase = newValue }
        }
        
        func body(content: Content) -> some View {
            content
                .overlay(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: phase - 0.3),
                            .init(color: Color.white.opacity(0.7), location: phase - 0.15),
                            .init(color: Color.white, location: phase),
                            .init(color: Color.white.opacity(0.7), location: phase + 0.15),
                            .init(color: Color.clear, location: phase + 0.3)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.hardLight)
                )
                .mask(content)
        }
    }
}

extension View {
    func shimmer(duration: Double = 1.5, bounce: Bool = false) -> some View {
        modifier(ShimmerEffect(duration: duration, bounce: bounce))
    }
}

// MARK: - NeumorphicStyle View Modifier
struct NeumorphicStyle: ViewModifier {
    var lightShadowColor: Color = Color.white.opacity(0.8)
    var darkShadowColor: Color = Color.black.opacity(0.15)
    var shadowRadius: CGFloat = 8
    var shadowOffset: CGFloat = 6
    var backgroundColor: Color = Color.ui.background
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
                    .shadow(color: darkShadowColor, radius: shadowRadius, x: shadowOffset, y: shadowOffset)
                    .shadow(color: lightShadowColor, radius: shadowRadius, x: -shadowOffset, y: -shadowOffset)
            )
    }
}

extension View {
    func neumorphic(
        lightShadowColor: Color = Color.white.opacity(0.8),
        darkShadowColor: Color = Color.black.opacity(0.15),
        shadowRadius: CGFloat = 8,
        shadowOffset: CGFloat = 6,
        backgroundColor: Color = Color.ui.background
    ) -> some View {
        modifier(NeumorphicStyle(
            lightShadowColor: lightShadowColor,
            darkShadowColor: darkShadowColor,
            shadowRadius: shadowRadius,
            shadowOffset: shadowOffset,
            backgroundColor: backgroundColor
        ))
    }
}

// MARK: - Custom Card Style
struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.ui.secondaryBackground.opacity(0.6))
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
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardStyle())
    }
} 