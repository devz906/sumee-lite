import SwiftUI
import GameController
import Combine

struct GamepadRemapView: View {
    @ObservedObject var gameController: GameControllerManager
    @ObservedObject var mappingManager: ControllerMappingManager
    
    // Remap State
    @Binding var selectedRemapConsole: String
    @Binding var selectedRemapRow: Int
    @Binding var listeningForAction: Int?
    @Binding var listeningActionName: String
    @Binding var heldInputs: Set<ControllerInput>
    @Binding var lastRemapTimestamp: TimeInterval
    
    // Theme Colors
    let themeBlue: Color 
    let textMain: Color
    
    @State private var cachedActions: [any ConsoleAction] = []
    
    let consoles = ["Nintendo DS", "Game Boy Advance", "NES", "SNES", "PlayStation", "Sega Genesis"]

    var body: some View {
        VStack(spacing: 0) {
            // Header: Console Selector
            HStack(spacing: 12) {
                // Console Selector Menu (Center Stage)
                Menu {
                    ForEach(consoles, id: \.self) { console in
                        Button(console) { 
                            selectedRemapConsole = console
                            selectedRemapRow = 0
                            let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundColor(themeBlue)
                        Text(selectedRemapConsole)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(textMain)
                        Image(systemName: "chevron.down.circle.fill")
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                    .overlay(
                        Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
                }
                
                // L1/R1 Hint (Moved Left)
                HStack(spacing: 2) {
                    Text("L1")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("R1")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Hints Group
                HStack(spacing: 8) {
                    // X Hint
                    HStack(spacing: 4) {
                       Text("X")
                           .font(.system(size: 12, weight: .bold, design: .rounded))
                           .foregroundColor(.white)
                           .frame(width: 20, height: 20)
                           .background(Color.gray)
                           .clipShape(Circle())
                    }
                    
                    Button(action: { mappingManager.resetToDefaults(console: selectedRemapConsole) }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.clear)
            
            // Actions List
            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                         
                             Color.clear.frame(height: max(0, geo.size.height * 0.5 - 30))
                            
                             ForEach(Array(cachedActions.enumerated()), id: \.offset) { index, action in
                                 remapRow(action: action, index: index).id(index)
                             }
                             
                             // Bottom Spacer to center last item
                             Color.clear.frame(height: max(0, geo.size.height * 0.5 - 30))
                        }
                        .padding(.horizontal, 20)
                    }
                    .mask(
                        LinearGradient(gradient: Gradient(colors: [.clear, .black, .black, .black, .clear]), startPoint: .top, endPoint: .bottom)
                    ) // Soft fade edges
                    .onChange(of: selectedRemapRow) { _, newIndex in
                        // Faster animation to keep up with rapid scrolling (0.15s matches input repeat rate)
                        withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) { 
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                    .onChange(of: selectedRemapConsole) { _ in 
                         // Reset scroll when console changes
                         DispatchQueue.main.async { proxy.scrollTo(0, anchor: .center) }
                    }
                }
            }
        }
        .padding(.bottom, 10)
        .onAppear { updateCachedActions() }
        .onChange(of: selectedRemapConsole) { _ in updateCachedActions() }
        
        // MARK: - Gamepad Navigation Logic (Universal Input)
        .onReceive(gameController.inputPublisher) { event in
            // Guard: Don't navigate if we are currently listening for a button press
            guard listeningForAction == nil else { return }
            
            switch event {
            case .up:
                // Direct update without animation wrapper so scroll observer takes full control
                selectedRemapRow = max(0, selectedRemapRow - 1)
                let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
                
            case .down:
                selectedRemapRow = min(cachedActions.count - 1, selectedRemapRow + 1)
                let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
                
            case .a:
                // Enter Remap Mode
                if selectedRemapRow >= 0 && selectedRemapRow < cachedActions.count {
                    let action = cachedActions[selectedRemapRow]
                    listeningActionName = action.name
                    listeningForAction = action.rawValue
                    let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
                }
                
            case .l1:
                 // Previous Console
                 if let currentIndex = consoles.firstIndex(of: selectedRemapConsole) {
                     let prevIndex = (currentIndex - 1 + consoles.count) % consoles.count
                     selectedRemapConsole = consoles[prevIndex]
                     selectedRemapRow = 0 // Reset Selection
                     let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
                 }
                
            case .r1:
                 // Next Console
                 if let currentIndex = consoles.firstIndex(of: selectedRemapConsole) {
                     let nextIndex = (currentIndex + 1) % consoles.count
                     selectedRemapConsole = consoles[nextIndex]
                     selectedRemapRow = 0 // Reset Selection
                     let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
                 }
                
            case .x:
                 // Reset Defaults
                 mappingManager.resetToDefaults(console: selectedRemapConsole)
                 let generator = UINotificationFeedbackGenerator()
                 generator.notificationOccurred(.warning)
                
            default: break
            }
        }
    }
    
    // Helpers
    
    // Efficiently update actions only when console changes
    private func updateCachedActions() {
        if selectedRemapConsole == "Nintendo DS" { cachedActions = [DSAction.fastForward] + DSAction.allCases.filter { $0 != .fastForward } }
        else if selectedRemapConsole == "Game Boy Advance" { cachedActions = [GBAAction.fastForward] + GBAAction.allCases.filter { $0 != .fastForward } }
        else if selectedRemapConsole == "NES" { cachedActions = [NESAction.fastForward] + NESAction.allCases.filter { $0 != .fastForward } }
        else if selectedRemapConsole == "SNES" { cachedActions = [SNESAction.fastForward] + SNESAction.allCases.filter { $0 != .fastForward } }
        else if selectedRemapConsole == "PlayStation" { cachedActions = [PSXAction.fastForward] + PSXAction.allCases.filter { $0 != .fastForward } }
        else if selectedRemapConsole == "Sega Genesis" { cachedActions = [GenesisAction.fastForward] + GenesisAction.allCases.filter { $0 != .fastForward } }
        else { cachedActions = [] }
    }
    
    func remapRow(action: any ConsoleAction, index: Int) -> some View {
        let isSelected = (index == selectedRemapRow)
        let isFastForward = action.name == "Fast Forward"
        
        return Button(action: {
            selectedRemapRow = index // Update selection on touch
            listeningActionName = action.name
            listeningForAction = action.rawValue
        }) {
            HStack {
                // Name
                Text(action.name)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : textMain)
                
                Spacer()
                
                // Mapped Input Capsule (Hardware Style)
                HStack(spacing: 6) {
                    Text(mappingManager.getInputLabel(for: action, console: selectedRemapConsole))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? themeBlue : .gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : Color.gray.opacity(0.1))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    if isSelected {
                        // "Wii U" Style Selection: Solid Blue with Soft Roundness
                        themeBlue
                        // Inner "Plastic" shine for depth without glow
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            .padding(1)
                    } else {
                        Color.white
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.05), radius: isSelected ? 8 : 2, x: 0, y: isSelected ? 4 : 1)
            .scaleEffect(isSelected ? 1.02 : 1.0) 
        }
        .buttonStyle(.plain)
        .padding(.horizontal, isSelected ? 0 : 8)
    }
}
