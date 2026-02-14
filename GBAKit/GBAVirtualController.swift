import SwiftUI



struct GBAButton: View {
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
                        colors: [Color(white: 0.7), Color(white: 0.5)],
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
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .padding(2)

            // Inner Body (Depress effect)
            if isPressed {
                RoundedRectangle(cornerRadius: cornerRadius - 2)
                    .fill(Color(white: 0.45))
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
                            colors: [Color(white: 0.6), Color(white: 0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(4)
            }

            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isPressed ? .white.opacity(0.5) : .white.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .frame(width: width, height: height)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .rotation3DEffect(
            .degrees(isPressed ? 15 : 0),
            axis: (x: 1.0, y: 0.0, z: 0.0), // Tilt top away (Sinking feels natural for top triggers)
            perspective: 0.5
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        GBAInput.shared.setButton(id, pressed: true)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    GBAInput.shared.setButton(id, pressed: false)
                }
        )
    }
}

struct GBADPad: View {
    let size: CGFloat = 140
    let thickness: CGFloat = 48
    
    @State private var pressedButtons: Set<Int> = []
    
    var body: some View {
        let isUp = pressedButtons.contains(GBAInput.ID_UP)
        let isDown = pressedButtons.contains(GBAInput.ID_DOWN)
        let isLeft = pressedButtons.contains(GBAInput.ID_LEFT)
        let isRight = pressedButtons.contains(GBAInput.ID_RIGHT)
        
        // Calculate Tilt (Inverted for correct physics)
        let tiltX: Double = isUp ? 10 : (isDown ? -10 : 0)
        let tiltY: Double = isLeft ? -10 : (isRight ? 10 : 0)
        
        return ZStack {
            // Shadow (Static base)
            Image(systemName: "dpad.fill")
                .resizable()
                .frame(width: size, height: size)
                .foregroundColor(.black.opacity(0.4))
                .blur(radius: 4)
                .offset(y: 5)
                .scaleEffect(0.95)
            
            // Unified Cross Body
            ZStack {
                // The Shape Structure (Two crossed rectangles)
                Group {
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: thickness, height: size)
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: size, height: thickness)
                }
                .foregroundColor(.clear) // Make base clear, we use it for layout
                .background(
                    // Unified Gradient Layer
                    LinearGradient(
                        colors: [Color(white: 0.25), Color(white: 0.15)], // Dark Grey Plastic
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .mask(
                        // Mask using the same cross shape
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .frame(width: thickness, height: size)
                            RoundedRectangle(cornerRadius: 6)
                                .frame(width: size, height: thickness)
                        }
                    )
                )
        
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
                
                // Subtle Directional Arrows (Triangles) - Embimbed in the surface
                Group {
                    Image(systemName: "play.fill")
                        .rotationEffect(.degrees(-90))
                        .offset(y: -size/3 + 5)
                        .foregroundColor(isUp ? .white.opacity(0.5) : .black.opacity(0.3)) // Light up active
                    
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
                .shadow(color: .white.opacity(0.1), radius: 0, x: 0, y: 1) // Engraved edge highlight
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
            // Initial animation for smooth return to center
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.6), value: pressedButtons)

            // Touch Handling Layer (Static, stays on top to catch touches consistently)
            Color.white.opacity(0.001)
                .frame(width: size * 1.5, height: size * 1.5)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateDirection(value.location, center: CGPoint(x: size * 0.75, y: size * 0.75))
                        }
                        .onEnded { _ in
                            releaseAll()
                        }
                )
        }
        .frame(width: size, height: size)
    }
    
    private func updateDirection(_ location: CGPoint, center: CGPoint) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        
        // Deadzone check (center of d-pad)
        if hypot(dx, dy) < 15 {
            releaseAll()
            return
        }
        
        // Calculate angle
        // atan2 returns -pi to pi. -pi/2 is UP, 0 is RIGHT, pi/2 is DOWN, pi/-pi is LEFT
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 } // Normalize to 0-360
        
        // 8-way logic (45 degree sectors)
        var newPressed: Set<Int> = []
        
        if angle >= 337.5 || angle < 22.5 {
            newPressed.insert(GBAInput.ID_RIGHT)
        } else if angle >= 22.5 && angle < 67.5 {
            newPressed.insert(GBAInput.ID_RIGHT)
            newPressed.insert(GBAInput.ID_DOWN)
        } else if angle >= 67.5 && angle < 112.5 {
            newPressed.insert(GBAInput.ID_DOWN)
        } else if angle >= 112.5 && angle < 157.5 {
            newPressed.insert(GBAInput.ID_DOWN)
            newPressed.insert(GBAInput.ID_LEFT)
        } else if angle >= 157.5 && angle < 202.5 {
            newPressed.insert(GBAInput.ID_LEFT)
        } else if angle >= 202.5 && angle < 247.5 {
            newPressed.insert(GBAInput.ID_LEFT)
            newPressed.insert(GBAInput.ID_UP)
        } else if angle >= 247.5 && angle < 292.5 {
            newPressed.insert(GBAInput.ID_UP)
        } else if angle >= 292.5 && angle < 337.5 {
            newPressed.insert(GBAInput.ID_UP)
            newPressed.insert(GBAInput.ID_RIGHT)
        }
        
        updateInputs(newPressed)
    }
    
    private func updateInputs(_ newPressed: Set<Int>) {
        if newPressed != pressedButtons {
            // Haptic feedback on change
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            // Release buttons no longer pressed
            for id in pressedButtons.subtracting(newPressed) {
                GBAInput.shared.setButton(id, pressed: false)
            }
            
            // Press new buttons
            for id in newPressed.subtracting(pressedButtons) {
                GBAInput.shared.setButton(id, pressed: true)
            }
            
            pressedButtons = newPressed
        }
    }
    
    private func releaseAll() {
        for id in pressedButtons {
            GBAInput.shared.setButton(id, pressed: false)
        }
        pressedButtons.removeAll()
    }
}

struct GBACircularButton: View {
    let size: CGFloat
    var label: String = ""
    var isPressed: Bool
    
    // A/B Colors

    var buttonColor: Color = Color(red: 0.35, green: 0.35, blue: 0.4) 
    
    var body: some View {
        ZStack {
            // Shadow
            Circle()
                .fill(Color.black.opacity(isPressed ? 0.2 : 0.4))
                .offset(y: isPressed ? 1 : 3)
                .blur(radius: 2)
            
            // Main Body (Glossy Plastic)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            buttonColor.opacity(0.9),
                            buttonColor.opacity(1.0)
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
            
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: size * 0.45, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    .offset(y: isPressed ? 0 : -1)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    }
}

struct GBAActionButtonsPad: View {
    struct ButtonDef {
        let id: Int
        let label: String
        let offset: CGPoint
    }
    
    let buttons: [ButtonDef] = [
        ButtonDef(id: GBAInput.ID_B, label: "B", offset: CGPoint(x: -30, y: 15)),
        ButtonDef(id: GBAInput.ID_A, label: "A", offset: CGPoint(x: 30, y: -20))
    ]
    
    @State private var pressedButtons: Set<Int> = []
    
    var body: some View {
        ZStack {
            // Visual Layer
            ForEach(buttons, id: \.id) { btn in
                GBACircularButton(size: 60, label: btn.label, isPressed: pressedButtons.contains(btn.id))
                    .offset(x: btn.offset.x, y: btn.offset.y)
            }
            
            // Touch Layer (UIKit MultiTouch)
            GBAMultiTouchPad(buttons: buttons) { newPressed in
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
        .frame(width: 130, height: 130)
    }
}

// Helper: True Multi-Touch Handler using UIKit
struct GBAMultiTouchPad: UIViewRepresentable {
    let buttons: [GBAActionButtonsPad.ButtonDef]
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
        var buttons: [GBAActionButtonsPad.ButtonDef] = []
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
                        if hypot(loc.x - btnCenter.x, loc.y - btnCenter.y) < 45 { // 45 radius
                            foundBtn = btn.id
                            break
                        }
                    }
                    if let id = foundBtn { activeTouches[touch] = id }
                    else { activeTouches.removeValue(forKey: touch) }
                }
            }
            let all = Set(activeTouches.values)
            GBAInput.shared.updateActionButtons(all)
            onUpdate?(all)
        }
    }
}

struct GBAVirtualController: View {
    @ObservedObject var controlManager = GBAControlManager.shared
    @ObservedObject var skinManager = GBASkinManager.shared
    @ObservedObject var input = GBAInput.shared
    
    @State private var mode: VisibilityMode = .visible
    var isTransparent: Bool = false
    var showInputControls: Bool = true
    
    // Estados de visibilidad
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
    
    // Helper para hacer controles arrastrables
    private func draggable(key: WritableKeyPath<GBAControlPositions, CGPoint>) -> some ViewModifier {
        DraggableGBA(manager: controlManager, key: key)
    }
    
    public init(isTransparent: Bool = false, showInputControls: Bool = true) {
        self.isTransparent = isTransparent
        self.showInputControls = showInputControls
    }
    
    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height >= geo.size.width
            
            // Check for Skin (which handles enabled check internally)
            if let representation = skinManager.currentRepresentation(portrait: isPortrait) {
                // --- SKIN MODE ---
                GBASkinInputOverlay(representation: representation, viewSize: geo.size, showInputControls: showInputControls)
            } else if !input.isControllerConnected {
                // --- STANDARD MODE (Only if no physical controller) ---
                ZStack {
                    // Main Container
                    if !isTransparent && mode == .visible {
                         Color(white: 0.7).edgesIgnoringSafeArea(.all)
                    }
                
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
                
                // Top curve filler (optional)
                VStack { Spacer(); Color.clear }
                
                // The Controller Shape container
                VStack {
                    Spacer()
                    ZStack {
                        // The Body Shape - Solo visible si no es transparente total
                        if !isTransparent {
                            RoundedRectangle(cornerRadius: 30)
                                .fill(Color(white: 0.7))
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
                                .edgesIgnoringSafeArea(.bottom)
                                .opacity(mode.opacity)
                        }
                        
      
                        if showInputControls {
                        Group {
                            // Shoulders Row (L / R)
                            VStack {
                                HStack {
                                    GBAButton(id: GBAInput.ID_L, label: "L", width: 100, height: 45, cornerRadius: 15)
                                        .modifier(draggable(key: isPortrait ? \.lPortrait : \.lLandscape))
                                        .padding(.leading, 15)
                                    
                                    Spacer()
                                    
                                    GBAButton(id: GBAInput.ID_R, label: "R", width: 100, height: 45, cornerRadius: 15)
                                        .modifier(draggable(key: isPortrait ? \.rPortrait : \.rLandscape))
                                        .padding(.trailing, 15)
                                }
                                .padding(.top, geo.size.height > geo.size.width ? 0 : 20)
                                .offset(y: geo.size.height > geo.size.width ? -15 : 0)
                                .padding(.bottom, 5)
                                Spacer()
                            }
           
                            
                            // 2. D-Pad (Left)
                            VStack {
                                Spacer()
                                HStack {
                                    GBADPad()
                                        .modifier(draggable(key: isPortrait ? \.dpadPortrait : \.dpadLandscape))
                                        .padding(.leading, 15)
                                        .padding(.bottom, 40)
                                    Spacer()
                                }
                            }
                            
                            // 3. Start/Select (Center)
                            VStack {
                                Spacer()
                                HStack(spacing: geo.size.width > geo.size.height ? 2 : 8) {
                                    // Start/Select Styling
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
                                                .frame(width: 45, height: 14) // Slightly taller
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                                )
                                                // Bevel
                                                .overlay(
                                                    Capsule()
                                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                                        .padding(1)
                                                )
                                                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                                        }
                                        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in 
                                            guard !GBAControlManager.shared.isEditing else { return }
                                            GBAInput.shared.setButton(GBAInput.ID_SELECT, pressed: true)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred() 
                                        }.onEnded { _ in 
                                            GBAInput.shared.setButton(GBAInput.ID_SELECT, pressed: false) 
                                        })
                                        
                                        Text("SELECT")
                                            .font(.system(size: 9, weight: .bold)) // Bolder
                                            .foregroundColor(Color(white: 0.3)) // Matches GBA case text
                                    }
                                    .modifier(draggable(key: isPortrait ? \.selectPortrait : \.selectLandscape))
                                    
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
                                            guard !GBAControlManager.shared.isEditing else { return }
                                            GBAInput.shared.setButton(GBAInput.ID_START, pressed: true)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred() 
                                        }.onEnded { _ in 
                                            GBAInput.shared.setButton(GBAInput.ID_START, pressed: false) 
                                        })
                                        
                                        Text("START")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(Color(white: 0.3))
                                    }
                                    .modifier(draggable(key: isPortrait ? \.startPortrait : \.startLandscape))
                                }
                                .padding(.bottom, geo.size.height > geo.size.width ? 5 : 50)
                                .offset(y: 5)
                            }
                            
                            // 4. A/B Buttons (Right)
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    GBAActionButtonsPad()
                                    .modifier(draggable(key: isPortrait ? \.abButtonsPortrait : \.abButtonsLandscape))
                                    .padding(.trailing, 15)
                                    .padding(.bottom, 40)
                                }
                            }
                        }
                        .padding(.bottom, geo.size.height > geo.size.width ? 60 : 0) // Raise controls in Portrait Mode
                        .opacity(mode.opacity)
                        .allowsHitTesting(mode != .hidden || controlManager.isEditing)
                        } 
                    }
                    .frame(height: 300) // Base container height
                    

                     
                }
                
                // Botones de Menu (Overlay Layout)
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
                                    controlManager.positions.showBezel.toggle()
                                    controlManager.saveConfig() // Save change automatically
                                }) {
                                    Label(controlManager.positions.showBezel ? "Hide Screen Bezel" : "Show Screen Bezel", systemImage: controlManager.positions.showBezel ? "rectangle.dashed" : "rectangle.fill")
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
            } // Close else if
        }
    }
}


struct DraggableGBA: ViewModifier {
    @ObservedObject var manager: GBAControlManager
    let key: WritableKeyPath<GBAControlPositions, CGPoint>
    
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


