import SwiftUI
import UIKit
import QuartzCore

struct FloatingCartridgesView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var romManager = ROMStorageManager.shared
    var isPaused: Bool = false
    
    var body: some View {
        FloatingCartridgesEngineView(
            roms: romManager.roms,
            blurRadius: settings.floatingCartridgesBlur ? 2 : 0,
            isPaused: isPaused
        )
        .ignoresSafeArea()
    }
}

// UIViewRepresentable

struct FloatingCartridgesEngineView: UIViewRepresentable {
    var roms: [ROMItem]
    var blurRadius: CGFloat
    var isPaused: Bool
    
    func makeUIView(context: Context) -> FloatingEngineView {
        let view = FloatingEngineView()
        return view
    }
    
    func updateUIView(_ uiView: FloatingEngineView, context: Context) {
        // Update configuration
        uiView.updateConfiguration(roms: roms, blurRadius: blurRadius)
        
        if isPaused {
            uiView.pause()
        } else {
            uiView.resume()
        }
    }
}

//  Core Animation Engine

class FloatingEngineView: UIView {
    private var displayLink: CADisplayLink?
    private var cartridges: [CartridgeLayer] = []
    
    // Configuration state to detect changes
    private var currentBlur: CGFloat = 0
    private var currentROMs: [ROMItem] = []
    
    // Startup delay to ensure assets are ready
    private var isReady: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startLoop()
            
            // Wait 1.0 second before spawning cartridges to ensure images are loaded
            if !isReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.isReady = true
                    self?.rebuildCartridges()
                }
            }
        } else {
            stopLoop()
        }
    }
    
    func updateConfiguration(roms: [ROMItem], blurRadius: CGFloat) {
        // Only rebuild if meaningful changes occurred
        let needsRebuild = (roms != currentROMs)
        let needsBlurUpdate = (blurRadius != currentBlur)
        
        currentROMs = roms
        currentBlur = blurRadius
        
        if needsRebuild {
            rebuildCartridges()
        }
        
        if needsBlurUpdate {
            updateBlur()
        }
    }
    
    private func rebuildCartridges() {
        // Guard against zero bounds AND startup delay
        guard isReady && bounds.width > 0 && bounds.height > 0 else { return }
        
        // Clear existing
        cartridges.forEach { $0.removeFromSuperlayer() }
        cartridges.removeAll()
        
        guard !currentROMs.isEmpty else { return }
        
        // Hardcoded "High" Quality
        let count = 8
        
        for _ in 0..<count {
            guard let rom = currentROMs.randomElement() else { continue }
            let layer = CartridgeLayer(rom: rom)
            layer.setupRandomState(in: bounds)

            
            self.layer.addSublayer(layer)
            cartridges.append(layer)
        }
        
        // Update blur state for the new cartridges
        updateBlur()
    }
    
    private func updateBlur() {
        // Simple opacity adjust as a cheap "blur" equivalent for background
        let targetOpacity: Float = currentBlur > 0 ? 0.6 : 0.8
        let isBlurActive = currentBlur > 0
        
        for cartridge in cartridges {
            // Trigger Real Blur if needed
            cartridge.setBlur(isBlurActive)
            cartridge.intendedOpacity = targetOpacity
        }
    }
    
    func pause() {
        displayLink?.isPaused = true
    }
    
    func resume() {
        displayLink?.isPaused = false
    }
    
    private func startLoop() {
        stopLoop()
        displayLink = CADisplayLink(target: self, selector: #selector(gameLoop))
        // OPTIMIZATION: Cap at 30fps to reduce battery drain and thermal impact
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        } else {
            displayLink?.preferredFramesPerSecond = 30
        }
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func gameLoop() {
        guard !cartridges.isEmpty, bounds.width > 0, bounds.height > 0 else { return }
        
        for cartridge in cartridges {
            cartridge.update(in: bounds)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // If empty (first launch), build
        if cartridges.isEmpty {
            rebuildCartridges()
        }
    }
}

// Cartridge Layer

class CartridgeLayer: CALayer {
    var velocity = CGPoint.zero
    var rotationSpeed: CGFloat = 0
    var cardSize: CGFloat = 85
    
    var intendedOpacity: Float = 0.8 {
        didSet {
            // If already loaded, update immediately
            if isLoaded {
                self.opacity = intendedOpacity
            }
        }
    }
    private var isLoaded = false
    
    private let gradientLayer = CAGradientLayer()
    private let imageLayer = CALayer()
    private let badgeLayer = CATextLayer()
    private let blurredLayer = CALayer() // Layer to hold the blurred snapshot
    
    private var isBlurActive: Bool = false
    private var rawImage: UIImage? // Store loaded image to regenerate blur if needed
    
    init(rom: ROMItem) {
        super.init()
        setupVisuals(for: rom)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setBlur(_ active: Bool) {
        // Prevent redundant work
        guard isBlurActive != active else { return }
        isBlurActive = active
        
        if active {
            // Only generate if we are loaded. If not loaded, reveal() will call this later.
            if isLoaded {
                regenerateBlur()
            }
        } else {
            blurredLayer.contents = nil
            blurredLayer.opacity = 0
            // Show sublayers
            gradientLayer.isHidden = false
            imageLayer.isHidden = false
            badgeLayer.isHidden = false
        }
    }
    
    private func regenerateBlur(completion: (() -> Void)? = nil) {
        guard isBlurActive else { 
            completion?()
            return 
        }
        
        // 1. Snapshot the sharp components
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            completion?()
            return
        }
        
        // Render layers manually into context with correct offsets
       
        gradientLayer.render(in: ctx)
        
   
        ctx.saveGState()
        ctx.translateBy(x: imageLayer.frame.origin.x, y: imageLayer.frame.origin.y)
        imageLayer.render(in: ctx)
        ctx.restoreGState()
        
        // Badge (at bottom)
        ctx.saveGState()
        ctx.translateBy(x: badgeLayer.frame.origin.x, y: badgeLayer.frame.origin.y)
        badgeLayer.render(in: ctx)
        ctx.restoreGState()
        
        let sharpImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 2. Blur it (Background thread to avoid hitch)
        guard let input = sharpImage else { 
            completion?()
            return 
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let blurred = self.applyBlur(to: input, radius: 4) 
            
            DispatchQueue.main.async {
                // Check if we are still blurred
                guard self.isBlurActive else { 
                    completion?()
                    return 
                }
                
                // Update Content
                self.blurredLayer.contents = blurred?.cgImage
                self.blurredLayer.opacity = 1.0
                
                // Hide underneath layers ONLY if we have content
                if blurred != nil {
                    self.gradientLayer.isHidden = true
                    self.imageLayer.isHidden = true
                    self.badgeLayer.isHidden = true
                }
                
                completion?()
            }
        }
    }
    
    private func applyBlur(to image: UIImage, radius: CGFloat) -> UIImage? {
        guard let ciImg = CIImage(image: image) else { return image }
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImg, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        
        guard let output = filter?.outputImage else { return image }
        
        // Crop transparent edges
        let context = CIContext()
        // Keep original bounds
        let rect = ciImg.extent
        if let cgimg = context.createCGImage(output, from: rect) {
            return UIImage(cgImage: cgimg)
        }
        return image
    }
    
    func setupRandomState(in bounds: CGRect) {
        let size = CGFloat.random(in: 0.7...1.0)
        self.transform = CATransform3DMakeScale(size, size, 1)
        
        // Random Position
        let x = CGFloat.random(in: 0...bounds.width)
        let y = CGFloat.random(in: 0...bounds.height)
        self.position = CGPoint(x: x, y: y)
        
        // Random Rotation
        let rot = CGFloat.random(in: -0.3...0.3)
        self.setValue(rot, forKeyPath: "transform.rotation.z")
        
        // Speed (High Quality Setting)
        let speedRange: ClosedRange<CGFloat> = -0.5...0.5
        velocity = CGPoint(
            x: CGFloat.random(in: speedRange),
            y: CGFloat.random(in: speedRange)
        )
        
        rotationSpeed = CGFloat.random(in: -0.002...0.002)
    }
    
    func update(in bounds: CGRect) {
        // Move
        var pos = self.position
        pos.x += velocity.x
        pos.y += velocity.y
        
        // Wrap
        let margin: CGFloat = 100
        if pos.x < -margin { pos.x = bounds.width + margin }
        else if pos.x > bounds.width + margin { pos.x = -margin }
        
        if pos.y < -margin { pos.y = bounds.height + margin }
        else if pos.y > bounds.height + margin { pos.y = -margin }
        
        // Safety Check for Nan/Inf to prevent crashes
        if pos.x.isFinite && pos.y.isFinite {
            self.position = pos
        }
        
        // Rotate
        if let currentRot = self.value(forKeyPath: "transform.rotation.z") as? CGFloat {
            self.setValue(currentRot + rotationSpeed, forKeyPath: "transform.rotation.z")
        }
    }
    
    // Disable implicit animations (CRITICAL for updating in a game loop)
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
    
    private func setupVisuals(for rom: ROMItem) {
        self.bounds = CGRect(x: 0, y: 0, width: cardSize, height: cardSize)
        self.cornerRadius = 16
        self.masksToBounds = false
        self.opacity = 0 // Start invisible!
        
        // Shadow (On the root layer)
        self.shadowColor = UIColor.black.cgColor
        self.shadowOpacity = 0.3
        self.shadowOffset = CGSize(width: 0, height: 4)
        self.shadowRadius = 4
        
        // Blurred Layer (Topmost)
        blurredLayer.frame = self.bounds
        blurredLayer.cornerRadius = 16
        blurredLayer.masksToBounds = true
        blurredLayer.opacity = 0 // Hidden by default
        addSublayer(blurredLayer)
        
        // 2. Gradient Background
        gradientLayer.frame = self.bounds
        gradientLayer.cornerRadius = 16
        gradientLayer.colors = getColors(for: rom)
        gradientLayer.startPoint = CGPoint(x: 1, y: 1)
        gradientLayer.endPoint = CGPoint(x: 0, y: 0)
        gradientLayer.zPosition = -1 // Ensure behind blur
        addSublayer(gradientLayer)
        
        // 3. Image
        imageLayer.frame = CGRect(x: 6, y: 6, width: cardSize - 12, height: cardSize - 12)
        imageLayer.cornerRadius = 11
        imageLayer.backgroundColor = UIColor(white: 0.9, alpha: 0.3).cgColor
        imageLayer.masksToBounds = true
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.zPosition = -0.5
        addSublayer(imageLayer)
        
        // 4. Badge
        badgeLayer.string = getConsoleName(for: rom)
        badgeLayer.fontSize = 10
        badgeLayer.foregroundColor = UIColor.white.cgColor
        badgeLayer.alignmentMode = .center
        badgeLayer.backgroundColor = getBadgeColor(for: rom).cgColor
        badgeLayer.cornerRadius = 4
        badgeLayer.frame = CGRect(x: 6, y: cardSize - 20, width: 30, height: 14)
        badgeLayer.contentsScale = UIScreen.main.scale
        badgeLayer.zPosition = -0.5
        addSublayer(badgeLayer)
        
        // Async Load Image -> Then Reveal
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            var finalImage: UIImage? = nil
            
            if let image = rom.getThumbnail() {
                finalImage = self.resizeImage(image, targetSize: CGSize(width: 100, height: 100))
                self.rawImage = finalImage
            }
            
            DispatchQueue.main.async {
                self.imageLayer.contents = finalImage?.cgImage
                
                // If blur active, we must gen it now that we have image (or not)
                if self.isBlurActive {
                    self.regenerateBlur { [weak self] in
                        self?.reveal()
                    }
                } else {
                    self.reveal()
                }
            }
        }
    }
    
    private func reveal() {
        guard !isLoaded else { return }
        isLoaded = true
        
        // Fade In
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = intendedOpacity
        fade.duration = 0.8
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        self.add(fade, forKey: "entryFade")
        self.opacity = intendedOpacity
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    // Helpers copied/adapted from ROMCardView logic
    private func getColors(for rom: ROMItem) -> [CGColor] {
        let colors: [UIColor]
        switch rom.console {
        case .ios: colors = [UIColor(red: 90/255, green: 200/255, blue: 250/255, alpha: 1), UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)]
        case .gameboyColor: colors = [UIColor(red: 0.55, green: 0.2, blue: 0.7, alpha: 1), UIColor(red: 0.45, green: 0.15, blue: 0.6, alpha: 1)]
        case .gameboyAdvance: colors = [UIColor(red: 0.35, green: 0.25, blue: 0.55, alpha: 1), UIColor(red: 0.3, green: 0.2, blue: 0.5, alpha: 1)]
        case .nes: colors = [UIColor(red: 0.22, green: 0.57, blue: 0.9, alpha: 1), UIColor(red: 0.98, green: 0.27, blue: 0.29, alpha: 1)]
        case .snes: colors = [UIColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1), UIColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1)]
        case .nintendoDS: colors = [UIColor(red: 0.7, green: 0.9, blue: 0.96, alpha: 1), UIColor(red: 0.41, green: 0.53, blue: 0.56, alpha: 1)]
        case .nintendo64: colors = [UIColor(red: 0.55, green: 0.71, blue: 0.8, alpha: 1), UIColor(red: 0.27, green: 0.35, blue: 0.4, alpha: 1)]
        case .playstation: colors = [UIColor(red: 0.21, green: 0.6, blue: 0.89, alpha: 1), UIColor(red: 0.14, green: 0.51, blue: 0.78, alpha: 1)]
        case .psp: colors = [UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1), UIColor.black]
        case .web: colors = [UIColor(red: 100/255, green: 240/255, blue: 255/255, alpha: 1), UIColor(red: 0/255, green: 150/255, blue: 200/255, alpha: 1)]
        case .meloNX: colors = [UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1), UIColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 1)]
        case .manicEmu: colors = [UIColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 1), UIColor.black]
        case .segaGenesis: colors = [UIColor.black, UIColor.white]
        default: colors = [UIColor(red: 0.93, green: 0.9, blue: 0.36, alpha: 1), UIColor(red: 0.84, green: 0.5, blue: 0.56, alpha: 1)]
        }
        return colors.map { $0.cgColor }
    }
    
    private func getBadgeColor(for rom: ROMItem) -> UIColor {
        switch rom.console {
        case .ios: return UIColor(red: 0, green: 0.48, blue: 1, alpha: 1)
        case .gameboyColor: return UIColor(red: 0.55, green: 0.2, blue: 0.7, alpha: 1)
        case .gameboyAdvance: return UIColor(red: 0.3, green: 0.2, blue: 0.5, alpha: 1)
        case .nes: return UIColor(red: 0.98, green: 0.27, blue: 0.29, alpha: 1)
        case .snes: return UIColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1)
        case .nintendoDS: return UIColor(red: 0.41, green: 0.53, blue: 0.56, alpha: 1)
        case .nintendo64: return UIColor(red: 0.27, green: 0.35, blue: 0.4, alpha: 1)
        case .playstation: return UIColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1)
        case .psp: return UIColor.black
        case .ios: return UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)
        case .web: return UIColor(red: 0/255, green: 180/255, blue: 220/255, alpha: 1)
        case .meloNX: return UIColor(red: 255/255, green: 50/255, blue: 50/255, alpha: 1)
        case .manicEmu: return UIColor.black
        case .segaGenesis: return UIColor.black
        default: return UIColor(red: 0.84, green: 0.5, blue: 0.56, alpha: 1)
        }
    }
    
    private func getConsoleName(for rom: ROMItem) -> String {
        switch rom.console {
        case .ios: return "iOS"
        case .gameboyColor: return "GBC"
        case .gameboyAdvance: return "GBA"
        case .nes: return "NES"
        case .snes: return "SNES"
        case .nintendoDS: return "NDS"
        case .nintendo64: return "N64"
        case .playstation: return "PSX"
        case .psp: return "PSP"
        case .web: return "WEB"
        case .segaGenesis: return "GEN"
        case .ios: return "iOS"
        case .meloNX: return "NSW"
        case .manicEmu: return "MAN"
        default: return "GB"
        }
    }
}
