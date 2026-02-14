import SwiftUI
import UIKit
import QuartzCore

struct NewYearBackgroundView: View {
    // Control flags similar to other backgrounds
    var isPaused: Bool = false
    
    var body: some View {
        ZStack {
            // 1. Static Night Gradient (Background)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.05), // Midnight Black
                    Color(red: 0.1, green: 0.08, blue: 0.15), // Deep Night Purple-ish
                    Color(red: 0.2, green: 0.15, blue: 0.05)   // Faint Gold Glow
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 2. High-Performance Fireworks Engine
            FireworksEngineView(isPaused: isPaused)
                .ignoresSafeArea()
        }
    }
}

//  UIViewRepresentable

struct FireworksEngineView: UIViewRepresentable {
    var isPaused: Bool
    
    func makeUIView(context: Context) -> FireworksView {
        let view = FireworksView()
        return view
    }
    
    func updateUIView(_ uiView: FireworksView, context: Context) {
        if isPaused {
            uiView.stop()
        } else {
            uiView.start()
        }
    }
}

//  Core Animation Fireworks Engine

class FireworksView: UIView {
    private var timer: Timer?
    
    // Cache generated particle images to avoid UIGraphics usage during animation
    private var sparkImage: UIImage?
    private var glowImage: UIImage?
    
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
        
        // Pre-generate assets (Smaller sizes)
        sparkImage = generateParticleImage(size: CGSize(width: 4, height: 4), color: .white, isGlow: false)
        glowImage = generateParticleImage(size: CGSize(width: 8, height: 8), color: .white, isGlow: true)
        
        start()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            start()
        } else {
            stop()
        }
    }
    
    func start() {
        stop() // Ensure no duplicates
        // Launch a firework every 0.6 to 1.2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            // Randomize slightly
            if Double.random(in: 0...1) > 0.2 {
                self?.launchShow()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func launchShow() {
        guard let window = window else { return }
        let width = bounds.width
        let height = bounds.height
        
        // Random Horizontal Position
        let randomX = CGFloat.random(in: width * 0.2...width * 0.8)
        
        // Vertical Trajectory (Start and End share X)
        let startPoint = CGPoint(x: randomX, y: height + 20)
        let endPoint = CGPoint(x: randomX, y: CGFloat.random(in: height * 0.15...height * 0.45))
        
        // Colors
        let colors: [UIColor] = [.red, .yellow, .cyan, .green, .magenta, .orange, .white, .purple, .systemTeal]
        let color = colors.randomElement() ?? .white
        
        // 1. Rocket Animation (CATransaction for completion)
        let rocketLayer = CALayer()
        rocketLayer.backgroundColor = color.cgColor
        rocketLayer.cornerRadius = 1.5
        rocketLayer.frame = CGRect(x: 0, y: 0, width: 3, height: 12)
        rocketLayer.position = startPoint
        rocketLayer.presentation() 
        
        // Simple shadow/glow for now is cheaper
        rocketLayer.shadowColor = color.cgColor
        rocketLayer.shadowOpacity = 0.6
        rocketLayer.shadowRadius = 4
        rocketLayer.shadowOffset = .zero
        
        layer.addSublayer(rocketLayer)
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            rocketLayer.removeFromSuperlayer()
            self.explode(at: endPoint, color: color)
        }
        
        let launchDuration = Double.random(in: 1.0...1.4)
        
        // Position Animation
        let anim = CABasicAnimation(keyPath: "position")
        anim.fromValue = startPoint
        anim.toValue = endPoint
        anim.duration = launchDuration
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        rocketLayer.add(anim, forKey: "fly")
        // Update model to end position so it doesn't snap back before removal
        rocketLayer.position = endPoint
        
        CATransaction.commit()
    }
    
    private func explode(at position: CGPoint, color: UIColor) {
        let emitter = CAEmitterLayer()
        emitter.position = position
        emitter.emitterPosition = .zero 
        emitter.emitterShape = .point
        emitter.emitterMode = .outline
        emitter.renderMode = .additive
        
        // 1. Small Sparks (The main burst)
        let sparkCell = CAEmitterCell()
        sparkCell.name = "spark"
        sparkCell.contents = sparkImage?.cgImage
        sparkCell.birthRate = 0
        sparkCell.lifetime = 1.2
        sparkCell.lifetimeRange = 0.4
        sparkCell.color = color.cgColor
        sparkCell.alphaSpeed = -0.8
        sparkCell.velocity = 120
        sparkCell.velocityRange = 40
        sparkCell.emissionRange = .pi * 2
        sparkCell.yAcceleration = 60
        sparkCell.scale = 0.8
        sparkCell.scaleRange = 0.4 // Varied sizes
        
        // 2. Larger Glows (Interspersed - fewer of them)
        let glowCell = CAEmitterCell()
        glowCell.name = "glow"
        glowCell.contents = glowImage?.cgImage
        glowCell.birthRate = 0
        glowCell.lifetime = 1.4
        glowCell.lifetimeRange = 0.5
        glowCell.color = color.withAlphaComponent(0.8).cgColor
        glowCell.alphaSpeed = -1.0
        glowCell.velocity = 90
        glowCell.velocityRange = 30
        glowCell.emissionRange = .pi * 2
        glowCell.yAcceleration = 40
        glowCell.scale = 0.6
        glowCell.scaleRange = 0.3
        
        emitter.emitterCells = [sparkCell, glowCell]
        layer.addSublayer(emitter)
        
        emitter.timeOffset = CACurrentMediaTime()
        emitter.beginTime = CACurrentMediaTime()
        
        // Trigger Burst for Sparks
        let sparkBurst = CABasicAnimation(keyPath: "emitterCells.spark.birthRate")
        sparkBurst.fromValue = 800
        sparkBurst.toValue = 0
        sparkBurst.duration = 0.1
        sparkBurst.fillMode = .forwards
        sparkBurst.isRemovedOnCompletion = false
        
        // Trigger Burst for Glows
        let glowBurst = CABasicAnimation(keyPath: "emitterCells.glow.birthRate")
        glowBurst.fromValue = 100
        glowBurst.toValue = 0
        glowBurst.duration = 0.1
        glowBurst.fillMode = .forwards
        glowBurst.isRemovedOnCompletion = false
        
        emitter.add(sparkBurst, forKey: "sparkBurst")
        emitter.add(glowBurst, forKey: "glowBurst")
        
        // Cleanup Layer after particles die
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            emitter.removeFromSuperlayer()
        }
    }
    
    // Robust Image Generation (0 CPU impact during runtime)
    private func generateParticleImage(size: CGSize, color: UIColor, isGlow: Bool) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        
        ctx.setFillColor(color.cgColor)
        if isGlow {
            // Soft Radial Gradient or simple soft circle
            let rect = CGRect(origin: .zero, size: size)
            ctx.fillEllipse(in: rect)
        } else {
            ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
