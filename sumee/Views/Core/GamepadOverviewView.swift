import SwiftUI
import GameController
import SceneKit

struct GamepadOverviewView: View {
    @ObservedObject var gameController: GameControllerManager
    let themeBlue: Color
    let textMain: Color
    
    var body: some View {
        VStack(spacing: 24) {
            if gameController.controllerName.isEmpty {
                // No Controller State
                Image(systemName: "gamecontroller.slash.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray.opacity(0.3))
                
                Text("No Controller Connected")
                    .font(.title2.bold())
                    .foregroundColor(textMain.opacity(0.6))
            } else {
                // Controller Connected State
                ZStack {
                    if gameController.controllerName.lowercased().contains("xbox") {
                        // 3D Xbox Model
                        Controller3DModelView(
                            modelName: "Xbox_Controller",
                            rotationX: Double(gameController.leftThumbstickY * -0.5),
                            rotationY: Double(gameController.leftThumbstickX * 0.5)
                        )
                        .frame(width: 300, height: 220)
                        // Removed offset to avoid intersection with title
                        .shadow(
                            color: Color.black.opacity(0.2),
                            radius: 20,
                            x: CGFloat(gameController.leftThumbstickX * -10),
                            y: CGFloat(gameController.leftThumbstickY * 10) + 20
                        )
                    } else if gameController.controllerName.lowercased().contains("dualshock") || gameController.controllerName.lowercased().contains("ps4") {
                        // 3D PS4 Model
                        Controller3DModelView(
                            modelName: "DualShock_4_PlayStation_Controller",
                            rotationX: Double(gameController.leftThumbstickY * -0.5),
                            rotationY: Double(gameController.leftThumbstickX * 0.5)
                        )
                        .frame(width: 300, height: 220)
                        .offset(y: 30)
                        .shadow(
                            color: Color.black.opacity(0.2),
                            radius: 20,
                            x: CGFloat(gameController.leftThumbstickX * -10),
                            y: CGFloat(gameController.leftThumbstickY * 10) + 20
                        )
                    } else if gameController.controllerName.lowercased().contains("dualsense") || gameController.controllerName.lowercased().contains("ps5") {
                        // 3D PS5 Model
                        Controller3DModelView(
                            modelName: "Playstation_5_Dualsense",
                            rotationX: Double(gameController.leftThumbstickY * -0.5),
                            rotationY: Double(gameController.leftThumbstickX * 0.5)
                        )
                        .frame(width: 300, height: 220)
                        .offset(y: 30)
                        .shadow(
                            color: Color.black.opacity(0.2),
                            radius: 20,
                            x: CGFloat(gameController.leftThumbstickX * -10),
                            y: CGFloat(gameController.leftThumbstickY * 10) + 20
                        )
                    } else {
                        // Generic 3D Model
                        Controller3DModelView(
                            modelName: "generic",
                            rotationX: Double(gameController.leftThumbstickY * -0.5),
                            rotationY: Double(gameController.leftThumbstickX * 0.5)
                        )
                        .frame(width: 300, height: 220)
                        .offset(y: 30)
                        .shadow(
                            color: Color.black.opacity(0.2),
                            radius: 20,
                            x: CGFloat(gameController.leftThumbstickX * -10),
                            y: CGFloat(gameController.leftThumbstickY * 10) + 20
                        )
                    }
                }
                .padding(.bottom, 10)
                
                VStack(spacing: 8) {
                    Text(gameController.controllerName)
                        .font(.largeTitle.bold())
                        .foregroundColor(textMain)
                    
                    HStack(spacing: 6) {
                         if gameController.isWiredConnection {
                            Image(systemName: "cable.connector")
                            Text("Wired Connection")
                        } else {
                            Image(systemName: "bluetooth")
                            Text("Bluetooth")
                            if let level = gameController.controllerBatteryLevel {
                                Text("• \(Int(level * 100))% Battery")
                            }
                        }
                    }
                    .font(.headline)
                    .foregroundColor(textMain.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.05)))
                }
                .offset(y: -50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }
}

// SceneKit Helper for USDZ
struct Controller3DModelView: UIViewRepresentable {
    let modelName: String
    let rotationX: Double
    let rotationY: Double
    
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = true
        
        // Try to load scene from bundle
        if let url = Bundle.main.url(forResource: modelName, withExtension: "usdz") {
            do {
                let scene = try SCNScene(url: url, options: nil)
                
                // Adjust scale/position if needed (USDZ models can vary in default scale)
                scene.rootNode.childNodes.forEach { node in
                    // Default scale
                    var scaleValue: Float = 1.3
                    
                    if modelName == "generic" {
                        scaleValue = 2.2
                    }
                    
                    node.scale = SCNVector3(scaleValue, scaleValue, scaleValue)
                    
                    // Fix orientation for PS5 model (User requested 90 on X)
                    if modelName == "Playstation_5_Dualsense" {
                        node.eulerAngles.x += Float.pi / 2
                    }
                }
                
                view.scene = scene
            } catch {
                print("Error loading USDZ: \(error)")
            }
        } else {
            print("USDZ file not found: \(modelName)")
        }
        
        return view
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let rootNode = uiView.scene?.rootNode else { return }
        
        // Apply smooth rotation based on joystick input
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.1
        
        // Convert joystick (-1 to 1) to radians 
        let pitch = Float(rotationX)
        let yaw = Float(rotationY)
        
        rootNode.eulerAngles = SCNVector3(pitch, yaw, 0)
        
        SCNTransaction.commit()
    }
}
