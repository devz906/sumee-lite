import SwiftUI

struct ImportAnimationView: View {
    let rom: ROMItem
    var onDismiss: () -> Void
    
    @State private var animationPhase: AnimationPhase = .variableInit
    
    enum AnimationPhase {
        case variableInit
        case blackScreen
        case dropIn
        case settled
        case dismiss
    }
    
    var body: some View {
        ZStack {
            // Absolute Black Background
            Color.black
                .ignoresSafeArea()
                .opacity(animationPhase == .dismiss ? 0 : 1)
            
            if animationPhase == .dropIn || animationPhase == .settled || animationPhase == .dismiss {
                VStack(spacing: 20) {
                    // ROM Card
                    ROMCardView(rom: rom, isSelected: true)
                        .scaleEffect(1.2)
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                        .offset(y: animationPhase == .dropIn ? -300 : 0) // Start high up
                        .opacity(animationPhase == .dropIn ? 0 : (animationPhase == .dismiss ? 0 : 1))
                }
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        // Phase 1: Immediate Black Screen
        animationPhase = .blackScreen
        
        // Phase 2: Drop In
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            animationPhase = .dropIn
            
            // Play Sound
            AudioManager.shared.playCartridgeSound()
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animationPhase = .settled
            }
        }
        
        // Phase 3: Dismiss (Faster)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.4)) {
                animationPhase = .dismiss
            }
            
            // Call completion after animation finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onDismiss()
            }
        }
    }
}
