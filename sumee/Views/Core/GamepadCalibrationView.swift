import SwiftUI
import GameController

struct GamepadCalibrationView: View {
    @ObservedObject var gameController: GameControllerManager
    let themeBlue: Color
    let textMain: Color
    let panelBg: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Left Stick Card
            stickCalibrationCard(
                title: "Left Stick",
                inner: $gameController.leftStickInnerDeadzone,
                outer: $gameController.leftStickOuterDeadzone,
                rawX: gameController.rawLeftThumbstickX,
                rawY: gameController.rawLeftThumbstickY,
                calX: gameController.leftThumbstickX,
                calY: gameController.leftThumbstickY
            )
            
            // Right Stick Card
            stickCalibrationCard(
                title: "Right Stick",
                inner: $gameController.rightStickInnerDeadzone,
                outer: $gameController.rightStickOuterDeadzone,
                rawX: gameController.rawRightThumbstickX,
                rawY: gameController.rawRightThumbstickY,
                calX: gameController.rightThumbstickX,
                calY: gameController.rightThumbstickY
            )
        }
        .padding(14)
    }
    
    // Local Helpers
    
    func stickCalibrationCard(title: String, inner: Binding<Float>, outer: Binding<Float>, rawX: Float, rawY: Float, calX: Float, calY: Float) -> some View {
        VStack(spacing: 0) {
            // Header
            Text(title)
                .font(.headline)
                .foregroundColor(textMain)
                .padding(.top, 16)
            
            HStack(spacing: 20) {
                // Visualizer (Left)
                ZStack {
                    Circle()
                        .fill(Color(white: 0.95))
                        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    
                    // Crosshair
                    Path { p in
                        p.move(to: CGPoint(x: 60, y: 10)); p.addLine(to: CGPoint(x: 60, y: 110))
                        p.move(to: CGPoint(x: 10, y: 60)); p.addLine(to: CGPoint(x: 110, y: 60))
                    }.stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    
                    // Zones
                    Circle().fill(Color.red.opacity(0.1))
                        .frame(width: CGFloat(inner.wrappedValue) * 120, height: CGFloat(inner.wrappedValue) * 120)
                        .overlay(Circle().stroke(Color.red.opacity(0.3), lineWidth: 1))
                    
                    Circle().stroke(themeBlue.opacity(0.5), lineWidth: 1)
                        .frame(width: CGFloat(outer.wrappedValue) * 120, height: CGFloat(outer.wrappedValue) * 120)
                    
                    // Input Dot
                    Circle().fill(themeBlue)
                        .frame(width: 12, height: 12)
                        .shadow(radius: 1)
                        .offset(x: CGFloat(rawX) * 60, y: CGFloat(-rawY) * 60)
                }
                .frame(width: 120, height: 120)
                
                // Sliders (Right)
                VStack(spacing: 14) {
                    sliderControl(label: "Deadzone", value: inner, color: themeBlue, range: 0...0.9)
                    sliderControl(label: "Outer Range", value: outer, color: themeBlue, range: 0.5...1.0)
                }
                .frame(maxWidth: 180)
            }
            .padding(16)
        }
        .background(panelBg)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
    
    func sliderControl(label: String, value: Binding<Float>, color: Color, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundColor(.gray)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%").font(.caption.bold()).foregroundColor(color)
            }
            Slider(value: value, in: range)
                .accentColor(color)
        }
    }
}
