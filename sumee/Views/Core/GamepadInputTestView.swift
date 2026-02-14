import SwiftUI
import GameController

struct GamepadInputTestView: View {
    @ObservedObject var gameController: GameControllerManager
    
    // Internal State for Testing (persists only while view is active)
    @State private var testedInputs: Set<String> = []
    
    let totalInputs: Int
    let themeBlue: Color
    let panelBg: Color
    let textMain: Color
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) { // Tighter spacing, Center alignment
            
            // --- LEFT HANDLE ---
            VStack(spacing: 12) {
                // Triggers/Shoulders
                HStack(alignment: .center, spacing: 10) {
                     GamepadButton("L1", active: gameController.buttonL1Pressed, width: 60, height: 36, isTested: testedInputs.contains("L1"), themeBlue: themeBlue, textMain: textMain)
                     GamepadTrigger(title: "L2", value: gameController.triggerL2Value, height: 36, themeBlue: themeBlue)
                }
                
                Divider()
                
                // Controls
                HStack(alignment: .top, spacing: 12) {
                     // D-Pad
                     VStack(spacing: 2) {
                        GamepadButton("↑", active: gameController.rawDpadUp, width: 32, height: 32, isTested: testedInputs.contains("UP"), themeBlue: themeBlue, textMain: textMain)
                        HStack(spacing: 2) {
                            GamepadButton("←", active: gameController.rawDpadLeft, width: 32, height: 32, isTested: testedInputs.contains("LEFT"), themeBlue: themeBlue, textMain: textMain)
                            GamepadButton("→", active: gameController.rawDpadRight, width: 32, height: 32, isTested: testedInputs.contains("RIGHT"), themeBlue: themeBlue, textMain: textMain)
                        }
                        GamepadButton("↓", active: gameController.rawDpadDown, width: 32, height: 32, isTested: testedInputs.contains("DOWN"), themeBlue: themeBlue, textMain: textMain)
                     }
                     
                     // Left Stick
                     GamepadStick(title: "L Stick", x: gameController.leftThumbstickX, y: gameController.leftThumbstickY, pressed: gameController.l3Pressed, isTested: testedInputs.contains("L3"), size: 50, themeBlue: themeBlue)
                }
            }
            .padding(14)
            .background(panelBg)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
            
            // --- CENTER ---
            VStack(spacing: 12) {
                Text("MENU").font(.caption2.bold()).foregroundColor(.gray)
                
                GamepadButton(gameController.isWiredConnection || gameController.controllerName.contains("Xbox") ? "VIEW" : "SELECT", active: gameController.buttonSelectPressed, width: 80, height: 36, isTested: testedInputs.contains("SELECT"), themeBlue: themeBlue, textMain: textMain)
                GamepadButton(gameController.isWiredConnection || gameController.controllerName.contains("Xbox") ? "MENU" : "START", active: gameController.buttonStartPressed, width: 80, height: 36, isTested: testedInputs.contains("START"), themeBlue: themeBlue, textMain: textMain)
                
                // Progress Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.1), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(testedInputs.count) / CGFloat(totalInputs))
                        .stroke(themeBlue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(Int((CGFloat(testedInputs.count) / CGFloat(totalInputs)) * 100))%")
                            .font(.headline.bold())
                            .foregroundColor(themeBlue)
                        Text("Tested")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 60, height: 60)
            }
            .padding(14)
            .background(panelBg)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
            
            // --- RIGHT HANDLE ---
            VStack(spacing: 12) {
                // Triggers/Shoulders
                HStack(alignment: .center, spacing: 10) {
                    GamepadTrigger(title: "R2", value: gameController.triggerR2Value, height: 36, themeBlue: themeBlue)
                    GamepadButton("R1", active: gameController.buttonR1Pressed, width: 60, height: 36, isTested: testedInputs.contains("R1"), themeBlue: themeBlue, textMain: textMain)
                }
                
                Divider()
                
                // Controls
                HStack(alignment: .top, spacing: 12) {
                     // Right Stick
                     GamepadStick(title: "R Stick", x: gameController.rightThumbstickX, y: gameController.rightThumbstickY, pressed: gameController.r3Pressed, isTested: testedInputs.contains("R3"), size: 50, themeBlue: themeBlue)
                     
                     // Face Buttons
                     VStack(spacing: 2) {
                        GamepadButton("Y", active: gameController.buttonYPressed, width: 32, height: 32, isTested: testedInputs.contains("Y"), themeBlue: themeBlue, textMain: textMain)
                        HStack(spacing: 2) {
                            GamepadButton("X", active: gameController.buttonXPressed, width: 32, height: 32, isTested: testedInputs.contains("X"), themeBlue: themeBlue, textMain: textMain)
                            GamepadButton("B", active: gameController.buttonBPressed, width: 32, height: 32, isTested: testedInputs.contains("B"), themeBlue: themeBlue, textMain: textMain)
                        }
                        GamepadButton("A", active: gameController.buttonAPressed, width: 32, height: 32, isTested: testedInputs.contains("A"), themeBlue: themeBlue, textMain: textMain)
                     }
                }
            }
            .padding(14)
            .background(panelBg)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        // Check Inputs (Optimized with Shared Monitor)
        .onGamepadInput { input, pressed in
            if pressed {
                switch input {
                case .buttonA: testedInputs.insert("A")
                case .buttonB: testedInputs.insert("B")
                case .buttonX: testedInputs.insert("X")
                case .buttonY: testedInputs.insert("Y")
                case .leftShoulder: testedInputs.insert("L1")
                case .rightShoulder: testedInputs.insert("R1")
                case .leftTrigger: testedInputs.insert("L2")
                case .rightTrigger: testedInputs.insert("R2")
                case .leftThumbstickButton: testedInputs.insert("L3")
                case .rightThumbstickButton: testedInputs.insert("R3")
                case .buttonMenu: testedInputs.insert("START")
                case .buttonOptions: testedInputs.insert("SELECT")
                case .dpadUp: testedInputs.insert("UP")
                case .dpadDown: testedInputs.insert("DOWN")
                case .dpadLeft: testedInputs.insert("LEFT")
                case .dpadRight: testedInputs.insert("RIGHT")
                default: break
                }
            }
        }
    }
}
