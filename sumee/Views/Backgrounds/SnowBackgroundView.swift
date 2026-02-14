import SwiftUI
import UIKit
import QuartzCore

struct SnowBackgroundView: View {
    var isPaused: Bool = false
    
    var body: some View {
        ZStack {
            // Festive Christmas Gradient (Static Background)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.55, green: 0.0, blue: 0.1), // Dark Cherry
                    Color(red: 0.85, green: 0.15, blue: 0.2) // Holiday Red
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // High-Performance Snow Engine
            SnowEngineView(isPaused: isPaused)
                .ignoresSafeArea()
        }
    }
}

//  UIViewRepresentable

struct SnowEngineView: UIViewRepresentable {
    var isPaused: Bool
    
    func makeUIView(context: Context) -> SnowView {
        return SnowView()
    }
    
    func updateUIView(_ uiView: SnowView, context: Context) {
        if isPaused {
            uiView.pause()
        } else {
            uiView.resume()
        }
    }
}

// Core Animation Snow Engine

class SnowView: UIView {
    private let emitterLayer = CAEmitterLayer()
    
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
        
        // Configure Emitter
        emitterLayer.emitterShape = .line
        emitterLayer.emitterMode = .outline
        emitterLayer.renderMode = .additive // Nice blending for snow overlap
        
        // Initial config (will be updated in layoutSubviews)
        emitterLayer.emitterPosition = CGPoint(x: bounds.width / 2, y: -50)
        emitterLayer.emitterSize = CGSize(width: bounds.width, height: 1)
        
        // Create Snowflake Cell
        let flake = CAEmitterCell()
        flake.contents = generateSnowflakeImage()?.cgImage
        flake.birthRate = 20          // Continuous flow
        flake.lifetime = 20.0        // Long enough to reach bottom
        flake.velocity = 60          // Falling speed
        flake.velocityRange = 20     // Variance
        flake.yAcceleration = 10     // Gravity
        flake.emissionLongitude = .pi // Downwards
        flake.emissionRange = .pi / 4 // Spread width
        flake.spin = 1.0             // Rotation speed
        flake.spinRange = 2.0        // Variance
        flake.scale = 0.12           // Smaller base size
        flake.scaleRange = 0.08      // Variance
        flake.alphaRange = 0.5       // Opacity variance
        flake.alphaSpeed = -0.02     // Slight fade out at very end
        
        emitterLayer.emitterCells = [flake]
        layer.addSublayer(emitterLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update emitter to span full width
        emitterLayer.emitterPosition = CGPoint(x: bounds.width / 2, y: -20)
        emitterLayer.emitterSize = CGSize(width: bounds.width + 100, height: 1)
    }
    
    func pause() {
        emitterLayer.speed = 0
    }
    
    func resume() {
        emitterLayer.speed = 1
    }
    
    // Robust Image Generation (0 CPU impact during runtime)
    private func generateSnowflakeImage() -> UIImage? {
        let size = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        
        // Soft white circle (Snowflake)
        ctx.setFillColor(UIColor.white.cgColor)
        
        
       
        let rect = CGRect(origin: .zero, size: size)
        ctx.fillEllipse(in: rect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
