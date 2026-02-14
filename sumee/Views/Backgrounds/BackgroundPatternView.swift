import SwiftUI
import UIKit
import QuartzCore
import Combine

struct BackgroundPatternView: View {
    var isAnimating: Bool = true
    var isPaused: Bool = false
    
    var body: some View {
        // Vectorial implementation
        VectorGridPatternView(isAnimating: isAnimating && !isPaused)
            .ignoresSafeArea()
    }
}


// Smart Pattern View (Replicator + Power Awareness)
struct VectorGridPatternView: UIViewRepresentable {
    var isAnimating: Bool
    
    func makeUIView(context: Context) -> UIView {
        return SmartReplicatorGridView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let view = uiView as? SmartReplicatorGridView {
            view.setIsAnimating(isAnimating)
        }
    }
}

class SmartReplicatorGridView: UIView {
    // Hardware Replicators
    private let gridReplicator = CAReplicatorLayer()   // Horizonal (Columns)
    private let columnReplicator = CAReplicatorLayer() // Vertical (Rows)
    private let dotLayer = CALayer()                   // The single source dot
    
    private let spacing: CGFloat = 24
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // 1. Configure Dot
        dotLayer.bounds = CGRect(x: 0, y: 0, width: 4.5, height: 4.5)
        dotLayer.cornerRadius = 2.25
        dotLayer.contentsScale = UIScreen.main.scale
        
        // 2. Configure Vertical Column
        columnReplicator.addSublayer(dotLayer)
     
        
        // 3. Configure Horizontal Grid
        gridReplicator.addSublayer(columnReplicator)
        layer.addSublayer(gridReplicator)
        
        // 4. Initial Colors
        updateColors()
        
        // 5. Observers
        setupObservers()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setupObservers() {
        // Theme
        SettingsManager.shared.$activeThemeID
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateColors() }
            }
            .store(in: &cancellables)
            
        // "Smart" Power Awareness
        NotificationCenter.default.addObserver(self, selector: #selector(checkPowerState), name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(checkPowerState), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(checkPowerState), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    // Layout & Replicator Logic
    override func layoutSubviews() {
        super.layoutSubviews()
        

        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        
  
        gridReplicator.frame = CGRect(x: 0, y: 0, width: width, height: height)
        
        // Calculate Instances needed
        let cols = Int(ceil(width / spacing))
        let rows = Int(ceil(height / spacing))
        
        // Configure Column (Vertical)

        columnReplicator.instanceCount = rows
        columnReplicator.instanceTransform = CATransform3DMakeTranslation(0, spacing, 0)
        
        // Configure Grid (Horizontal)
  
        gridReplicator.instanceCount = cols
        gridReplicator.instanceTransform = CATransform3DMakeTranslation(spacing, 0, 0)
        
        // Dot placement
     
        dotLayer.position = CGPoint(x: spacing/2, y: spacing/2)
    }
    
    //  Appearance
    private func updateColors() {
        let isDark = SettingsManager.shared.activeTheme.isDark
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if isDark {
            self.backgroundColor = UIColor(white: 0.08, alpha: 1)
            dotLayer.backgroundColor = UIColor.white.withAlphaComponent(0.15).cgColor
        } else {
            self.backgroundColor = UIColor(red: 0.89, green: 0.91, blue: 0.94, alpha: 1)
            dotLayer.backgroundColor = UIColor.black.withAlphaComponent(0.06).cgColor
        }
        
        CATransaction.commit()
    }
    
    //  Animation Engine
    private var externalIsAnimating: Bool = true
    
    func setIsAnimating(_ isAnimating: Bool) {
        externalIsAnimating = isAnimating
        checkPowerState()
    }
    
    @objc private func checkPowerState() {
        // 1. Check Hardware Limitations
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let isPad = UIDevice.current.userInterfaceIdiom == .pad // Disable on iPad for performance
        
        // 2. Decide
        // Force Static on ALL Devices for maximum performance 
        let shouldActuallyAnimate = false // externalIsAnimating && !lowPower && !reduceMotion && !isPad
        
        if shouldActuallyAnimate {
            startAnimation()
        } else {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        if gridReplicator.animation(forKey: "shift") != nil { return }
        
        // GPU movement of the entire replicator system
        let animation = CABasicAnimation(keyPath: "transform.translation")
        animation.fromValue = NSValue(cgSize: .zero)
        animation.toValue = NSValue(cgSize: CGSize(width: spacing, height: spacing))
        animation.duration = 4.0
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        
        // Native GPU Throttling (20 FPS)
        if #available(iOS 15.0, *) {
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 20)
        }
        
        gridReplicator.add(animation, forKey: "shift")
    }
    
    private func stopAnimation() {
        gridReplicator.removeAnimation(forKey: "shift")
    }
}
