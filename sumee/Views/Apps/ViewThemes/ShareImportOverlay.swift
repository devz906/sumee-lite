import SwiftUI
import UniformTypeIdentifiers

struct ShareImportOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectionIndex: Int
    @ObservedObject var settings: SettingsManager

    // Actions for Touch Interaction
    var onExport: (() -> Void)?
    var onImport: (() -> Void)?
    
    // File Importer State 
    @Environment(\.colorScheme) var colorScheme
    
    // Theme Colors
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
            
            // Adjust dimensions
            let cardWidth = min(geo.size.width - 40, isLandscape ? 400 : 360)
            
            ZStack {
                // 1. Background
                themeBg.ignoresSafeArea()
                PromptGridBackground(isDark: colorScheme == .dark)
                    .ignoresSafeArea()
                
                // 2. Main Content Card
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                             .font(.system(size: 32))
                             .foregroundColor(themeBlue)
                             .padding(.top, 10)
                        
                        Text("Share Theme")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(textMain)
                        
                        Text("Export your custom theme or import a new one.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 30)
                    
                    // Options List
                    VStack(spacing: 16) {
                        // Option 0: Export
                        MenuOptionButton(
                            title: "Export to File",
                            icon: "arrow.up.doc.fill",
                            isSelected: selectionIndex == 0,
                            action: { 
                                selectionIndex = 0
                                onExport?()
                            }
                        )
                        
                        // Option 1: Import
                        MenuOptionButton(
                            title: "Import from File",
                            icon: "arrow.down.doc.fill",
                            isSelected: selectionIndex == 1,
                            action: { 
                                selectionIndex = 1
                                onImport?()
                            }
                        )
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                    
                }
                .background(cardBg)
                .overlay(alignment: .topTrailing) {
                    Button(action: { withAnimation { isPresented = false } }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.gray.opacity(0.6))
                            .background(Circle().fill(cardBg))
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 20, x: 0, y: 10)
                .frame(width: cardWidth)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .zIndex(3000)
    }
    
    // MARK: - Helper Views
    
    private func MenuOptionButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .white : themeBlue)
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : textMain)
                
                Spacer()
            }
            .padding()
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? themeBlue : (colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95)))
            )
            .rotatingBorder(isSelected: isSelected, lineWidth: 3)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// Background Component
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
