import SwiftUI

struct MDSkinInputOverlay: View {
    let representation: MDSkinRepresentation
    let viewSize: CGSize
    let showInputControls: Bool
    
    // Mapping Logic based on PicoDriveInput constants and Genesis Layout
 
    private func mapInput(_ key: String) -> Int? {
        switch key.lowercased() {
        case "a": return PicoDriveInput.ID_B
        case "b": return PicoDriveInput.ID_A
        case "c": return PicoDriveInput.ID_Y
        case "x": return PicoDriveInput.ID_L
        case "y": return PicoDriveInput.ID_X
        case "z": return PicoDriveInput.ID_R
        case "start": return PicoDriveInput.ID_START
        case "mode", "select": return PicoDriveInput.ID_SELECT
        case "up": return PicoDriveInput.ID_UP
        case "down": return PicoDriveInput.ID_DOWN
        case "left": return PicoDriveInput.ID_LEFT
        case "right": return PicoDriveInput.ID_RIGHT
        case "menu": return 999
        case "togglefastforward", "fastforward": return 996
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            if showInputControls {
                // Use UIScreen for full edge-to-edge calculation
                let screenW = UIScreen.main.bounds.width
                let screenH = UIScreen.main.bounds.height
                let isPortrait = screenH > screenW
                
                // Fallback to Image Size if avail, else Screen
                let bgImage = MDSkinManager.shared.resolveAssetImage(named: representation.backgroundImageName)
                let baseMapSize = representation.mappingSize ?? 
                              bgImage.map { MDSkinSize(width: $0.size.width, height: $0.size.height) } ??
                              MDSkinSize(width: screenW, height: screenH)
                
                // CORRECTED LOGIC: Check for Aspect Ratio Mismatch (Squashed PDF issue)
                let isPDF = representation.backgroundImageName.lowercased().contains(".pdf")
                
                let effectiveMapSize: MDSkinSize = {
                    if let img = bgImage, isPDF {
                        let imageAR = img.size.width / img.size.height
                        let mapAR = baseMapSize.width / baseMapSize.height
                        if abs(imageAR - mapAR) > 0.1 {
                            return MDSkinSize(width: baseMapSize.width, height: baseMapSize.width / imageAR)
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
                
                let zones = calculateZones(representation: representation, scaleX: scaleX, scaleY: scaleY, offsetX: offsetX, offsetY: offsetY)
                MDSkinMultiTouchOverlay(zones: zones)
            }
        }
        .ignoresSafeArea()
    }
    
    // Removed legacy getMetrics() as logic is now inlined for PDF awareness
    
    private func calculateZones(representation: MDSkinRepresentation, scaleX: CGFloat, scaleY: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> [MDTouchZone] {
        var zones: [MDTouchZone] = []
        
        for item in representation.items {
            let frame = item.frame
            let rect = CGRect(
                x: frame.x * scaleX + offsetX,
                y: frame.y * scaleY + offsetY,
                width: frame.width * scaleX,
                height: frame.height * scaleY
            )
            
            // Apply extended edges if any
            var hitRect = rect
            if let extended = item.extendedEdges {
                let top = (extended.top ?? 0) * scaleY
                let bottom = (extended.bottom ?? 0) * scaleY
                let left = (extended.left ?? 0) * scaleX
                let right = (extended.right ?? 0) * scaleX
                hitRect = CGRect(x: rect.minX - left, y: rect.minY - top, width: rect.width + left + right, height: rect.height + top + bottom)
            }
            
            if let inputs = item.inputs {
                switch inputs {
                case .distinct(let keys):
                    if let key = keys.first {
                        if key == "menu" {
                            zones.append(MDTouchZone(rect: hitRect, type: .menu))
                        } else if let id = mapInput(key) {
                            zones.append(MDTouchZone(rect: hitRect, type: .button(id)))
                        }
                    }
                case .directional:
                    // INFLATED HITBOX: Increase D-Pad active area by 50pts to prevent drop-off near screen
                    let dpadRect = hitRect.insetBy(dx: -50, dy: -50)
                    zones.append(MDTouchZone(rect: dpadRect, type: .dpad))
                }
            }
        }
        return zones
    }
}

// --- Multi-Touch Logic ---

struct MDTouchZone {
    enum ZoneType {
        case button(Int)
        case dpad
        case menu
    }
    let rect: CGRect
    let type: ZoneType
}

struct MDSkinMultiTouchOverlay: UIViewRepresentable {
    let zones: [MDTouchZone]
    
    func makeUIView(context: Context) -> MDSkinMultiTouchView {
        let view = MDSkinMultiTouchView()
        view.zones = zones
        view.isMultipleTouchEnabled = true
        return view
    }
    
    func updateUIView(_ uiView: MDSkinMultiTouchView, context: Context) {
        uiView.zones = zones
    }
}

class MDSkinMultiTouchView: UIView {
    var zones: [MDTouchZone] = []
    
    // Track active touches: InputID -> Count (for buttons)
    // For DPad: calculate direction per touch
    
    private var activeButtons: Set<Int> = []
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateInputs(touches: event?.allTouches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateInputs(touches: event?.allTouches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateInputs(touches: event?.allTouches)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateInputs(touches: event?.allTouches)
    }
    
    private func updateInputs(touches: Set<UITouch>?) {
        guard let touches = touches else { return }
        
        var nextButtons: Set<Int> = []
        var dpadPressed = false
        var dpadAngle: CGFloat = -1
        
        for touch in touches {
            let loc = touch.location(in: self)
            if touch.phase == .ended || touch.phase == .cancelled { continue }
            
            var captured = false
            for zone in zones {
                if zone.rect.contains(loc) {
                    captured = true
                    switch zone.type {
                    case .button(let id):
                        nextButtons.insert(id)
                    case .menu:
                        if touch.phase == .began {
                            MDSkinManager.shared.nextSkin()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    case .dpad:
                        dpadPressed = true
                        let center = CGPoint(x: zone.rect.midX, y: zone.rect.midY)
                        let dx = loc.x - center.x
                        let dy = loc.y - center.y
                        if hypot(dx, dy) >= 5 { // Deadzone
                            var angle = atan2(dy, dx) * 180 / .pi
                            if angle < 0 { angle += 360 }
                            dpadAngle = angle
                        }
                    }
                }
                if captured { break } // One zone per touch priority
            }
        }
        
        // Resolve DPad
        if dpadPressed && dpadAngle >= 0 {
             if dpadAngle >= 337.5 || dpadAngle < 22.5 { nextButtons.insert(PicoDriveInput.ID_RIGHT) }
             else if dpadAngle >= 22.5 && dpadAngle < 67.5 { nextButtons.insert(PicoDriveInput.ID_RIGHT); nextButtons.insert(PicoDriveInput.ID_DOWN) }
             else if dpadAngle >= 67.5 && dpadAngle < 112.5 { nextButtons.insert(PicoDriveInput.ID_DOWN) }
             else if dpadAngle >= 112.5 && dpadAngle < 157.5 { nextButtons.insert(PicoDriveInput.ID_DOWN); nextButtons.insert(PicoDriveInput.ID_LEFT) }
             else if dpadAngle >= 157.5 && dpadAngle < 202.5 { nextButtons.insert(PicoDriveInput.ID_LEFT) }
             else if dpadAngle >= 202.5 && dpadAngle < 247.5 { nextButtons.insert(PicoDriveInput.ID_LEFT); nextButtons.insert(PicoDriveInput.ID_UP) }
             else if dpadAngle >= 247.5 && dpadAngle < 292.5 { nextButtons.insert(PicoDriveInput.ID_UP) }
             else if dpadAngle >= 292.5 && dpadAngle < 337.5 { nextButtons.insert(PicoDriveInput.ID_UP); nextButtons.insert(PicoDriveInput.ID_RIGHT) }
        }
        
        // 1. Release buttons not in next
        for id in activeButtons.subtracting(nextButtons) {
            PicoDriveInput.shared.setButton(id, pressed: false)
        }
        
        // 2. Press new buttons
        for id in nextButtons.subtracting(activeButtons) {
            PicoDriveInput.shared.setButton(id, pressed: true)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        activeButtons = nextButtons
    }
}
