import SwiftUI

struct PSXButton: View {
    let id: Int
    let label: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Shadow
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.3))
                .blur(radius: 2)
                .offset(x: 0, y: isPressed ? 1 : 3)
            
            // Base Shape (Bevel Look)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.6), Color(white: 0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .padding(1)
                )
            
            // Top Highlights
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .padding(2)

            // Inner Body (Depress effect)
            if isPressed {
                RoundedRectangle(cornerRadius: cornerRadius - 2)
                    .fill(Color(white: 0.35))
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius - 2)
                            .stroke(Color.black.opacity(0.2), lineWidth: 2)
                            .blur(radius: 1)
                            .padding(4)
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius - 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.5), Color(white: 0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(4)
            }

            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isPressed ? .white.opacity(0.5) : .white.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .frame(width: width, height: height)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .rotation3DEffect(
            .degrees(isPressed ? 15 : 0),
            axis: (x: 1.0, y: 0.0, z: 0.0),
            perspective: 0.5
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        PSXInput.shared.setButton(id, pressed: true)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    PSXInput.shared.setButton(id, pressed: false)
                }
        )
    }
}

// Reutilizamos diseño de DPad pero enviamos IDs de PSX
struct PSXDPad: View {
    let size: CGFloat = 140
    let thickness: CGFloat = 48
    
    @State private var pressedButtons: Set<Int> = []
    
    var body: some View {
        let isUp = pressedButtons.contains(PSXInput.ID_UP)
        let isDown = pressedButtons.contains(PSXInput.ID_DOWN)
        let isLeft = pressedButtons.contains(PSXInput.ID_LEFT)
        let isRight = pressedButtons.contains(PSXInput.ID_RIGHT)
        
        // Tilt Logic (Inverted for correct physics)
        let tiltX: Double = isUp ? 10 : (isDown ? -10 : 0)
        let tiltY: Double = isLeft ? -10 : (isRight ? 10 : 0)
        
        return ZStack {
            // Shadow
            Image(systemName: "dpad.fill")
                .resizable()
                .frame(width: size, height: size)
                .foregroundColor(.black.opacity(0.4))
                .blur(radius: 4)
                .offset(y: 5)
                .scaleEffect(0.95)
            
            // Unified Cross Body
            ZStack {
                Group {
                    // Vertical
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: thickness, height: size)
                    // Horizontal
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: size, height: thickness)
                }
                .foregroundColor(.clear)
                .background(
                    LinearGradient(
                        colors: [Color(white: 0.25), Color(white: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .mask(
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .frame(width: thickness, height: size)
                            RoundedRectangle(cornerRadius: 6)
                                .frame(width: size, height: thickness)
                        }
                    )
                )
                // Individual Segment Indents (Sony Syle Illusion)
                .overlay(
                    Circle()
                        .fill(Color(white: 0.15))
                        .frame(width: thickness * 0.5, height: thickness * 0.5)
                        .shadow(color: .white.opacity(0.05), radius: 1, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: -1)
                )
                // Bevel/Stroke
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            .frame(width: thickness, height: size)
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            .frame(width: size, height: thickness)
                    }
                    .mask(
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .frame(width: thickness, height: size)
                            RoundedRectangle(cornerRadius: 6)
                                .frame(width: size, height: thickness)
                        }
                    )
                )
                
                // Directional Triangles
                Group {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 10, weight: .black))
                        .rotationEffect(.degrees(0))
                        .offset(y: -size/2 + 12) // Pushed to edge
                        .foregroundColor(isUp ? .white.opacity(0.6) : .black.opacity(0.4))
                        .scaleEffect(0.6)
                    
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 10, weight: .black))
                        .rotationEffect(.degrees(180))
                        .offset(y: size/2 - 12) // Pushed to edge
                        .foregroundColor(isDown ? .white.opacity(0.6) : .black.opacity(0.4))
                        .scaleEffect(0.6)
                        
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 10, weight: .black))
                        .rotationEffect(.degrees(-90))
                        .offset(x: -size/2 + 12) // Pushed to edge
                        .foregroundColor(isLeft ? .white.opacity(0.6) : .black.opacity(0.4))
                        .scaleEffect(0.6)
                        
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 10, weight: .black))
                        .rotationEffect(.degrees(90))
                        .offset(x: size/2 - 12) // Pushed to edge
                        .foregroundColor(isRight ? .white.opacity(0.6) : .black.opacity(0.4))
                        .scaleEffect(0.6)
                }
                .font(.system(size: 14, weight: .black))
            }
            .rotation3DEffect(
                .degrees(tiltX),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                perspective: 0.5
            )
            .rotation3DEffect(
                .degrees(tiltY),
                axis: (x: 0.0, y: 1.0, z: 0.0),
                perspective: 0.5
            )
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.6), value: pressedButtons)
            
            // Touch Handling with GeometryReader
            GeometryReader { geo in
                Color.white.opacity(0.001)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                updateDirection(value.location, center: center)
                            }
                            .onEnded { _ in
                                releaseAll()
                            }
                    )
            }
            .frame(width: size * 1.6, height: size * 1.6)
        }
        .frame(width: size, height: size)
    }
    
    private func updateDirection(_ location: CGPoint, center: CGPoint) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        
        if hypot(dx, dy) < 10 {
            releaseAll()
            return
        }
        
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        
        var newPressed: Set<Int> = []
        
        if angle >= 337.5 || angle < 22.5 {
            newPressed.insert(PSXInput.ID_RIGHT)
        } else if angle >= 22.5 && angle < 67.5 {
            newPressed.insert(PSXInput.ID_RIGHT)
            newPressed.insert(PSXInput.ID_DOWN)
        } else if angle >= 67.5 && angle < 112.5 {
            newPressed.insert(PSXInput.ID_DOWN)
        } else if angle >= 112.5 && angle < 157.5 {
            newPressed.insert(PSXInput.ID_DOWN)
            newPressed.insert(PSXInput.ID_LEFT)
        } else if angle >= 157.5 && angle < 202.5 {
            newPressed.insert(PSXInput.ID_LEFT)
        } else if angle >= 202.5 && angle < 247.5 {
            newPressed.insert(PSXInput.ID_LEFT)
            newPressed.insert(PSXInput.ID_UP)
        } else if angle >= 247.5 && angle < 292.5 {
            newPressed.insert(PSXInput.ID_UP)
        } else if angle >= 292.5 && angle < 337.5 {
            newPressed.insert(PSXInput.ID_UP)
            newPressed.insert(PSXInput.ID_RIGHT)
        }
        
        updateInputs(newPressed)
    }
    
    private func updateInputs(_ newPressed: Set<Int>) {
        if newPressed != pressedButtons {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            for id in pressedButtons.subtracting(newPressed) {
                PSXInput.shared.setButton(id, pressed: false)
            }
            
            for id in newPressed.subtracting(pressedButtons) {
                PSXInput.shared.setButton(id, pressed: true)
            }
            
            pressedButtons = newPressed
        }
    }
    
    private func releaseAll() {
        for id in pressedButtons {
            PSXInput.shared.setButton(id, pressed: false)
        }
        pressedButtons.removeAll()
    }
}

struct PSXCircularButton: View {
    let size: CGFloat
    let icon: String // SF Symbol name
    let color: Color
    var isPressed: Bool
    
    var body: some View {
        ZStack {
            // Shadow (Dynamic)
            Circle()
                .fill(Color.black.opacity(isPressed ? 0.2 : 0.4))
                .offset(y: isPressed ? 1 : 3)
                .blur(radius: 2)
            
            // Main Body (Glossy Black Plastic)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.25),
                            Color(white: 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Glossy Reflection Top
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.4), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(2)
                        .blur(radius: 1)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
            
            // Icon (Glow / Inset look)
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .bold)) // Bold for clearer symbol
                .foregroundColor(color)
                .shadow(color: color.opacity(0.6), radius: 2, x: 0, y: 0) // Glow
                .overlay(
                     Image(systemName: icon)
                         .font(.system(size: size * 0.5, weight: .bold))
                         .foregroundColor(.white.opacity(0.3))
                         .offset(x: -0.5, y: -0.5)
                         .mask(Image(systemName: icon).font(.system(size: size * 0.5, weight: .bold)))
                , alignment: .center)
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .offset(y: isPressed ? 1 : 0)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    }
}

struct PSXActionButtonsPad: View {
    // Defines the layout of buttons relative to the center
    struct ButtonDef {
        let id: Int
        let icon: String
        let color: Color
        let offset: CGPoint
    }
    
    let buttons: [ButtonDef] = [
        ButtonDef(id: PSXInput.ID_X, icon: "triangle", color: .green, offset: CGPoint(x: 0, y: -50)),
        ButtonDef(id: PSXInput.ID_B, icon: "multiply", color: .blue, offset: CGPoint(x: 0, y: 50)),
        ButtonDef(id: PSXInput.ID_Y, icon: "square", color: .pink, offset: CGPoint(x: -50, y: 0)),
        ButtonDef(id: PSXInput.ID_A, icon: "circle", color: .red, offset: CGPoint(x: 50, y: 0))
    ]
    
    @State private var pressedButtons: Set<Int> = []
    
    var body: some View {
        ZStack {
            // Visual Layer
            ForEach(buttons, id: \.id) { btn in
                PSXCircularButton(size: 55, icon: btn.icon, color: btn.color, isPressed: pressedButtons.contains(btn.id))
                    .offset(x: btn.offset.x, y: btn.offset.y)
            }
            
            // Touch Layer (UIKit MultiTouch)
            PSXMultiTouchPad(buttons: buttons) { newPressed in
                if newPressed != pressedButtons {
                    // Haptics
                    let added = newPressed.subtracting(pressedButtons)
                    if !added.isEmpty {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    pressedButtons = newPressed
                }
            }
        }
        .frame(width: 150, height: 150)
    }
}

// Helper: True Multi-Touch Handler using UIKit
struct PSXMultiTouchPad: UIViewRepresentable {
    let buttons: [PSXActionButtonsPad.ButtonDef]
    var onUpdate: (Set<Int>) -> Void
    
    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.buttons = buttons
        view.onUpdate = onUpdate
        return view
    }
    
    func updateUIView(_ uiView: TouchView, context: Context) {
        uiView.buttons = buttons
        uiView.onUpdate = onUpdate
    }
    
    class TouchView: UIView {
        var buttons: [PSXActionButtonsPad.ButtonDef] = []
        var onUpdate: ((Set<Int>) -> Void)?
        private var activeTouches: [UITouch: Int] = [:]
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            backgroundColor = .clear
        }
        
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { updateTouches(touches, phase: .began) }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { updateTouches(touches, phase: .moved) }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { updateTouches(touches, phase: .ended) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { updateTouches(touches, phase: .cancelled) }
        
        private func updateTouches(_ touches: Set<UITouch>, phase: UITouch.Phase) {
            let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
            
            for touch in touches {
                if phase == .ended || phase == .cancelled {
                    activeTouches.removeValue(forKey: touch)
                } else {
                    let loc = touch.location(in: self)
                    var foundBtn: Int? = nil
                    for btn in buttons {
                        let btnCenter = CGPoint(x: center.x + btn.offset.x, y: center.y + btn.offset.y)
                        if hypot(loc.x - btnCenter.x, loc.y - btnCenter.y) < 40 { // 40 radius
                            foundBtn = btn.id
                            break
                        }
                    }
                    if let id = foundBtn { activeTouches[touch] = id }
                    else { activeTouches.removeValue(forKey: touch) }
                }
            }
            let all = Set(activeTouches.values)
            PSXInput.shared.updateActionButtons(all)
            onUpdate?(all)
        }
    }
}

struct PSXVirtualController: View {
    var isTransparent: Bool = false
    
    // Visibility States
    enum VisibilityMode {
        case visible
        case transparent
        case hidden
        
        var opacity: Double {
            switch self {
            case .visible: return 1.0
            case .transparent: return 0.2
            case .hidden: return 0.0
            }
        }
        
        mutating func next() {
            switch self {
            case .visible: self = .transparent
            case .transparent: self = .hidden
            case .hidden: self = .visible
            }
        }
    }
    
    @ObservedObject var controlManager = PSXControlManager.shared
    @ObservedObject var skinManager = PSXSkinManager.shared
    @State private var mode: VisibilityMode = .visible
    

    private func draggable(key: WritableKeyPath<PSXControlPositions, CGPoint>) -> some ViewModifier {
        DraggablePSX(manager: controlManager, key: key)
    }
    
    var body: some View {
        GeometryReader { geo in
            // Robust Orientation Check (Match DSKit)
            let isPortrait = UIScreen.main.bounds.height > UIScreen.main.bounds.width || geo.size.height > geo.size.width
            
            ZStack {
                // Background Logic handled by PSXScreenLayout now
                
                // MODO EDICIÓN: Grid Overlay
                if controlManager.isEditing {
                    // Color.black.opacity(0.5).ignoresSafeArea() // REMOVED to allow screen interaction
                    VStack {
                        Text("EDIT MODE")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 50)
                        
                        Text("Drag controls to allow custom positioning")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 20) {
                            Button(action: { controlManager.resetConfig() }) {
                                Text("Reset")
                                    .bold()
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.red)
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: { 
                                controlManager.saveConfig()
                                withAnimation { controlManager.isEditing = false }
                            }) {
                                Text("Save")
                                    .bold()
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        Spacer()
                    }
                    .zIndex(100)
                }
                
                if let skinRepresentation = skinManager.currentRepresentation(portrait: isPortrait) {
                    // --- SKIN OVERLAY ---
                    PSXSkinInputOverlay(
                        representation: skinRepresentation,
                        viewSize: geo.size,
                        showInputControls: true
                    )
                } else {
                    if isPortrait {
                        // --- PORTRAIT MODE LAYOUT (Bottom Half) ---
                        // Use nested VStack with Spacer to push everything to the bottom
                        VStack {
                            Spacer()
                            
                            // Controls Container
                            VStack {
                                // Top Shoulders
                                HStack(spacing: 20) {
                                    HStack(spacing: 5) {
                                        PSXButton(id: PSXInput.ID_L2, label: "L2", width: 70, height: 40, cornerRadius: 10)
                                        PSXButton(id: PSXInput.ID_L, label: "L1", width: 70, height: 40, cornerRadius: 10)
                                    }
                                    .modifier(draggable(key: isPortrait ? \.lClusterPortrait : \.lClusterLandscape))
                                    
                                    Spacer()
                                    HStack(spacing: 5) {
                                        PSXButton(id: PSXInput.ID_R, label: "R1", width: 70, height: 40, cornerRadius: 10)
                                        PSXButton(id: PSXInput.ID_R2, label: "R2", width: 70, height: 40, cornerRadius: 10)
                                    }
                                    .modifier(draggable(key: isPortrait ? \.rClusterPortrait : \.rClusterLandscape))
                                }
                                .padding(.top, 50)
                                .padding(.leading, 30) // Adjusted to 30
                                .padding(.trailing, 30) // Adjusted to 30
                                
                                Spacer()
                                
                                // Bottom Controls Area
                                ZStack(alignment: .bottom) {
                                    // Layer 1: D-Pad and Face Buttons (Main Inputs)
                                    HStack(alignment: .bottom) {
                                        PSXDPad()
                                            .modifier(draggable(key: isPortrait ? \.dpadPortrait : \.dpadLandscape))
                                            .padding(.bottom, 120)
                                            .padding(.leading, 15) // Moved closer to Left edge
                                        
                                        Spacer()
                                        
                                        // Face Buttons
                                        PSXActionButtonsPad()
                                        .modifier(draggable(key: isPortrait ? \.faceButtonsPortrait : \.faceButtonsLandscape))
                                        .padding(.bottom, 120) // Moved significantly higher
                                        .padding(.trailing, 15) // Moved closer to Right edge
                                    }
                                    
                                    // Layer 2: Start/Select (Center Bottom)
                                    HStack(spacing: 25) {
                                        // Select
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color(white: 0.35), Color(white: 0.25)],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                                    .frame(width: 45, height: 14)
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                                    )
                                                    .overlay(
                                                        Capsule()
                                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                                            .padding(1)
                                                    )
                                                    .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                                            }
                                            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in 
                                                guard !PSXControlManager.shared.isEditing else { return }
                                                PSXInput.shared.setButton(PSXInput.ID_SELECT, pressed: true)
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            }.onEnded { _ in 
                                                PSXInput.shared.setButton(PSXInput.ID_SELECT, pressed: false) 
                                            })
                                            
                                            Text("SELECT").font(.system(size: 9, weight: .bold)).foregroundColor(Color(white: 0.3))
                                        }
                                        .modifier(draggable(key: isPortrait ? \.selectPortrait : \.selectLandscape))

                                        // Start
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color(white: 0.35), Color(white: 0.25)],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                                    .frame(width: 45, height: 14)
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                                    )
                                                    .overlay(
                                                        Capsule()
                                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                                            .padding(1)
                                                    )
                                                    .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                                            }
                                            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in 
                                                guard !PSXControlManager.shared.isEditing else { return }
                                                PSXInput.shared.setButton(PSXInput.ID_START, pressed: true)
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            }.onEnded { _ in 
                                                PSXInput.shared.setButton(PSXInput.ID_START, pressed: false) 
                                            })
                                            
                                            Text("START").font(.system(size: 9, weight: .bold)).foregroundColor(Color(white: 0.3))
                                        }
                                        .modifier(draggable(key: isPortrait ? \.startPortrait : \.startLandscape))
                                    }
                                    .padding(.bottom, 20)
                                }
                            }
                            .frame(height: geo.size.height * 0.5) // Takes bottom 50%
                            .opacity(mode.opacity)
                            .allowsHitTesting(mode != .hidden || controlManager.isEditing)
                        }
                    } else {
                        // --- LANDSCAPE MODE LAYOUT (Overlay) ---
                        ZStack {
                            Group {
                                // Top Shoulders
                                VStack {
                                    HStack(spacing: 20) {
                                        HStack(spacing: 5) {
                                            PSXButton(id: PSXInput.ID_L2, label: "L2", width: 70, height: 40, cornerRadius: 10)
                                            PSXButton(id: PSXInput.ID_L, label: "L1", width: 70, height: 40, cornerRadius: 10)
                                        }
                                        .modifier(draggable(key: isPortrait ? \.lClusterPortrait : \.lClusterLandscape))
                                        
                                        Spacer()
                                        HStack(spacing: 5) {
                                            PSXButton(id: PSXInput.ID_R, label: "R1", width: 70, height: 40, cornerRadius: 10)
                                            PSXButton(id: PSXInput.ID_R2, label: "R2", width: 70, height: 40, cornerRadius: 10)
                                        }
                                        .modifier(draggable(key: isPortrait ? \.rClusterPortrait : \.rClusterLandscape))
                                    }
                                    .padding(.top, 80).padding(.horizontal, 20) // Adjusted top padding
                                    Spacer()
                                }
                                
                                // Bottom Controls (D-Pad, Face Buttons, Start/Select)
                                VStack {
                                    Spacer()
                                    HStack(alignment: .bottom) {
                                        PSXDPad()
                                            .modifier(draggable(key: isPortrait ? \.dpadPortrait : \.dpadLandscape))
                                            .padding(.bottom, 80).padding(.leading, 30)
                                        
                                        Spacer()
                                        
                                        // Select / Start
                                        HStack(spacing: 25) {
                                            // Select
                                            VStack(spacing: 4) {
                                                ZStack {
                                                    Capsule()
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color(white: 0.35), Color(white: 0.25)],
                                                                startPoint: .top,
                                                                endPoint: .bottom
                                                            )
                                                        )
                                                        .frame(width: 45, height: 14)
                                                        .overlay(
                                                            Capsule()
                                                                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                                        )
                                                        .overlay(
                                                            Capsule()
                                                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                                                .padding(1)
                                                        )
                                                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                                                }
                                                .gesture(DragGesture(minimumDistance: 0).onChanged { _ in 
                                                    guard !PSXControlManager.shared.isEditing else { return }
                                                    PSXInput.shared.setButton(PSXInput.ID_SELECT, pressed: true)
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                }.onEnded { _ in 
                                                    PSXInput.shared.setButton(PSXInput.ID_SELECT, pressed: false) 
                                                })
                                                
                                                Text("SELECT").font(.system(size: 9, weight: .bold)).foregroundColor(Color(white: 0.3))
                                            }
                                            .modifier(draggable(key: isPortrait ? \.selectPortrait : \.selectLandscape))

                                            // Start
                                            VStack(spacing: 4) {
                                                ZStack {
                                                    Capsule()
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color(white: 0.35), Color(white: 0.25)],
                                                                startPoint: .top,
                                                                endPoint: .bottom
                                                            )
                                                        )
                                                        .frame(width: 45, height: 14)
                                                        .overlay(
                                                            Capsule()
                                                                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                                        )
                                                        .overlay(
                                                            Capsule()
                                                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                                                .padding(1)
                                                        )
                                                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                                                }
                                                .gesture(DragGesture(minimumDistance: 0).onChanged { _ in 
                                                    guard !PSXControlManager.shared.isEditing else { return }
                                                    PSXInput.shared.setButton(PSXInput.ID_START, pressed: true)
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                }.onEnded { _ in 
                                                    PSXInput.shared.setButton(PSXInput.ID_START, pressed: false) 
                                                })
                                                
                                                Text("START").font(.system(size: 9, weight: .bold)).foregroundColor(Color(white: 0.3))
                                            }
                                            .modifier(draggable(key: isPortrait ? \.startPortrait : \.startLandscape))
                                        }
                                        .padding(.bottom, 20)
                                        
                                        Spacer()
                                        
                                        PSXActionButtonsPad()
                                        .modifier(draggable(key: isPortrait ? \.faceButtonsPortrait : \.faceButtonsLandscape))
                                        .padding(.bottom, 80).padding(.trailing, 30)
                                    }
                                }
                            }
                            .opacity(mode.opacity)
                            .allowsHitTesting(mode != .hidden || controlManager.isEditing)
                        }
                    }
                }
                
                // Visibility Toggle & Edit Button
                VStack {
                    if isPortrait {
                        Spacer() // Push to bottom
                        HStack {
                            Spacer() // Push to right
                            
                            Menu {
                                Button(action: {
                                    withAnimation { controlManager.isEditing = true }
                                }) {
                                    Label("Edit Layout", systemImage: "slider.horizontal.3")
                                }
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        mode.next()
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    Label("Change Opacity", systemImage: "sun.min")
                                }
                            } label: {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(10)
                                    .background(Circle().fill(Color.black.opacity(0.3)))
                            }
                            .padding(.bottom, 10)
                            .padding(.trailing, 10)
                        }
                        .opacity(controlManager.isEditing ? 0 : 1)
                        .allowsHitTesting(!controlManager.isEditing)
                    } else {
                        // Landscape: Top Right
                        HStack {
                            Spacer() // Push to right
                            
                            Menu {
                                Button(action: {
                                    withAnimation { controlManager.isEditing = true }
                                }) {
                                    Label("Edit Layout", systemImage: "slider.horizontal.3")
                                }
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        mode.next()
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    Label("Change Opacity", systemImage: "sun.min")
                                }
                            } label: {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(10)
                                    .background(Circle().fill(Color.black.opacity(0.3)))
                            }
                            .padding(.top, 20)
                            .padding(.trailing, 20)
                        }
                        .opacity(controlManager.isEditing ? 0 : 1)
                        .allowsHitTesting(!controlManager.isEditing)
                        
                        Spacer() 
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct DraggablePSX: ViewModifier {
    @ObservedObject var manager: PSXControlManager
    let key: WritableKeyPath<PSXControlPositions, CGPoint>
    
    @State private var dragOffset: CGPoint = .zero
    
    func body(content: Content) -> some View {
        let currentPos = manager.positions[keyPath: key]
        let isEditing = manager.isEditing
        
        return content
            .offset(x: currentPos.x + dragOffset.x, y: currentPos.y + dragOffset.y)
            .overlay(
                isEditing ? 
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow, lineWidth: 2)
                        .padding(-5)
                    : nil
            )
            .simultaneousGesture(
                isEditing ?
                DragGesture()
                    .onChanged { value in
                        dragOffset = CGPoint(x: value.translation.width, y: value.translation.height)
                    }
                    .onEnded { value in
                        let newPos = CGPoint(x: currentPos.x + value.translation.width, y: currentPos.y + value.translation.height)
                        manager.updatePosition(key, value: newPos)
                        dragOffset = .zero
                    }
                : nil
            )
    }
}        
    

