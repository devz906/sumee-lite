import SwiftUI

struct ControlAction: Identifiable {
    var id: String {
        return "\(label)-\(icon)"
    }
    let icon: String
    let label: String
    var action: (() -> Void)? = nil
}

struct ControlCard: View {
    let actions: [ControlAction]
    var position: BubblePosition = .left // Default to left style
    var glowColor: Color? = nil // Optional custom glow color
    var isOpaque: Bool = false // Toggle for performance optimization
    var isHorizontal: Bool = false // Toggle for horizontal layout
    var scale: CGFloat = 1.0 // Scale factor for size
    
    var body: some View {
        Group {
            if isHorizontal {
                HStack(spacing: 16 * scale) {
                    ForEach(actions) { item in
                        if let itemAction = item.action {
                            Button(action: itemAction) {
                                ControlActionRow(icon: item.icon, label: item.label, scale: scale)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ControlActionRow(icon: item.icon, label: item.label, scale: scale)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4 * scale) {
                    ForEach(actions) { item in
                        if let itemAction = item.action {
                            Button(action: itemAction) {
                                ControlActionRow(icon: item.icon, label: item.label, scale: scale)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            ControlActionRow(icon: item.icon, label: item.label, scale: scale)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12 * scale)
        .padding(.vertical, 8 * scale)
        .background(
            Group {
                if isOpaque {
                    RoundedRectangle(cornerRadius: 16 * scale)
                        .fill(Color.white) // 100% Solid -> No GPU Blending
                } else {
                    BubbleBackground(position: position, cornerRadius: 16 * scale)
                }
            }
        )
    }
}

struct ControlActionRow: View {
    let icon: String
    let label: String
    var scale: CGFloat = 1.0
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        HStack(spacing: 6 * scale) {
            Image(systemName: icon)
                .font(.system(size: 14 * scale, weight: .bold))
                .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : .black.opacity(0.8))
                .frame(width: 18 * scale, alignment: .center)
            
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : .black.opacity(0.8))
            }
        }
    }
}
