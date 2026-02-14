import SwiftUI

public struct PicoDriveScreenLayout: View {
    @ObservedObject var core: PicoDriveCore
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isLedOn = false
    @State private var isScreenOn = false
    
    public init(core: PicoDriveCore) {
        self.core = core
    }

    // Dynamic Theme Background (Matches ResumePromptView)
    var themeBg: Color {
        colorScheme == .dark 
            ? Color(red: 28/255, green: 28/255, blue: 30/255) // Dark Grey Mesh
            : Color(red: 235/255, green: 235/255, blue: 240/255) // Light Grey Mesh
    }
    
    // [NEW] Overlay Support
    var overlayContent: AnyView?
    
    public func screenOverlay<Content: View>(@ViewBuilder content: () -> Content) -> PicoDriveScreenLayout {
        var copy = self
        copy.overlayContent = AnyView(content())
        return copy
    }
    
    // Reusable Power LED Component
    private var powerLED: some View {
        let activeColor = Color.red
        let labelColor = (colorScheme == .dark) ? Color.gray.opacity(0.8) : Color.black.opacity(0.6)
        
        return VStack(spacing: 4) {
            Text("POWER") // Or "BATTERY" for portable, but Genesis uses "POWER" usually
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

    @ObservedObject var skinManager = MDSkinManager.shared
    @ObservedObject var input = PicoDriveInput.shared
    @ObservedObject var controlManager = PicoDriveControlManager.shared
    
    // [NEW] Gesture State for Edit Mode
    @State private var gestureStartOffset: CGPoint?
    @State private var gestureStartScale: CGFloat?
    
    public var body: some View {
        GeometryReader { geo in
            // Robust Orientation
            let isPortrait = geo.size.height >= geo.size.width
            
            // --- SKIN SUPPORT CHECK ---
            // --- SKIN SUPPORT CHECK ---
            if let representation = skinManager.currentRepresentation(portrait: isPortrait),
               let bgImage = skinManager.resolveAssetImage(named: representation.backgroundImageName) {
               
               GeometryReader { _ in
                   let screenW = geo.size.width
                   let screenH = geo.size.height
                   
                   // Fallback to Image Size if Mapping Size is missing.
                   let baseMapSize = representation.mappingSize ?? MDSkinSize(width: bgImage.size.width, height: bgImage.size.height)
                   
                   // CORRECTED LOGIC: Check for Aspect Ratio Mismatch (Squashed PDF issue)
                   // If the PDF image has a different aspect ratio than the JSON mapping size,
                   // we trust the IMAGE for the visual shape to prevent squashing.
                   let imageAR = bgImage.size.width / bgImage.size.height
                   let mapAR = baseMapSize.width / baseMapSize.height
                   let isPDF = representation.backgroundImageName.lowercased().contains(".pdf")
                   
                   let effectiveMapSize: MDSkinSize = {
                       if isPDF && abs(imageAR - mapAR) > 0.1 {
                           return MDSkinSize(width: baseMapSize.width, height: baseMapSize.width / imageAR)
                       }
                       return baseMapSize
                   }()
                   
                   // Aspect Fit Logic based on EFFECTIVE size
                   let widthRatio = screenW / effectiveMapSize.width
                   let heightRatio = screenH / effectiveMapSize.height
                   
                   // Only apply Aspect Fit for PDFs if distortion is significant (>10%)
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
                       // 0. Black Background
                       Color.black.ignoresSafeArea()
                       
                       // 1. Screens (Rendered BEHIND skin)
                       let screens = representation.effectiveScreens
                       
                       if screens.isEmpty {
                           // Fallback: Render Screen in the remaining space ABOVE the skin (Portrait) or Center (Landscape)
                           if isPortrait {
                               let gameAreaHeight = max(offsetY, 0)
                               let renderH = min(gameAreaHeight, screenW * 0.75) // 4:3 Aspect Ratio Limit
                               let renderW = renderH * (4.0/3.0)
                               
                               GlowingPicoDriveRenderView(renderer: core.renderer, isScreenOn: isScreenOn, overlay: overlayContent)
                                   .frame(width: renderW, height: renderH)
                                   .position(x: screenW / 2, y: gameAreaHeight / 2)
                           } else {
                               // Landscape Center Fallback
                               GlowingPicoDriveRenderView(renderer: core.renderer, isScreenOn: isScreenOn, overlay: overlayContent)
                                   .aspectRatio(4.0/3.0, contentMode: .fit)
                                   .frame(width: screenW, height: screenH)
                                   .position(x: screenW/2, y: screenH/2)
                           }
                       } else {
                           ForEach(0..<screens.count, id: \.self) { i in
                               let screenDef = screens[i]
                               let frame = screenDef.outputFrame
                               
                               ZStack {
                                   PicoDriveRenderView(renderer: core.renderer)
                                   overlayContent
                               }
                               .frame(width: frame.width * scaleX, height: frame.height * scaleY)
                               .position(
                                   x: offsetX + (frame.x + frame.width/2) * scaleX,
                                   y: offsetY + (frame.y + frame.height/2) * scaleY
                               )
                           }
                       }
                       
                       // 2. Background (Rendered ON TOP of screen)
                       Image(uiImage: bgImage)
                           .resizable()
                           .frame(width: finalWidth, height: finalHeight)
                           .position(x: offsetX + finalWidth / 2, y: offsetY + finalHeight / 2)
                   }
               }
               .ignoresSafeArea()
               
            } else {
                // ... fallback ...
                ZStack {
                    // Unified Background with Grid
                    ZStack {
                        themeBg.ignoresSafeArea()
                        PromptGridBackground(isDark: colorScheme == .dark)
                            .ignoresSafeArea()
                    }

                     if isPortrait {
                         // Copy of fallback code to ensure I don't delete it
                        VStack(spacing: 0) {
                            Spacer().frame(height: max(geo.safeAreaInsets.top, 50) + 20) 
                            ZStack {
                                let scale = isPortrait ? controlManager.positions.screenScalePortrait : controlManager.positions.screenScaleLandscape
                                let offset = isPortrait ? controlManager.positions.screenPositionPortrait : controlManager.positions.screenPositionLandscape

                                GlowingPicoDriveRenderView(renderer: core.renderer, isScreenOn: isScreenOn, overlay: overlayContent)
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
                                                                DragGesture(coordinateSpace: .named("PicoDriveScreen"))
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
                            .offset(y: -20)
                            HStack(alignment: .bottom, spacing: 20) {
                                 Text("SEGA GENESIS").font(.system(size: 18, weight: .black, design: .rounded)).italic().foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.6))
                                 Spacer()
                                 powerLED.padding(.bottom, 5)
                            }
                            .padding(.top, 10).padding(.horizontal, 30)
                            Spacer()
                        }
                        .ignoresSafeArea()
                     } else {
                        ZStack {
                            let scale = isPortrait ? controlManager.positions.screenScalePortrait : controlManager.positions.screenScaleLandscape
                            let offset = isPortrait ? controlManager.positions.screenPositionPortrait : controlManager.positions.screenPositionLandscape

                            GlowingPicoDriveRenderView(renderer: core.renderer, isScreenOn: isScreenOn, overlay: overlayContent)
                                .scaleEffect(scale)
                                .offset(x: offset.x, y: offset.y)
                                .overlay(
                                    Group {
                                        if controlManager.isEditing {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.yellow, lineWidth: 2)
                                                
                                                Color.white.opacity(0.001)
                                                    .gesture(
                                                        SimultaneousGesture(
                                                            DragGesture(coordinateSpace: .named("PicoDriveScreen"))
                                                                .onChanged { value in
                                                                    let current = isPortrait ? controlManager.positions.screenPositionPortrait : controlManager.positions.screenPositionLandscape
                                                                    if gestureStartOffset == nil { gestureStartOffset = current }
                                                                    if let start = gestureStartOffset {
                                                                        controlManager.updateScreenPosition(isPortrait: isPortrait, position: CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height))
                                                                    }
                                                                }
                                                                .onEnded { _ in gestureStartOffset = nil },
                                                            
                                                            MagnificationGesture()
                                                                .onChanged { value in
                                                                    let current = isPortrait ? controlManager.positions.screenScalePortrait : controlManager.positions.screenScaleLandscape
                                                                    if gestureStartScale == nil { gestureStartScale = current }
                                                                    if let start = gestureStartScale {
                                                                        controlManager.updateScreenScale(isPortrait: isPortrait, scale: max(0.5, min(3.0, start * value)))
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
                                .padding(.vertical, 10).offset(y: -10)
                            VStack {
                                HStack { Spacer(); powerLED.padding(.top, max(geo.safeAreaInsets.top, 20)).padding(.trailing, max(geo.safeAreaInsets.trailing, 40)) }
                                Spacer()
                            }
                        }.ignoresSafeArea()
                     }
                }
            } // End Skin Check
        }
        .coordinateSpace(name: "PicoDriveScreen")
        .onAppear {
            // Sequence:
            // 0.5s: LED Flicker 1 (On)
            // 0.7s: LED Flicker 1 (Off)
            // 0.9s: LED Flicker 2 (On)
            // 1.0s: LED Flicker 2 (Off)
            // 1.4s: LED Stable On
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
            
            // Screen On (Last, slow fade)
            withAnimation(.easeIn(duration: 1.0).delay(baseDelay + 2.0)) {
                isScreenOn = true
            }
        }
    }
    
    // Helper for Metrics
    private func getSkinMetrics(for representation: MDSkinRepresentation, geoSize: CGSize) -> (scaleX: CGFloat, scaleY: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        let mapSize = representation.mappingSize ?? MDSkinSize(width: screenW, height: screenH)
        
        let mapRatio = mapSize.width / mapSize.height
        let screenRatio = screenW / screenH
        
        if abs(mapRatio - screenRatio) > 0.1 {
            // Aspect Fit + Bottom Align
            let scale = min(screenW / mapSize.width, screenH / mapSize.height)
            let offsetX = (screenW - mapSize.width * scale) / 2
            let offsetY = screenH - (mapSize.height * scale) // Push to bottom
            return (scale, scale, offsetX, offsetY)
        } else {
            // Fill
            return (screenW / mapSize.width, screenH / mapSize.height, 0, 0)
        }
    }
}

struct GlowingPicoDriveRenderView: View {
    let renderer: PicoDriveRenderer
    var isScreenOn: Bool
    var overlay: AnyView?
    
    var body: some View {
        ZStack {
            PicoDriveRenderView(renderer: renderer)
                .aspectRatio(4.0/3.0, contentMode: .fit)
                .cornerRadius(12)
                .blur(radius: 15)
                .opacity(isScreenOn ? 0.8 : 0.0)
                .scaleEffect(1.15)
            
            ZStack {
                PicoDriveRenderView(renderer: renderer)
                    .opacity(isScreenOn ? 1.0 : 0.0)
                
                overlay
            }
            .aspectRatio(4.0/3.0, contentMode: .fit)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 5)
            //.opacity(isScreenOn ? 1.0 : 0.0)
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
