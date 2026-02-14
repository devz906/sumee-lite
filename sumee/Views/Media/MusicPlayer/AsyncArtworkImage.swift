import SwiftUI
import MediaPlayer
import AVFoundation

struct AsyncArtworkImage: View {
    let item: MPMediaItem?
    let size: CGSize
    let cornerRadius: CGFloat
    
    var fileURL: URL? = nil // Local file support
    var artwork: UIImage? = nil // Direct artwork fallback
    
    @State private var image: UIImage?
    @State private var currentTask: Task<Void, Never>?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .cornerRadius(cornerRadius)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(red: 0.298, green: 0.302, blue: 0.412)) // Depth Color
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size.width * 0.4))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            currentTask?.cancel()
            currentTask = nil
        }
        .onChange(of: item) { _, _ in loadImage() }
        .onChange(of: artwork) { _, _ in loadImage() }
        .onChange(of: fileURL) { _, _ in loadImage() }
    }
    
    private func loadImage() {
        currentTask?.cancel()
        
        // 1. Prefer direct artwork if available
        if let directArtwork = artwork {
            self.image = directArtwork
            return
        }
        
        // 2. Setup Main Task
        currentTask = Task {
            let targetSize = size
            let targetURL = fileURL
            let targetItem = item
            
            // Spawn Detached Task for Heavy Lifting
            let processingTask = Task.detached(priority: .userInitiated) { () -> UIImage? in
                if Task.isCancelled { return nil }
                
                // A. Local File
                if let url = targetURL {
                    let asset = AVAsset(url: url)
                    if Task.isCancelled { return nil }
                    guard let metadata = try? await asset.load(.commonMetadata) else { return nil }
                    if Task.isCancelled { return nil }
                    
                    for item in metadata {
                         if item.commonKey == .commonKeyArtwork, let data = try? await item.load(.dataValue) {
                            return UIImage(data: data) 
                         }
                    }
                    return nil
                }
                
                // B. Apple Music Item
                if let item = targetItem, let artwork = item.artwork {
                    // image(at:) is synchronous and blocking, perfect for detached task
                    return artwork.image(at: targetSize)
                }
                
                return nil
            }
            
            // Wait for result with Cancellation Propagation
            let result = await withTaskCancellationHandler {
                return await processingTask.value
            } onCancel: {
                processingTask.cancel()
            }
            
            // Update UI on Main Actor
            if !Task.isCancelled {
                withAnimation(.easeIn(duration: 0.2)) {
                    self.image = result
                }
            }
        }
    }
}
