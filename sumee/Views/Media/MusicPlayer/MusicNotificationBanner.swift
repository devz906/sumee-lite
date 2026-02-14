import SwiftUI

struct MusicNotificationBanner: View {
    let track: AudioManager.TrackInfo
    
    var body: some View {
        HStack(spacing: 8) {
            // Album Art / Icon
            ZStack {
                if let artwork = track.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(.gray)
                }
            }
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
            
            // Text Info
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black.opacity(0.9))
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(1)
            }
            
            // Music Icon
            Image(systemName: "waveform")
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: 200) // Even more compact
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white) // Solid white background
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4) // Soft diffused shadow
        )
    }
}

struct MusicNotificationBanner_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2).ignoresSafeArea()
            
            MusicNotificationBanner(track: AudioManager.TrackInfo(
                title: "Internet Settings",
                artist: "Pan!c Pop",
                artwork: UIImage(systemName: "gamecontroller.fill")
            ))
        }
    }
}
