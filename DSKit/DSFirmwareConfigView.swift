import SwiftUI
import AVKit


//made with <3

struct DSFirmwareConfigView: View {
    @Environment(\.dismiss) var dismiss
    var onFinish: () -> Void
    
    // Controller Access
    @ObservedObject var controller = GameControllerManager.shared
    
    // State for the wizard flow
    @State private var showIntro = true // Boot Animation State
    @State private var currentStep = 1
    
    // User Data
    @State private var selectedLanguage: Int = 1 // 0-5
    @State private var nickname: String = ""
    @State private var message: String = ""
    @State private var selectedColorIndex: Int = 0
    @State private var birthMonth: Int = 1
    @State private var birthDay: Int = 1
    
    // Navigation State for Grids/Keyboards
    @State private var cursorX: Int = 0
    @State private var cursorY: Int = 0
    @State private var keyboardMode: Int = 0 // 0: Upper, 1: Lower, 2: Symbols
    
    // Joystick Throttling
    @State private var lastStickTime = Date()
    
    // DS Colors
    let dsColors: [Color] = [
        Color(red: 0.6, green: 0.6, blue: 0.6), // Gray
        Color(red: 0.55, green: 0.35, blue: 0.15), // Brown
        Color(red: 0.9, green: 0.2, blue: 0.2), // Red
        Color(red: 1.0, green: 0.6, blue: 0.7), // Pink
        Color(red: 1.0, green: 0.5, blue: 0.0), // Orange
        Color(red: 0.9, green: 0.9, blue: 0.0), // Yellow
        Color(red: 0.6, green: 0.9, blue: 0.0), // Lime
        Color(red: 0.0, green: 0.8, blue: 0.0), // Green
        Color(red: 0.0, green: 0.5, blue: 0.0), // Dark Green
        Color(red: 0.2, green: 0.8, blue: 0.8), // Turquoise
        Color(red: 0.2, green: 0.2, blue: 0.9), // Blue
        Color(red: 0.3, green: 0.0, blue: 0.6), // Indigo
        Color(red: 0.8, green: 0.4, blue: 0.8), // Violet
        Color(red: 0.5, green: 0.0, blue: 0.5), // Purple
        Color(red: 0.9, green: 0.2, blue: 0.6), // Magenta
        Color(red: 0.3, green: 0.3, blue: 0.3)  // Dark Gray
    ]
    @State private var viewOpacity: Double = 0.0
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            if !showIntro {
                configContent
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            } else {
                DSBootAnimView {
                    // Animation Finished
                    withAnimation(.easeOut(duration: 0.5)) {
                        showIntro = false
                    }
                    AudioManager.shared.playDSConfigMusic()
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .opacity(viewOpacity)
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                viewOpacity = 1.0
            }
            AppDelegate.orientationLock = .landscape
            UIViewController.attemptRotationToDeviceOrientation()
            // Music is now started after intro video finishes
            controller.disableHomeNavigation = true
            resetCursor()
        }
        .onDisappear {
            // Release orientation lock when finished
            AppDelegate.orientationLock = .all
            UIViewController.attemptRotationToDeviceOrientation()
            AudioManager.shared.stopDSConfigMusic()
            controller.disableHomeNavigation = false
        }
        .onChange(of: controller.lastInputTimestamp) { _ in
            handleControllerInput()
        }
        .onChange(of: controller.leftThumbstickX) { _ in handleControllerInput() }
        .onChange(of: controller.leftThumbstickY) { _ in handleControllerInput() }
        .onChange(of: currentStep) { _ in
             resetCursor()
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
    }
    
    private var configContent: some View {
        ZStack {
            // 1. Background
            RetroGridBackground()
                .ignoresSafeArea()
            
            // 2. Main Layout (Rigid VStack)
            VStack(spacing: 0) {
                // Header (Fixed at Top)
                StepsHeader(currentStep: currentStep)
                    .padding(.top, 30)
                    .padding(.bottom, 10)
                    .frame(height: 60)
                
                // Content (Expands)
                ZStack {
                    if currentStep == 1 {
                        StepLanguageController(
                            selection: $selectedLanguage,
                            cursorX: $cursorX,
                            cursorY: $cursorY
                        )
                        .padding(.top, 30)
                    } else if currentStep == 2 {
                        StepKeyboardController(
                            title: "User Name",
                            text: $nickname,
                            maxLength: 10,
                            cursorX: $cursorX,
                            cursorY: $cursorY,
                            mode: $keyboardMode
                        )
                        .padding(.top, 30)
                    } else if currentStep == 3 {
                        StepKeyboardController(
                            title: "User Message",
                            text: $message,
                            maxLength: 26,
                            cursorX: $cursorX,
                            cursorY: $cursorY,
                            mode: $keyboardMode
                        )
                        .padding(.top, 30)
                    } else if currentStep == 4 {
                        StepColorController(
                            selection: $selectedColorIndex,
                            colors: dsColors,
                            cursorX: $cursorX,
                            cursorY: $cursorY
                        )
                        .padding(.top, 30)
                    } else if currentStep == 5 {
                        StepBirthdayController(
                            month: $birthMonth,
                            day: $birthDay,
                            cursorX: $cursorX
                        )
                    } else if currentStep == 6 {
                        StepConfirmController(onSave: saveAndFinish)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // Footer (Fixed at Bottom)
                RetroControllerHints(
                    currentStep: currentStep, 
                    l1Pressed: controller.buttonL1Pressed,
                    r1Pressed: controller.buttonR1Pressed,
                    onNext: {
                        if currentStep < 6 { currentStep += 1; AudioManager.shared.playSwipeSound() }
                    },
                    onBack: {
                        if currentStep > 1 { currentStep -= 1; AudioManager.shared.playSwipeSound() }
                    },
                    onFinish: saveAndFinish
                )
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 20)
        }
    }

    
    private func resetCursor() {
        cursorX = 0
        cursorY = 0
        keyboardMode = 0 // Reset to Uppercase
        if currentStep == 1 { cursorX = selectedLanguage % 3; cursorY = selectedLanguage / 3 }
        if currentStep == 4 { cursorX = selectedColorIndex % 8; cursorY = selectedColorIndex / 8 }
        // Keyboard: Start at input (optional) or first key. Default 0,0 is fine.
    }
    
    private func handleControllerInput() {
        if controller.buttonR1Pressed {
            if currentStep < 6 { currentStep += 1; AudioManager.shared.playSwipeSound() }
            return
        }
        if controller.buttonL1Pressed {
            if currentStep > 1 { currentStep -= 1; AudioManager.shared.playSwipeSound() }
            return
        }
        
        // Unified Input Logic (D-Pad + Joystick)
        let now = Date()
        let isStickReady = now.timeIntervalSince(lastStickTime) > 0.2
        
  
        let stickUp = isStickReady && controller.leftThumbstickY > 0.5
        let stickDown = isStickReady && controller.leftThumbstickY < -0.5
        let stickLeft = isStickReady && controller.leftThumbstickX < -0.5
        let stickRight = isStickReady && controller.leftThumbstickX > 0.5
        
        let up = controller.dpadUp || stickUp
        let down = controller.dpadDown || stickDown
        let left = controller.dpadLeft || stickLeft
        let right = controller.dpadRight || stickRight
        
        // Update stick timer if stick was used
        if (stickUp || stickDown || stickLeft || stickRight) {
            lastStickTime = now
        }
        
        switch currentStep {
        case 1: handleLanguageInput(u: up, d: down, l: left, r: right)
        case 2: handleKeyboardInput(text: $nickname, max: 10, u: up, d: down, l: left, r: right)
        case 3: handleKeyboardInput(text: $message, max: 26, u: up, d: down, l: left, r: right)
        case 4: handleColorInput(u: up, d: down, l: left, r: right)
        case 5: handleBirthdayInput(u: up, d: down, l: left, r: right)
        case 6: handleConfirmInput()
        default: break
        }
    }
    
    // --- Controller Input Handlers ---
    
    private func handleLanguageInput(u: Bool, d: Bool, l: Bool, r: Bool) {
        let cols = 3
        let rows = 2
        
        if r { cursorX = (cursorX + 1) % cols; AudioManager.shared.playMoveSound() }
        if l { cursorX = (cursorX - 1 + cols) % cols; AudioManager.shared.playMoveSound() }
        if d { if cursorY < rows - 1 { cursorY += 1; AudioManager.shared.playMoveSound() } }
        if u { if cursorY > 0 { cursorY -= 1; AudioManager.shared.playMoveSound() } }
        
        if controller.buttonAPressed {
            let index = cursorY * cols + cursorX
            if index < 6 {
                selectedLanguage = index
                AudioManager.shared.playSelectSound()
            }
        }
    }
    
    private func handleKeyboardInput(text: Binding<String>, max: Int, u: Bool, d: Bool, l: Bool, r: Bool) {
        let cols = 10
        let rows = 5
        
        // Navigation
        if r {
            if cursorY == 4 {
              
                cursorX = (cursorX + 1) % 3
            } else {
                cursorX = (cursorX + 1) % cols
            }
            AudioManager.shared.playMoveSound()
        }
        if l {
            if cursorY == 4 {
                cursorX = (cursorX - 1 + 3) % 3
            } else {
                cursorX = (cursorX - 1 + cols) % cols
            }
            AudioManager.shared.playMoveSound()
        }
        if d {
            if cursorY < rows - 1 {
                cursorY += 1
                if cursorY == 4 {
                    // Mapping to bottom 3 buttons
                    if cursorX < 3 { cursorX = 0 }      // Left side -> Caps
                    else if cursorX > 6 { cursorX = 2 } // Right side -> Backspace
                    else { cursorX = 1 }                // Center -> Space
                }
                AudioManager.shared.playMoveSound()
            }
        }
        if u {
            if cursorY > 0 {
                cursorY -= 1
                if cursorX >= cols { cursorX = cols - 1 }
                
                let cameFromRow4 = (cursorY + 1 == 4)
                if cameFromRow4 {
                    if cursorX == 0 { cursorX = 1 } // Caps -> W/S
                    else if cursorX == 2 { cursorX = 9 } // Backspace -> P/Delete
                    else { cursorX = 5 } // Space -> Center
                }
                AudioManager.shared.playMoveSound()
            }
        }
        
        // Action
        if controller.buttonAPressed {
            if cursorY == 4 {
                if cursorX == 0 { // Caps/Mode Switch
                    keyboardMode = (keyboardMode + 1) % 3
                    AudioManager.shared.playSelectSound()
                } else if cursorX == 1 { // Space
                    if text.wrappedValue.count < max {
                        text.wrappedValue += " "
                        AudioManager.shared.playSelectSound()
                    }
                } else { // Backspace
                    deleteCharacter(text: text)
                }
            } else {
                typeCharacter(at: cursorY, col: cursorX, text: text, max: max)
            }
        }
        
        if controller.buttonBPressed {
            deleteCharacter(text: text)
        }
    }
    
    private func handleColorInput(u: Bool, d: Bool, l: Bool, r: Bool) {
        let cols = 8
        let rows = 2
        
        if r { cursorX = (cursorX + 1) % cols; AudioManager.shared.playMoveSound() }
        if l { cursorX = (cursorX - 1 + cols) % cols; AudioManager.shared.playMoveSound() }
        if d { if cursorY < rows - 1 { cursorY += 1; AudioManager.shared.playMoveSound() } }
        if u { if cursorY > 0 { cursorY -= 1; AudioManager.shared.playMoveSound() } }
        
        if controller.buttonAPressed {
            let index = cursorY * cols + cursorX
            if index < 16 {
                selectedColorIndex = index
                AudioManager.shared.playSelectSound()
            }
        }
    }
    
    private func handleBirthdayInput(u: Bool, d: Bool, l: Bool, r: Bool) {
        if r && cursorX == 0 { cursorX = 1; AudioManager.shared.playMoveSound() }
        if l && cursorX == 1 { cursorX = 0; AudioManager.shared.playMoveSound() }
        
        if u {
            changeBirthdayValue(increment: true)
            AudioManager.shared.playMoveSound()
        }
        
        if d {
            changeBirthdayValue(increment: false)
            AudioManager.shared.playMoveSound()
        }
    }
    
    private func handleConfirmInput() {
        if controller.buttonAPressed {
            saveAndFinish()
        }
    }
    
    private func typeCharacter(at row: Int, col: Int, text: Binding<String>, max: Int) {
        // Space logic handled in handleKeyboardInput for controller, here for touch if needed or reuse
        // But getChar only handles rows 0-3
        let char = getChar(row: row, col: col, mode: keyboardMode)
        if text.wrappedValue.count < max {
            text.wrappedValue += char
            AudioManager.shared.playSelectSound()
        }
    }
    
    private func deleteCharacter(text: Binding<String>) {
        if !text.wrappedValue.isEmpty {
            text.wrappedValue.removeLast()
            AudioManager.shared.playMoveSound()
        }
    }
    
    private func changeBirthdayValue(increment: Bool) {
        if cursorX == 0 { // Month
            if increment {
                birthMonth = birthMonth == 12 ? 1 : birthMonth + 1
            } else {
                birthMonth = birthMonth == 1 ? 12 : birthMonth - 1
            }
        } else { // Day
            if increment {
                birthDay = birthDay == 31 ? 1 : birthDay + 1
            } else {
                birthDay = birthDay == 1 ? 31 : birthDay - 1
            }
        }
    }
    
    private func getChar(row: Int, col: Int, mode: Int) -> String {
        let keys = StepKeyboardController.getKeys(mode: mode)
        if row >= 0 && row < keys.count {
            let rowKeys = keys[row]
            if col >= 0 && col < rowKeys.count {
                return rowKeys[col]
            }
        }
        return "?"
    }
    
    private func saveAndFinish() {
        guard let sysDir = DSBiosManager.shared.systemDirectory else {
            onFinish()
            return
        }
        
        let finalNick = nickname.isEmpty ? "Sumee" : nickname
        let finalMsg = message.isEmpty ? "Hello!" : message
        
        let firmwarePath = sysDir.appendingPathComponent("firmware.bin")
        AudioManager.shared.playStartGameSound()
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if FileManager.default.fileExists(atPath: firmwarePath.path) {
                    let data = try Data(contentsOf: firmwarePath)
                    
                    let settings = DSFirmwarePatcher.UserSettings(
                        nickname: finalNick,
                        message: finalMsg,
                        favoriteColor: selectedColorIndex,
                        birthMonth: birthMonth,
                        birthDay: birthDay,
                        language: selectedLanguage
                    )
                    
                    if let patchedData = DSFirmwarePatcher.patchFirmware(data: data, settings: settings) {
                        try patchedData.write(to: firmwarePath)
                    }
                }
                
                // Mark setup as complete so it doesn't show again automatically
                UserDefaults.standard.set(true, forKey: "ds_firmware_configured")
                
            } catch {
                print(" Error updating firmware: \(error)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onFinish()
            }
        }
    }
}

// MARK: - Controller Views (Optimized for Landscape)

struct StepLanguageController: View {
    @Binding var selection: Int
    @Binding var cursorX: Int
    @Binding var cursorY: Int
    
    let languages = ["日本語", "English", "Français", "Deutsch", "Italiano", "Español"]
    
    var body: some View {
        HStack(spacing: 10) { // Reduced spacing further
            // Left: Instruction
            VStack {
                Text("Select Language")
                    .font(.headline).foregroundColor(.gray)
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    Image(systemName: "globe")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .frame(width: 80, height: 80)
                
                Spacer()
            }
            .frame(width: 150) // Reduced width to 150 to give max width to buttons
            
            // Right: Grid (3 columns x 2 rows)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                ForEach(0..<languages.count, id: \.self) { index in
                    let isSelected = selection == index
                    let isFocused = (cursorY * 3 + cursorX) == index
                    
                    Button(action: {
                        selection = index
                        cursorX = index % 3
                        cursorY = index / 3
                        AudioManager.shared.playSelectSound()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color(red: 0.45, green: 0.55, blue: 0.65) : Color.white)
                                .shadow(radius: 2)
                            
                            if isFocused {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 3)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            }
                            
                            Text(languages[index])
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(isSelected ? .white : .black)
                                .lineLimit(1) // Force single line
                                .minimumScaleFactor(0.5) // Allow text to scale down to fit
                        }
                        .frame(height: 65) // Reverted height to 65
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
    }
}

struct StepKeyboardController: View {
    let title: String
    @Binding var text: String
    let maxLength: Int
    @Binding var cursorX: Int
    @Binding var cursorY: Int
    @Binding var mode: Int
    
    var body: some View {
        HStack(spacing: 20) {
            // Left: Input Display
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline).foregroundColor(.gray)
                
                HStack(alignment: .top) {
                    Text(text + "_")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(minHeight: 60) 
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                
                HStack {
                    Spacer()
                    Text("\(text.count)/\(maxLength)")
                        .font(.caption).foregroundColor(.gray)
                }
                Spacer()
            }
            .frame(width: 200)
            
            // Right: Keyboard Grid
            VStack(spacing: 6) {
                let keys = StepKeyboardController.getKeys(mode: mode)
                
                ForEach(0..<keys.count, id: \.self) { rowIndex in
                    HStack(spacing: 4) {
                        ForEach(0..<keys[rowIndex].count, id: \.self) { colIndex in
                            let isFocused = (cursorY == rowIndex && cursorX == colIndex)
                            let char = keys[rowIndex][colIndex]
                            
                            Button(action: {
                                if text.count < maxLength {
                                    text += char
                                    cursorY = rowIndex
                                    cursorX = colIndex
                                    AudioManager.shared.playSelectSound()
                                }
                            }) {
                                KeyButton(char: char, isFocused: isFocused)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Bottom Row: Shift + Space + Backspace
                HStack(spacing: 10) {
                    // Shift/Mode Key (Index 0 in Row 4)
                    let isShiftFocused = (cursorY == 4 && cursorX == 0)
                    Button(action: {
                        mode = (mode + 1) % 3
                        cursorY = 4
                        cursorX = 0
                        AudioManager.shared.playSelectSound()
                    }) {
                        KeyButton(char: getModeLabel(mode), isFocused: isShiftFocused)
                            .frame(width: 50)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Space Key (Index 1 in Row 4)
                    let isSpaceFocused = (cursorY == 4 && cursorX == 1)
                    Button(action: {
                        if text.count < maxLength {
                            text += " "
                            cursorY = 4
                            cursorX = 1
                            AudioManager.shared.playSelectSound()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(white: 0.95))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSpaceFocused ? Color.gray : Color.gray, lineWidth: isSpaceFocused ? 3 : 1))
                            Text("SPACE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .frame(height: 35)
                        .frame(maxWidth: .infinity) // Fill remaining space
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Backspace Key (Index 2 in Row 4)
                    let isBSFocused = (cursorY == 4 && cursorX == 2)
                    Button(action: {
                        if !text.isEmpty {
                            text.removeLast()
                            cursorY = 4
                            cursorX = 2
                            AudioManager.shared.playMoveSound()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isBSFocused ? Color.gray : Color.gray, lineWidth: isBSFocused ? 3 : 1))
                            Image(systemName: "delete.left.fill")
                                .foregroundColor(.black)
                        }
                        .frame(width: 50, height: 35)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(10)
    }
    
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
                ["A","S","D","F","G","H","J","K","L","-"],
                ["Z","X","C","V","B","N","M",",",".","/"]
            ]
        case 1: // Lower
            return [
                ["1","2","3","4","5","6","7","8","9","0"],
                ["q","w","e","r","t","y","u","i","o","p"],
                ["a","s","d","f","g","h","j","k","l","-"],
                ["z","x","c","v","b","n","m",",",".","/"]
            ]
        case 2: // Symbols
            return [
                ["!","@","#","$","%","^","&","*","(",")"],
                ["~","`","<",">","[","]","{","}","|","_"],
                ["+","=","\\",";",":","\"","'","?","¿","¡"],
                ["€","£","¥","©","®","™","°","²","³"," "]
            ]
        default: return []
        }
    }
}

struct KeyButton: View {
    let char: String
    let isFocused: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            if isFocused {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray, lineWidth: 2)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray, lineWidth: 1)
            }
            
            Text(char)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
        }
        .frame(height: 35)
        .frame(maxWidth: .infinity)
    }
}

struct StepColorController: View {
    @Binding var selection: Int
    let colors: [Color]
    @Binding var cursorX: Int
    @Binding var cursorY: Int
    
    var body: some View {
        VStack {
            Text("Favorite Color")
                .font(.headline).foregroundColor(.gray)
                .padding(.bottom, 10)
            
            // Landscape Grid 8x2
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                ForEach(0..<colors.count, id: \.self) { index in
                    let isSelected = selection == index
                    let isFocused = (cursorY * 8 + cursorX) == index
                    
                    Button(action: {
                        selection = index
                        cursorX = index % 8
                        cursorY = index / 8
                        AudioManager.shared.playSelectSound()
                    }) {
                        ZStack {
                            Rectangle()
                                .fill(colors[index])
                                .aspectRatio(1, contentMode: .fit)
                                .border(Color.white, width: 2)
                                .shadow(radius: 2)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .font(.title3)
                                    .shadow(radius: 1)
                            }
                            
                            if isFocused {
                                Rectangle()
                                    .strokeBorder(Color.gray, lineWidth: 3)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }
}

struct StepBirthdayController: View {
    @Binding var month: Int
    @Binding var day: Int
    @Binding var cursorX: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Birthday")
                .font(.headline).foregroundColor(.gray)
            
            HStack(spacing: 20) {
                // Month Spinner
                BirthdaySpinner(
                    label: "Month",
                    value: month,
                    isFocused: cursorX == 0,
                    onTap: { cursorX = 0 },
                    onUp: { month = month == 12 ? 1 : month + 1; cursorX = 0 },
                    onDown: { month = month == 1 ? 12 : month - 1; cursorX = 0 }
                )
                
                Text("/")
                    .font(.largeTitle).foregroundColor(.gray)
                    .padding(.top, 15) // Align with numbers
                
                // Day Spinner
                BirthdaySpinner(
                    label: "Day",
                    value: day,
                    isFocused: cursorX == 1,
                    onTap: { cursorX = 1 },
                    onUp: { day = day == 31 ? 1 : day + 1; cursorX = 1 },
                    onDown: { day = day == 1 ? 31 : day - 1; cursorX = 1 }
                )
            }
        }
        .padding()
        .padding(.bottom, 50) // Move content up as requested
    }
}

struct BirthdaySpinner: View {
    let label: String
    let value: Int
    let isFocused: Bool
    var onTap: () -> Void
    var onUp: () -> Void
    var onDown: () -> Void
    
    var body: some View {
        VStack {
            Text(label)
                .font(.caption).bold().foregroundColor(.gray)
            
            VStack(spacing: 5) {
                Button(action: onUp) {
                    Image(systemName: "triangle.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 2)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isFocused ? Color.gray : Color.gray, lineWidth: isFocused ? 3 : 1))
                    
                    Text("\(value)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                }
                .onTapGesture(perform: onTap)
                
                Button(action: onDown) {
                    Image(systemName: "triangle.fill")
                        .font(.caption)
                        .rotationEffect(.degrees(180))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Intro Animation View
struct DSBootAnimView: View {
    var onFinish: () -> Void
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            if let player = player {
                CustomVideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(0.8) // Smaller video
                    .offset(x: 50) // Move slightly to the right
                    .edgesIgnoringSafeArea(.all)
                    // Listen for end of playback
                    .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
                        onFinish()
                    }
            }
        }
        .onAppear {
            if let url = findVideoURL() {
                let p = AVPlayer(url: url)
                self.player = p
                p.play()
            } else {
                print(" DSBootAnimView: 'intro_nds.mp4' not found.")
                onFinish()
            }
        }
    }
    
    private func findVideoURL() -> URL? {
        if let url = Bundle.main.url(forResource: "intro_nds", withExtension: "mp4") { return url }
        if let url = Bundle.main.url(forResource: "intro_nds", withExtension: "mp4", subdirectory: "Videos") { return url }
        return nil
    }
}

// Custom Player to enforce white background
struct CustomVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(player: player)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No update needed
    }
    
    class PlayerUIView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        
        init(player: AVPlayer) {
            super.init(frame: .zero)
            self.backgroundColor = .white // Enforce white background
            
            guard let layer = self.layer as? AVPlayerLayer else { return }
            layer.player = player
            layer.videoGravity = .resizeAspect // Fit, but background will be white
            layer.backgroundColor = UIColor.white.cgColor
        }
        
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}

struct StepConfirmController: View {
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Setup Complete!")
                .font(.title)
                .foregroundColor(.black)
            
            Text("Your profile is ready.")
                .font(.body)
                .foregroundColor(.gray)
            
            Button(action: onSave) {
                Text("Done!")
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.45, green: 0.55, blue: 0.65))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    // Add a subtle border to indicate it's the active element (visually focused)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 4) // Always focused style since it's the only action
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RetroControllerHints: View {
    let currentStep: Int
    var l1Pressed: Bool
    var r1Pressed: Bool
    var onNext: () -> Void
    var onBack: () -> Void
    var onFinish: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            if currentStep > 1 {
                Button(action: onBack) {
                    HStack {
                        // Visual feedback when L1 is pressed
                        Image(systemName: l1Pressed ? "button.programmable" : "arrow.left")
                            .foregroundColor(l1Pressed ? .orange : .white)
                        
                        Text("Back (L)")
                            .foregroundColor(l1Pressed ? .orange : .white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
            
            // Removed central "Select/Finish" button as requested
            
            Spacer()
            
            if currentStep < 6 {
                Button(action: onNext) {
                    HStack {
                        Text("Next (R)")
                            .foregroundColor(r1Pressed ? .orange : .white)
                        
                        // Visual feedback when R1 is pressed
                        Image(systemName: r1Pressed ? "button.programmable" : "arrow.right")
                            .foregroundColor(r1Pressed ? .orange : .white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10)
        .font(.caption).bold()
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .padding(.horizontal, 40)
    }
}

struct RetroGridBackground: View {
    var body: some View {
        Color(white: 0.95) // Light gray background
            .overlay(
                GeometryReader { geo in
                    Path { path in
                        let width = geo.size.width
                        let height = geo.size.height
                        let spacing: CGFloat = 20
                        
                        // Vertical lines
                        for x in stride(from: 0, to: width, by: spacing) {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                        
                        // Horizontal lines
                        for y in stride(from: 0, to: height, by: spacing) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }
            )
    }
}

struct StepsHeader: View {
    let currentStep: Int
    
    var body: some View {
        HStack(spacing: 15) { // Increased spacing slightly
            ForEach(1...6, id: \.self) { step in
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color(white: 0.95), Color(white: 0.85)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    
                    Text("\(step)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(currentStep == step ? .black : .gray.opacity(0.5))
                        .scaleEffect(currentStep == step ? 1.1 : 1.0)
                }
                .frame(width: 40, height: 40) // Increased slightly
                
                if step < 6 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
