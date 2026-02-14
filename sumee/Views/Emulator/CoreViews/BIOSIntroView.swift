import SwiftUI
import AVFoundation

struct BIOSIntroView: View {
    var onFinish: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    // Config
    let logoText = "SUMEE!"
    
    // Animation State
    @State private var letterScales: [CGFloat]
    @State private var letterOpacities: [Double]
    @State private var isLanded: Bool = false
    @State private var impactFlashOpacity: Double = 0
    
    @State private var player: AVAudioPlayer?
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        let count = "SUMEE!".count
        // Start state: Huge and Invisible
        _letterScales = State(initialValue: Array(repeating: 10.0, count: count))
        _letterOpacities = State(initialValue: Array(repeating: 0.0, count: count))
    }
    
   
    
    // 3. Background
    var backgroundView: some View {
        let colors: [Color] = colorScheme == .dark ?
            [
                Color(white: 0.15),
                Color.black
            ] :
            [
                Color.white,
                Color(red: 0.88, green: 0.9, blue: 1.0)
            ]
            
        return RadialGradient(
            gradient: Gradient(colors: colors),
            center: .center,
            startRadius: 5,
            endRadius: 500
        )
    }
    
    // 1. Moving State: Metallic
    var metallicGradient: LinearGradient {
        let colors: [Color] = colorScheme == .dark ?
            [ // Dark Chrome
                Color(white: 0.3),
                Color(white: 0.1),
                Color(white: 0.25)
            ] :
            [ // Silver
                Color(white: 0.8),
                Color(white: 0.4),
                Color(white: 0.7)
            ]
            
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // 2. Landed State: Brand Gradient
    var brandGradient: LinearGradient {

        let colors: [Color] = colorScheme == .dark ?
            [ // Neon/Glowy Indigo
                Color(red: 100/255, green: 80/255, blue: 200/255),
                Color(red: 140/255, green: 120/255, blue: 255/255),
                Color(red: 80/255, green: 60/255, blue: 160/255)
            ] :
            [ // Standard Deep Brand
                Color(red: 60/255, green: 40/255, blue: 120/255),
                Color(red: 100/255, green: 80/255, blue: 180/255),
                Color(red: 40/255, green: 20/255, blue: 80/255)
            ]
            
        return LinearGradient(
            colors: colors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundView.ignoresSafeArea()
            
            VStack {
                HStack(spacing: 4) { // Improved spacing
                    ForEach(Array(logoText.enumerated()), id: \.offset) { index, char in
                        Text(String(char))
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            // Gradient Logic
                            .foregroundStyle(
                                isLanded ? AnyShapeStyle(brandGradient) : AnyShapeStyle(metallicGradient)
                            )
                            // Shadow logic: No shadow while flying (clean), soft shadow when landed
                            .shadow(
                                color: isLanded ? Color.indigo.opacity(0.4) : .clear,
                                radius: isLanded ? 4 : 0,
                                x: 0, 
                                y: isLanded ? 4 : 0
                            )
                            .scaleEffect(letterScales[index])
                            .opacity(letterOpacities[index])
                            .blur(radius: isLanded ? 0 : 2) // Motion blur simulation
                    }
                }
            }
            
            // Impact Flash Overlay
            Color.white
                .ignoresSafeArea()
                .opacity(impactFlashOpacity)
                .blendMode(.overlay) // Adds brightness without washing out completely
        }
        .onAppear {
            startCinematicAnimation()
        }
    }
    
    private func playSound() {
        guard let url = Bundle.main.url(forResource: "sound_bios", withExtension: "mp3") else { return }
        try? player = AVAudioPlayer(contentsOf: url)
        player?.play()
    }
    
    private func startCinematicAnimation() {
        // High-Quality Timing
        let letterDelay = 0.12
        let duration = 0.5
        
        for i in 0..<logoText.count {
            let delay = Double(i) * letterDelay
            
            // Fly-in: Spring with no bounce, just smooth deceleration (magnetic snap)
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(delay)) {
                letterOpacities[i] = 1.0
                letterScales[i] = 1.0
            }
        }
        
        let totalTime = Double(logoText.count) * letterDelay + 0.3
        
        // Impact Moment (All letters settled)
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            // 1. Color Snap
            isLanded = true
            
            // 2. Audio Impact
            playSound()
            
            // 3. Visual Flash "Bloom"
            withAnimation(.easeOut(duration: 0.1)) {
                impactFlashOpacity = 0.6
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                impactFlashOpacity = 0
            }
        }
        
        // Finish larget delay to admire
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime + 2.5) {
            onFinish()
        }
    }
}
