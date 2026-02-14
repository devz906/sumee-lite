import SwiftUI

struct IconLaunchAnimationView: View {
    let rom: ROMItem
    let sourceRect: CGRect
    let targetRect: CGRect // Where it should land (e.g., center of screen or LiveArea icon position)
    @Binding var isAnimating: Bool
    
    // Internal Animation State
    @State private var progress: CGFloat = 0.0
    @State private var isRotating: Bool = false
    @State private var finishing: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let screenSize = geo.size
            
            // Interpolate Position
            let startX = sourceRect.midX
            let startY = sourceRect.midY
            
            let endX = screenSize.width / 2
            let endY = screenSize.height / 2
            
            // Cubic Bezier Logic for "S-Curve" / Wide Loop
            let startPoint = CGPoint(x: startX, y: startY)
            let endPoint = CGPoint(x: endX, y: endY)
            
            // Vector form Start to End
            let vector = CGPoint(x: endPoint.x - startPoint.x, y: endPoint.y - startPoint.y)
            
            // Control Points: FORCED LEFT TURN
            // P1: Force movement 250pt to the LEFT of start, regardless of direction
            let p1 = CGPoint(
                x: startPoint.x - 250,
                y: startPoint.y + (vector.y * 0.1) // Mild vertical progression
            )
            
            // P2: Guide towards center with velocity
            let p2 = CGPoint(
                x: endPoint.x - 50, // Approach from slightly left
                y: endPoint.y - (vector.y * 0.2) // Coming in hot
            )
            
            // Cubic Bezier Formula: B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
            let t = progress
            let u = 1 - t
            let tt = t * t
            let uu = u * u
            let uuu = uu * u
            let ttt = tt * t
            
            let currentX = uuu * startPoint.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * endPoint.x
            let currentY = uuu * startPoint.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * endPoint.y
            
            // Motion Blur: Increase with speed (Peaking towards end)
            let blurAmount = 20.0 * progress // Maximum blur at impact
            
            // Construct temp AppItem for visual Consistency
            let tempItem = AppItem(
                name: rom.displayName,
                iconName: "gamecontroller.fill",
                color: .blue, // specific color doesn't matter for ROMs usually
                isROM: true,
                romItem: rom
            )
            
            let texture = tempItem.resolveIconImage()
            
            ZStack {
                // Background Removed as per request
                
                // Shadow (Separate to ensure circular shape)
                Circle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 85, height: 85) // Slightly smaller than view
                    .scaleEffect(1.0 + (progress * 0.8)) // Grow with object
                    .blur(radius: 10 * progress)
                    .offset(y: 20 * progress)
                    .position(x: currentX, y: currentY)
                    .opacity(finishing ? 0 : 1)
                
                // The Flying 3D Icon
                Real3DIconView(textureImage: texture, isRotating: isRotating)
                    .frame(width: 120, height: 120) // SCNView container
                    .scaleEffect(1.0 + (progress * 0.8)) // Scale up to 1.8x and stay there
                    .blur(radius: max(0, blurAmount)) // Strong Motion blur effect
                    // Rotation handled internally by Real3DIconView via SCNAction
                    .position(x: currentX, y: currentY)
                    .opacity(finishing ? 0 : 1) // Just fade out
                    .animation(.easeOut(duration: 0.3), value: finishing)
            }
        }
        .onAppear {
            // Use EaseIn for "Acceleration" effect (Starts slow, slams into center)
            withAnimation(.easeIn(duration: 0.8)) {
                progress = 1.0
            }
            
            // Trigger 3D Spin (handled by SceneKit)
            isRotating = true
            
            // Final Disappear (At 0.8s mark)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation {
                    finishing = true
                }
            }
        }
    }
}
