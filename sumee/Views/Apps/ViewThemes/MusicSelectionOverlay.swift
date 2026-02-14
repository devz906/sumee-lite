import SwiftUI

struct MusicSelectionOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectionIndex: Int
    @ObservedObject var settings: SettingsManager
    
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
            // Calculate responsive dimensions
        
            let listHeight = isLandscape 
                ? max(150, geo.size.height - 140) 
                : 550.0
            
            let cardWidth = min(geo.size.width - 40, isLandscape ? 480 : 420)
            
            ZStack {
                // 1. Background (Solid with Grid)
                themeBg.ignoresSafeArea()
                PromptGridBackground(isDark: colorScheme == .dark)
                    .ignoresSafeArea()
                
                // 2. Main Content Card
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 6) {
                        Text("Select Music")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(textMain)
                        
                        Text("Choose background music")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, isLandscape ? 20 : 30)
                    .padding(.bottom, isLandscape ? 10 : 20)
                    
                    // List of Songs
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(0..<MusicPlayerManager.shared.systemSongs.count, id: \.self) { index in
                                    let song = MusicPlayerManager.shared.systemSongs[index]
                                    let isSelected = (settings.customThemeMusic == song.fileName)
                                    let isFocused = (selectionIndex == index)
                                    
                                    Button(action: {
                                        handleSelection(song: song)
                                    }) {
                                        HStack {
                                            // Icon
                                            ZStack {
                                                Image(systemName: isSelected ? "speaker.wave.2.fill" : "music.note")
                                                    .foregroundColor(isFocused ? .white : (isSelected ? themeBlue : .gray))
                                            }
                                            .frame(width: 24, height: 24)
                                            
                                            // Text
                                            Text(song.title)
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundColor(isFocused ? .white : textMain)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(isFocused ? .white : themeBlue)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(isFocused ? themeBlue : (colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95)))
                                        )
                                        // The rotating border from ResumePromptView
                                        .rotatingBorder(isSelected: isFocused, lineWidth: 4)
                                        .scaleEffect(isFocused ? 1.02 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                        .frame(height: listHeight) // Dynamic Height
                        .onChange(of: selectionIndex) { _, newIndex in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    
                    Spacer().frame(height: 20)
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
        .zIndex(2000)
    }
    
    private func handleSelection(song: Song) {
        settings.customThemeMusic = song.fileName
        AudioManager.shared.playSelectSound()
        // We close on selection for music as it's a single choice
        withAnimation { isPresented = false }
    }
}

// Background Component (Local Copy to match ResumePromptView style)
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
