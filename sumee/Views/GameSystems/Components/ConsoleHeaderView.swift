import SwiftUI

struct ConsoleHeaderView: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                     VisualEffectBlur(blurStyle: .systemThinMaterialDark)
                        .cornerRadius(16)
                )
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.leading, 4)
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
