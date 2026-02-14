import SwiftUI
import UIKit
import ImageIO

// Wrapper to play Animated UIImages (GIFs) in SwiftUI
struct SumeeGIFView: UIViewRepresentable {
    let image: UIImage
    var contentMode: UIView.ContentMode = .scaleAspectFit
    
    func makeUIView(context: Context) -> UIImageView {
        // Deduplicated initialization
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false // Pass touches through
        // Allow the image view to shrink to fit the SwiftUI frame
        imageView.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: .vertical)
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Check if image pointer changed to avoid unnecessary reloads
        if uiView.image !== image {
            uiView.image = image
            uiView.startAnimating()
        }
        uiView.contentMode = contentMode
    }
}

// Wrapper for raw GIF Data (clean implementation)
struct DataGIFView: UIViewRepresentable {
    let gifData: Data
    var contentMode: UIView.ContentMode = .scaleAspectFill
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false // Pass touches through
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Only reload if needed (optimization can be added, but for now safe)
        if uiView.image == nil {
            uiView.image = UIImage.gifImage(data: gifData)
        }
    }
}

// Remote GIF Loader
struct RemoteGIFView: View {
    let url: URL
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        ZStack {
            if let image = image {
                SumeeGIFView(image: image)
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.white)
            }
        }
        .onAppear(perform: loadGIF)
        .onChange(of: url) { _ in loadGIF() }
    }
    
    private func loadGIF() {
        isLoading = true
        loadError = false
        image = nil
        
        DispatchQueue.global(qos: .userInteractive).async {
            if let data = try? Data(contentsOf: url),
               let animatedImage = UIImage.gifImage(data: data) {
                DispatchQueue.main.async {
                    self.image = animatedImage
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = true
                }
            }
        }
    }
}

// UIImage Extension for GIF display
extension UIImage {
    static func gifImage(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        
        var images: [UIImage] = []
        var duration: Double = 0
        
        let count = CGImageSourceGetCount(source)
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cgImage))
                
                // Get delay time
                var delaySeconds = 0.1
                let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, i, nil)
                let gifProperties = (cfProperties as? [String: Any])?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
                
                if let delay = gifProperties?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double {
                    delaySeconds = delay
                } else if let delay = gifProperties?[kCGImagePropertyGIFDelayTime as String] as? Double {
                    delaySeconds = delay
                }
                
                duration += delaySeconds
            }
        }
        
        // Safety check for duration
        if duration == 0 { duration = 0.1 * Double(count) }
        
        return UIImage.animatedImage(with: images, duration: duration)
    }
}
