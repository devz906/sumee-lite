import SwiftUI

struct RotatingBorder: ViewModifier {
    let isSelected: Bool
    let isEditing: Bool
    var lineWidth: CGFloat = 4
    
    // We use a state to drive the rotation animation
    @State private var rotation: Double = 0
    
    // Define the gradient colors based on the design requested
    private var gradientColors: [Color] {
        if isEditing {
            // Orange/Yellow for editing
            return [.orange, .yellow, .orange]
        } else {
            // Blue/Cyan/White smooth loop
            return [
                Color(red: 0/255, green: 158/255, blue: 224/255),
                Color.cyan,
                Color.white,
                Color.cyan,
                Color(red: 0/255, green: 158/255, blue: 224/255)
            ]
        }
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isSelected {
                        // OPTIMIZATION: Removed GeometryReader to prevent layout thrashing.
                     
                        AngularGradient(
                            gradient: Gradient(colors: gradientColors),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                        // Scale 1.5 ensures coverage of corners for any rectangular aspect ratio < 1:1.5
                        // Scale 3.0 is safe for widgets (2:1 or 4:1)
                        .scaleEffect(3.0)
                        .rotationEffect(.degrees(rotation))
                        .mask(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(lineWidth: lineWidth)
                        )
                        .allowsHitTesting(false)
                        .onAppear {
                            rotation = 0
                            // Low-power linear animation
                            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                    }
                }
            )
    }
}

extension View {
    func rotatingBorder(isSelected: Bool, isEditing: Bool = false, lineWidth: CGFloat = 4) -> some View {
        self.modifier(RotatingBorder(isSelected: isSelected, isEditing: isEditing, lineWidth: lineWidth))
    }
}
