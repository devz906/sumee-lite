import SwiftUI

public struct GBAScreenLayout: View {
    @ObservedObject var core: GBACore
    @ObservedObject var skinManager = GBASkinManager.shared
    @ObservedObject var input = GBAInput.shared
    @ObservedObject var controlManager = GBAControlManager.shared
    
    let aspectRatio: CGFloat
    let logoName: String
    var overlayContent: AnyView?
    @Environment(\.colorScheme) var colorScheme

    @State private var isLedOn = false
    @State private var isLogoOn = false
    @State private var isScreenOn = false
    
    //  Gesture State for Edit Mode
    @State private var gestureStartOffset: CGPoint?
    @State private var gestureStartScale: CGFloat?
    
    public init(core: GBACore, aspectRatio: CGFloat = 1.5, logoName: String = "GBA") {
        self.core = core
        self.aspectRatio = aspectRatio
        self.logoName = logoName
    }
    
    // [Modifier to set overlay
    public func screenOverlay<Content: View>(@ViewBuilder content: () -> Content) -> GBAScreenLayout {
        var copy = self
        copy.overlayContent = AnyView(content())
        return copy
    }
    
    // Helper to load image from specific paths
    private func getLogoImage() -> Image? {
        // Construct unique filename: <System>_Full_Logo
        // e.g., "GBA_Full_Logo", "GB_Full_Logo"
        let filename = "\(logoName)_Full_Logo"
        
        // Try loading from main bundle (files are likely flattened at root by Xcode)
        if let path = Bundle.main.path(forResource: filename, ofType: "png") {
             if let uiImage = UIImage(contentsOfFile: path) {
                 return Image(uiImage: uiImage)
             }
        }
        return nil
    }

    // Dynamic Theme Background (Matches ResumePromptView)
    var themeBg: Color {
        colorScheme == .dark 
            ? Color(red: 28/255, green: 28/255, blue: 30/255)
            : Color(red: 235/255, green: 235/255, blue: 240/255)
    }

    // Computed Glow Color based on Console
    private var glowColor: Color {
        switch logoName {
        case "GBA": return .purple
        case "GB": return .green
        case "GBC": return .yellow
        default: return .white
        }
    }
    
    // Reusable Power LED Component
    private var powerLED: some View {
        let activeColor = (colorScheme == .dark) ? glowColor : .red
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

    // Console Name for Light Mode
    private var consoleDisplayName: String {
        switch logoName {
        case "GBA": return "GAME BOY ADVANCE"
        case "GB": return "GAME BOY"
        case "GBC": return "GAME BOY COLOR"
        default: return "GAME BOY"
        }
    }

    public var body: some View {
        GeometryReader { geo in
        
            // Robust Orientation Detection
            let isPortrait = geo.size.height >= geo.size.width
            let _ = print("📐 [GBAScreenLayout] Size: \(geo.size), isPortrait: \(isPortrait)")
            
            ZStack { // Wrapper to hold coordinate space
                // --- SKIN SUPPORT CHECK ---
            if let representation = skinManager.currentRepresentation(portrait: isPortrait),
               let bgImage = skinManager.resolveAssetImage(named: representation.backgroundImageName) {
                
                // Render Active Skin
                GeometryReader { _ in
                    let screenW = geo.size.width
                    let screenH = geo.size.height
                    let mapSize = representation.mappingSize ?? GBASkinSize(width: screenW, height: screenH)
                    
                    // Aspect Fit Logic
                    // Calculate scale to fit the mapping size into the screen size preserving aspect ratio
                    let widthRatio = screenW / mapSize.width
                    let heightRatio = screenH / mapSize.height
                    
                    // Check if skin is PDF based on name
                    let isPDF = representation.backgroundImageName.lowercased().contains(".pdf")
                    
                    // Only apply Aspect Fit for PDFs (which carry vector data and might have weird ratios like 4:3)
                    // Standard Image skins usually prefer "Stretch to Fill" even if mismatch is moderate.
                    // Tolerance: 0.1 (10%) for PDFs to avoid extreme distortion. Images always stretch.
                    let useAspectFit = isPDF && abs(widthRatio - heightRatio) > 0.1
                    
                    let scaleX = useAspectFit ? min(widthRatio, heightRatio) : widthRatio
                    let scaleY = useAspectFit ? min(widthRatio, heightRatio) : heightRatio
                    
                    // Calculate offsets to center (Landscape) or align bottom (Portrait)
                    let offsetX = (screenW - mapSize.width * scaleX) / 2
                    
                
                    let isPortrait = screenH > screenW
                    let offsetY = (useAspectFit && isPortrait) ? 
                        (screenH - (mapSize.height * scaleY)) : 
                        ((screenH - mapSize.height * scaleY) / 2)
                    
                    ZStack(alignment: .topLeading) {
                        // 1. Game Screen (Now rendered BEHIND skin)
                        if let screens = representation.screens {
                            ForEach(0..<screens.count, id: \.self) { i in
                                let screenDef = screens[i]
                                let frame = screenDef.outputFrame
                                
                                // Positioned Render View relative to the FITTED rect
                                ZStack {
                                    GBARenderView(renderer: core.renderer)
                                    overlayContent // [NEW] Inject Overlay
                                }
                                .frame(width: frame.width * scaleX, height: frame.height * scaleY)
                                .position(
                                    x: offsetX + (frame.x + frame.width/2) * scaleX,
                                    y: offsetY + (frame.y + frame.height/2) * scaleY
                                )

                            }
                        } else {
                            // Fallback: No screens defined in JSON.
                            // If Portrait & Aspect Fit: Skin is at Bottom. Place Game in the Top Gap.
                            if isPortrait {
                                let gameAreaHeight = max(offsetY, 0)
                               
                                ZStack {
                                    GBARenderView(renderer: core.renderer)
                                    overlayContent
                                }
                                .aspectRatio(aspectRatio, contentMode: .fit)
                                .frame(width: screenW, height: gameAreaHeight)
                                .position(x: screenW/2, y: gameAreaHeight/2)
                            } else {
                                // Landscape: Center on screen (Best guess)
                                // Landscape: Center on screen (Best guess)
                                ZStack {
                                    GBARenderView(renderer: core.renderer)
                                    overlayContent
                                }
                                .aspectRatio(aspectRatio, contentMode: .fit)
                                .frame(width: screenW, height: screenH)
                                .position(x: screenW/2, y: screenH/2)
                            }
                        }
                        
                        // 2. Background Image (Now rendered ON TOP of game)
                        // Render at offset with scaled size
                        Image(uiImage: bgImage)
                            .resizable()
                            .frame(width: mapSize.width * scaleX, height: mapSize.height * scaleY)
                            .position(x: offsetX + (mapSize.width * scaleX) / 2, y: offsetY + (mapSize.height * scaleY) / 2)
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
                            
                            // Define Scale & Offset BEFORE the ZStack so they are available
                            let scale = isPortrait ? controlManager.positions.screenScalePortrait : controlManager.positions.screenScaleLandscape
                            let offset = isPortrait ? controlManager.positions.screenPositionPortrait : controlManager.positions.screenPositionLandscape

                            // Top Section: Game
                            ZStack {
                                    VStack(alignment: .center, spacing: 0) {
                                        if controlManager.positions.showBezel {
                                            // 1. BEZEL MODE: Unified Screen + Text + LED
                                            VStack(spacing: 0) {
                                                // Disable GLOW when Bezel is ON (Optimization)
                                                GlowingGBARenderView(renderer: core.renderer, aspectRatio: aspectRatio, isScreenOn: isScreenOn, overlay: overlayContent, showGlow: false)
                                                
                                                // Bezel Text & LED (Always visible in Bezel Mode)
                                                HStack(alignment: .center) {
                                                     Text(consoleDisplayName)
                                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                                        .italic()
                                                        .foregroundColor(Color.white.opacity(0.5))
                                                     Spacer()
                                                     powerLED
                                                        .padding(.bottom, 12)
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.black.opacity(0.85))
                                            }
                                            // Apply Styling ONLY when Bezel is ON
                                            .background(Color.black.opacity(0.85))
                                            .cornerRadius(12)
                                            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                                        } else {
                                            // 2. NO BEZEL MODE: Just the Screen
                                            // Enable GLOW for aesthetics when bezel is OFF
                                            GlowingGBARenderView(renderer: core.renderer, aspectRatio: aspectRatio, isScreenOn: isScreenOn, overlay: overlayContent, showGlow: true)
                                        }
                                    }
                                    .frame(minHeight: 0, maxHeight: .infinity)
                            }
                            .scaleEffect(scale)
                            .offset(x: offset.x, y: offset.y)
                            .frame(height: geo.size.height * 0.45)
                            .frame(maxWidth: .infinity)
                            .zIndex(10)
                            .overlay(
                                Group {
                                    if controlManager.isEditing {
                                        ZStack {
                                             RoundedRectangle(cornerRadius: 12)
                                                 .stroke(Color.yellow, lineWidth: 2)
                                             Color.white.opacity(0.001)
                                                 .gesture(
                                                     SimultaneousGesture(
                                                         DragGesture(coordinateSpace: .named("GBAScreen"))
                                                             .onChanged { value in
                                                                 let current = isPortrait ? controlManager.positions.screenPositionPortrait : controlManager.positions.screenPositionLandscape
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
                                        .scaleEffect(scale)
                                        .offset(x: offset.x, y: offset.y)
                                    }
                                }
                            )

                            Spacer()
                        }
                        
                    } else {
                        // --- LANDSCAPE MODE ---
                        // Center the game view properly
                        ZStack {
                            // ZStack wrapper to apply transforms
                            let scale = isPortrait ? controlManager.positions.screenScalePortrait : controlManager.positions.screenScaleLandscape
                            let offset = isPortrait ? controlManager.positions.screenPositionPortrait : controlManager.positions.screenPositionLandscape

                            GlowingGBARenderView(renderer: core.renderer, aspectRatio: aspectRatio, isScreenOn: isScreenOn, overlay: overlayContent)
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
                                                            DragGesture(coordinateSpace: .named("GBAScreen"))
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
                                            .scaleEffect(scale) // Match screen scale
                                            .offset(x: offset.x, y: offset.y) // Match screen offset
                                        }
                                    }
                                )
                                .padding(.vertical, 10)
                        }
                        .ignoresSafeArea()
                    }
                }
            }
        }
        .coordinateSpace(name: "GBAScreen")
    }
        .onAppear {
            // Sequence:
            // 0.5s: LED Flicker 1 (On)
            // 0.7s: LED Flicker 1 (Off)
            // 0.9s: LED Flicker 2 (On)
            // 1.0s: LED Flicker 2 (Off)
            // 1.4s: LED Stable On
            // 2.2s: Logo Glow On
            // 3.0s: Screen On
            
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
}

// Wrapper for Ambilight Glow Effect
struct GlowingGBARenderView: View {
    let renderer: GBARenderer
    let aspectRatio: CGFloat
    var isScreenOn: Bool
    var overlay: AnyView? 
    var showGlow: Bool = true
    
    var body: some View {
        ZStack {

            if isScreenOn && showGlow {
                GBARenderView(renderer: renderer)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .cornerRadius(8)
                    .blur(radius: 25) 
                    .opacity(0.6)     
                    .saturation(1.5)  
                    .scaleEffect(1.12)
            }
            
            // Main Content Layer (Sharp)
            ZStack {
                GBARenderView(renderer: renderer)
                    .opacity(isScreenOn ? 1.0 : 0.0)
                
                overlay
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 5)
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
