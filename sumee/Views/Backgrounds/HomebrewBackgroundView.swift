import SwiftUI
import QuartzCore

struct HomebrewBackgroundView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            // Capa nativa UIView para máximo performance
            NativeBackgroundView()
                .ignoresSafeArea()
        }
    }
}

//  UIView Representable (Core Animation Layer)
struct NativeBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        return CAHomebrewView(frame: UIScreen.main.bounds)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class CAHomebrewView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        setupObservers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
        setupObservers()
    }
    
    private var waveLayers: [CALayer] = []

    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Rebuild on layout change
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        waveLayers.removeAll()
        setupLayers()
        checkPowerState()
    }
    
    // MARK: - Power & Throttling
    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(checkPowerState), name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(checkPowerState), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(checkPowerState), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func checkPowerState() {
        // "Smart" Check:
        // 1. Low Power Mode (Yellow Battery)
        // 2. Reduce Motion (Accessibility)
        
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let shouldAnimate = !lowPower && !reduceMotion
        
        // Waves: Speed 0 = Freeze time.
        toggleLayerPause(paused: !shouldAnimate)
    }
    
    private func toggleLayerPause(paused: Bool) {
        if paused {
            // Congelar
            guard layer.speed != 0 else { return } 
            let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
            layer.speed = 0.0
            layer.timeOffset = pausedTime
        } else {
            // Reanudar desde donde se quedó
            guard layer.speed == 0 else { return }
            let pausedTime = layer.timeOffset
            layer.speed = 1.0
            layer.timeOffset = 0.0
            layer.beginTime = 0.0
            let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
            layer.beginTime = timeSincePause
        }
    }
    
    // Layer Setup
    private func setupLayers() {
        let width = bounds.width
        let height = bounds.height
   
        let centerY = height - 100
        
     
        addWaveLayer(imageName: "img_wave", duration: 18, yPos: centerY, width: width, mirror: false)
    }
    
    private func addWaveLayer(imageName: String, duration: TimeInterval, yPos: CGFloat, width: CGFloat, mirror: Bool = false) {
        let movingLayer = CALayer()
        

        let waveHeight: CGFloat = 200
        
     
        let totalHeight = waveHeight
       
        movingLayer.frame = CGRect(x: 0, y: yPos - (waveHeight/2), width: width * 2, height: totalHeight)
        
        // Load Raw Image
        guard let waveImage = UIImage(named: imageName)?.cgImage else {
            print(" Revert: Missing \(imageName). View might be empty.")
            return 
        }
        
        for i in 0...1 {
            let container = CALayer()
            container.frame = CGRect(x: CGFloat(i) * width, y: 0, width: width, height: totalHeight)
            
            let imageLayer = CALayer()
            imageLayer.frame = container.bounds
            imageLayer.contents = waveImage
            // Use .resize to stretch if needed, or .resizeAspect to fill
            imageLayer.contentsGravity = .resize 
            
            if mirror {
                imageLayer.transform = CATransform3DMakeScale(-1, 1, 1)
            }
            
            container.addSublayer(imageLayer)
            

            
            movingLayer.addSublayer(container)
        }
        
        layer.addSublayer(movingLayer)
        waveLayers.append(movingLayer)
        
        // Animación Infinita
        let animation = CABasicAnimation(keyPath: "position.x")
        let startX = width
        let endX = 0.0
        
        movingLayer.position.x = startX
        
        animation.fromValue = startX
        animation.toValue = endX
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        
        // NATIVE THROTTLING: 20 FPS
     
        if #available(iOS 15.0, *) {
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 20)
        }
        
        movingLayer.add(animation, forKey: "waveMove")
    }
}
