import SwiftUI

struct NESSkinInputOverlay: View {
    let representation: NESSkinRepresentation
    let viewSize: CGSize
    let showInputControls: Bool
    
    private func mapInput(_ key: String) -> Int? {
        switch key.lowercased() {
        case "a": return NESInput.ID_A
        case "b": return NESInput.ID_B
        case "start": return NESInput.ID_START
        case "select": return NESInput.ID_SELECT
        case "up": return NESInput.ID_UP
        case "down": return NESInput.ID_DOWN
        case "left": return NESInput.ID_LEFT
        case "right": return NESInput.ID_RIGHT
        case "menu": return 999
        case "fastforward": return 996
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            if showInputControls {
                let screenW = UIScreen.main.bounds.width
                let screenH = UIScreen.main.bounds.height
                let mapSize = representation.mappingSize ?? NESSkinSize(width: screenW, height: screenH)
                
                // Fallback to Image Size if avail, else Screen
                let bgImage = NESSkinManager.shared.resolveAssetImage(named: representation.backgroundImageName)
                let baseMapSize = representation.mappingSize ?? 
                              bgImage.map { NESSkinSize(width: $0.size.width, height: $0.size.height) } ??
                              NESSkinSize(width: screenW, height: screenH)
                
                // CORRECTED LOGIC: Check for Aspect Ratio Mismatch (Squashed PDF issue)
                let isPDF = representation.backgroundImageName.lowercased().contains(".pdf")
                
                let effectiveMapSize: NESSkinSize = {
                    if let img = bgImage, isPDF {
                        let imageAR = img.size.width / img.size.height
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
                
                // Align Bottom for Portrait if aspect fitting, else Center
                let isPortrait = screenH > screenW
                let offsetY = (useAspectFit && isPortrait) ?
                    (screenH - finalHeight) :
                    ((screenH - finalHeight) / 2)
                
                let zones = calculateZones(representation: representation, scaleX: scaleX, scaleY: scaleY, offsetX: offsetX, offsetY: offsetY)
                NESSkinMultiTouchOverlay(zones: zones)
            }
        }
        .ignoresSafeArea()
    }
    
    private func calculateZones(representation: NESSkinRepresentation, scaleX: CGFloat, scaleY: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> [NESTouchZone] {
        var zones: [NESTouchZone] = []
        
        for item in representation.items {
            let frame = item.frame
            var rect = CGRect(
                x: offsetX + frame.x * scaleX,
                y: offsetY + frame.y * scaleY,
                width: frame.width * scaleX,
                height: frame.height * scaleY
            )
            
            if let extended = item.extendedEdges {
                let top = (extended.top ?? 0) * scaleY
                let bottom = (extended.bottom ?? 0) * scaleY
                let left = (extended.left ?? 0) * scaleX
                let right = (extended.right ?? 0) * scaleX
                rect = CGRect(x: rect.minX - left, y: rect.minY - top, width: rect.width + left + right, height: rect.height + top + bottom)
            }
            
            if let inputs = item.inputs {
                switch inputs {
                case .distinct(let keys):
                    if let key = keys.first {
                        if key == "menu" {
                            zones.append(NESTouchZone(rect: rect, type: .menu))
                        } else if let id = mapInput(key) {
                            zones.append(NESTouchZone(rect: rect, type: .button(id)))
                        }
                    }
                case .directional:
                    // INFLATED HITBOX: Increase D-Pad active area by 50pts
                    let dpadRect = rect.insetBy(dx: -50, dy: -50)
                    zones.append(NESTouchZone(rect: dpadRect, type: .dpad))
                }
            }
        }
        return zones
    }
}

// --- Multi-Touch Logic ---

struct NESTouchZone {
    enum ZoneType {
        case button(Int)
        case dpad
        case menu
    }
    let rect: CGRect
    let type: ZoneType
}

struct NESSkinMultiTouchOverlay: UIViewRepresentable {
    let zones: [NESTouchZone]
    
    func makeUIView(context: Context) -> NESSkinMultiTouchView {
        let view = NESSkinMultiTouchView()
        view.zones = zones
        view.isMultipleTouchEnabled = true
        return view
    }
    
    func updateUIView(_ uiView: NESSkinMultiTouchView, context: Context) {
        uiView.zones = zones
    }
}

class NESSkinMultiTouchView: UIView {
    var zones: [NESTouchZone] = []
    
    private var activeButtons: Set<Int> = []
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { updateInputs(touches: event?.allTouches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { updateInputs(touches: event?.allTouches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { updateInputs(touches: event?.allTouches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { updateInputs(touches: event?.allTouches) }
    
    private func updateInputs(touches: Set<UITouch>?) {
        guard let touches = touches else { return }
        
        var nextButtons: Set<Int> = []
        var dpadPressed = false
        var dpadAngle: CGFloat = -1
        
        for touch in touches {
            let loc = touch.location(in: self)
            if touch.phase == .ended || touch.phase == .cancelled { continue }
            
            for zone in zones {
                if zone.rect.contains(loc) {
                    switch zone.type {
                    case .button(let id):
                         if id == 996 {
                            // FF handled externally or just toggle?
                            // NESInput usually doesn't have FF ID in constants unless added.
                            // Assuming 996 is FF
                         } else {
                            nextButtons.insert(id)
                         }
                    case .menu:
                        if touch.phase == .began {
                            NESSkinManager.shared.nextSkin()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    case .dpad:
                        dpadPressed = true
                        let center = CGPoint(x: zone.rect.midX, y: zone.rect.midY)
                        let dx = loc.x - center.x
                        let dy = loc.y - center.y
                        if hypot(dx, dy) >= 5 {
                            var angle = atan2(dy, dx) * 180 / .pi
                            if angle < 0 { angle += 360 }
                            dpadAngle = angle
                        }
                    }
                }
            }
        }
        
        if dpadPressed && dpadAngle >= 0 {
             if dpadAngle >= 337.5 || dpadAngle < 22.5 { nextButtons.insert(NESInput.ID_RIGHT) }
             else if dpadAngle >= 22.5 && dpadAngle < 67.5 { nextButtons.insert(NESInput.ID_RIGHT); nextButtons.insert(NESInput.ID_DOWN) }
             else if dpadAngle >= 67.5 && dpadAngle < 112.5 { nextButtons.insert(NESInput.ID_DOWN) }
             else if dpadAngle >= 112.5 && dpadAngle < 157.5 { nextButtons.insert(NESInput.ID_DOWN); nextButtons.insert(NESInput.ID_LEFT) }
             else if dpadAngle >= 157.5 && dpadAngle < 202.5 { nextButtons.insert(NESInput.ID_LEFT) }
             else if dpadAngle >= 202.5 && dpadAngle < 247.5 { nextButtons.insert(NESInput.ID_LEFT); nextButtons.insert(NESInput.ID_UP) }
             else if dpadAngle >= 247.5 && dpadAngle < 292.5 { nextButtons.insert(NESInput.ID_UP) }
             else if dpadAngle >= 292.5 && dpadAngle < 337.5 { nextButtons.insert(NESInput.ID_UP); nextButtons.insert(NESInput.ID_RIGHT) }
        }
        
        for id in activeButtons.subtracting(nextButtons) {
            NESInput.shared.setButton(id, pressed: false)
        }
        
        for id in nextButtons.subtracting(activeButtons) {
            NESInput.shared.setButton(id, pressed: true)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        activeButtons = nextButtons
    }
}
