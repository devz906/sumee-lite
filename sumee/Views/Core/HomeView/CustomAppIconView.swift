import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct CustomAppIconView: View {
    let item: AppItem
    let isSelected: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let path = item.customImagePath,
                   let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let fileURL = documents.appendingPathComponent(path)
                    
                    if fileURL.pathExtension.lowercased() == "gif" {
                        // Simple GIF support using WKWebView wrapper or ImageIO
                        GIFImageView(url: fileURL)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        AsyncImage(url: fileURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure(_):
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    }
                } else {
                    Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                }
                
                // Selection Border removed as per user request
            }
            // VITA STYLE: Circle Clip
            .clipShape(Circle()) 
            // 3D Glass Effect Overlay
            .overlay(VitaBubbleOverlay())
            // Optimized shadow: Fixed radius, toggle opacity only
            .shadow(color: isSelected ? Color.cyan.opacity(0.5) : Color.clear, radius: 3)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .offset(y: floatOffset) // Floating Animation
            .onAppear {
                 // Start Random Floating
                 withAnimation(Animation.easeInOut(duration: Double.random(in: 2.5...3.5)).repeatForever(autoreverses: true)) {
                     floatOffset = CGFloat.random(in: -3...3)
                 }
            }
        }
    }
    
    @State private var floatOffset: CGFloat = 0.0
}

struct GIFImageView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.clipsToBounds = true
        
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        containerView.addSubview(imageView)
        
        // Pin image to edges of container
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Retrieve the UIImageView from the container
        guard let imageView = uiView.subviews.first as? UIImageView else { return }
        
        if imageView.image == nil && imageView.animationImages == nil {
            loadGIF(into: imageView, from: url)
        }
    }
    
    private func loadGIF(into imageView: UIImageView, from url: URL) {
        DispatchQueue.global(qos: .userInteractive).async {
            guard let data = try? Data(contentsOf: url),
                  let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
            
            let count = CGImageSourceGetCount(source)
            var images: [UIImage] = []
            var duration: TimeInterval = 0
            
            // Thumbnail options to downsample large GIFs to icon size (optimization)
            let maxPixelSize = 180 // 90pt * 2x scale
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            
            for i in 0..<count {
                if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, i, options as CFDictionary) {
                    images.append(UIImage(cgImage: cgImage))
                    
                    var frameDuration: TimeInterval = 0.1
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                        
                        if let delayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double {
                            frameDuration = delayTime
                        } else if let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                            frameDuration = delayTime
                        }
                    }
                    
                    if frameDuration < 0.011 { frameDuration = 0.1 }
                    duration += frameDuration
                }
            }
            
            DispatchQueue.main.async {
                imageView.contentMode = .scaleAspectFit // Ensure fit
                if count <= 1 {
                    imageView.image = images.first
                } else {
                    imageView.animationImages = images
                    imageView.animationDuration = duration
                    imageView.startAnimating()
                }
            }
        }
    }
}
