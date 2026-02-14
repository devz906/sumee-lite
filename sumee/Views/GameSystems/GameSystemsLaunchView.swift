import SwiftUI

struct GameSystemsLaunchView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: HomeViewModel
    
    @State private var animationState: LaunchState = .initial
    @State private var showContent = false
    @AppStorage("disableStartAnimation") var disableStartAnimation: Bool = false
    
    enum LaunchState {
        case initial
        case expanding
        case splash
    }
    
    var body: some View {
        ZStack {
            // Background (Expanding Circle/Screen)
            Color.black
                .clipShape(Circle())
                .scaleEffect(animationState == .initial ? 0.01 : 2.5)
                .opacity(animationState == .initial ? 0 : (showContent ? 0 : 1))
                .ignoresSafeArea()
            
            if showContent {
                GameSystemsView(isPresented: Binding(
                    get: { isPresented },
                    set: { newValue in
                        if !newValue {
                            startExitSequence()
                        }
                    }
                ), homeViewModel: viewModel, // Passing full VM
                onRequestFilePicker: {
                    viewModel.showingFilePicker = true
                }, onRequestMusicPlayer: {
                    viewModel.showMusicPlayer = true
                }, onEmulatorStarted: { started in
                    // Update header visibility immediately/synchronously with caller
                    viewModel.showGameSystemsHeader = !started
                })
                .transition(.opacity)
            } else {
                // Splash Screen Content
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "gamecontroller.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    Text("Game Systems")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
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
    }
    
    private func startLaunchSequence() {
        if disableStartAnimation {
            showContent = true
            viewModel.showGameSystemsHeader = true
            return
        }

        // Music fade out handled by HomeViewModel before presenting this view
        
        // Check if Music Player is active
        if MusicPlayerManager.shared.isPlaying {
            print(" Music Player active, skipping Game Systems audio")
        } else {
            // Play start sound
            AudioManager.shared.playStartGameSound()
            
            // Music playback moved to GameSystemsView.onAppear to ensure reliability
            // AudioManager.shared.playGameSystemsMusic()
        }
        
        // Step 1: Expand from center
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animationState = .expanding
        }
        
        // Step 2: Settle to normal size (Splash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                animationState = .splash
            }
        }
        
        // Step 3: Show Content
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.5)) {
                showContent = true
            }
            // Show Header with Glass Effect after content appears
            withAnimation(.easeIn(duration: 0.5)) {
                viewModel.showGameSystemsHeader = true
            }
        }
    }
    
    private func startExitSequence() {
        if disableStartAnimation {
            viewModel.showGameSystemsHeader = false
            isPresented = false
            return
        }

        // Hide Header immediately on exit
        withAnimation(.easeOut(duration: 0.3)) {
            viewModel.showGameSystemsHeader = false
        }

        // Check if Music Player is active
        if MusicPlayerManager.shared.isPlaying {
            print("Music Player active, skipping Game Systems exit audio")
            dismissAndAnimate()
        } else {
            // Play stop sound
            AudioManager.shared.playStopGameSound()
            
            // Background music is now continuous, so we don't need to stop or fade it in here
            /*
            AudioManager.shared.stopGameSystemsMusic()
            AudioManager.shared.fadeInBackgroundMusic(duration: 0.8)
            */
            
            dismissAndAnimate()
        }
    }
    
    private func dismissAndAnimate() {
        // Step 1: Hide Content (Show Splash)
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
            isPresented = false
        }
    }
}
