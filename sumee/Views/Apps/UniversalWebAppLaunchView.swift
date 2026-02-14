import SwiftUI
import AVFoundation

struct UniversalWebAppLaunchView<Content: View>: View {
    @Binding var isPresented: Bool
    let systemApp: SystemApp
    let content: (Binding<Bool>) -> Content
    
    @State private var animationState: LaunchState = .initial
    @State private var showContent = false
    
    enum LaunchState {
        case initial
        case expanding
        case splash
    }
    
    init(isPresented: Binding<Bool>, systemApp: SystemApp, @ViewBuilder content: @escaping (Binding<Bool>) -> Content) {
        self._isPresented = isPresented
        self.systemApp = systemApp
        self.content = content
    }
    
    var body: some View {
        ZStack {
            // Background (Expanding Animation)
            Color.black
                .clipShape(Circle())
                .scaleEffect(animationState == .initial ? 0.01 : 2.5)
                .opacity(animationState == .initial ? 0 : 1)
                .ignoresSafeArea()
            
            if showContent {
                // Pass a proxy binding that triggers exit sequence instead of immediate dismiss
                content(Binding(
                    get: { isPresented },
                    set: { newValue in
                        if !newValue {
                            startExitSequence()
                        }
                    }
                ))
                .transition(.opacity)
            } else {
                // Splash Screen
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Icon Support (Assets vs SF Symbols)
                    Group {
                        if UIImage(named: systemApp.iconName) != nil {
                            Image(systemApp.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .cornerRadius(22)
                        } else {
                            Image(systemName: systemApp.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(systemApp.defaultColor)
                        }
                    }
                    .shadow(color: systemApp.defaultColor.opacity(0.6), radius: 15, x: 0, y: 0)
                    
                    Text(systemApp.defaultName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    Spacer()
                }
                .scaleEffect(animationState == .initial ? 0.1 : (animationState == .expanding ? 1.2 : 1.0))
                .opacity(animationState == .initial ? 0 : 1)
                .transition(.opacity)
            }
        }
        .onAppear {
            startLaunchSequence()
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
    }
    
    // ... startLaunchSequence (unchanged) ...
    
    private func startExitSequence() {
        // Logic specific to exiting
        if MusicPlayerManager.shared.isPlaying {
             // Just dismiss if player is handling audio
        } else {
            AudioManager.shared.playStopGameSound()
            AudioManager.shared.fadeInBackgroundMusic(duration: 0.8)
        }
        
        dismissAndAnimate()
    }
    
    private func dismissAndAnimate() {
         // Step 1: Hide Content
         withAnimation(.easeOut(duration: 0.3)) {
             showContent = false
             animationState = .splash
         }
         
         // Step 2: Shrink to center
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
             withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                 animationState = .initial
             }
         }
         
         // Step 3: Dismiss View
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
             self.isPresented = false
         }
    }
    
    private func startLaunchSequence() {
        // Audio Logic
        if MusicPlayerManager.shared.isPlaying {
            print(" Music Player active, skipping \(systemApp.defaultName) start audio")
        } else {
            AudioManager.shared.playStartGameSound()
        }
        
        // 1. Expand
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animationState = .expanding
        }
        
        // 2. Settle Splash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                animationState = .splash
            }
        }
        
        // 3. Reveal Content
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.5)) {
                showContent = true
            }
            
            // Fade ambient music if playing (unless system app wants it paused totally, handled by ViewModel)
             if MusicPlayerManager.shared.isPlaying {
                AudioManager.shared.fadeOutBackgroundMusic(duration: 0.5)
            }
        }
    }
}
