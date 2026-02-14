import SwiftUI
import QuartzCore

enum XMBVariant {
    case blue
    case black
}

struct SUMEEXMBBackgroundView: View {
    var isAnimatePaused: Bool = false
    var variant: XMBVariant = .blue
    
    var body: some View {
        ZStack {
            if variant == .blue {
                // Fondo tipo PlayStation 3 (Azul Profundo a Negro/Azul)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.0, green: 0.35, blue: 0.65),
                        Color(red: 0.0, green: 0.1, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            } else {
                // Fondo Black
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.1), // Carbon
                        Color.black
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            
            // Capa nativa UIView para máximo performance
            NativeXMBBackgroundView(isPaused: isAnimatePaused, variant: variant)
                .ignoresSafeArea()
        }
    }
}

// UIView Representable (Core Animation Layer)
struct NativeXMBBackgroundView: UIViewRepresentable {
    var isPaused: Bool
    var variant: XMBVariant
    
    func makeUIView(context: Context) -> CASUMEEXMBView {
        let view = CASUMEEXMBView(frame: UIScreen.main.bounds)
        view.variant = variant
        return view
    }
    
    func updateUIView(_ uiView: CASUMEEXMBView, context: Context) {
        if isPaused {
             uiView.pauseAnimation()
        } else {
             uiView.resumeAnimation()
        }
    }
}

class CASUMEEXMBView: UIView {
    var variant: XMBVariant = .blue {
        didSet {
          
            if oldValue != variant {
                layer.sublayers?.forEach { $0.removeFromSuperlayer() }
                waveLayers.removeAll()
                setupLayers()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false 
        setupObservers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        setupLayers()
        setupObservers() // Start monitoring power
    }
    
   
    func pauseAnimation() {
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0.0
        layer.timeOffset = pausedTime
    }

    func resumeAnimation() {
        let pausedTime = layer.timeOffset
        layer.speed = 1.0
        layer.timeOffset = 0.0
        layer.beginTime = 0.0
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        layer.beginTime = timeSincePause
    }
    
    private var waveLayers: [CALayer] = []
    private var emitterLayer: CAEmitterLayer?
    private var lastBounds: CGRect = .zero

    // using existing cachedDotImage (works for both)
    private static let cachedDotImage: CGImage? = {
        let size = CGSize(width: 32, height: 32)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        // Generic sparkling dot
        let dotColor = UIColor(white: 1.0, alpha: 0.8) // Pure white light
        context.setFillColor(dotColor.cgColor)
        context.setShadow(offset: .zero, blur: 5, color: dotColor.cgColor)
        context.fillEllipse(in: CGRect(x: 4, y: 4, width: 24, height: 24))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.cgImage
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size == lastBounds.size { return }
        lastBounds = bounds
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        waveLayers.removeAll()
        setupLayers()
        checkPowerState()
    }
    
    private func setupLayers() {
        let width = bounds.width
        let height = bounds.height
        let centerY = height * 0.5
        
        let colorBack: UIColor
        let colorMid: UIColor
        let colorFront: UIColor
        
        if variant == .blue {
             colorBack = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.15)
             colorMid  = UIColor(white: 1.0, alpha: 0.3)
             colorFront = UIColor(white: 1.0, alpha: 0.6)
        } else {
             // Black Variant: Silver/Grey tones
             colorBack = UIColor(white: 0.6, alpha: 0.15) // Silver mist
             colorMid  = UIColor(white: 0.8, alpha: 0.25) // Brighter silver
             colorFront = UIColor(white: 1.0, alpha: 0.5) // White edge
        }
        
        addWaveLayer(imageName: "img_xmb", duration: 30, yPos: centerY, color: colorBack, width: width, fillBottom: false)
        addWaveLayer(imageName: "img_xmb", duration: 22, yPos: centerY + 10, color: colorMid, width: width, mirror: true, fillBottom: false)
        addWaveLayer(imageName: "img_xmb", duration: 15, yPos: centerY + 20, color: colorFront, width: width, fillBottom: false)
        
        // 2. Partículas (Puntitos flotantes tipo XMB - Optimizados)
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: width / 2, y: height / 2)
        emitter.emitterShape = .rectangle
        emitter.emitterSize = CGSize(width: width, height: height)
        emitter.renderMode = .additive
        
        let cell = CAEmitterCell()
        
        if let img = UIImage(named: "img_sparkle")?.cgImage {
             cell.contents = img
        } else {
             // Usar imagen cacheada
             cell.contents = CASUMEEXMBView.cachedDotImage
        }
        
      
        cell.birthRate = 4
        cell.lifetime = 20.0
        
        cell.velocity = 5
        cell.velocityRange = 3
        cell.emissionRange = .pi * 2
        
        cell.scale = 0.04
        cell.scaleRange = 0.05
        
       
        cell.alphaSpeed = -0.03
        
        cell.spin = 0.5
        cell.spinRange = 1.0
        
        emitter.emitterCells = [cell]
        layer.addSublayer(emitter)
        emitterLayer = emitter
    }
    
    // Cache de la imagen
    private static let cachedWaveImage: CGImage? = UIImage(named: "img_xmb")?.cgImage


    
    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(checkPowerState), name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(checkPowerState), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(checkPowerState), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func checkPowerState() {
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let systemAllowsAnimation = !lowPower && !reduceMotion
        
      
        emitterLayer?.birthRate = (systemAllowsAnimation && !isPad) ? 4 : 0
        
        // Waves:
        if systemAllowsAnimation {
             if layer.speed == 0 { resumeAnimation() }
        } else {
             if layer.speed != 0 { pauseAnimation() }
        }
    }
    
    // Updated addWaveLayer to use cache and rasterization + THROTTLING
    private func addWaveLayer(imageName: String, duration: TimeInterval, yPos: CGFloat, color: UIColor, width: CGFloat, mirror: Bool = false, fillBottom: Bool = false) {
        let movingLayer = CALayer()
        let waveHeight: CGFloat = 300 
        let totalHeight = waveHeight + (fillBottom ? 1000 : 0)
        
        movingLayer.frame = CGRect(x: 0, y: yPos - (waveHeight/2), width: width * 2, height: totalHeight)
        
        // Usar imagen cacheada en lugar de cargar de disco
        guard let waveImage = CASUMEEXMBView.cachedWaveImage else { return }
        
        for i in 0...1 {
            let container = CALayer()
            container.frame = CGRect(x: CGFloat(i) * width, y: 0, width: width, height: totalHeight)
            
            // 1. Parte Superior (La Ola con forma)
            let waveShapeLayer = CALayer()
            waveShapeLayer.frame = CGRect(x: 0, y: 0, width: width, height: waveHeight)
            
            let mask = CALayer()
            mask.contents = waveImage
            mask.frame = waveShapeLayer.bounds
            mask.contentsGravity = .resize 
            
            let waveColorLayer = CALayer()
            waveColorLayer.backgroundColor = color.cgColor
            waveColorLayer.frame = waveShapeLayer.bounds
            waveColorLayer.mask = mask
            
            if mirror {
                waveColorLayer.transform = CATransform3DMakeScale(-1, 1, 1)
            }
            
            waveShapeLayer.addSublayer(waveColorLayer)
            container.addSublayer(waveShapeLayer)
   
            container.shouldRasterize = true
            container.rasterizationScale = UIScreen.main.scale
            
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
        
        // ENERGY SAVING: 20 FPS THROTTLING
        if #available(iOS 15.0, *) {
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 20)
        }
        
        movingLayer.add(animation, forKey: "waveMove")
    }
}
