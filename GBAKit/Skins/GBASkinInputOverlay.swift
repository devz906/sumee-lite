import SwiftUI

struct GBASkinInputOverlay: View {
    let representation: GBASkinRepresentation
    let viewSize: CGSize
    let showInputControls: Bool
    
    private func mapInput(_ key: String) -> Int? {
        switch key.lowercased() {
        case "a": return GBAInput.ID_A
        case "b": return GBAInput.ID_B
        case "l": return GBAInput.ID_L
        case "r": return GBAInput.ID_R
        case "start": return GBAInput.ID_START
        case "select": return GBAInput.ID_SELECT
        case "up": return GBAInput.ID_UP
        case "down": return GBAInput.ID_DOWN
        case "left": return GBAInput.ID_LEFT
        case "right": return GBAInput.ID_RIGHT
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
                let mapSize = representation.mappingSize ?? GBASkinSize(width: screenW, height: screenH)
                
                // Aspect Fit Logic (Duplicate of GBAScreenLayout for consistency)
                let widthRatio = screenW / mapSize.width
                let heightRatio = screenH / mapSize.height
                let isPDF = representation.backgroundImageName.lowercased().contains(".pdf")
                let useAspectFit = isPDF
                
                let scaleX = useAspectFit ? min(widthRatio, heightRatio) : widthRatio
                let scaleY = useAspectFit ? min(widthRatio, heightRatio) : heightRatio
                
                let offsetX = (screenW - mapSize.width * scaleX) / 2
                
                // Align Bottom for Portrait if aspect fitting, else Center
                let isPortrait = screenH > screenW
                let offsetY = (useAspectFit && isPortrait) ?
                    (screenH - (mapSize.height * scaleY)) :
                    ((screenH - mapSize.height * scaleY) / 2)
                
                let zones = calculateZones(representation: representation, scaleX: scaleX, scaleY: scaleY, offsetX: offsetX, offsetY: offsetY)
                GBASkinMultiTouchOverlay(zones: zones)
            }
        }
        .ignoresSafeArea()
    }
    
    private func calculateZones(representation: GBASkinRepresentation, scaleX: CGFloat, scaleY: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> [GBATouchZone] {
        var zones: [GBATouchZone] = []
        
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
                            zones.append(GBATouchZone(rect: rect, type: .menu))
                        } else if let id = mapInput(key) {
                            zones.append(GBATouchZone(rect: rect, type: .button(id)))
                        }
                    }
                case .directional:
                    // INFLATED HITBOX: Increase D-Pad active area by 50pts
                    let dpadRect = rect.insetBy(dx: -50, dy: -50)
                    zones.append(GBATouchZone(rect: dpadRect, type: .dpad))
                }
            }
        }
        return zones
    }
}

// --- Multi-Touch Logic ---

struct GBATouchZone {
    enum ZoneType {
        case button(Int)
        case dpad
        case menu
    }
    let rect: CGRect
    let type: ZoneType
}

struct GBASkinMultiTouchOverlay: UIViewRepresentable {
    let zones: [GBATouchZone]
    
    func makeUIView(context: Context) -> GBASkinMultiTouchView {
        let view = GBASkinMultiTouchView()
        view.zones = zones
        view.isMultipleTouchEnabled = true
        return view
    }
    
    func updateUIView(_ uiView: GBASkinMultiTouchView, context: Context) {
        uiView.zones = zones
    }
}

class GBASkinMultiTouchView: UIView {
    var zones: [GBATouchZone] = []
    
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
               
                         } else {
                            nextButtons.insert(id)
                         }
                    case .menu:
                        if touch.phase == .began {
                            GBASkinManager.shared.nextSkin()
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
             if dpadAngle >= 337.5 || dpadAngle < 22.5 { nextButtons.insert(GBAInput.ID_RIGHT) }
             else if dpadAngle >= 22.5 && dpadAngle < 67.5 { nextButtons.insert(GBAInput.ID_RIGHT); nextButtons.insert(GBAInput.ID_DOWN) }
             else if dpadAngle >= 67.5 && dpadAngle < 112.5 { nextButtons.insert(GBAInput.ID_DOWN) }
             else if dpadAngle >= 112.5 && dpadAngle < 157.5 { nextButtons.insert(GBAInput.ID_DOWN); nextButtons.insert(GBAInput.ID_LEFT) }
             else if dpadAngle >= 157.5 && dpadAngle < 202.5 { nextButtons.insert(GBAInput.ID_LEFT) }
             else if dpadAngle >= 202.5 && dpadAngle < 247.5 { nextButtons.insert(GBAInput.ID_LEFT); nextButtons.insert(GBAInput.ID_UP) }
             else if dpadAngle >= 247.5 && dpadAngle < 292.5 { nextButtons.insert(GBAInput.ID_UP) }
             else if dpadAngle >= 292.5 && dpadAngle < 337.5 { nextButtons.insert(GBAInput.ID_UP); nextButtons.insert(GBAInput.ID_RIGHT) }
        }
        
        for id in activeButtons.subtracting(nextButtons) {
            GBAInput.shared.setButton(id, pressed: false)
        }
        
        for id in nextButtons.subtracting(activeButtons) {
            GBAInput.shared.setButton(id, pressed: true)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        activeButtons = nextButtons
    }
}
