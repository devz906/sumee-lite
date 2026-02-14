import SwiftUI
import GameController

//  Shared Gamepad Components

struct GamepadStick: View {
    let title: String
    let x: Float
    let y: Float
    let pressed: Bool
    let isTested: Bool
    let size: CGFloat
    let themeBlue: Color
    
    init(title: String, x: Float, y: Float, pressed: Bool, isTested: Bool, size: CGFloat = 60, themeBlue: Color) {
        self.title = title
        self.x = x
        self.y = y
        self.pressed = pressed
        self.isTested = isTested
        self.size = size
        self.themeBlue = themeBlue
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(Color(white: 0.95))
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                
                Circle().fill((pressed || isTested) ? themeBlue : Color.gray)
                    .opacity(pressed ? 0.8 : 1.0)
                    .frame(width: size * 0.4, height: size * 0.4) // Cap scale
                    .shadow(radius: 1)
                    .offset(x: CGFloat(x) * (size * 0.3), y: CGFloat(-y) * (size * 0.3))
            }
            Text(title).font(.caption2.bold()).foregroundColor((pressed || isTested) ? themeBlue : .gray)
        }
    }
}

struct GamepadTrigger: View {
    let title: String
    let value: Float
    let height: CGFloat
    let themeBlue: Color
    
    init(title: String, value: Float, height: CGFloat = 50, themeBlue: Color) {
        self.title = title
        self.value = value
        self.height = height
        self.themeBlue = themeBlue
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.9))
                    .frame(width: 14, height: height)
                
                RoundedRectangle(cornerRadius: 4).fill(themeBlue)
                    .frame(width: 14, height: CGFloat(value) * height)
            }
            Text(title).font(.caption2.bold()).foregroundColor(.gray)
        }
    }
}

struct GamepadButton: View {
    let label: String
    let active: Bool
    let width: CGFloat
    let height: CGFloat
    let isTested: Bool
    let themeBlue: Color
    let textMain: Color
    
    init(_ label: String, active: Bool, width: CGFloat = 44, height: CGFloat = 44, isTested: Bool = false, themeBlue: Color, textMain: Color) {
        self.label = label
        self.active = active
        self.width = width
        self.height = height
        self.isTested = isTested
        self.themeBlue = themeBlue
        self.textMain = textMain
    }

    var body: some View {
        ZStack {
            if active || isTested {
                // Active or Tested: Solid Theme Blue
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeBlue)
                    .opacity(active ? 0.8 : 1.0)
            } else {
                // Untested: White with subtle border
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
            }
            
            Text(label)
                .font(.system(size: height * 0.35, weight: .bold))
                .foregroundColor((active || isTested) ? .white : textMain)
        }
        .frame(width: width, height: height)
        .scaleEffect(active ? 0.92 : 1.0) // Physical press feeling
        .animation(.easeOut(duration: 0.1), value: active)
    }
}

// Controller Icon Helpers

func getControllerIconName(from controllerName: String) -> String {
    let name = controllerName.lowercased()
    if name.contains("xbox") { return "xbox.logo" }
    if name.contains("playstation") || name.contains("dualshock") || name.contains("dualsense") { return "playstation.logo" }
    if name.contains("switch") || name.contains("joy-con") { return "switch.2" }
    return "gamecontroller.fill"
}

func getControllerBrandColor(from controllerName: String) -> Color {
    let name = controllerName.lowercased()
    if name.contains("xbox") { return Color.green }
    if name.contains("playstation") || name.contains("dualshock") || name.contains("dualsense") { return Color.blue }
    if name.contains("switch") || name.contains("joy-con") { return Color.red }
    return Color.gray
}

// Input Monitoring
// Consolidated logic to reduce code duplication and centralize input observation
struct GamepadInputMonitor: ViewModifier {
    @ObservedObject var gameController = GameControllerManager.shared
    var onInput: (ControllerInput, Bool) -> Void
    
    func body(content: Content) -> some View {
        // We split the modifiers to avoid "Expression too complex" compiler errors
        let faceButtons = content
            .onChange(of: gameController.buttonAPressed) { _, v in onInput(.buttonA, v) }
            .onChange(of: gameController.buttonBPressed) { _, v in onInput(.buttonB, v) }
            .onChange(of: gameController.buttonXPressed) { _, v in onInput(.buttonX, v) }
            .onChange(of: gameController.buttonYPressed) { _, v in onInput(.buttonY, v) }
            
        let shoulders = faceButtons
            .onChange(of: gameController.buttonL1Pressed) { _, v in onInput(.leftShoulder, v) }
            .onChange(of: gameController.buttonR1Pressed) { _, v in onInput(.rightShoulder, v) }
            .onChange(of: gameController.buttonL2Pressed) { _, v in onInput(.leftTrigger, v) }
            .onChange(of: gameController.buttonR2Pressed) { _, v in onInput(.rightTrigger, v) }
            
        let secondary = shoulders
            .onChange(of: gameController.l3Pressed) { _, v in onInput(.leftThumbstickButton, v) }
            .onChange(of: gameController.r3Pressed) { _, v in onInput(.rightThumbstickButton, v) }
            .onChange(of: gameController.buttonStartPressed) { _, v in onInput(.buttonMenu, v) }
            .onChange(of: gameController.buttonSelectPressed) { _, v in onInput(.buttonOptions, v) }
            
        let dpad = secondary
            .onChange(of: gameController.dpadUp) { _, v in onInput(.dpadUp, v) }
            .onChange(of: gameController.dpadDown) { _, v in onInput(.dpadDown, v) }
            .onChange(of: gameController.dpadLeft) { _, v in onInput(.dpadLeft, v) }
            .onChange(of: gameController.dpadRight) { _, v in onInput(.dpadRight, v) }
            
        return dpad
    }
}

// Extension to make it easier to apply
extension View {
    func onGamepadInput(perform action: @escaping (ControllerInput, Bool) -> Void) -> some View {
        self.modifier(GamepadInputMonitor(onInput: action))
    }
}
