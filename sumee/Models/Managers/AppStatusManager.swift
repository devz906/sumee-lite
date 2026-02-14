import SwiftUI
import Combine

class AppStatusManager: ObservableObject {
    static let shared = AppStatusManager()
    
    @Published var messages: [StatusMessage] = []
    
    func show(_ text: String, icon: String = "info.circle", duration: TimeInterval = 2.0) {
        let msg = StatusMessage(id: UUID(), text: text, icon: icon)
        messages.append(msg)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.messages.removeAll { $0.id == msg.id }
        }
    }
}

struct StatusMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let icon: String
}

struct StatusToastView: View {
    @ObservedObject var status = AppStatusManager.shared
    
    var body: some View {
        VStack {
            Spacer()
            ForEach(status.messages) { msg in
                HStack(spacing: 8) {
                    Image(systemName: msg.icon)
                        .foregroundColor(.white)
                    Text(msg.text)
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.75))
                .cornerRadius(12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .padding(.bottom, 20)
        }
        .animation(.easeInOut(duration: 0.25), value: status.messages)
        .allowsHitTesting(false)
    }
}

extension Notification.Name {
    // static let sketchUpdated = Notification.Name("SketchUpdatedNotification") // Removed
}
