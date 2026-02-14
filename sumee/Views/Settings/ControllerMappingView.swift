import SwiftUI
import GameController

struct ControllerMappingView: View {
    var console: String = "GBA"
    
    var body: some View {
        Group {
            if console == "Nintendo DS" || console == "NintendoDS" || console == "DS" {
                GenericControllerMappingView<DSAction>(console: console)
            } else if console == "NES" || console == "Nintendo Entertainment System" {
                GenericControllerMappingView<NESAction>(console: console)
            } else if console == "SNES" || console == "Super NES" || console == "Super Nintendo Entertainment System" {
                GenericControllerMappingView<SNESAction>(console: console)
            } else if console == "PlayStation" || console == "PSX" || console == "PS1" {
                GenericControllerMappingView<PSXAction>(console: console)
            } else if console == "Genesis" || console == "Sega Genesis" || console == "Mega Drive" || console == "MegaDrive" {
                GenericControllerMappingView<GenesisAction>(console: console)
            } else {
                GenericControllerMappingView<GBAAction>(console: console)
            }
        }
    }
}

struct GenericControllerMappingView<Action: ConsoleAction>: View {
    let console: String
    @ObservedObject var manager = ControllerMappingManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    // State for listening
    @State private var listeningForAction: Action? = nil
    @State private var timer: Timer?
    @State private var activeSessionInputs: Set<ControllerInput> = []
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text("Controller Options (\(console))")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        manager.resetToDefaults(console: console)
                    }) {
                        Text("Reset")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                
                // Instructions
                if let listening = listeningForAction {
                    VStack {
                        Text("Press a button, or hold two buttons simultaneously for a combo:")
                            .foregroundColor(.gray)
                        Text(listening.name)
                            .font(.title)
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.8))
                    .onAppear {
                        startListening()
                    }
                    .onDisappear {
                        stopListening()
                    }
                } else {
                    // List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(Action.allCases)) { action in
                                Button(action: {
                                    listeningForAction = action
                                }) {
                                    HStack {
                                        Text(action.name)
                                            .foregroundColor(.white)
                                            .bold()
                                        Spacer()
                                        
                                        // Show current input label
                                        let label = manager.getInputLabel(for: action, console: console)
                                        Text(label)
                                            .foregroundColor(.yellow)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.gray.opacity(0.3))
                                            .cornerRadius(8)
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground).opacity(0.4))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }
    
    func startListening() {
        // Reset session
        activeSessionInputs = []
        
      
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard let action = listeningForAction else { return }
            
            var currentlyPressed: Set<ControllerInput> = []
            
            // Check all connected controllers
            for controller in GCController.controllers() {
                guard let gamepad = controller.extendedGamepad else { continue }
                
                // Check all known inputs
                for input in ControllerInput.allCases {
                    if input.isPressed(on: gamepad) {
                        currentlyPressed.insert(input)
                    }
                }
            }
            
            if !currentlyPressed.isEmpty {
                // User is holding buttons. Accumulate them.
                for input in currentlyPressed {
                    if activeSessionInputs.count < 2 { // Limit to 2 buttons
                        activeSessionInputs.insert(input)
                    }
                }
            } else {
                // User released all buttons.
                if !activeSessionInputs.isEmpty {
                    // Commit the session
                    let finalInputs = Array(activeSessionInputs)
                    let names = finalInputs.map { $0.rawValue }.joined(separator: " + ")
                    print("Remapped \(action.name) to \(names)")
                    
                    manager.setMapping(for: action, inputs: finalInputs, console: console)
                    
                    // Feedback
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    
                    listeningForAction = nil
                    activeSessionInputs = []
                }
      
            }
        }
    }
    
    func stopListening() {
        timer?.invalidate()
        timer = nil
    }
}
