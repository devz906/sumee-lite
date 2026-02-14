import SwiftUI

struct DiscordLaunchView: View {
    @Binding var isPresented: Bool
    
    @State private var animationState: LaunchState = .initial
    @State private var showContent = false
    
    enum LaunchState {
        case initial
        case expanding
        case splash
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .clipShape(Circle())
                .scaleEffect(animationState == .initial ? 0.01 : 2.5)
                .opacity(animationState == .initial ? 0 : 1)
                .ignoresSafeArea()
            
            if showContent {
                // Discord content
                ZStack {
                    Color.white.ignoresSafeArea()
                    
                    VStack {
                         Spacer()
                         Image("discord_icon")
                             .resizable()
                             .scaledToFit()
                             .frame(width: 100, height: 100)
                             .foregroundColor(Color(red: 88/255, green: 101/255, blue: 242/255))
                         Text("If you have an idea, you are a programmer or you want to report a bug, enter our discord")
                             .font(.body)
                             .multilineTextAlignment(.center)
                             .padding(.horizontal)
                             .padding(.top, 10)
                             .foregroundColor(.black)
                         
                         Button(action: {
                             if let url = URL(string: "https://discord.gg/VVRFE6Aa4R") {
                                 UIApplication.shared.open(url)
                             }
                         }) {
                             Text("Join Discord")
                                 .fontWeight(.bold)
                                 .foregroundColor(.white)
                                 .padding(.horizontal, 24)
                                 .padding(.vertical, 12)
                                 .background(Color(red: 88/255, green: 101/255, blue: 242/255))
                                 .cornerRadius(25)
                         }
                         .padding(.top, 20)
                         
                         Spacer()
                         
                         // Close button
                         Button(action: {
                             startExitSequence()
                         }) {
                             HStack(spacing: 8) {
                                  Image(systemName: "b.circle.fill")
                                      .font(.system(size: 20))
                                  Text("to close")
                                      .fontWeight(.bold)
                             }
                             .font(.headline)
                             .foregroundColor(.white)
                             .padding(.horizontal, 24)
                             .padding(.vertical, 12)
                             .background(Color(red: 88/255, green: 101/255, blue: 242/255))
                             .cornerRadius(25)
                             .shadow(radius: 4)
                         }
                         .padding(.bottom, 40)
                    }
                }
                .transition(.opacity)
            } else {
                // Splash Screen Content
                VStack {
                    Spacer()
                    VStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 88/255, green: 101/255, blue: 242/255))
                                .frame(width: 80, height: 80)
                            
                            Image("discord_icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.white)
                        }
                        .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 0)
                        
                        Text("Discord")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.top, 16)
                    }
                    .scaleEffect(animationState == .initial ? 0.1 : (animationState == .expanding ? 1.2 : 1.0))
                    .opacity(animationState == .initial ? 0 : 1)
                    .rotationEffect(.degrees(animationState == .initial ? -180 : 0))
                        
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            startLaunchSequence()
        }
        .onReceive(GameControllerManager.shared.$buttonBPressed) { pressed in
            if pressed {
                startExitSequence()
            }
        }
    }
    
    private func startLaunchSequence() {
        // Music fade out logic
        if MusicPlayerManager.shared.isPlaying {
            print("Music Player active, skipping Discord Launch audio")
        } else {
            AudioManager.shared.fadeOutBackgroundMusic(duration: 0.5)
            AudioManager.shared.playStartGameSound()
        }
        
        // Step 1: Expand from center
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animationState = .expanding
        }
        
        // Step 2: Settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                animationState = .splash
            }
        }
        
        // Step 3: Show Content
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.5)) {
                showContent = true
            }
        }
    }
    
    private func startExitSequence() {
        // Play sound unconditionally if that's what's missing, or ensure logic is correct
        AudioManager.shared.playStopGameSound {
            if !MusicPlayerManager.shared.isPlaying {
                AudioManager.shared.fadeInBackgroundMusic(duration: 0.8)
            }
        }
        dismissAndAnimate()
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
