import SwiftUI

struct GameLaunchView: View {
    let rom: ROMItem
    var launchMode: GameLaunchMode = .normal

    var sourceRect: CGRect = .zero
    var launchImage: UIImage? = nil
    
    var onDismiss: (() -> Void)?
    var shouldRestoreHomeNavigation: Bool = true
    @Environment(\.dismiss) var dismiss
    
    @State private var animationState: LaunchState = .initial
    @State private var showEmulator = false
    @State private var closingImage: UIImage? = nil 
    @State private var correctedLaunchImage: UIImage? = nil
    
    enum LaunchState {
        case initial
        case expanding
        case splash
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // MARK: - Background Animation
                // 1. LiveArea Zoom (Rectangle Expand)
                if (launchMode == .resume || launchMode == .restart) && sourceRect != .zero {
      
                     if let image = closingImage ?? correctedLaunchImage {
                         Image(uiImage: image)
                             .resizable()
                             .aspectRatio(contentMode: .fill)
                       
                             .blur(radius: animationState != .initial ? 15 : 0)
                             .frame(
                                 width: animationState == .initial ? sourceRect.width : geo.size.width,
                                 height: animationState == .initial ? sourceRect.height : geo.size.height
                             )
                             .cornerRadius(animationState == .initial ? 16 : 0)
                             .clipped() // Ensure content doesn't spill out during transition
                             .position(
                                 x: animationState == .initial ? sourceRect.midX : geo.size.width / 2,
                                 y: animationState == .initial ? sourceRect.midY : geo.size.height / 2
                             )
                             .ignoresSafeArea()
                    } else {
                         Color.black
                             .frame(
                                 width: animationState == .initial ? sourceRect.width : geo.size.width,
                                 height: animationState == .initial ? sourceRect.height : geo.size.height
                             )
                             .cornerRadius(animationState == .initial ? 16 : 0)
                             .position(
                                 x: animationState == .initial ? sourceRect.midX : geo.size.width / 2,
                                 y: animationState == .initial ? sourceRect.midY : geo.size.height / 2
                             )
                             .ignoresSafeArea()
                    }
                } else {
          
                    Color.black
                       .clipShape(Circle())
                       .scaleEffect(animationState == .initial ? 0.01 : 2.5)
                       .position(x: geo.size.width / 2, y: geo.size.height / 2) // Explicit center
                       .opacity(animationState == .initial ? 0 : 1)
                       .ignoresSafeArea()
                }
                
                if showEmulator {
                    EmulatorView(
                        rom: rom,
                        launchMode: launchMode,
                        onDismiss: {
                            startExitSequence()
                        },
                        shouldRestoreHomeNavigation: shouldRestoreHomeNavigation
                    )
                    .transition(.opacity)
                } else {
                   
                    if launchMode == .normal {
                        VStack {
                            Spacer()
                            ROMCardView(rom: rom, isSelected: true)
                                .scaleEffect(animationState == .initial ? 0.1 : (animationState == .expanding ? 1.2 : 1.0))
                                .opacity(animationState == .initial ? 0 : 1)
                                .rotationEffect(.degrees(animationState == .initial ? -180 : 0))
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
        .onAppear {
            startLaunchSequence()
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .ignoresSafeArea(.all)
    }
    
    private func startLaunchSequence() {
 
        if let original = launchImage {
            // Check orientation of SCREEN vs IMAGE
            let screenSize = UIScreen.main.bounds.size
            let isScreenLandscape = screenSize.width > screenSize.height
            let isImageLandscape = original.size.width > original.size.height
            
            if isScreenLandscape != isImageLandscape {
                // Mismatch! Rotate 90 degrees
                print("GameLaunchView: Orientation Mismatch (Screen: \(isScreenLandscape ? "Land" : "Port"), Image: \(isImageLandscape ? "Land" : "Port")). Rotating...")
                self.correctedLaunchImage = original.rotated(by: .pi / 2)
            } else {
                self.correctedLaunchImage = original
            }
        }
        
        // Check if Music Player is active
        if MusicPlayerManager.shared.isPlaying {
            print(" Music Player active, skipping Game Launch audio")
        } else {
  
            if rom.console != .ios {
                AudioManager.shared.fadeOutBackgroundMusic(duration: 0.5)
            }
            
            // Play start game sound
            AudioManager.shared.playStartGameSound()
        }
        
        // Step 1: Expand from center
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animationState = .expanding
        }
        
        // Step 1.5: Special Case for MeloNX and ManicEmu
        if rom.console == .meloNX || rom.console == .manicEmu {
             DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                 print(" GameLaunchView: Launching \(rom.console.systemName) via URL Scheme")
                 if let urlString = rom.externalLaunchURL, let url = URL(string: urlString) {
                     UIApplication.shared.open(url)
                 }
                 
                 // Close launch view
                 if let onDismiss = self.onDismiss {
                     onDismiss()
                 } else {
                     dismiss()
                 }
             }
             return
        }
        

    
        if rom.console == .ios {
         
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                print(" GameLaunchView: Launching iOS App")
                
                if let urlString = rom.externalLaunchURL {
          
                     if urlString.contains("apple.com") && urlString.contains("/id") {
                         AppLauncher.shared.presentStoreOverlay(from: urlString)
                     } else {
                  
                         AppLauncher.shared.openURLScheme(urlString)
                     }
                }
                
               
                if let onDismiss = self.onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }
            return
        }
        
       
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                animationState = .splash
            }
        }
        
        // Step 3: Launch Emulator
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeIn(duration: 0.5)) {
                showEmulator = true
            }
        }
    }
    
    private func startExitSequence() {
     
        if let screenshot = loadClosingScreenshot() {
            print("📸 GameLaunchView: Loaded closing screenshot")
            
            // Apply Orientation Correction to Screenshot too
            let screenSize = UIScreen.main.bounds.size
            let isScreenLandscape = screenSize.width > screenSize.height
            let isImageLandscape = screenshot.size.width > screenshot.size.height
            
            if isScreenLandscape != isImageLandscape {
                 self.closingImage = screenshot.rotated(by: .pi / 2)
            } else {
                 self.closingImage = screenshot
            }
        }
        
        // Check if Music Player is active
        if MusicPlayerManager.shared.isPlaying {
            print(" Music Player active, skipping Game Exit audio")
            // Just dismiss
            dismissAndAnimate()
        } else {
   
            AudioManager.shared.playStopGameSound {
                AudioManager.shared.fadeInBackgroundMusic(duration: 0.8)
            }
            dismissAndAnimate()
        }
    }
    
    private func dismissAndAnimate() {

        withAnimation(.easeOut(duration: 0.3)) {
            showEmulator = false
            animationState = .splash
        }
        
  
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
           
                animationState = .initial
            }
        }
        

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onDismiss?()
        }
    }
    
    private func loadClosingScreenshot() -> UIImage? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let statesDir = documents.appendingPathComponent("states").appendingPathComponent(rom.displayName)
        let screenshotURL = statesDir.appendingPathComponent("autosave.png")
   
        if FileManager.default.fileExists(atPath: screenshotURL.path) {
            if let data = try? Data(contentsOf: screenshotURL) {
                return UIImage(data: data)
            }
        }
        return nil
    }
}

// Image Utilities
extension UIImage {
    func rotated(by radians: CGFloat) -> UIImage? {
        var newSize = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians)).integral.size
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        
        context.translateBy(x: newSize.width/2, y: newSize.height/2)

        context.rotate(by: radians)
        
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
