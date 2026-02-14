import SwiftUI
import Combine

struct VirtualKeyboard: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    var onCommit: () -> Void
    
    // Controller Access
    @ObservedObject private var controller = GameControllerManager.shared
    
    // State
    @State private var cursorX: Int = 0
    @State private var cursorY: Int = 0
    @State private var mode: Int = 1 // Start in Lowercase (1)
    
    // Throttling & Input State
    @State private var lastInputTime = Date()
    @State private var wasAPressed = false
    @State private var wasBPressed = false
    @State private var wasXPressed = false
    @State private var wasYPressed = false
    @State private var wasStartPressed = false
    @State private var wasL1Pressed = false
    @State private var wasR1Pressed = false
    
    // Navigation State
    @State private var navDirectionHeld: String? = nil
    @State private var navHoldStartTime: Date? = nil
    @State private var lastNavRepeatTime: Date = Date()
    
    // Backspace Repeat State
    @State private var xHoldStartTime: Date? = nil
    @State private var lastXRepeatTime: Date = Date()
    
    // Button A Repeat State
    @State private var aHoldStartTime: Date? = nil
    @State private var lastARepeatTime: Date = Date()
    
    // Touch Repeat State
    @State private var touchHeldKey: String? = nil
    @State private var popupKey: String? = nil // Visual only
    @State private var touchHoldStartTime: Date? = nil
    @State private var lastTouchRepeatTime: Date = Date()
    
    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width
            
            ZStack(alignment: isPortrait ? .bottom : .center) {
                // Dimmed Background (Removed visual dimming, kept hit area)
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { isPresented = false }
                }
            
            // Keyboard Frame
            VStack(spacing: isPortrait ? 20 : 12) {
                // Input Display
                HStack {
                    TextField("", text: $text)
                        .font(.system(size: isPortrait ? 24 : 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .disabled(true) // Disable touch typing here, rely on virtual keys
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue, lineWidth: 2))
                    
                    // Paste Button
                    if UIPasteboard.general.hasStrings {
                        Button(action: {
                            if let content = UIPasteboard.general.string {
                                text.append(content)
                                AudioManager.shared.playSelectSound()
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                                .font(.system(size: isPortrait ? 24 : 18))
                                .padding(4)
                        }
                    }

                    if !text.isEmpty {
                        Button(action: { text = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: isPortrait ? 24 : 18))
                        }
                    }
                }
                .padding(.horizontal, 4)
                
                // Keys Grid
                VStack(spacing: isPortrait ? 8 : 3) {
                    let keys = VirtualKeyboard.getKeys(mode: mode)
                    
                    ForEach(0..<keys.count, id: \.self) { rowIndex in
                        HStack(spacing: isPortrait ? 4 : 2) {
                            ForEach(0..<keys[rowIndex].count, id: \.self) { colIndex in
                                let isFocused = (cursorY == rowIndex && cursorX == colIndex)
                                let char = keys[rowIndex][colIndex]
                                
                                VirtualKeyButton(char: char, isFocused: isFocused, height: isPortrait ? 44 : 26, fontSize: isPortrait ? 20 : 12)
                                    .overlay(
                                        Group {
                                            if popupKey == char {
                                                KeyPopup(char: char)
                                                    .offset(y: -60)
                                                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                                                    .zIndex(100)
                                            }
                                        }, alignment: .center
                                    )
                                    .zIndex(popupKey == char ? 100 : 0)
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in
                                                if touchHeldKey != char {
                                                    touchHeldKey = char
                                                    popupKey = char
                                                    touchHoldStartTime = Date()
                                                    lastTouchRepeatTime = Date()
                                                    triggerHaptic()
                                                    
                                                    if char == "DEL" {
                                                        if !text.isEmpty {
                                                            text.removeLast()
                                                        }
                                                        AudioManager.shared.playSelectSound()
                                                    } else if char == "CAPS" || char == "caps" {
                                                        mode = (mode == 0) ? 1 : 0
                                                        AudioManager.shared.playSelectSound()
                                                    } else {
                                                        typeCharacter(char)
                                                    }
                                                }
                                            }
                                            .onEnded { _ in
                                                touchHeldKey = nil
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                    if touchHeldKey == nil {
                                                        withAnimation {
                                                            popupKey = nil
                                                        }
                                                    }
                                                }
                                            }
                                    )
                            }
                        }
                    }
                    
                    // Bottom Row: Caps + Sym + Comma + Dot + Space + Enter
                    HStack(spacing: isPortrait ? 8 : 6) {
                        let bottomHeight: CGFloat = isPortrait ? 44 : 28
                        let bottomFontSize: CGFloat = isPortrait ? 16 : 10
                        
                        // Sym Key (Index 0)
                        let isSymFocused = (cursorY == 4 && cursorX == 0)
                        Button(action: {
                            mode = (mode == 2) ? 0 : 2
                            AudioManager.shared.playSelectSound()
                            triggerHaptic()
                        }) {
                            VirtualKeyButton(char: (mode == 2) ? "ABC" : "123", isFocused: isSymFocused, height: bottomHeight, fontSize: bottomFontSize)
                                .frame(width: isPortrait ? 50 : 40)
                        }
                        
                         // Space Key (Index 1)
                        let isSpaceFocused = (cursorY == 4 && cursorX == 1)
                        Button(action: {
                            text += " "
                            AudioManager.shared.playSelectSound()
                            triggerHaptic()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(white: 0.95))
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(isSpaceFocused ? Color.blue : Color.gray, lineWidth: isSpaceFocused ? 3 : 1))
                                Text("SPACE")
                                    .font(.system(size: bottomFontSize, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .frame(height: bottomHeight)
                            .frame(maxWidth: .infinity)
                        }
                        
                         // .com Key (Index 2)
                        let isDotComFocused = (cursorY == 4 && cursorX == 2)
                        Button(action: {
                            typeCharacter(".com")
                            triggerHaptic()
                        }) {
                            VirtualKeyButton(char: ".com", isFocused: isDotComFocused, height: bottomHeight, fontSize: isPortrait ? 14 : 10)
                                .frame(width: isPortrait ? 55 : 45)
                        }
                        
                        // Enter Key (Index 3)
                        let isEnterFocused = (cursorY == 4 && cursorX == 3)
                        Button(action: {
                            onCommit()
                            withAnimation { isPresented = false }
                            triggerHaptic()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.blue)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(isEnterFocused ? Color.white : Color.clear, lineWidth: isEnterFocused ? 3 : 0))
                                Text("GO")
                                    .font(.system(size: bottomFontSize, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(height: bottomHeight)
                            .frame(width: isPortrait ? 55 : 45)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: isPortrait ? 0 : 16)
                    .fill(Color(white: 0.92))
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
            )
            .frame(maxWidth: isPortrait ? .infinity : 680) // Limit width on large screens to prevent stretching
            .padding(.bottom, isPortrait ? 30 : 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            AudioManager.shared.playSwipeSound()
            // Reset state on appear to prevent immediate triggering if button is held
            if controller.buttonAPressed { wasAPressed = true }
            if controller.buttonBPressed { wasBPressed = true }
            if controller.buttonXPressed { wasXPressed = true }
            if controller.buttonYPressed { wasYPressed = true }
            if controller.buttonStartPressed { wasStartPressed = true }
            if controller.buttonL1Pressed { wasL1Pressed = true }
            if controller.buttonR1Pressed { wasR1Pressed = true }
        }
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            if isPresented {
                handleInput()
                handleTouchRepeat()
            }
        }
    }
    
    //  - Logic
    
    private func handleTouchRepeat() {
        guard let key = touchHeldKey, let start = touchHoldStartTime else { return }
        
        // Wait 0.4s before starting repeat
        if Date().timeIntervalSince(start) > 0.4 {
             // Repeat every 0.1s
            if Date().timeIntervalSince(lastTouchRepeatTime) > 0.1 {
                if key == "BACKSPACE" || key == "DEL" {
                    if !text.isEmpty {
                        text.removeLast()
                    }
                    AudioManager.shared.playSelectSound()
                    triggerHaptic() // Trigger haptic on repeat
                } else {
                    typeCharacter(key)
                }
                lastTouchRepeatTime = Date()
            }
        }
    }
    
    private func handleInput() {
        let now = Date()
        
        // --- BUTTON A: Select (With Repeat) ---
        if controller.buttonAPressed {
            if !wasAPressed { 
                // Initial Press & Execute
                executeAction()
                wasAPressed = true
                aHoldStartTime = now
                lastARepeatTime = now
            } else {
                 // Held Down - Repeat Logic
                if let start = aHoldStartTime, now.timeIntervalSince(start) > 0.4 {
                    // Repeat every 0.1s
                     if now.timeIntervalSince(lastARepeatTime) > 0.1 {
                        executeAction()
                        lastARepeatTime = now
                    }
                }
            }
        } else {
            wasAPressed = false 
            aHoldStartTime = nil
        }
        
        // --- BUTTON B: Close Keyboard ---
        if controller.buttonBPressed {
            if !wasBPressed {
                withAnimation { isPresented = false }
               
                wasBPressed = true
            }
        } else {
            wasBPressed = false
        }
        
        // --- BUTTON X: Backspace (With Repeat) ---
        if controller.buttonXPressed {
            if !wasXPressed {
                // Initial Press
                if !text.isEmpty {
                    text.removeLast()
                }
                // Play Sound Always
                AudioManager.shared.playSelectSound()
                
                wasXPressed = true
                xHoldStartTime = now
                lastXRepeatTime = now
            } else {
                // Held Down - Repeat Logic
                if let start = xHoldStartTime, now.timeIntervalSince(start) > 0.4 {
                    // Repeat every 0.1s
                    if now.timeIntervalSince(lastXRepeatTime) > 0.1 {
                        if !text.isEmpty {
                            text.removeLast()
                        }
                        AudioManager.shared.playSelectSound()
                        lastXRepeatTime = now
                    }
                }
            }
        } else {
            wasXPressed = false
            xHoldStartTime = nil
        }
        
        // --- BUTTON Y: Clear All ---
        if controller.buttonYPressed {
            if !wasYPressed {
                text = ""
                AudioManager.shared.playSelectSound()
                wasYPressed = true
            }
        } else {
            wasYPressed = false
        }
        
        // --- BUTTON L1: Previous Mode ---
        if controller.buttonL1Pressed {
            if !wasL1Pressed {
                mode = (mode - 1 + 3) % 3
                AudioManager.shared.playSelectSound()
                wasL1Pressed = true
            }
        } else {
            wasL1Pressed = false
        }

        // --- BUTTON R1: Next Mode ---
        if controller.buttonR1Pressed {
            if !wasR1Pressed {
                mode = (mode + 1) % 3
                AudioManager.shared.playSelectSound()
                wasR1Pressed = true
            }
        } else {
            wasR1Pressed = false
        }
        
        // --- BUTTON Y: Unused currently (or space?) ---
        // Removed original Y mapping as requested
        
        // --- BUTTON START: GO ---
        if controller.buttonStartPressed {
            if !wasStartPressed {
                onCommit()
                withAnimation { isPresented = false }
                wasStartPressed = true
            }
        } else {
            wasStartPressed = false
        }
        
        // --- NAVIGATION ---
        let up = controller.dpadUp || controller.leftThumbstickY > 0.5
        let down = controller.dpadDown || controller.leftThumbstickY < -0.5
        let left = controller.dpadLeft || controller.leftThumbstickX < -0.5
        let right = controller.dpadRight || controller.leftThumbstickX > 0.5
        
        // Determine active direction
        var activeDir: String? = nil
        if up { activeDir = "up" }
        else if down { activeDir = "down" }
        else if left { activeDir = "left" }
        else if right { activeDir = "right" }
        
        if let dir = activeDir {
            if dir != navDirectionHeld {
                // New Press - Move Immediately
                navDirectionHeld = dir
                navHoldStartTime = now
                lastNavRepeatTime = now
                moveCursor(direction: dir)
            } else {
                // Held - Repetition Logic
                // Wait 0.4s before starting to repeat
                if let start = navHoldStartTime, now.timeIntervalSince(start) > 0.4 {
                    // Repeat every 0.08s
                    if now.timeIntervalSince(lastNavRepeatTime) > 0.08 {
                        lastNavRepeatTime = now
                        moveCursor(direction: dir)
                    }
                }
            }
        } else {
            // Reset when released
            navDirectionHeld = nil
            navHoldStartTime = nil
        }
    }

    private func moveCursor(direction: String) {
        let cols = 10
        let rows = 5
        var moved = false
        
        if direction == "right" {
             if cursorY == 4 {
                cursorX = (cursorX + 1) % 4 // Sym, Space, ., Go
            } else {
                let keys = VirtualKeyboard.getKeys(mode: mode)
                let rowCount = keys[cursorY].count
                cursorX = (cursorX + 1) % rowCount
            }
            moved = true
        } else if direction == "left" {
             if cursorY == 4 {
                cursorX = (cursorX - 1 + 4) % 4
            } else {
                let keys = VirtualKeyboard.getKeys(mode: mode)
                let rowCount = keys[cursorY].count
                cursorX = (cursorX - 1 + rowCount) % rowCount
            }
            moved = true
        } else if direction == "down" {
            if cursorY < rows - 1 {
                cursorY += 1
                if cursorY == 4 {
                   // Map upper rows
                   if cursorX < 2 { cursorX = 0 } // Sym
                   else if cursorX < 6 { cursorX = 1 } // Space
                   else if cursorX < 8 { cursorX = 2 } // .
                   else { cursorX = 3 } // Go
                }
                moved = true
            }
        } else if direction == "up" {
            if cursorY > 0 {
                cursorY -= 1
                let keys = VirtualKeyboard.getKeys(mode: mode)
                let rowCount = keys[cursorY].count
                if cursorX >= rowCount {
                    cursorX = rowCount - 1
                }
                moved = true
            }
        }
        
        if moved {
            AudioManager.shared.playMoveSound()
        }
    }
    
    private func executeAction() {
        if cursorY == 4 {
            if cursorX == 0 { // Sym
                mode = (mode == 2) ? 0 : 2
                AudioManager.shared.playSelectSound()
                triggerHaptic()
            } else if cursorX == 1 { // Space
                 text += " "
                AudioManager.shared.playSelectSound()
                triggerHaptic()
            } else if cursorX == 2 { // .com
                typeCharacter(".com")
            } else if cursorX == 3 { // Enter
                onCommit()
                withAnimation { isPresented = false }
                triggerHaptic()
            }
        } else {
            // Type Char
            let keys = VirtualKeyboard.getKeys(mode: mode)
            if cursorY < keys.count && cursorX < keys[cursorY].count {
                let char = keys[cursorY][cursorX]
                if char == "DEL" {
                    if !text.isEmpty {
                        text.removeLast()
                    }
                    AudioManager.shared.playSelectSound()
                    triggerHaptic()
                } else if char == "CAPS" || char == "caps" {
                    mode = (mode == 0) ? 1 : 0
                    AudioManager.shared.playSelectSound()
                    triggerHaptic()
                } else {
                    typeCharacter(char)
                }
            }
        }
    }
    
    private func typeCharacter(_ char: String) {
        text += char
        AudioManager.shared.playSelectSound()
        triggerHaptic()
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // Helpers copied from DSFirmwareConfig
    private func getModeLabel(_ mode: Int) -> String {
        switch mode {
        case 0: return "CAPS"
        case 1: return "abc"
        case 2: return "Sym"
        default: return "Caps"
        }
    }
    
    static func getKeys(mode: Int) -> [[String]] {
        switch mode {
        case 0: // Upper
            return [
                ["1","2","3","4","5","6","7","8","9","0"],
                ["Q","W","E","R","T","Y","U","I","O","P"],
                ["A","S","D","F","G","H","J","K","L"], // Removed -
                ["CAPS","Z","X","C","V","B","N","M","DEL"] // Added CAPS at start
            ]
        case 1: // Lower
            return [
                ["1","2","3","4","5","6","7","8","9","0"],
                ["q","w","e","r","t","y","u","i","o","p"],
                ["a","s","d","f","g","h","j","k","l"], // Removed -
                ["caps","z","x","c","v","b","n","m","DEL"] // Added caps at start
            ]
        case 2: // Symbols
            return [
                ["!","@","#","$","%","^","&","*","(",")"],
                ["~","`","<",">","[","]","{","}","|","_"],
                ["+","=","\\",";",":","\"","'","?","¿","¡"],
                ["-",",",".","€","£","¥","©","®","™","/"] // Added -, ,, . here
            ]
        default: return []
        }
    }
}

fileprivate struct VirtualKeyButton: View {
    let char: String
    let isFocused: Bool
    var height: CGFloat = 26
    var fontSize: CGFloat = 12
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            if isFocused {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blue, lineWidth: 2)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray, lineWidth: 1)
            }
            
            if char == "DEL" {
                 Image(systemName: "delete.left.fill")
                    .foregroundColor(.black)
                    .font(.system(size: fontSize))
            } else if char == "CAPS" || char == "caps" {
                Image(systemName: char == "CAPS" ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .foregroundColor(.black)
                    .font(.system(size: fontSize))
            } else {
                Text(char)
                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

fileprivate struct KeyPopup: View {
    let char: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
            
            if char == "DEL" {
                Image(systemName: "delete.left.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
            } else {
                Text(char)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
            }
        }
        .frame(width: 60, height: 60)
    }
}
