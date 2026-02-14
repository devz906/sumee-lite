import SwiftUI

// --- NES Components (Simplified from SNES) ---

struct NESButton: View {
    let id: Int
    let label: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Shadow/Relief
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(white: 0.2))
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .opacity(isPressed ? 0.7 : 1.0)
            
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        NESInput.shared.setButton(id, pressed: true)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    NESInput.shared.setButton(id, pressed: false)
                }
        )
    }
}

struct NESCircularButton: View {
    let size: CGFloat
    let label: String
    let color: Color
    var isPressed: Bool
    
    var body: some View {
        ZStack {
            // Shadow (Dynamic)
            Circle()
                .fill(Color.black.opacity(isPressed ? 0.2 : 0.4))
                .offset(y: isPressed ? 1 : 3)
                .blur(radius: 2)
            
            // Main Body (Glossy Plastic)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.9),
                            color.opacity(1.0)
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
                                colors: [Color.white.opacity(0.5), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(2)
                        .blur(radius: 1)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
            
            Text(label)
                .font(.system(size: size * 0.45, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                .offset(y: isPressed ? 0 : -1)
        }
        .frame(width: size, height: size)
        .frame(width: size * 1.3, height: size * 1.3) // Expand Hit Area
        .contentShape(Circle())
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    }
}

// NES only has 2 buttons: A and B (Simpler than SNES)
struct NESActionButtonsPad: View {
    struct ButtonDef {
        let id: Int
        let label: String
        let color: Color
        let offset: CGPoint
    }
    
    let buttons: [ButtonDef] = [
        ButtonDef(id: NESInput.ID_B, label: "B", color: .red, offset: CGPoint(x: -30, y: 0)),
        ButtonDef(id: NESInput.ID_A, label: "A", color: .red, offset: CGPoint(x: 30, y: 0))
    ]
    
    @State private var pressedButtons: Set<Int> = []
    
    var body: some View {
        ZStack {
            // Visual Layer
            ForEach(buttons, id: \.id) { btn in
                NESCircularButton(size: 55, label: btn.label, color: btn.color, isPressed: pressedButtons.contains(btn.id))
                    .offset(x: btn.offset.x, y: btn.offset.y)
            }
            
            // Touch Layer (UIKit MultiTouch)
            NESMultiTouchPad(buttons: buttons) { newPressed in
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
        .frame(width: 130, height: 80)
    }
}

// Helper: True Multi-Touch Handler using UIKit
struct NESMultiTouchPad: UIViewRepresentable {
    let buttons: [NESActionButtonsPad.ButtonDef]
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
        var buttons: [NESActionButtonsPad.ButtonDef] = []
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
            NESInput.shared.updateActionButtons(all)
            onUpdate?(all)
        }
    }
}

struct NESDPad: View {
    let size: CGFloat = 140
    let thickness: CGFloat = 48
    
    @State private var pressedButtons: Set<Int> = []
    
    var body: some View {
        let isUp = pressedButtons.contains(NESInput.ID_UP)
        let isDown = pressedButtons.contains(NESInput.ID_DOWN)
        let isLeft = pressedButtons.contains(NESInput.ID_LEFT)
        let isRight = pressedButtons.contains(NESInput.ID_RIGHT)
        
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
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: thickness, height: size)
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
                
                // Subtle Directional Arrows
                Group {
                    Image(systemName: "play.fill")
                        .rotationEffect(.degrees(-90))
                        .offset(y: -size/3 + 5)
                        .foregroundColor(isUp ? .white.opacity(0.5) : .black.opacity(0.3))
                    
                    Image(systemName: "play.fill")
                        .rotationEffect(.degrees(90))
                        .offset(y: size/3 - 5)
                        .foregroundColor(isDown ? .white.opacity(0.5) : .black.opacity(0.3))
                        
                    Image(systemName: "play.fill")
                        .rotationEffect(.degrees(180))
                        .offset(x: -size/3 + 5)
                        .foregroundColor(isLeft ? .white.opacity(0.5) : .black.opacity(0.3))
                        
                    Image(systemName: "play.fill")
                        .rotationEffect(.degrees(0))
                        .offset(x: size/3 - 5)
                        .foregroundColor(isRight ? .white.opacity(0.5) : .black.opacity(0.3))
                }
                .font(.system(size: 10, weight: .black))
                .shadow(color: .white.opacity(0.1), radius: 0, x: 0, y: 1)
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
            newPressed.insert(NESInput.ID_RIGHT)
        } else if angle >= 22.5 && angle < 67.5 {
            newPressed.insert(NESInput.ID_RIGHT)
            newPressed.insert(NESInput.ID_DOWN)
        } else if angle >= 67.5 && angle < 112.5 {
            newPressed.insert(NESInput.ID_DOWN)
        } else if angle >= 112.5 && angle < 157.5 {
            newPressed.insert(NESInput.ID_DOWN)
            newPressed.insert(NESInput.ID_LEFT)
        } else if angle >= 157.5 && angle < 202.5 {
            newPressed.insert(NESInput.ID_LEFT)
        } else if angle >= 202.5 && angle < 247.5 {
            newPressed.insert(NESInput.ID_LEFT)
            newPressed.insert(NESInput.ID_UP)
        } else if angle >= 247.5 && angle < 292.5 {
            newPressed.insert(NESInput.ID_UP)
        } else if angle >= 292.5 && angle < 337.5 {
            newPressed.insert(NESInput.ID_UP)
            newPressed.insert(NESInput.ID_RIGHT)
        }
        
        updateInputs(newPressed)
    }
    
    private func updateInputs(_ newPressed: Set<Int>) {
        if newPressed != pressedButtons {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            for id in pressedButtons.subtracting(newPressed) {
                NESInput.shared.setButton(id, pressed: false)
            }
            
            for id in newPressed.subtracting(pressedButtons) {
                NESInput.shared.setButton(id, pressed: true)
            }
            
            pressedButtons = newPressed
        }
    }
    
    private func releaseAll() {
        for id in pressedButtons {
            NESInput.shared.setButton(id, pressed: false)
        }
        pressedButtons.removeAll()
    }
}

public struct NESVirtualController: View {
    var isTransparent: Bool = false
    var showInputControls: Bool = true
    
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
    
    @State private var mode: VisibilityMode = .visible
    
    @ObservedObject var controlManager = NESControlManager.shared
    @ObservedObject var skinManager = NESSkinManager.shared
    
    // Helper para hacer controles arrastrables
    private func draggable(key: WritableKeyPath<NESControlPositions, CGPoint>) -> some ViewModifier {
        DraggableNES(manager: controlManager, key: key)
    }
    
    public var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height >= geo.size.width
            
            if let representation = skinManager.currentRepresentation(portrait: isPortrait) {
                NESSkinInputOverlay(representation: representation, viewSize: geo.size, showInputControls: showInputControls)
            } else {
                ZStack {
                Color.clear.frame(width: geo.size.width, height: geo.size.height)
                
                // MODO EDICIÓN: Grid Overlay
                if controlManager.isEditing {
                    // Color.black.opacity(0.5).ignoresSafeArea() // REMOVED to allow screen interaction
                    VStack {
                        Text("EDIT MODE")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 50)
                        
                        Text("Drag controls to customize positioning")
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
                
                // Robust Orientation Detection
                if UIScreen.main.bounds.height > UIScreen.main.bounds.width || geo.size.height > geo.size.width {
                    
                    // --- PORTRAIT MODE ---
                    ZStack {
                        Group {
                            // 1. D-Pad (Bottom Left)
                            VStack {
                                Spacer()
                                NESDPad()
                                    .modifier(draggable(key: isPortrait ? \.dpadPortrait : \.dpadLandscape))
                                    .padding(.leading, 10)
                                    .padding(.bottom, 110)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // 2. Buttons A/B (Bottom Right)
                            VStack {
                                Spacer()
                                NESActionButtonsPad()
                                    .modifier(draggable(key: isPortrait ? \.buttonsPortrait : \.buttonsLandscape))
                                    .padding(.trailing, 20)
                                    .padding(.bottom, 120)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            // 3. Start / Select (Center Bottom)
                            VStack {
                                Spacer()
                                HStack(spacing: 40) {
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
                                                .frame(width: 55, height: 14)
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
                                            guard !NESControlManager.shared.isEditing else { return }
                                            NESInput.shared.setButton(NESInput.ID_SELECT, pressed: true)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }.onEnded { _ in 
                                            NESInput.shared.setButton(NESInput.ID_SELECT, pressed: false) 
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
                                                .frame(width: 55, height: 14)
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
                                            guard !NESControlManager.shared.isEditing else { return }
                                            NESInput.shared.setButton(NESInput.ID_START, pressed: true)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }.onEnded { _ in 
                                            NESInput.shared.setButton(NESInput.ID_START, pressed: false) 
                                        })
                                        
                                        Text("START").font(.system(size: 9, weight: .bold)).foregroundColor(Color(white: 0.3))
                                    }
                                    .modifier(draggable(key: isPortrait ? \.startPortrait : \.startLandscape))
                                }
                                .padding(.bottom, 35)
                            }
                        }
                        .opacity(mode.opacity)
                        .allowsHitTesting(mode != .hidden || controlManager.isEditing)
                        
                        // 4. Visibility Button
                        VStack(spacing: 8) {
                            Spacer()
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
                        }
                        .padding(.bottom, 15)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(controlManager.isEditing ? 0 : 1)
                        .allowsHitTesting(!controlManager.isEditing)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else {
                    // --- LANDSCAPE MODE ---
                    ZStack {
                        Group {
                            // 1. D-Pad & Action Buttons (Sides)
                            HStack {
                                // LEFT SIDE: D-Pad
                                VStack {
                                    Spacer().frame(height: 160)
                                    NESDPad()
                                        .modifier(draggable(key: isPortrait ? \.dpadPortrait : \.dpadLandscape))
                                        .padding(.bottom, 20)
                                    Spacer()
                                }
                                .frame(width: 180).padding(.leading, 60)
                                
                                Spacer()
                                
                                // RIGHT SIDE: A/B
                                VStack {
                                    Spacer().frame(height: 160)
                                    NESActionButtonsPad()
                                        .modifier(draggable(key: isPortrait ? \.buttonsPortrait : \.buttonsLandscape))
                                        .padding(.bottom, 20)
                                    Spacer()
                                }
                                .frame(width: 180).padding(.trailing, 60)
                            }
                            
                            // 2. Start / Select (Center Bottom - Unified)
                            VStack {
                                Spacer()
                                HStack(spacing: 40) {
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
                                                .frame(width: 55, height: 14)
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
                                            guard !NESControlManager.shared.isEditing else { return }
                                            NESInput.shared.setButton(NESInput.ID_SELECT, pressed: true)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }.onEnded { _ in 
                                            NESInput.shared.setButton(NESInput.ID_SELECT, pressed: false) 
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
                                                .frame(width: 55, height: 14)
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
                                            guard !NESControlManager.shared.isEditing else { return }
                                            NESInput.shared.setButton(NESInput.ID_START, pressed: true)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }.onEnded { _ in 
                                            NESInput.shared.setButton(NESInput.ID_START, pressed: false) 
                                        })
                                        
                                        Text("START").font(.system(size: 9, weight: .bold)).foregroundColor(Color(white: 0.3))
                                    }
                                    .modifier(draggable(key: isPortrait ? \.startPortrait : \.startLandscape))
                                }
                                .padding(.bottom, 20)
                            }
                        }
                        .opacity(mode.opacity)
                        .allowsHitTesting(mode != .hidden || controlManager.isEditing)
                        
                        // Visibility Button (Center Bottom)
                        VStack {
                            Spacer()
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
                            .padding(.bottom, 20)
                        }
                        .opacity(controlManager.isEditing ? 0 : 1)
                        .allowsHitTesting(!controlManager.isEditing)
                    }
                }
            }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct DraggableNES: ViewModifier {
    @ObservedObject var manager: NESControlManager
    let key: WritableKeyPath<NESControlPositions, CGPoint>
    
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
