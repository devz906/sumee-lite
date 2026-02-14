import SwiftUI
import AVKit

struct WelcomeView: View {
    var onDismiss: () -> Void
    enum WelcomeStep {
        case video
        case name
        case avatar
        case theme
        case bootVideo
    }
    
    @State private var currentStep: WelcomeStep = .video
    @ObservedObject private var profileManager = ProfileManager.shared
    @ObservedObject private var controller = GameControllerManager.shared
    
    // Keyboard State
    @State private var cursorX: Int = 0
    @State private var cursorY: Int = 0
    @State private var keyboardMode: Int = 0
    @State private var lastStickTime = Date()
    
    // Avatar Selection State
    @State private var avatarCursorRow: Int = 0
    @State private var avatarCursorCol: Int = 0
    @State private var selectedAvatarColor: Color = .blue
    @State private var showPhotoPicker = false
    @State private var pickedAvatarImage: UIImage?
    
    @State private var selectedTheme: Int = 0 // 0: Default, 1: Christmas, 2: Homebrew
    @State private var themeCursorPosition: Int = 0 // 0: Default, 1: Christmas, 2: Homebrew, 3: Next
    
    let avatarColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown,
        .gray, .black
    ]
    let avatarGridCols = 7
    
    // Limits
    private let maxNameLength = 12
    
    var body: some View {
        ZStack {
            // 1. Background
            WelcomeRetroGridBackground()
                .ignoresSafeArea()
                .onTapGesture {
              
                }
            
            // 2. Intro Video
     
            switch currentStep {
            case .video:
                WelcomeVideoPlayer {
                    withAnimation(.easeOut(duration: 0.5)) {
                        currentStep = .name
                    }
                    AudioManager.shared.playProfileMusic()
                }
                .transition(.opacity)
                .edgesIgnoringSafeArea(.all)
                
            case .name:
                VStack(spacing: 20) {
                    Text("Enter Your Name")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                    
                    WelcomeKeyboardController(
                        text: $profileManager.username,
                        maxLength: maxNameLength,
                        cursorX: $cursorX,
                        cursorY: $cursorY,
                        mode: $keyboardMode
                    )
                    
                    Button(action: {
                        goToAvatarStep()
                    }) {
                        Text("Next")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(cursorY == 5 ? Color.white : Color(red: 0.45, green: 0.55, blue: 0.65))
                            .foregroundColor(cursorY == 5 ? Color(red: 0.45, green: 0.55, blue: 0.65) : .white)
                            .cornerRadius(8)
                            .scaleEffect(cursorY == 5 ? 1.1 : 1.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.45, green: 0.55, blue: 0.65), lineWidth: cursorY == 5 ? 3 : 0)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 20)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                
            case .avatar:
                WelcomeAvatarSelectionView(
                    username: profileManager.username,
                    colors: avatarColors,
                    gridCols: avatarGridCols,
                    cursorRow: $avatarCursorRow,
                    cursorCol: $avatarCursorCol,
                    selectedColor: $selectedAvatarColor,
                    pickedImage: pickedAvatarImage,
                    onGalleryRequest: {
                        showPhotoPicker = true
                    },
                    onFinish: {
                        withAnimation {
                            currentStep = .theme
                        }
                        AudioManager.shared.playSelectSound()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                
            case .theme:
                WelcomeThemeSelectionView(
                    selectedTheme: $selectedTheme,
                    cursorPosition: $themeCursorPosition,
                    onFinish: {
                        withAnimation {
                            currentStep = .bootVideo
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                
            case .bootVideo:
                WelcomeBootVideoPlayer {
                    finishSetup()
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // Lock to Landscape
            AppDelegate.orientationLock = .landscape
            if #available(iOS 16.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
                }
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            }
            
            // Stop any background music when WelcomeView appears
            AudioManager.shared.stopBackgroundMusic()
            
            // Reset default name
            if profileManager.username == "Type your user name" {
                profileManager.username = ""
            }
            controller.disableHomeNavigation = true
        }
        .onDisappear {
            // Unlock Orientation
            AppDelegate.orientationLock = .all
            
            // Force rotation update
            if #available(iOS 16.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.unknown.rawValue, forKey: "orientation")
            }
            UIViewController.attemptRotationToDeviceOrientation()
            
            AudioManager.shared.stopBackgroundMusic()
            controller.disableHomeNavigation = false
        }
        .onChange(of: controller.lastInputTimestamp) { _ in
            if currentStep != .video { handleControllerInput() }
        }
        .onChange(of: controller.leftThumbstickX) { _ in if currentStep != .video { handleControllerInput() } }
        .onChange(of: controller.leftThumbstickY) { _ in if currentStep != .video { handleControllerInput() } }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectedImage: $pickedAvatarImage) {
                // On dismiss
            }
        }
    }
    
    private func goToAvatarStep() {
        if profileManager.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profileManager.username = "Sumee"
        }
        withAnimation {
            currentStep = .avatar
        }
    }
    
    private func finishSetup() {
        // Save Icon Set preference
        profileManager.iconSet = 1
        
        // Save Theme Preference
        let settings = SettingsManager.shared
        // Reset both first to ensure clean state
   
        
        switch selectedTheme {
        case 1: settings.activeThemeID = "christmas"
        case 2: settings.activeThemeID = "homebrew"
        default: 
            // Default selected (0)
            if SettingsManager.isOlderDevice() {
                // Older Device (iPhone 15-, Non-M1 iPad) -> Use Custom Photo (Performance)
                 settings.activeThemeID = "custom_photo"
            } else {
                // Newer Device -> Use Dark Mode
                 settings.activeThemeID = "dark_mode"
            }
        }
        // 0 is default (both false)
        
        if let pickedImage = pickedAvatarImage {
            profileManager.saveImage(pickedImage)
        } else {
            // Generate Image from color
            let initial = String(profileManager.username.prefix(1)).uppercased()
            let image = UIImage.from(color: UIColor(selectedAvatarColor), size: CGSize(width: 200, height: 200), text: initial)
            profileManager.saveImage(image)
        }
        
        dismiss()
    }
    
    private func dismiss() {
        if profileManager.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profileManager.username = "Sumee"
        }
        
        AudioManager.shared.stopBackgroundMusic()
        // Restart main background music
        AudioManager.shared.playBackMusic()
        onDismiss()
    }
    
    // Input State Tracking for "Tap vs Hold" logic
    @State private var lastInputState: (up: Bool, down: Bool, left: Bool, right: Bool) = (false, false, false, false)
    
    //  Controller Input
    private func handleControllerInput() {
        // Unified Input Logic
        let now = Date()
        let deadzone: Float = 0.5
        
        // 1. Determine Current Raw Intent
        let stickUp = controller.leftThumbstickY > deadzone
        let stickDown = controller.leftThumbstickY < -deadzone
        let stickLeft = controller.leftThumbstickX < -deadzone
        let stickRight = controller.leftThumbstickX > deadzone
        
        let currentUp = controller.dpadUp || stickUp
        let currentDown = controller.dpadDown || stickDown
        let currentLeft = controller.dpadLeft || stickLeft
        let currentRight = controller.dpadRight || stickRight
        
        // 2. Logic: Detect New Press vs Hold
        var shouldExecute = false
        
        // Check if ANY state changed to TRUE (Rising Edge - Tap)
        if (currentUp && !lastInputState.up) ||
            (currentDown && !lastInputState.down) ||
            (currentLeft && !lastInputState.left) ||
            (currentRight && !lastInputState.right) {
            shouldExecute = true
            // Reset timer so "Hold" logic starts fresh after a delay
            lastStickTime = now.addingTimeInterval(0.4) // Initial Delay before repeat starts
        }
        // Check if state is HELD (True && True) AND Timer expired (Repeat)
        else if (currentUp || currentDown || currentLeft || currentRight) {
            if now >= lastStickTime {
                shouldExecute = true
                lastStickTime = now.addingTimeInterval(0.15) // Repeat Rate suitable for typing
            }
        }
        
        // 3. Update State History
        lastInputState = (currentUp, currentDown, currentLeft, currentRight)
        
        // 4. Execution
        var navUp = false
        var navDown = false
        var navLeft = false
        var navRight = false
        
        if shouldExecute {
             navUp = currentUp
             navDown = currentDown
             navLeft = currentLeft
             navRight = currentRight
        }
        
        // Always pass control to handler (it handles buttons internally)
        if currentStep == .name {
            handleKeyboardInput(
                text: $profileManager.username,
                max: maxNameLength,
                u: navUp,
                d: navDown,
                l: navLeft,
                r: navRight
            )
        } else if currentStep == .avatar {
            handleAvatarInput(u: navUp, d: navDown, l: navLeft, r: navRight)
        } else if currentStep == .theme {
            handleThemeInput(u: navUp, d: navDown, l: navLeft, r: navRight)
        }
        
        // Always Check Buttons (Independent of navigation)
        handleButtons()
    }
    
    //Input Handlers
    
    private func handleThemeInput(u: Bool, d: Bool, l: Bool, r: Bool) {
        // Navigate between Default (0), Christmas (1), Homebrew (2), and Next (3)
        if u {
            if themeCursorPosition > 0 {
                themeCursorPosition -= 1
                AudioManager.shared.playMoveSound()
            }
        }
        
        if d {
            if themeCursorPosition < 3 {
                themeCursorPosition += 1
                AudioManager.shared.playMoveSound()
            }
        }
        
        if controller.buttonAPressed {
            if themeCursorPosition == 3 {
                // Next button
                AudioManager.shared.playSelectSound()
                withAnimation {
                    currentStep = .bootVideo
                }
            } else {
                // Theme selection button
                selectedTheme = themeCursorPosition
                AudioManager.shared.playSelectSound()
            }
        }
        
        if controller.buttonBPressed {
            withAnimation {
                currentStep = .avatar
            }
            AudioManager.shared.playMoveSound()
        }
    }
    
    private func handleButtons() {
        // Start to finish
        if controller.buttonStartPressed {
            finishSetup() // Or dismiss
            AudioManager.shared.playStartGameSound()
        }
    }
    
    private func handleAvatarInput(u: Bool, d: Bool, l: Bool, r: Bool) {
        let totalItems = avatarColors.count + 1 // +1 for Gallery
        let rows = (totalItems + avatarGridCols - 1) / avatarGridCols + 1 // +1 for "Finish" button row
        
        if r {
            if avatarCursorRow == rows - 1 {
                // On Finish button
            } else {
                avatarCursorCol = (avatarCursorCol + 1) % avatarGridCols
                // Check bounds
                let index = avatarCursorRow * avatarGridCols + avatarCursorCol
                if index >= totalItems { avatarCursorCol = 0 } // Wrap
            }
            AudioManager.shared.playMoveSound()
            // Removed autoSelectAvatar()
        }
        
        if l {
             if avatarCursorRow == rows - 1 {
                // On Finish button
            } else {
                avatarCursorCol = (avatarCursorCol - 1 + avatarGridCols) % avatarGridCols
                // Check bounds: if we wrapped to an empty spot at end of row?
                // Simpler: just clamp to last valid item if we land past it
                let index = avatarCursorRow * avatarGridCols + avatarCursorCol
                if index >= totalItems {
                     // Wrap to last VALID item? Or 0?
                     // Let's wrap to index 0 (Gallery) if we go past end
                     if avatarCursorCol >= (totalItems % avatarGridCols) {
                        avatarCursorCol = (totalItems % avatarGridCols) - 1
                     }
                }
            }
            AudioManager.shared.playMoveSound()
            // Removed autoSelectAvatar()
        }
        
        if d {
            if avatarCursorRow < rows - 1 {
                avatarCursorRow += 1
                if avatarCursorRow == rows - 1 {
                    // Moving to Finish Button
                    avatarCursorCol = 0 // Reset col
                } else {
                    // Check valid index in new row
                    let index = avatarCursorRow * avatarGridCols + avatarCursorCol
                    if index >= totalItems { avatarCursorCol = (totalItems - 1) % avatarGridCols }
                    
                    // Removed autoSelectAvatar()
                }
                AudioManager.shared.playMoveSound()
            }
        }
        
        if u {
            if avatarCursorRow > 0 {
                avatarCursorRow -= 1
                // Removed autoSelectAvatar()
                AudioManager.shared.playMoveSound()
            }
        }
        
        // Actions
        if controller.buttonAPressed {
            if avatarCursorRow == rows - 1 {
                withAnimation {
                    currentStep = .theme
                }
                AudioManager.shared.playSelectSound()
            } else {
                // Check what is currently FOCUSED
                let index = avatarCursorRow * avatarGridCols + avatarCursorCol
                
                if index == 0 {
                    // Gallery Button
                    showPhotoPicker = true
                    AudioManager.shared.playSelectSound()
                } else if index > 0 && index < totalItems {
                    // Color Item
                    pickedAvatarImage = nil // Clear any picked image
                    selectedAvatarColor = avatarColors[index - 1] // Update selection
                    AudioManager.shared.playSelectSound()
                }
            }
        }
        
        if controller.buttonBPressed {
            // Go Back
            withAnimation {
                currentStep = .name
            }
            AudioManager.shared.playMoveSound()
        }
    }
    
    private func handleKeyboardInput(text: Binding<String>, max: Int, u: Bool, d: Bool, l: Bool, r: Bool) {
            let cols = 10
            let rows = 6 // Added row 5 for Finish button
            
            // Navigation
            if r {
                if cursorY == 5 {
                    // Stay on Finish button
                } else if cursorY == 4 {
                    cursorX = (cursorX + 1) % 3
                } else {
                    cursorX = (cursorX + 1) % cols
                }
                AudioManager.shared.playMoveSound()
            }
            if l {
                if cursorY == 5 {
                    // Stay on Finish button
                } else if cursorY == 4 {
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
                        if cursorX < 3 { cursorX = 0 }      // Caps
                        else if cursorX > 6 { cursorX = 2 } // Backspace
                        else { cursorX = 1 }                // Space
                    } else if cursorY == 5 {
                        cursorX = 0 // Center for Finish button
                    }
                    AudioManager.shared.playMoveSound()
                }
            }
            if u {
                if cursorY > 0 {
                    cursorY -= 1
                    if cursorY == 4 {
                        cursorX = 1 // Default to Space when coming up from Finish
                    } else if cursorX >= cols {
                        cursorX = cols - 1
                    }
                    
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
                if cursorY == 5 {
                    // Next Button
                    goToAvatarStep()
                    AudioManager.shared.playStartGameSound()
                } else if cursorY == 4 {
                    if cursorX == 0 { // Caps/Mode Switch
                        keyboardMode = (keyboardMode + 1) % 3
                        AudioManager.shared.playSelectSound()
                    } else if cursorX == 1 { // Space
                        if text.wrappedValue.count < max {
                            text.wrappedValue += " "
                            AudioManager.shared.playSelectSound()
                        }
                    } else { // Backspace
                        if !text.wrappedValue.isEmpty {
                            text.wrappedValue.removeLast()
                            AudioManager.shared.playMoveSound()
                        }
                    }
                } else {
                    let keys = WelcomeKeyboardController.getKeys(mode: keyboardMode)
                    if cursorY < keys.count && cursorX < keys[cursorY].count {
                        let char = keys[cursorY][cursorX]
                        if text.wrappedValue.count < max {
                            text.wrappedValue += char
                            AudioManager.shared.playSelectSound()
                        }
                    }
                }
            }
            
            if controller.buttonBPressed {
                if !text.wrappedValue.isEmpty {
                    text.wrappedValue.removeLast()
                    AudioManager.shared.playMoveSound()
                }
            }
            
            if controller.buttonXPressed {
                // X: Insert Space
                if text.wrappedValue.count < max {
                    text.wrappedValue += " "
                    AudioManager.shared.playSelectSound()
                }
            }
            
            if controller.buttonYPressed {
                // Y: Change Mode (CAPS)
                keyboardMode = (keyboardMode + 1) % 3
                AudioManager.shared.playSelectSound()
            }
        }
    }



// Helper Views

struct WelcomeKeyboardController: View {
        @Binding var text: String
        let maxLength: Int
        @Binding var cursorX: Int
        @Binding var cursorY: Int
        @Binding var mode: Int
        
        var body: some View {
            HStack(spacing: 20) {
                // Left: Input Display
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text(text.isEmpty ? "Type Name..." : text + "_")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(text.isEmpty ? .gray : .black)
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
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Controls:")
                            .font(.caption).bold().foregroundColor(.gray)
                        Text("A: Type / Select")
                            .font(.caption).foregroundColor(.gray)
                        Text("B: Backspace")
                            .font(.caption).foregroundColor(.gray)
                        Text("Y: Caps/Mode")
                            .font(.caption).foregroundColor(.gray)
                        Text("X: Space")
                            .font(.caption).foregroundColor(.gray)
                        Text("Highlight 'Finish' & Press A")
                            .font(.caption).foregroundColor(.gray)
                    }
                }
                .frame(width: 200)
                
                // Right: Keyboard Grid
                VStack(spacing: 6) {
                    let keys = WelcomeKeyboardController.getKeys(mode: mode)
                    
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
                                    WelcomeKeyButton(char: char, isFocused: isFocused)
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
                            WelcomeKeyButton(char: getModeLabel(mode), isFocused: isShiftFocused)
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
                            .frame(maxWidth: .infinity)
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
    
    struct WelcomeKeyButton: View {
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
    
    
    struct WelcomeVideoPlayer: View {
        var onFinish: () -> Void
        @State private var player: AVPlayer?
        
        var body: some View {
            ZStack {
                Color.white.ignoresSafeArea() // White background
                
                if let player = player {
                    WelcomeCustomVideoPlayer(player: player)
                        .frame(width: 620, height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
                            onFinish()
                        }
                }
            }
            .onAppear {
                if let url = Bundle.main.url(forResource: "welcome_video", withExtension: "mp4") ??
                    Bundle.main.url(forResource: "welcome_video", withExtension: "mp4", subdirectory: "Videos") {
                    let p = AVPlayer(url: url)
                    self.player = p
                    p.play()
                } else {
                    print(" WelcomeVideoPlayer: 'welcome_video.mp4' not found.")
                    onFinish()
                }
            }
        }
    }
    
    struct WelcomeAvatarSelectionView: View {
        let username: String
        let colors: [Color]
        let gridCols: Int
        @Binding var cursorRow: Int
        @Binding var cursorCol: Int
        @Binding var selectedColor: Color
        var pickedImage: UIImage?
        var onGalleryRequest: () -> Void
        var onFinish: () -> Void
        
        var body: some View {
            GeometryReader { geo in
                let isLandscape = geo.size.width > 600 // Threshold for landscape layout
                
                ZStack {
                    if isLandscape {
                        // Landscape Layout (HStack)
                        HStack(alignment: .center, spacing: 50) {
                            // LEFT COLUMN: Title & Preview
                            VStack(spacing: 30) {
                                Text("Choose Color\nor Image")
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                
                                // Preview
                                ZStack {
                                    if let picked = pickedImage {
                                        Image(uiImage: picked)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 130, height: 130)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white, lineWidth: 5))
                                            .shadow(radius: 6)
                                    } else {
                                        Circle()
                                            .fill(selectedColor)
                                            .frame(width: 130, height: 130)
                                            .shadow(radius: 6)
                                            .overlay(Circle().stroke(Color.white, lineWidth: 5))
                                        
                                        // Simple initial
                                        Text(String(username.prefix(1)).uppercased())
                                            .font(.system(size: 55, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                }
                            }
                            .frame(width: 240)
                            
                            // RIGHT COLUMN: Grid & Finish
                            VStack(spacing: 25) {
                                gridContent
                                finishButton(isFocused: (cursorRow == (colors.count + 1 + gridCols - 1) / gridCols))
                            }
                        }
                        .padding(.horizontal, 30)
                    } else {
                        // Portrait Layout (VStack)
                        VStack(spacing: 20) {
                             Spacer()
                            
                            Text("Choose Color\nor Image")
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            // Preview
                            ZStack {
                                if let picked = pickedImage {
                                    Image(uiImage: picked)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 110, height: 110)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                        .shadow(radius: 4)
                                } else {
                                    Circle()
                                        .fill(selectedColor)
                                        .frame(width: 110, height: 110)
                                        .shadow(radius: 4)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                    
                                    Text(String(username.prefix(1)).uppercased())
                                        .font(.system(size: 45, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                            }
                            
                            // Grid
                            gridContent
                            
                            // Finish
                            finishButton(isFocused: (cursorRow == (colors.count + 1 + gridCols - 1) / gridCols))
                             .padding(.top, 10)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        
        // Helper Views to avoid duplication
        var gridContent: some View {
            VStack(spacing: 8) {
                let totalItems = colors.count + 1
                let rows = (totalItems + gridCols - 1) / gridCols
                
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<gridCols, id: \.self) { col in
                            let index = row * gridCols + col
                            if index < totalItems {
                                let isFocused = (cursorRow == row && cursorCol == col)
                                
                                if index == 0 {
                                    // Gallery Button
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.9))
                                        
                                        Image(systemName: "photo.fill")
                                            .foregroundColor(.gray)
                                            .font(.headline)
                                        
                                        if isFocused {
                                            Circle()
                                                .stroke(Color.black.opacity(0.6), lineWidth: 3)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .scaleEffect(isFocused ? 1.15 : 1.0)
                                    .onTapGesture {
                                        onGalleryRequest()
                                        cursorRow = row
                                        cursorCol = col
                                    }
                                } else {
                                    // Color Item
                                    let colorIndex = index - 1
                                    let color = colors[colorIndex]
                                    
                                    ZStack {
                                        Circle()
                                            .fill(color)
                                        
                                        if isFocused {
                                            Circle()
                                                .stroke(Color.black.opacity(0.6), lineWidth: 3)
                                        }
                                        
                                        if pickedImage == nil && selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.white)
                                                .font(.headline)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .scaleEffect(isFocused ? 1.15 : 1.0)
                                    .onTapGesture {
                                        selectedColor = color
                                        cursorRow = row
                                        cursorCol = col
                                    }
                                }
                            } else {
                                 // Spacer for integrity
                                 Circle().fill(Color.clear).frame(width: 44, height: 44)
                            }
                        }
                    }
                }
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    .background(Color.white.opacity(0.6))
            )
        }
        
        func finishButton(isFocused: Bool) -> some View {
            Button(action: onFinish) {
                Text("Next")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(isFocused ? Color.white : Color(red: 0.45, green: 0.55, blue: 0.65))
                    .foregroundColor(isFocused ? Color(red: 0.45, green: 0.55, blue: 0.65) : .white)
                    .cornerRadius(8)
                    .scaleEffect(isFocused ? 1.1 : 1.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 0.45, green: 0.55, blue: 0.65), lineWidth: isFocused ? 3 : 0)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

struct WelcomeBootVideoPlayer: View {
    var onFinish: () -> Void
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                WelcomeCustomVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
                        onFinish()
                    }
            }
        }
        .onAppear {
            // Try different paths to locate the video
            var url = Bundle.main.url(forResource: "boot_video", withExtension: "mov")
            if url == nil {
                url = Bundle.main.url(forResource: "boot_video", withExtension: "mov", subdirectory: "Resources/Videos")
            }
            
            if let videoURL = url {
                print(" WelcomeBootVideoPlayer: Found video at \(videoURL.path)")
                let p = AVPlayer(url: videoURL)
                self.player = p
                p.play()
            } else {
                print(" WelcomeBootVideoPlayer: 'boot_video.mov' not found in bundle.")
                print("Available video resources: \(Bundle.main.urls(forResourcesWithExtension: "mov", subdirectory: nil) ?? [])")
                onFinish()
            }
        }
    }
}

struct WelcomeCustomVideoPlayer: UIViewRepresentable {
        let player: AVPlayer
        
        func makeUIView(context: Context) -> UIView {
            return PlayerUIView(player: player)
        }
        
        func updateUIView(_ uiView: UIView, context: Context) { }
        
        class PlayerUIView: UIView {
            override static var layerClass: AnyClass { AVPlayerLayer.self }
            
            init(player: AVPlayer) {
                super.init(frame: .zero)
                self.backgroundColor = .white
                
                if let layer = self.layer as? AVPlayerLayer {
                    layer.player = player
                    layer.videoGravity = .resizeAspect // Fit within frame
                    layer.backgroundColor = UIColor.white.cgColor // White "bars"
                }
            }
            
            required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        }
    }
    
    struct WelcomeRetroGridBackground: View {
        var body: some View {
            Color(white: 0.95)
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

extension UIImage {
    static func from(color: UIColor, size: CGSize = CGSize(width: 1, height: 1), text: String? = nil) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            if let text = text {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                
                // Calculate optimal font size (approx 50% of height)
                let fontSize = size.height * 0.5
                let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
                
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraphStyle
                ]
                
                let string = NSAttributedString(string: text, attributes: attrs)
                let textSize = string.size()
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                string.draw(in: textRect)
            }
        }
    }
}

struct WelcomeThemeSelectionView: View {
    @Binding var selectedTheme: Int
    @Binding var cursorPosition: Int
    var onFinish: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 40) {
            // LEFT: Preview (Conceptual Icon)
            VStack(spacing: 20) {
                // Title
                Text("Theme Preview")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                
                // Represent the theme with a large icon
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(radius: 8)
                        .frame(width: 140, height: 140)
                    
                    if selectedTheme == 1 {
                        // Christmas
                        Image(systemName: "snowflake")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.2))
                    } else if selectedTheme == 2 {
                        // Homebrew
                        Image("homebrew_preview")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .cornerRadius(16)
                            .shadow(radius: 2)
                    } else {
                        // Default (standard logo or simple gamepad)
                        Image(systemName: "gamecontroller.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(themeName(for: selectedTheme))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .frame(width: 200)
            
            // RIGHT: Selection Buttons
            VStack(spacing: 20) {
                Text("Choose Theme")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                
                themeButton(title: "Default", index: 0)
                themeButton(title: "Christmas", index: 1)
                themeButton(title: "Bubbles", index: 2)
                
                // Next Button
                Button(action: onFinish) {
                    Text("Next")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(cursorPosition == 3 ? Color.white : Color(red: 0.45, green: 0.55, blue: 0.65))
                        .foregroundColor(cursorPosition == 3 ? Color(red: 0.45, green: 0.55, blue: 0.65) : .white)
                        .cornerRadius(8)
                        .scaleEffect(cursorPosition == 3 ? 1.1 : 1.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.45, green: 0.55, blue: 0.65), lineWidth: cursorPosition == 3 ? 3 : 0)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func themeName(for index: Int) -> String {
        switch index {
        case 0: return "Default"
        case 1: return "Christmas"
        case 2: return "Bubbles"
        default: return ""
        }
    }
    
    private func themeButton(title: String, index: Int) -> some View {
        Button(action: {
            selectedTheme = index
            cursorPosition = index
        }) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .frame(width: 180, height: 44)
                .background(cursorPosition == index ? Color.white : Color(red: 0.45, green: 0.55, blue: 0.65))
                .foregroundColor(cursorPosition == index ? Color(red: 0.45, green: 0.55, blue: 0.65) : .white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.45, green: 0.55, blue: 0.65), lineWidth: cursorPosition == index ? 3 : 0)
                )
                .scaleEffect(cursorPosition == index ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
