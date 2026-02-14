import SwiftUI
import MediaPlayer

struct FullMediaControlsView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var musicPlayer = MusicPlayerManager.shared
    
    var body: some View {
        // Controls Card
        VStack(spacing: 12) {
            // Info
            VStack(spacing: 2) {
                Text(musicPlayer.currentSong?.title ?? "Not Playing")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                Text(musicPlayer.currentSong?.artist ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .padding(.top, 4)
            
            // Controls
            HStack(spacing: 24) {
                Button(action: { musicPlayer.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                
                Button(action: { musicPlayer.togglePlayPause() }) {
                    Image(systemName: musicPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                }
                
                Button(action: { musicPlayer.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
            }
            
            // Stop Button
            Button(action: { 
                musicPlayer.stop(clearSession: true)
                withAnimation { isPresented = false }
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(red: 0.298, green: 0.302, blue: 0.412)) // #4C4D69
                .cornerRadius(12)
            }
        }
        .padding(20)
        .padding(20)
        .background(SettingsManager.shared.reduceTransparency ? Material.thickMaterial : Material.regularMaterial)
        .cornerRadius(24)
        .shadow(radius: 20)
        .padding(20)
        .frame(maxWidth: 300)
    }
}
