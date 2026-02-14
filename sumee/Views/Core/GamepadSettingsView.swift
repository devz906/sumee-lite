
import SwiftUI
import GameController

struct GamepadSettingsView: View {
    @ObservedObject private var gameController = GameControllerManager.shared
    @Environment(\.dismiss) var dismiss
    
    // View State
    @State private var selectedTab: Int = 0 // Default to Overview
    // testedInputs removed from here to optimize performance (moved to Child View)
    
    // Navigation State
    @State private var l1HoldProgress: CGFloat = 0.0
    @State private var r1HoldProgress: CGFloat = 0.0
    @State private var holdTimer: Timer?
    @State private var transitionDirection: Edge = .trailing // Default direction
    let holdDuration: TimeInterval = 1.0
    
    // Remap State
    @State private var selectedRemapConsole: String = "Nintendo DS"
    @State private var selectedRemapRow: Int = 0 // Added missing state
    @State private var listeningForAction: Int? = nil // ID of action being remapped
    @State private var listeningActionName: String = ""
    @State private var lastRemapTimestamp: TimeInterval = 0 // Debounce for Remap Loop Fix
    @State private var heldInputs: Set<ControllerInput> = [] // For Combine inputs
    @ObservedObject private var mappingManager = ControllerMappingManager.shared
    
    // Total Inputs to Test (Passed to InputTestView)
    let totalInputs = 16 
    
    // Theme Colors
    let themeBlue = Color(red: 0/255, green: 158/255, blue: 224/255) // Classic Wii U Blue
    let themeBg = Color(red: 235/255, green: 235/255, blue: 240/255) // Light Grey Mesh
    let panelBg = Color.white
    let textMain = Color.black.opacity(0.8)
    
    var body: some View {
        ZStack {
            // 1. Light Mesh Background
            themeBg.ignoresSafeArea()
            
            // Grid Pattern
            backgroundGrid
            
            // Main Content
            mainLayout
            
            // Hold to Exit Overlay
            holdToExitOverlay
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedTab)
        
        // Navigation Logic
        .onChange(of: gameController.buttonL1Pressed) { _, pressed in
            if selectedTab >= 2 {
                // Input Test & Remap Mode: Hold to Exit
                if pressed {
                    startL1HoldTimer()
                } else {
                    cancelL1HoldTimer()
                }
            } else {
                // Normal Mode: Instant Switch
                if pressed {
                    changeTab(to: max(0, selectedTab - 1))
                }
            }
        }
        .onChange(of: gameController.buttonR1Pressed) { _, pressed in
            if selectedTab == 2 {
                // Input Test Mode: Hold to Remap (Switch to Tab 3)
                if pressed {
                    startR1HoldTimer()
                } else {
                    cancelR1HoldTimer()
                }
            } else if pressed && selectedTab < 3 {
                 // Normal Mode: Instant Switch
                changeTab(to: selectedTab + 1)
            }
        }
        .onChange(of: gameController.buttonBPressed) { _, pressed in
             if selectedTab >= 2 {
                 // Input Test & Remap Mode: Hold B to Exit (Same as L1)
                 if pressed {
                     startL1HoldTimer()
                 } else {
                     cancelL1HoldTimer()
                 }
             } else {
                 // Normal Mode
                 if pressed {
                     if selectedTab == 0 {
                         dismiss()
                     } else if selectedTab == 1 {
                         changeTab(to: 0)
                     }
                 }
             }
         }
         // Force Light Mode for consistent Wii U / 3DS aesthetic
         .preferredColorScheme(.light)
    }
    
    //  Helper Methods
    
    func changeTab(to newTab: Int) {
        if newTab == selectedTab { return }
        transitionDirection = newTab > selectedTab ? .trailing : .leading
        withAnimation { 
            selectedTab = newTab
        }
    }
    
    // Main Layout
    var mainLayout: some View {
        VStack(spacing: 8) {
            //  Compact Header (Floating Bar)
            HStack {
                // Back Button
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Text("Back")
                            .font(.headline)
                            .foregroundColor(textMain)
                            
                        // Hint B
                        Text("B")
                           .font(.system(size: 12, weight: .bold, design: .rounded))
                           .foregroundColor(.white)
                           .frame(width: 20, height: 20)
                           .background(Color.gray)
                           .clipShape(Circle())
                    }
                }
                .padding(.leading, 20)
                
                Spacer()
                
                // Controller Status Pill (Hidden on Overview)
                if selectedTab != 0 {
                    HStack(spacing: 12) {
                        Image(systemName: getControllerIconName(from: gameController.controllerName))
                            .font(.title3)
                            .foregroundColor(getControllerBrandColor(from: gameController.controllerName))
                        
                        Text(gameController.controllerName.isEmpty ? "No Controller" : gameController.controllerName)
                            .font(.subheadline.bold())
                            .foregroundColor(textMain)
                            .lineLimit(1)
                        
                        Divider().frame(height: 16)
                        
                        // Connection / Battery
                        HStack(spacing: 4) {
                            if gameController.isWiredConnection {
                                Image(systemName: "cable.connector").font(.caption)
                                Text("USB").font(.caption.bold())
                            } else {
                                Image(systemName: "battery.100").foregroundColor(.green).font(.caption)
                                if let level = gameController.controllerBatteryLevel {
                                    Text("\(Int(level * 100))%").font(.caption.bold())
                                }
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                }
                
                Spacer()
                
                // Tab Switcher
                HStack(spacing: 0) {
                    tabOption(title: "Overview", icon: "info.circle", tag: 0)
                    Divider().frame(height: 20)
                    tabOption(title: "Calibration", icon: "slider.horizontal.3", tag: 1)
                    Divider().frame(height: 20)
                    tabOption(title: "Input Test", icon: "gamecontroller", tag: 2)
                    Divider().frame(height: 20)
                    tabOption(title: "Remap", icon: "arrow.triangle.2.circlepath", tag: 3)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                .padding(.trailing, 20)
            }
            .padding(.top, 10)
            .frame(height: 60)
            
            //  Main Content Canvas
            GeometryReader { geo in
                ZStack {
                    if selectedTab == 0 {
                        GamepadOverviewView(gameController: gameController, themeBlue: themeBlue, textMain: textMain)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .transition(.asymmetric(
                                insertion: .move(edge: transitionDirection),
                                removal: .move(edge: transitionDirection == .trailing ? .leading : .trailing)
                            ))
                    } else if selectedTab == 1 {
                        GamepadCalibrationView(gameController: gameController, themeBlue: themeBlue, textMain: textMain, panelBg: panelBg)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .transition(.asymmetric(
                                insertion: .move(edge: transitionDirection),
                                removal: .move(edge: transitionDirection == .trailing ? .leading : .trailing)
                            ))
                    } else if selectedTab == 2 {
                        GamepadInputTestView(gameController: gameController, totalInputs: totalInputs, themeBlue: themeBlue, panelBg: panelBg, textMain: textMain)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .transition(.asymmetric(
                                insertion: .move(edge: transitionDirection),
                                removal: .move(edge: transitionDirection == .trailing ? .leading : .trailing)
                            ))
                    } else {
                        GamepadRemapView(
                            gameController: gameController,
                            mappingManager: mappingManager,
                            selectedRemapConsole: $selectedRemapConsole,
                            selectedRemapRow: $selectedRemapRow, // Now valid
                            listeningForAction: $listeningForAction,
                            listeningActionName: $listeningActionName,
                            heldInputs: $heldInputs,
                            lastRemapTimestamp: $lastRemapTimestamp,
                            themeBlue: themeBlue, // Added arg
                            textMain: textMain    // Added arg
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(.asymmetric(
                            insertion: .move(edge: transitionDirection),
                            removal: .move(edge: transitionDirection == .trailing ? .leading : .trailing)
                        ))
                    }
                }
            }
        }
        .overlay(remapListeningOverlay) // Input Listening Overlay
    }
    
    // Subviews
    
    var backgroundGrid: some View {
        GamepadGridBackground()
            .ignoresSafeArea()
    }

    var holdToExitOverlay: some View {
        Group {
            // L1 Hold (Exit)
            if l1HoldProgress > 0 {
                holdToast(
                    text: "Hold to Exit",
                    iconName: "arrow.uturn.backward",
                    progress: l1HoldProgress
                )
            }
            // R1 Hold (Next/Remap)
            else if r1HoldProgress > 0 {
                holdToast(
                    text: "Hold for Remap",
                    iconName: "arrow.right.circle.fill",
                    progress: r1HoldProgress
                )
            }
        }
    }
    
    // Generic Toast Component
    func holdToast(text: String, iconName: String, progress: CGFloat) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 14) {
                // Icon Container
                ZStack {
                    Circle()
                        .fill(themeBlue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeBlue)
                }

                Text(text)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(textMain)
                
                // Progress Indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(themeBlue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    Color.white
                    Capsule()
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                }
            )
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            .padding(.bottom, 50)
            .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
            .zIndex(100)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: progress > 0)
    }

    
    func tabOption(title: String, icon: String, tag: Int) -> some View {
        Button(action: { changeTab(to: tag) }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                if selectedTab == tag {
                    Text(title).font(.subheadline.bold())
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .foregroundColor(selectedTab == tag ? themeBlue : Color.gray)
            .background(selectedTab == tag ? themeBlue.opacity(0.1) : Color.clear)
        }
    }
    
    //  Listening Overlay
    
    var remapListeningOverlay: some View {
        Group {
            if let _ = listeningForAction {
                ZStack {
                    // Dimmed Background
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            listeningForAction = nil
                            listeningActionName = ""
                            heldInputs.removeAll()
                        }
                        .transition(.opacity)
                    
                    // Main Modal Card
                    VStack(spacing: 0) {
                        // Header Stripe
                        HStack {
                            Text("Map Input")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                listeningForAction = nil
                                listeningActionName = ""
                                heldInputs.removeAll()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(themeBlue)
                        
                        VStack(spacing: 24) {
                            // Instruction & Target
                            VStack(spacing: 8) {
                                Text("Press button for:")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text(listeningActionName)
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundColor(textMain)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                            }
                            .padding(.top, 10)
                            
                            // Visual Feedback Area
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(white: 0.96))
                                    .frame(minHeight: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                    )
                                
                                if heldInputs.isEmpty {
                                    // Idle State
                                    HStack(spacing: 12) {
                                        Image(systemName: "gamecontroller")
                                            .font(.title)
                                            .foregroundColor(.gray.opacity(0.4))
                                        Text("Waiting for input...")
                                            .font(.callout)
                                            .foregroundColor(.gray.opacity(0.5))
                                    }
                                } else {
                                    // Active Input State
                                    HStack(spacing: 8) {
                                        ForEach(Array(heldInputs.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { input in
                                            Text(input.rawValue)
                                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(themeBlue)
                                                .foregroundColor(.white)
                                                .clipShape(Capsule())
                                                .shadow(color: themeBlue.opacity(0.3), radius: 4, y: 2)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: heldInputs)
                            .frame(height: 80)
                            
                            // Footer Hint
                            Text("Hold multiple buttons strictly together\nto create a combo mapping.")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 40)
                    .frame(maxWidth: 400) // Don't get too wide on iPad
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
                .zIndex(200)
                
                // Attach Input Listener
                .onGamepadInput(perform: handleRemapInput)
            }
        }
    }
    
    // Centralized Input Handler
    func handleRemapInput(input: ControllerInput, pressed: Bool) {
        guard let actionID = listeningForAction else { return }
        let currentConsole = selectedRemapConsole

        if pressed {
            // Button DOWN: Add to held inputs
             heldInputs.insert(input)
        } else {

            if !heldInputs.isEmpty {
                 let inputsToMap = Array(heldInputs)
                 
        
                 switch currentConsole {
                 case "Nintendo DS":
                     if let action = DSAction(rawValue: actionID) { mappingManager.setMapping(for: action, inputs: inputsToMap, console: currentConsole) }
                 case "Game Boy Advance":
                     if let action = GBAAction(rawValue: actionID) { mappingManager.setMapping(for: action, inputs: inputsToMap, console: currentConsole) }
                 case "NES":
                     if let action = NESAction(rawValue: actionID) { mappingManager.setMapping(for: action, inputs: inputsToMap, console: currentConsole) }
                 case "SNES":
                     if let action = SNESAction(rawValue: actionID) { mappingManager.setMapping(for: action, inputs: inputsToMap, console: currentConsole) }
                 case "PlayStation":
                     if let action = PSXAction(rawValue: actionID) { mappingManager.setMapping(for: action, inputs: inputsToMap, console: currentConsole) }
                 case "Sega Genesis":
                     if let action = GenesisAction(rawValue: actionID) { mappingManager.setMapping(for: action, inputs: inputsToMap, console: currentConsole) }
                 default: break
                 }
                 
                 let generator = UINotificationFeedbackGenerator()
                 generator.notificationOccurred(.success)
                 
                 // Close Overlay
                 lastRemapTimestamp = Date().timeIntervalSince1970
                 listeningForAction = nil
                 listeningActionName = ""
                 heldInputs.removeAll()
            }
        }
    }
    
    // Timer Logic for L1 Hold (Navigation)
    func startL1HoldTimer() {
        l1HoldProgress = 0.0
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if l1HoldProgress < 1.0 {
                withAnimation(.linear(duration: 0.05)) { l1HoldProgress += 0.05 / (holdDuration * 0.5) } // Faster hold
            } else {
                // Complete
                cancelL1HoldTimer()
                
                // Set direction explicitly for "Back"
                transitionDirection = .leading 
                
                withAnimation { 
                    if selectedTab >= 2 { changeTab(to: 0) } // Return to Overview
                }
                let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.success)
                // Optional: Trigger Haptic Feedback Here
            }
        }
    }
    
    func cancelL1HoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        withAnimation(.easeOut(duration: 0.2)) {
            l1HoldProgress = 0.0
        }
    }
    
    // Timer Logic for R1 Hold (Remap)
    func startR1HoldTimer() {
        r1HoldProgress = 0.0
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if r1HoldProgress < 1.0 {
                withAnimation(.linear(duration: 0.05)) { r1HoldProgress += 0.05 / (holdDuration * 0.5) }
            } else {
                // Complete
                cancelR1HoldTimer()
                
                // Go to Remap
                transitionDirection = .trailing
                withAnimation { changeTab(to: 3) } 
                
                let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.success)
            }
        }
    }
    
    func cancelR1HoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        withAnimation(.easeOut(duration: 0.2)) {
            r1HoldProgress = 0.0
        }
    }
}


// Extracted Components (Optimizer)

struct GamepadGridBackground: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let spacing: CGFloat = 30
                for x in stride(from: 0, through: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: height))
                }
                for y in stride(from: 0, through: height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.black.opacity(0.03), lineWidth: 1)
        }
    }
}
