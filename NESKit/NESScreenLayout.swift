import SwiftUI

public struct NESScreenLayout: View {
    @ObservedObject var core: NESCore
    @ObservedObject var skinManager = NESSkinManager.shared
    @ObservedObject var input = NESInput.shared
    @ObservedObject var controlManager = NESControlManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    // Animation States
    @State private var isLedOn = false
    @State private var isLogoOn = false
    @State private var isScreenOn = false
    
    // [NEW] Gesture State for Edit Mode
    @State private var gestureStartOffset: CGPoint?
    @State private var gestureStartScale: CGFloat?
    
    public init(core: NESCore) {
        self.core = core
    }
    
    // [NEW] Overlay Support
    var overlayContent: AnyView?
    
    public func screenOverlay<Content: View>(@ViewBuilder content: () -> Content) -> NESScreenLayout {
        var copy = self
        copy.overlayContent = AnyView(content())
        return copy
    }
    
    // Helper to load image
    private func getLogoImage() -> Image? {
        if let path = Bundle.main.path(forResource: "NES_Full_Logo", ofType: "png") {
            if let uiImage = UIImage(contentsOfFile: path) {
                return Image(uiImage: uiImage)
            }
        }
        return nil
    }
    
    // Helper to load icon
    private func getIconImage() -> Image? {
        if let path = Bundle.main.path(forResource: "NES_Icon", ofType: "png") {
            if let uiImage = UIImage(contentsOfFile: path) {
                return Image(uiImage: uiImage)
            }
        }
        return nil
    }
    
    // Dynamic Theme Background (Matches ResumePromptView)
    var themeBg: Color {
        colorScheme == .dark 
            ? Color(red: 28/255, green: 28/255, blue: 30/255) // Dark Grey Mesh
            : Color(red: 235/255, green: 235/255, blue: 240/255) // Light Grey Mesh
    }

    // Computed Glow Color (NES Red)
    private var glowColor: Color {
        return .red
    }
    
    // Console Name for Light Mode
    private var consoleDisplayName: String {
        return "NINTENDO"
    }
    
    // Reusable Power LED Component
    private var powerLED: some View {
        let activeColor: Color = (colorScheme == .dark) ? .red : .red // NES LED is Red
        let labelColor = (colorScheme == .dark) ? Color.gray.opacity(0.8) : Color.black.opacity(0.6)
        
        return VStack(spacing: 4) {
            Text("POWER")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(labelColor)
            
            Circle()
                .fill(isLedOn ? activeColor : Color.black.opacity(0.3))
                .frame(width: 8, height: 8)
                .shadow(color: activeColor.opacity(isLedOn ? 1.0 : 0.0), radius: isLedOn ? 5 : 0)
                .shadow(color: activeColor.opacity(isLedOn ? 0.8 : 0.0), radius: isLedOn ? 10 : 0)
                .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
        }
    }
    
    public var body: some View {
        GeometryReader { geo in
            // Robust Orientation Detection
            let isPortrait = geo.size.height >= geo.size.width
            
            // --- SKIN SUPPORT CHECK ---
            if let representation = skinManager.currentRepresentation(portrait: isPortrait),
               let bgImage = skinManager.resolveAssetImage(named: representation.backgroundImageName) {
                
                // Render Active Skin
                GeometryReader { _ in
                    let screenW = geo.size.width
                    let screenH = geo.size.height
                    
                    // Fallback to Image Size if Mapping Size is missing.
                    let baseMapSize = representation.mappingSize ?? NESSkinSize(width: bgImage.size.width, height: bgImage.size.height)
                    
                    // CORRECTED LOGIC: Check for Aspect Ratio Mismatch (Squashed PDF issue)
                    let isPDF = representation.backgroundImageName.lowercased().contains(".pdf")
                    
                    let effectiveMapSize: NESSkinSize = {
                        if isPDF {
                            let imageAR = bgImage.size.width / bgImage.size.height
                            let mapAR = baseMapSize.width / baseMapSize.height
                            if abs(imageAR - mapAR) > 0.1 {
                                return NESSkinSize(width: baseMapSize.width, height: baseMapSize.width / imageAR)
                            }
                        }
                        return baseMapSize
                    }()
                    
                    // Aspect Fit Logic based on EFFECTIVE size
                    let widthRatio = screenW / effectiveMapSize.width
                    let heightRatio = screenH / effectiveMapSize.height
                    
                    // Use GBA Logic: Only Aspect Fit PDFs if distortion is significant (>10%)
                    let useAspectFit = isPDF && abs(widthRatio - heightRatio) > 0.1
                    
                    let viewScaleX = useAspectFit ? min(widthRatio, heightRatio) : widthRatio
                    let viewScaleY = useAspectFit ? min(widthRatio, heightRatio) : heightRatio
                    
                    // Final Visual Frame
                    let finalWidth = effectiveMapSize.width * viewScaleX
                    let finalHeight = effectiveMapSize.height * viewScaleY
                    
                    // Input Scales (Mapping JSON coords -> Final Visual Frame)
                    let scaleX = finalWidth / baseMapSize.width
                    let scaleY = finalHeight / baseMapSize.height
                    
                    let offsetX = (screenW - finalWidth) / 2
                    
                    // Align Bottom for Portrait if aspect fitting
                    let offsetY = (useAspectFit && isPortrait) ?
                    (screenH - finalHeight) :
                    ((screenH - finalHeight) / 2)
                    
                    ZStack(alignment: .topLeading) {
                        // 1. Game Screen (Rendered BEHIND skin)
                        if let screens = representation.screens {
                            ForEach(0..<screens.count, id: \.self) { i in
                                let screenDef = screens[i]
                                let frame = screenDef.outputFrame
                                
                                // Filter out "Background" screens (negative coordinates or huge size)
                                if frame.x >= 0 && frame.y >= 0 {
                                    ZStack {
                                        NESRenderView(renderer: core.renderer)
                                        overlayContent // [NEW] Inject Overlay
                                    }
                                    .frame(width: frame.width * scaleX, height: frame.height * scaleY)
                                    .position(
                                        x: offsetX + (frame.x + frame.width/2) * scaleX,
                                        y: offsetY + (frame.y + frame.height/2) * scaleY
                                    )
                                }
                            }
                        } else {
                            // Fallback: No screens defined in JSON.
                            if isPortrait {
                                let gameAreaHeight = max(offsetY, 0)
                              
                                ZStack {
                                    NESRenderView(renderer: core.renderer)
                                    overlayContent
                                }
                                .aspectRatio(256.0/240.0, contentMode: .fit)
                                .frame(width: screenW, height: gameAreaHeight)
                                .position(x: screenW/2, y: gameAreaHeight/2)
                            } else {
                                ZStack {
                                    NESRenderView(renderer: core.renderer)
                                    overlayContent
                                }
                                .aspectRatio(256.0/240.0, contentMode: .fit)
                                .frame(width: screenW, height: screenH)
                                .position(x: screenW/2, y: screenH/2)
                            }
                        }
                        
                        // 2. Background Image (Rendered ON TOP of game)
                        Image(uiImage: bgImage)
                            .resizable()
                            .frame(width: finalWidth, height: finalHeight)
                            .position(x: offsetX + finalWidth / 2, y: offsetY + finalHeight / 2)
                        
                        // 3. Input Overlay (Invisible touch zones)
                        NESSkinInputOverlay(
                            representation: representation,
                            viewSize: CGSize(width: screenW, height: screenH),
                            showInputControls: true
                        )
                    }
                    .ignoresSafeArea()
                }
            } else {
                // --- FALLBACK: EXISTING LAYOUT ---
                ZStack {
                    // Unified Background with Grid
                    ZStack {
                        themeBg.ignoresSafeArea()
                        PromptGridBackground(isDark: colorScheme == .dark)
                            .ignoresSafeArea()
                    }
                    
                    if isPortrait {
                        // --- PORTRAIT MODE ---
                        VStack(spacing: 0) {
                            // Top Spacer: Increased to avoid Notch significantly
                            Spacer().frame(height: max(geo.safeAreaInsets.top, 50))
                            
                            // Top Section: Game
                            ZStack {
                                // Video Container
                                let scale = isPortrait ? controlManager.positions.screenScalePortrait : controlManager.positions.screenScaleLandscape
                                let offset = isPortrait ? controlManager.positions.screenPositionPortrait : controlManager.positions.screenPositionLandscape
                                
                                GlowingNESRenderView(renderer: core.renderer, isScreenOn: isScreenOn, overlay: overlayContent)
                                    .scaleEffect(scale)
                                    .offset(x: offset.x, y: offset.y)
                                    .overlay(
                                        Group {
                                            if controlManager.isEditing {
                                                // EDIT MODE OVERLAY (Gestures)
                                                ZStack {
                                                    // 1. Visual Border
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.yellow, lineWidth: 2)
                                                    
                                                    // 2. Interaction Layer (Pan & Zoom)
                                                    Color.white.opacity(0.001)
                                                        .gesture(
                                                            SimultaneousGesture(
                                                                DragGesture(coordinateSpace: .named("NESScreen"))
                                                                    .onChanged { value in
                                                                        let current = isPortrait ? controlManager.positions.screenPositionPortrait : controlManager.positions.screenPositionLandscape
                                                                        
                                                                        // Capture initial state if needed
                                                                        if gestureStartOffset == nil { gestureStartOffset = current }
                                                                        
                                                                        if let start = gestureStartOffset {
                                                                            let newPos = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
                                                                            controlManager.updateScreenPosition(isPortrait: isPortrait, position: newPos)
                                                                        }
                                                                    }
                                                                    .onEnded { _ in gestureStartOffset = nil },
                                                                
                                                                MagnificationGesture()
                                                                    .onChanged { value in
                                                                        let current = isPortrait ? controlManager.positions.screenScalePortrait : controlManager.positions.screenScaleLandscape
                                                                        
                                                                        // Capture initial state
                                                                        if gestureStartScale == nil { gestureStartScale = current }
                                                                        
                                                                        if let start = gestureStartScale {
                                                                            let newScale = max(0.5, min(3.0, start * value))
                                                                            controlManager.updateScreenScale(isPortrait: isPortrait, scale: newScale)
                                                                        }
                                                                    }
                                                                    .onEnded { _ in gestureStartScale = nil }
                                                            )
                                                        )
                                                }
                                                .scaleEffect(scale) // Visual feedback follows screen
                                                .offset(x: offset.x, y: offset.y)
                                            }
                                        }
                                    )
                            }
                            .frame(height: geo.size.height * 0.45)
                            .frame(maxWidth: .infinity)
                            
                            // Logo & LED Display
                            if let logo = getLogoImage() {
                                HStack(alignment: .bottom, spacing: 20) {
                                    if colorScheme == .light {
                                        // Light Mode: Name (Left) ... LED (Right)
                                        Text(consoleDisplayName)
                                            .font(.system(size: 18, weight: .black, design: .rounded))
                                            .italic()
                                            .foregroundColor(Color.black.opacity(0.6))
                                        
                                        Spacer()
                                        
                                        powerLED
                                            .padding(.bottom, 5)
                                        
                                    } else {
                                        // Dark Mode: Logo (Glow) (Left) ... LED (Right)
                                        logo
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 40)
                                            .shadow(color: glowColor.opacity(isLogoOn ? 0.8 : 0.0), radius: isLogoOn ? 15 : 0, x: 0, y: 0)
                                        
                                        Spacer() // Push apart
                                        
                                        powerLED
                                            .padding(.bottom, 5)
                                    }
                                }
                                .padding(.top, 10)
                                .padding(.leading, 15)
                                .padding(.trailing, 30)
                                .opacity(0.9)
                            }
                            
                            // Bottom Section: Controls Area
                            Spacer()
                        }
                        .ignoresSafeArea()
                        
                    } else {
                        // --- LANDSCAPE MODE ---
                        // Center the game view properly
                        ZStack {
                            let scale = isPortrait ? controlManager.positions.screenScalePortrait : controlManager.positions.screenScaleLandscape
                            let offset = isPortrait ? controlManager.positions.screenPositionPortrait : controlManager.positions.screenPositionLandscape

                            GlowingNESRenderView(renderer: core.renderer, isScreenOn: isScreenOn, overlay: overlayContent)
                                .scaleEffect(scale)
                                .offset(x: offset.x, y: offset.y)
                                .overlay(
                                    Group {
                                        if controlManager.isEditing {
                                            // EDIT MODE OVERLAY (Gestures)
                                            ZStack {
                                                // 1. Visual Border
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.yellow, lineWidth: 2)
                                                
                                                // 2. Interaction Layer (Pan & Zoom)
                                                Color.white.opacity(0.001)
                                                    .gesture(
                                                        SimultaneousGesture(
                                                            DragGesture(coordinateSpace: .named("NESScreen"))
                                                                .onChanged { value in
                                                                    let current = isPortrait ? controlManager.positions.screenPositionPortrait : controlManager.positions.screenPositionLandscape
                                                                    
                                                                    // Capture initial state if needed
                                                                    if gestureStartOffset == nil { gestureStartOffset = current }
                                                                    
                                                                    if let start = gestureStartOffset {
                                                                        let newPos = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
                                                                        controlManager.updateScreenPosition(isPortrait: isPortrait, position: newPos)
                                                                    }
                                                                }
                                                                .onEnded { _ in gestureStartOffset = nil },
                                                            
                                                            MagnificationGesture()
                                                                .onChanged { value in
                                                                    let current = isPortrait ? controlManager.positions.screenScalePortrait : controlManager.positions.screenScaleLandscape
                                                                    
                                                                    // Capture initial state
                                                                    if gestureStartScale == nil { gestureStartScale = current }
                                                                    
                                                                    if let start = gestureStartScale {
                                                                        let newScale = max(0.5, min(3.0, start * value))
                                                                        controlManager.updateScreenScale(isPortrait: isPortrait, scale: newScale)
                                                                    }
                                                                }
                                                                .onEnded { _ in gestureStartScale = nil }
                                                        )
                                                    )
                                            }
                                            .scaleEffect(scale) // Visual feedback follows screen
                                            .offset(x: offset.x, y: offset.y)
                                        }
                                    }
                                )
                                .padding(.vertical, 10)
                            
                            // Bottom Right: Power LED
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    powerLED
                                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 10))
                                        .padding(.trailing, max(geo.safeAreaInsets.trailing, 40))
                                }
                            }
                            
                            // Bottom Left: NES Icon with Red Glow
                            if let icon = getIconImage() {
                                VStack {
                                    Spacer()
                                    HStack {
                                        icon
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                            .shadow(color: glowColor.opacity(0.8), radius: 10, x: 0, y: 0)
                                            .opacity(isLogoOn ? 1.0 : 0.0)
                                            .padding(.bottom, max(geo.safeAreaInsets.bottom, 10))
                                            .padding(.leading, max(geo.safeAreaInsets.leading, 40))
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .ignoresSafeArea()
                    }
                }
            }
        }
        .coordinateSpace(name: "NESScreen")
        .onAppear {
            // Sequence: Cold Boot
            let baseDelay = 0.5
                    
                    // Flicker 1
                    withAnimation(.linear(duration: 0.1).delay(baseDelay)) { isLedOn = true }
                    withAnimation(.linear(duration: 0.1).delay(baseDelay + 0.2)) { isLedOn = false }
                    
                    // Flicker 2
                    withAnimation(.linear(duration: 0.1).delay(baseDelay + 0.4)) { isLedOn = true }
                    withAnimation(.linear(duration: 0.1).delay(baseDelay + 0.5)) { isLedOn = false }
                    
                    // Stable On
                    withAnimation(.easeOut(duration: 0.2).delay(baseDelay + 0.9)) { isLedOn = true }
                    
                    // Logo Glow (After LED is stable)
                    withAnimation(.easeIn(duration: 1.0).delay(baseDelay + 1.7)) {
                        isLogoOn = true
                    }
                    
                    // Screen On (Last, slow fade)
                    withAnimation(.easeIn(duration: 1.0).delay(baseDelay + 2.5)) {
                        isScreenOn = true
                    }
                }
    }
    
    // Wrapper for Ambilight Glow Effect
    struct GlowingNESRenderView: View {
        let renderer: NESRenderer
        var isScreenOn: Bool
        var overlay: AnyView? // [NEW]
        
        var body: some View {
            ZStack {
                // Glow Layer (Blurred & Scaled)
                NESRenderView(renderer: renderer)
                    .aspectRatio(8.0/7.0, contentMode: .fit) // NES Aspect Ratio (256:240 = 16:15 ≈ 8:7)
                    .cornerRadius(12)
                    .blur(radius: 15)
                    .opacity(isScreenOn ? 0.8 : 0.0)
                    .scaleEffect(1.15)
                
                // Main Content Layer (Sharp)
                ZStack {
                    NESRenderView(renderer: renderer)
                        .opacity(isScreenOn ? 1.0 : 0.0) // Screen starts black
                    
                    overlay // [NEW] BIOS Overlay always visible
                }
                .aspectRatio(8.0/7.0, contentMode: .fit)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 5)
                // .opacity(isScreenOn ? 1.0 : 0.0) <- Removed global opacity
            }
        }
    }
}

// Background Component (Local Copy)
private struct PromptGridBackground: View {
    var isDark: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let spacing: CGFloat = 30
                for x in stride(from: 0, through: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: height))
                }
                for y in stride(from: 0, through: height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(
                isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), 
                lineWidth: 1
            )
        }
    }
}

