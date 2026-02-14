import SwiftUI
import MediaPlayer

struct SongCardView: View {
    let song: Song
    let isSelected: Bool
    var isPlaying: Bool = false // Add isPlaying with default false
    
    // Depth color requested by user: #4C4D69
    private let depthColor = Color(red: 0.298, green: 0.302, blue: 0.412)
    
    @State private var asyncArtwork: UIImage?
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(isSelected ? 0.5 : 0.3))
                    .offset(x: 0, y: isSelected ? 6 : 3)
                    .blur(radius: isSelected ? 4 : 2)
                
             
                if isSelected {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(depthColor)
                        .frame(width: 150, height: 150)
                        .offset(x: 4, y: 0)
                }
                
          
                ZStack {
                     AsyncArtworkImage(
                        item: song.mediaItem,
                        size: CGSize(width: 150, height: 150),
                        cornerRadius: 20,
                        fileURL: song.fileURL,
                        artwork: song.artwork
                     )
                    
                    // Music Frame Overlay
                    Image("music_frame")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .allowsHitTesting(false)
                    
                    // Liquid Glass Title Container
                    VStack {
                        Spacer()
                        ZStack {
                            Rectangle().fill(Material.ultraThinMaterial)
                            Color.white.opacity(0.1) // Glass tint
                        }
                        .frame(height: 40)
                        .mask(
                            RoundedRectangle(cornerRadius: 20)
                                .frame(width: 150, height: 150)
                                .mask(
                                    Rectangle()
                                        .frame(height: 40)
                                        .offset(y: 55) // Align to bottom
                                )
                        )
                        .overlay(
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                    
                                    Text(song.artist)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                }
                                Spacer()
                                
                                if isPlaying {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                        )
                    }
                }
                .frame(width: 150, height: 150)
                

            }
            .frame(width: 150, height: 150)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .rotation3DEffect(
                .degrees(isSelected ? -8 : 0),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.5
            )
            .offset(y: isSelected ? -5 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
            .padding(20) 
            .drawingGroup() 
            .padding(-20) // Restore original layout size
        }

    }
}
