import SwiftUI
import CoreImage

struct BackgroundImageView: View {
    @ObservedObject var viewModel: GameSystemsViewModel
    @ObservedObject var settings = SettingsManager.shared
    @State private var backgroundImage: UIImage?
    
    var body: some View {
        ZStack {
            if let image = backgroundImage {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                // Removed real-time blur modifier for performance
                .overlay(Color.black.opacity(0.4))
                .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                .id(viewModel.selectedIndex)
            } else {
                ThemeBackgroundView(
                    theme: settings.activeTheme,
                    isAnimatePaused: viewModel.showEmulator
                )
            }
        }
        .onAppear { updateBackground() }
        .onChange(of: viewModel.selectedIndex) { _ in
            withAnimation { updateBackground() }
        }
    }
    
    private func updateBackground() {
        guard !viewModel.filteredROMs.isEmpty,
              viewModel.selectedIndex >= 0,
              viewModel.selectedIndex < viewModel.filteredROMs.count else { return }
        
        let rom = viewModel.filteredROMs[viewModel.selectedIndex]
        
        DispatchQueue.global(qos: .userInteractive).async {
            guard let img = rom.getThumbnail() else { return }
            // Pre-calculate blur here
            let blurred = self.applyBlur(to: img, radius: 20)
            DispatchQueue.main.async {
                self.backgroundImage = blurred ?? img
            }
        }
    }
    
    // Shared context for performance
    private static let ciContext = CIContext(options: nil)

    private func applyBlur(to image: UIImage, radius: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        // Downscale for faster processing if needed, but assuming reasonable thumb size
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        
        guard let output = filter.outputImage else { return nil }
        
        // Enhance: Crop to prevent blurred edges fade
        let rect = ciImage.extent.insetBy(dx: radius * 3, dy: radius * 3)
        if let cgImage = Self.ciContext.createCGImage(output, from: rect) {
             return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
