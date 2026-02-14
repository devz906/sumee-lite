import SwiftUI

struct PicoDriveButton: View {
    let id: Int
    let label: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let color: Color
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Shadow
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(color.opacity(0.8))
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .opacity(isPressed ? 0.7 : 1.0)
            
            Text(label)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        PicoDriveInput.shared.setButton(id, pressed: true)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    PicoDriveInput.shared.setButton(id, pressed: false)
                }
        )
    }
}

struct PicoDriveCircularButton: View {
    let size: CGFloat
    let label: String
    let color: Color // Kept for compatibility, but we enforce Black for Genesis look
    var isPressed: Bool
    
    var body: some View {
        ZStack {
            // Shadow
            Circle()
                .fill(Color.black.opacity(isPressed ? 0.2 : 0.4))
                .offset(y: isPressed ? 1 : 3)
                .blur(radius: 2)
            
            // Main Body (Glossy Black Plastic)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.15),
                            Color.black
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
                                colors: [Color.white.opacity(0.35), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(2)
                        .blur(radius: 1)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
            
            // Text Label
            Text(label)
                .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                .offset(y: isPressed ? 0 : -1)
        }
        .frame(width: size, height: size)
        .frame(width: size * 1.3, height: size * 1.3) // Hit area
        .contentShape(Circle())
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    }
}

// Sega Genesis ABC Layout (3-Button)
struct PicoDriveActionButtonsPad: View {
    struct ButtonDef {
        let id: Int
        let label: String
        let color: Color
        let offset: CGPoint
    }
    
    // Layout: A (Left), B (Center), C (Right) in an arc or line
    let buttons: [ButtonDef] = [
        ButtonDef(id: PicoDriveInput.ID_B, label: "A", color: .gray, offset: CGPoint(x: -60, y: 20)),
        ButtonDef(id: PicoDriveInput.ID_A, label: "B", color: .gray, offset: CGPoint(x: 0, y: 0)),
        ButtonDef(id: PicoDriveInput.ID_Y, label: "C", color: .gray, offset: CGPoint(x: 60, y: -20))
    ]
    
    @State private var pressedButtons: Set<Int> = []
    
    var body: some View {
        ZStack {
            // Visual Layer
            ForEach(buttons, id: \.id) { btn in
                PicoDriveCircularButton(size: 55, label: btn.label, color: btn.color, isPressed: pressedButtons.contains(btn.id))
                    .offset(x: btn.offset.x, y: btn.offset.y)
            }
            
            // Touch Layer (UIKit MultiTouch)
            PicoDriveMultiTouchPad(buttons: buttons) { newPressed in
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
        .frame(width: 200, height: 100)
    }
}

// Helper: True Multi-Touch Handler using UIKit
struct PicoDriveMultiTouchPad: UIViewRepresentable {
    let buttons: [PicoDriveActionButtonsPad.ButtonDef]
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
        var buttons: [PicoDriveActionButtonsPad.ButtonDef] = []
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
            PicoDriveInput.shared.updateActionButtons(all)
            onUpdate?(all)
        }
    }
}

struct PicoDriveDPad: View {
    let size: CGFloat = 120
    
    @State private var pressedButtons: Set<Int> = []
    
    var body: some View {
        let isUp = pressedButtons.contains(PicoDriveInput.ID_UP)
        let isDown = pressedButtons.contains(PicoDriveInput.ID_DOWN)
        let isLeft = pressedButtons.contains(PicoDriveInput.ID_LEFT)
        let isRight = pressedButtons.contains(PicoDriveInput.ID_RIGHT)
        
        // Tilt Logic (Standard Cross Tilt)
        let tiltX: Double = isUp ? 8 : (isDown ? -8 : 0)
        let tiltY: Double = isLeft ? -8 : (isRight ? 8 : 0)
        
        return ZStack {
            // Shadow
            ZStack {
                RoundedRectangle(cornerRadius: 15).frame(width: size * 0.38, height: size)
                RoundedRectangle(cornerRadius: 15).frame(width: size, height: size * 0.38)
            }
            .foregroundColor(.black.opacity(0.4))
            .blur(radius: 4)
            .offset(y: 4)
            .scaleEffect(0.95)
            
            // Main Cross Body
            ZStack {
                // Vertical Arm
                RoundedRectangle(cornerRadius: 15)
                    .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.16)], startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.38, height: size)
                
                // Horizontal Arm
                RoundedRectangle(cornerRadius: 15)
                     .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.16)], startPoint: .top, endPoint: .bottom))
                    .frame(width: size, height: size * 0.38)
                
                // Center Dimple (Concave)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.1), Color(white: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.03), lineWidth: 1)
                    )
                    .shadow(color: .white.opacity(0.05), radius: 1, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 1, y: 1)
            }
            // Directional Arrows (Moved to Cross Arms)
            .overlay(
                Group {
                     // Up
                     Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.1))
                        .offset(y: -size * 0.35)
                        .shadow(color: .white.opacity(0.1), radius: 0, x: 0, y: 1)
                    
                    // Down
                     Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.1))
                        .offset(y: size * 0.35)
                         .shadow(color: .white.opacity(0.1), radius: 0, x: 0, y: 1)
                    
                    // Left
                     Image(systemName: "arrowtriangle.left.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.1))
                        .offset(x: -size * 0.35)
                         .shadow(color: .white.opacity(0.1), radius: 0, x: 0, y: 1)
                    
                    // Right
                     Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.1))
                        .offset(x: size * 0.35)
                         .shadow(color: .white.opacity(0.1), radius: 0, x: 0, y: 1)
                }
            )
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
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.5), value: pressedButtons)

            // Touch Handling
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
        
        // 8-Way Direction Logic
        if angle >= 337.5 || angle < 22.5 {
            newPressed.insert(PicoDriveInput.ID_RIGHT)
        } else if angle >= 22.5 && angle < 67.5 {
            newPressed.insert(PicoDriveInput.ID_RIGHT)
            newPressed.insert(PicoDriveInput.ID_DOWN)
        } else if angle >= 67.5 && angle < 112.5 {
            newPressed.insert(PicoDriveInput.ID_DOWN)
        } else if angle >= 112.5 && angle < 157.5 {
            newPressed.insert(PicoDriveInput.ID_DOWN)
            newPressed.insert(PicoDriveInput.ID_LEFT)
        } else if angle >= 157.5 && angle < 202.5 {
            newPressed.insert(PicoDriveInput.ID_LEFT)
        } else if angle >= 202.5 && angle < 247.5 {
            newPressed.insert(PicoDriveInput.ID_LEFT)
            newPressed.insert(PicoDriveInput.ID_UP)
        } else if angle >= 247.5 && angle < 292.5 {
            newPressed.insert(PicoDriveInput.ID_UP)
        } else if angle >= 292.5 && angle < 337.5 {
            newPressed.insert(PicoDriveInput.ID_UP)
            newPressed.insert(PicoDriveInput.ID_RIGHT)
        }
        
        updateInputs(newPressed)
    }
    
    private func updateInputs(_ newPressed: Set<Int>) {
        if newPressed != pressedButtons {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            for id in pressedButtons.subtracting(newPressed) {
                PicoDriveInput.shared.setButton(id, pressed: false)
            }
            
            for id in newPressed.subtracting(pressedButtons) {
                PicoDriveInput.shared.setButton(id, pressed: true)
            }
            
            pressedButtons = newPressed
        }
    }
    
    private func releaseAll() {
        for id in pressedButtons {
            PicoDriveInput.shared.setButton(id, pressed: false)
        }
        pressedButtons.removeAll()
    }
}

    public struct PicoDriveVirtualController: View {
    @ObservedObject var controlManager = PicoDriveControlManager.shared
    @State private var mode: VisibilityMode = .visible
    var isTransparent: Bool = false
    var showInputControls: Bool = true
    
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
    
    private func draggable(key: WritableKeyPath<PicoDriveControlPositions, CGPoint>) -> some ViewModifier {
        DraggablePicoDrive(manager: controlManager, key: key)
    }
    
    public init(isTransparent: Bool = false, showInputControls: Bool = true) {
        self.isTransparent = isTransparent
        self.showInputControls = showInputControls
    }
    
    @ObservedObject var skinManager = MDSkinManager.shared
    @ObservedObject var input = PicoDriveInput.shared
    
    public var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height >= geo.size.width
            
            if let representation = skinManager.currentRepresentation(portrait: isPortrait) {
                MDSkinInputOverlay(representation: representation, viewSize: geo.size, showInputControls: showInputControls)
            } else if !input.isControllerConnected {
                ZStack {
                // Force Full Screen always (prevents layout jumps)
                Color.clear.frame(width: geo.size.width, height: geo.size.height)
                
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
                
                if UIScreen.main.bounds.height > UIScreen.main.bounds.width || geo.size.height > geo.size.width {
                    // PORTRAIT
                    ZStack {
                        if showInputControls {
                            // D-Pad
                            VStack { 
                                Spacer(); 
                                PicoDriveDPad()
                                    .modifier(draggable(key: isPortrait ? \.dpadPortrait : \.dpadLandscape))
                                    .padding(.leading, 10)
                                    .padding(.bottom, 110) 
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Buttons
                            VStack { 
                                Spacer(); 
                                PicoDriveActionButtonsPad()
                                    .modifier(draggable(key: isPortrait ? \.buttonsPortrait : \.buttonsLandscape))
                                    .padding(.trailing, 20)
                                    .padding(.bottom, 120) 
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            // Start/Mode
                            VStack {
                                Spacer()
                                HStack(spacing: 40) {
                                    // MODE
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
                                                    Capsule().stroke(Color.black.opacity(0.3), lineWidth: 1)
                                                )
                                                .overlay(
                                                    Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1).padding(1)
                                                )
                                                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                                        }
                                        .gesture(DragGesture(minimumDistance: 0)
                                            .onChanged { _ in 
                                                // Simple check to prevent haptic spam during drag
                                                guard !PicoDriveControlManager.shared.isEditing else { return }
                                                let id = PicoDriveInput.ID_SELECT
                                                if (PicoDriveInput.shared.buttonMask & (UInt16(1) << id)) == 0 {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    PicoDriveInput.shared.setButton(id, pressed: true)
                                                }
                                            }
                                            .onEnded { _ in PicoDriveInput.shared.setButton(PicoDriveInput.ID_SELECT, pressed: false) }
                                        )
                                        
                                        Text("MODE").font(.system(size: 8, weight: .bold)).foregroundColor(Color(white: 0.3))
                                    }
                                    .modifier(draggable(key: isPortrait ? \.modePortrait : \.modeLandscape))
                                    
                                    // START
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
                                                    Capsule().stroke(Color.black.opacity(0.3), lineWidth: 1)
                                                )
                                                .overlay(
                                                    Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1).padding(1)
                                                )
                                                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                                        }
                                        .gesture(DragGesture(minimumDistance: 0)
                                            .onChanged { _ in 
                                                guard !PicoDriveControlManager.shared.isEditing else { return }
                                                let id = PicoDriveInput.ID_START
                                                if (PicoDriveInput.shared.buttonMask & (UInt16(1) << id)) == 0 {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    PicoDriveInput.shared.setButton(id, pressed: true)
                                                }
                                            }
                                            .onEnded { _ in PicoDriveInput.shared.setButton(PicoDriveInput.ID_START, pressed: false) }
                                        )
                                        
                                        Text("START").font(.system(size: 8, weight: .bold)).foregroundColor(Color(white: 0.3))
                                    }
                                    .modifier(draggable(key: isPortrait ? \.startPortrait : \.startLandscape))
                                }
                                .padding(.bottom, 25)
                            }
                        }
                    }
                    .opacity(mode.opacity)
                    .allowsHitTesting(mode != .hidden || controlManager.isEditing)
                } else {
                    // LANDSCAPE
                    ZStack {
                        if showInputControls {
                            HStack {
                               // Left Side: DPad
                               VStack { 
                                   Spacer()
                                   PicoDriveDPad().modifier(draggable(key: isPortrait ? \.dpadPortrait : \.dpadLandscape))
                                   Spacer().frame(height: 50)
                               }
                               .frame(width: 180).padding(.leading, 60)
                               
                               Spacer()
                               
                               // Right Side: Buttons
                               VStack { 
                                   Spacer()
                                   PicoDriveActionButtonsPad().modifier(draggable(key: isPortrait ? \.buttonsPortrait : \.buttonsLandscape))
                                   Spacer().frame(height: 50)
                               }
                               .frame(width: 180).padding(.trailing, 60)
                            }
                            
                            // Center Bottom controls (Start/Mode) - Overlay to keep centered
                            VStack {
                                Spacer()
                                HStack(spacing: 40) {
                                    VStack(spacing: 4) {
                                        Capsule().fill(Color(white: 0.2)).frame(width: 55, height: 14)
                                        Text("MODE").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.5))
                                    }
                                    .gesture(DragGesture(minimumDistance: 0)
                                        .onChanged { _ in 
                                            guard !PicoDriveControlManager.shared.isEditing else { return }
                                            let id = PicoDriveInput.ID_SELECT
                                            if (PicoDriveInput.shared.buttonMask & (UInt16(1) << id)) == 0 {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                PicoDriveInput.shared.setButton(id, pressed: true)
                                            }
                                        }
                                        .onEnded { _ in PicoDriveInput.shared.setButton(PicoDriveInput.ID_SELECT, pressed: false) }
                                    )
                                    .modifier(draggable(key: isPortrait ? \.modePortrait : \.modeLandscape))
                                    
                                    VStack(spacing: 4) {
                                        Capsule().fill(Color(white: 0.2)).frame(width: 55, height: 14)
                                        Text("START").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.5))
                                    }
                                    .gesture(DragGesture(minimumDistance: 0)
                                        .onChanged { _ in 
                                            guard !PicoDriveControlManager.shared.isEditing else { return }
                                            let id = PicoDriveInput.ID_START
                                            if (PicoDriveInput.shared.buttonMask & (UInt16(1) << id)) == 0 {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                PicoDriveInput.shared.setButton(id, pressed: true)
                                            }
                                        }
                                        .onEnded { _ in PicoDriveInput.shared.setButton(PicoDriveInput.ID_START, pressed: false) }
                                    )
                                    .modifier(draggable(key: isPortrait ? \.startPortrait : \.startLandscape))
                                }
                                .padding(.bottom, 20)
                            }
                        }
                    }
                    .opacity(mode.opacity)
                    .allowsHitTesting(mode != .hidden || controlManager.isEditing)
                }
                
                // Botones de Menu (Overlay)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if showInputControls {
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
                                    .padding(8)
                                    .background(Circle().fill(Color.black.opacity(0.3)))
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    .padding(.trailing, 20)
                }
                .opacity(controlManager.isEditing ? 0 : 1)
                .allowsHitTesting(!controlManager.isEditing)
            }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct DraggablePicoDrive: ViewModifier {
    @ObservedObject var manager: PicoDriveControlManager
    let key: WritableKeyPath<PicoDriveControlPositions, CGPoint>
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
                    .onChanged { value in dragOffset = CGPoint(x: value.translation.width, y: value.translation.height) }
                    .onEnded { value in
                        let newPos = CGPoint(x: currentPos.x + value.translation.width, y: currentPos.y + value.translation.height)
                        manager.updatePosition(key, value: newPos)
                        dragOffset = .zero
                    }
                : nil
            )
    }
}
