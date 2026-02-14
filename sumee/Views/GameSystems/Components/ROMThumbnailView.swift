import SwiftUI

struct ROMThumbnailView: View {
    let rom: ROMItem
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Placeholder matches the image's generic art style if missing
                Color.gray.opacity(0.3)
                    .overlay(Image(systemName: "gamecontroller").foregroundColor(.white))
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: rom.id) { _ in
            self.image = nil // Clear stale image
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let img = rom.getThumbnail()
            DispatchQueue.main.async {
                self.image = img
            }
        }
    }
}
