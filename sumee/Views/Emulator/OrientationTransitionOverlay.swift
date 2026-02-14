import SwiftUI

struct OrientationTransitionOverlay: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Adjusting Display...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        .zIndex(9999) // Always on top
    }
}
