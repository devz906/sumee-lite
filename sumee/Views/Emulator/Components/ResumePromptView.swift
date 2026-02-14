import SwiftUI

struct ResumePromptView: View {
    let screenshotURL: URL?
    let onResume: () -> Void
    let onNewGame: () -> Void
    
    @State private var screenshot: UIImage?
    @ObservedObject private var gameController = GameControllerManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    enum Action {
        case newGame
        case resume
    }
    
    @State private var selectedAction: Action = .resume
    
    // Animation States
    @State private var showContent = false
    
    // Dynamic Theme Colors
    var themeBlue: Color {
        Color(red: 0/255, green: 158/255, blue: 224/255)
    }
    
    var themeBg: Color {
        colorScheme == .dark 
            ? Color(red: 28/255, green: 28/255, blue: 30/255)
            : Color(red: 235/255, green: 235/255, blue: 240/255)
    }

    var cardBg: Color {
        colorScheme == .dark ? Color(red: 44/255, green: 44/255, blue: 46/255) : Color.white
    }
    
    var textMain: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.8)
    }
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            
            let cardHeight = isLandscape ? min(geo.size.height - 40, 320) : 520
            let cardWidth = isLandscape ? 500.0 : 340.0
            
            ZStack {
                // 1. Opaque Wii U Style Background (Hides Emulator)
                ZStack {
                    themeBg.ignoresSafeArea()
                    PromptGridBackground(isDark: colorScheme == .dark)
                }
                .opacity(showContent ? 1 : 0)
                
                // 2. Adaptive Card Layout
                ZStack {
                    if isLandscape {
                        // LANDSCAPE LAYOUT (HStack)
                        HStack(spacing: 0) {
                            // Left: Hero Image
                            heroImageSection(isLandscape: true)
                                .frame(width: cardWidth * 0.45)
                                .frame(maxHeight: .infinity)
                                .clipped()
                            
                            // Right: Controls
                            controlsSection(compact: true)
                                .frame(width: cardWidth * 0.55)
                                .padding(20)
                        }
                    } else {
                        // PORTRAIT LAYOUT (VStack)
                        VStack(spacing: 0) {
                            heroImageSection(isLandscape: false)
                                .frame(height: 220)
                            
                            controlsSection(compact: false)
                                .padding(24)
                        }
                    }
                }
                .background(cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 20, x: 0, y: 10) // Deeper shadow in dark mode
                .frame(width: cardWidth, height: isLandscape ? cardHeight : nil)
                // ENTRANCE ANIMATION
                .scaleEffect(showContent ? 1.0 : 0.95)
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 20)
                
                // 3. Floating Control Hints (Outside Card)
                VStack {
                    Spacer()
                    if isLandscape {
                        HStack {
                            ControlCard(
                                actions: [ControlAction(icon: "dpad.left.filled", label: "Select")], 
                                position: .left
                            )
                            Spacer()
                            ControlCard(
                                actions: [ControlAction(icon: "a.circle.fill", label: "Confirm")], 
                                position: .right
                            )
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                    } else {
                        // Portrait: Center bottom
                         HStack {
                            ControlCard(
                                actions: [
                                    ControlAction(icon: "dpad.left.filled", label: "Select"),
                                    ControlAction(icon: "a.circle.fill", label: "Confirm")
                                ],
                                position: .center,
                                isHorizontal: true
                            )
                        }
                        .padding(.bottom, 40)
                    }
                }
                .opacity(showContent ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(.identity) 
        .zIndex(2000)
        .onAppear {
            if let url = screenshotURL {
                self.screenshot = UIImage(contentsOfFile: url.path)
            }
            selectedAction = .resume
            
            // Fast, crisp entrance
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)) {
                showContent = true
            }
        }
        // Input Handling
        .onChange(of: gameController.dpadLeft) { _, pressed in
            if pressed {
                AudioManager.shared.playMoveSound()
                selectedAction = .newGame
            }
        }
        .onChange(of: gameController.dpadRight) { _, pressed in
            if pressed {
                AudioManager.shared.playMoveSound()
                selectedAction = .resume
            }
        }
        .onChange(of: gameController.buttonAPressed) { _, pressed in
            if pressed {
                AudioManager.shared.playSelectSound()
                switch selectedAction {
                case .resume: onResume()
                case .newGame: onNewGame()
                }
            }
        }
        .onChange(of: gameController.buttonBPressed) { _, pressed in
            if pressed {
                AudioManager.shared.playSelectSound()
                onNewGame()
            }
        }
    }
    
    //  Components
    
    @ViewBuilder
    func heroImageSection(isLandscape: Bool) -> some View {
        ZStack(alignment: isLandscape ? .topLeading : .bottomLeading) {
            colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95) // Placeholder
            
            if let image = screenshot {
                GeometryReader { imageGeo in
                    ZStack {
                        // 1. Blurred Background Fill (Subtle)
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: imageGeo.size.width, height: imageGeo.size.height)
                            .clipped()
                            .blur(radius: 20)
                            .opacity(0.3)
                        
                        // 2. Main Image Fit
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: imageGeo.size.width, height: imageGeo.size.height)
                    }
                }
                .clipped()
            } else {
                ZStack {
                    colorScheme == .dark ? Color(white: 0.1) : Color.white
                    Image(systemName: "gamecontroller.fill")
                        .font(.largeTitle)
                        .foregroundColor(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.2))
                }
            }
            
            // Gradient Overlay (Lighter, for text readability)
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: isLandscape ? .center : .top,
                endPoint: .bottom
            )
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(themeBlue).frame(width: 8, height: 8)
                    Text("AUTO-SAVE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3)) // Capsule bg for contrast
                        .clipShape(Capsule())
                }
            }
            .padding(16)
        }
    }
    
    @ViewBuilder
    func controlsSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 20) {
            
            // Title in the Content Section (Clean Typography)
            VStack(alignment: .leading, spacing: 6) {
                Text("Resume Game?")
                    .font(.system(size: 24, weight: .heavy, design: .rounded)) // Rounded Font
                    .foregroundColor(textMain)
                
                Text(compact ? "Continue where you left off?" : "Would you like to load your last auto-save point?")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
            
            if compact { Spacer() }
            
            // Buttons
            HStack(spacing: 12) {
                // RESTART
                Button(action: { 
                    AudioManager.shared.playSelectSound()
                    onNewGame() 
                }) {
                    Text("Restart")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(selectedAction == .newGame ? themeBlue : Color.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95))
                        )
                        .rotatingBorder(isSelected: selectedAction == .newGame, lineWidth: 4)
                        .scaleEffect(selectedAction == .newGame ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                
                // RESUME
                Button(action: { 
                    AudioManager.shared.playSelectSound()
                    onResume() 
                }) {
                     Text("Resume")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(themeBlue)
                        )
                        .rotatingBorder(isSelected: selectedAction == .resume, lineWidth: 4)
                        .scaleEffect(selectedAction == .resume ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
            }
            
            if compact { Spacer() }
        }
    }
}

// Background Component (Local Copy to match GamepadSettingsView style)
private struct PromptGridBackground: View {
    var isDark: Bool = false
    
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
            .stroke(
                isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), 
                lineWidth: 1
            )
        }
    }
}
