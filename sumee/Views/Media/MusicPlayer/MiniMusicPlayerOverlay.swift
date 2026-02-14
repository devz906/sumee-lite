
import SwiftUI

struct MiniMusicPlayerOverlay: View {
    @ObservedObject var musicPlayer = MusicPlayerManager.shared
    
    @State private var collapseTask: Task<Void, Never>?
    @State private var dragOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    
    var body: some View {
        Group {
            if let song = musicPlayer.currentSong, musicPlayer.isSessionActive {
                HStack(spacing: musicPlayer.isMiniPlayerExpanded ? 12 : 0) {
                    // Artwork (Always Visible)
                    if let artwork = song.artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 2)
                            .onTapGesture {
                                if !musicPlayer.isMiniPlayerExpanded { expand() }
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 48, height: 48)
                            .overlay(Image(systemName: "music.note").foregroundColor(.white))
                            .onTapGesture {
                                if !musicPlayer.isMiniPlayerExpanded { expand() }
                            }
                    }
                    
                    if musicPlayer.isMiniPlayerExpanded {
                        // Info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            
                            Text(song.artist)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        
                        Spacer()
                        
                        // Controls
                        HStack(spacing: 20) {
                            // Play/Pause
                            Button(action: {
                                musicPlayer.togglePlayPause()
                                AudioManager.shared.playSelectSound()
                                resetTimer()
                            }) {
                                Image(systemName: musicPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                            
                            // Next
                            Button(action: {
                                musicPlayer.playNext()
                                AudioManager.shared.playSelectSound()
                                resetTimer()
                            }) {
                                Image(systemName: "forward.fill")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                            
                            // Stop / Remove
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    musicPlayer.stop(clearSession: true)
                                }
                                AudioManager.shared.playSwipeSound()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(12)
                .background(BubbleBackground(cornerRadius: 20))
                .environment(\.colorScheme, SettingsManager.shared.activeTheme.isDark ? .dark : .light)
                .padding(.horizontal, 16)
                // Layout & Transitions
                .offset(dragOffset) // Apply draggable offset
                .gesture(
                    dragGesture
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
                .onAppear {
                    startCollapseTimer()
                }
                .onChange(of: musicPlayer.currentSong?.id) { _, _ in
            
                    expand()
                }
                .onTapGesture {
                    if musicPlayer.isMiniPlayerExpanded {
                        resetTimer()
                    } else {
                        expand()
                    }
                }
            }
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow dragging if collapsed
                guard !musicPlayer.isMiniPlayerExpanded else { return }
                
                // Update offset directly
                withAnimation(.interactiveSpring()) {
                    self.dragOffset = CGSize(
                        width: accumulatedOffset.width + value.translation.width,
                        height: accumulatedOffset.height + value.translation.height
                    )
                }
                resetTimer()
            }
            .onEnded { value in
                guard !musicPlayer.isMiniPlayerExpanded else { return }
                
                // Save final position
                self.accumulatedOffset = self.dragOffset
            }
    }
   
    private func expand() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            musicPlayer.isMiniPlayerExpanded = true
            dragOffset = .zero
            accumulatedOffset = .zero
        }
        startCollapseTimer()
    }
    
    private func resetTimer() {
        startCollapseTimer()
    }
    
    private func startCollapseTimer() {
        collapseTask?.cancel()
        collapseTask = Task {
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        musicPlayer.isMiniPlayerExpanded = false
                    }
                }
            }
        }
    }
}

