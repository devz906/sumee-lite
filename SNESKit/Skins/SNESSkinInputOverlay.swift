import SwiftUI

struct SNESSkinInputOverlay: View {
    let representation: SNESSkinRepresentation
    let viewSize: CGSize
    let showInputControls: Bool
    
    private func mapInput(_ key: String) -> Int? {
        switch key.lowercased() {
        case "a": return SNESInput.ID_A
        case "b": return SNESInput.ID_B
        case "x": return SNESInput.ID_X
        case "y": return SNESInput.ID_Y
        case "l": return SNESInput.ID_L
        case "r": return SNESInput.ID_R
        case "start": return SNESInput.ID_START
        case "select": return SNESInput.ID_SELECT
        case "up": return SNESInput.ID_UP
        case "down": return SNESInput.ID_DOWN
        case "left": return SNESInput.ID_LEFT
        case "right": return SNESInput.ID_RIGHT
        case "menu": return 999
        case "fastforward": return 996
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            if showInputControls {
                let screenW = viewSize.width
                let screenH = viewSize.height
                let mapSize = representation.mappingSize ?? SNESSkinSize(width: screenW, height: screenH)
                
                // Fallback to Image Size if avail, else Screen
                let bgImage = SNESSkinManager.shared.resolveAssetImage(named: representation.backgroundImageName)
                let baseMapSize = representation.mappingSize ?? 
                              bgImage.map { SNESSkinSize(width: $0.size.width, height: $0.size.height) } ??
                              SNESSkinSize(width: screenW, height: screenH)
                
                // Check for PDF usage to maintain aspect ratio logic if needed
                let isPDF = representation.backgroundImageName.lowercased().contains(".pdf")
                
                let effectiveMapSize: SNESSkinSize = {
                    if let img = bgImage, isPDF {
                        let imageAR = img.size.width / img.size.height
                        let mapAR = baseMapSize.width / baseMapSize.height
                        if abs(imageAR - mapAR) > 0.1 {
                            return SNESSkinSize(width: baseMapSize.width, height: baseMapSize.width / imageAR)
                        }
                    }
                    return baseMapSize
                }()
                
                // Adjust scaling based on effective map size vs screen size
                let widthRatio = screenW / effectiveMapSize.width
                let heightRatio = screenH / effectiveMapSize.height
                
                let useAspectFit = isPDF && abs(widthRatio - heightRatio) > 0.1
                
                let viewScaleX = useAspectFit ? min(widthRatio, heightRatio) : widthRatio
                let viewScaleY = useAspectFit ? min(widthRatio, heightRatio) : heightRatio
                
                let finalWidth = effectiveMapSize.width * viewScaleX
                let finalHeight = effectiveMapSize.height * viewScaleY
                
                let scaleX = finalWidth / baseMapSize.width
                let scaleY = finalHeight / baseMapSize.height
                
                let offsetX = (screenW - finalWidth) / 2
                
                let isPortrait = screenH > screenW
                let offsetY = (useAspectFit && isPortrait) ?
                    (screenH - finalHeight) :
                    ((screenH - finalHeight) / 2)
                
                // SKINS RENDER - REMOVED to avoid duplication
                /*
                if let img = bgImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: useAspectFit ? .fit : .fill)
                        .frame(width: finalWidth, height: finalHeight)
                        .position(x: offsetX + finalWidth / 2, y: offsetY + finalHeight / 2)
                }
                */

                let zones = calculateZones(representation: representation, scaleX: scaleX, scaleY: scaleY, offsetX: offsetX, offsetY: offsetY)
                SNESSkinMultiTouchOverlay(zones: zones)
            }
        }
        .ignoresSafeArea()
    }
    
    private func calculateZones(representation: SNESSkinRepresentation, scaleX: CGFloat, scaleY: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> [SNESTouchZone] {
        var zones: [SNESTouchZone] = []
        
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
                            zones.append(SNESTouchZone(rect: rect, type: .menu))
                        } else if let id = mapInput(key) {
                            zones.append(SNESTouchZone(rect: rect, type: .button(id)))
                        }
                    }
                case .directional:
                    let dpadRect = rect.insetBy(dx: -50, dy: -50)
                    zones.append(SNESTouchZone(rect: dpadRect, type: .dpad))
                }
            }
        }
        return zones
    }
}

// --- Multi-Touch Logic ---

struct SNESTouchZone {
    enum ZoneType {
        case button(Int)
        case dpad
        case menu
    }
    let rect: CGRect
    let type: ZoneType
}

struct SNESSkinMultiTouchOverlay: UIViewRepresentable {
    let zones: [SNESTouchZone]
    
    func makeUIView(context: Context) -> SNESSkinMultiTouchView {
        let view = SNESSkinMultiTouchView()
        view.zones = zones
        view.isMultipleTouchEnabled = true
        return view
    }
    
    func updateUIView(_ uiView: SNESSkinMultiTouchView, context: Context) {
        uiView.zones = zones
    }
}

class SNESSkinMultiTouchView: UIView {
    var zones: [SNESTouchZone] = []
    
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
                             // Toggle Fast Forward on Press
                             if touch.phase == .began {
                                 SNESCore.fastForward.toggle()
                                 if SNESCore.fastForward {
                                     UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                 } else {
                                     UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                 }
                             }
                         } else {
                             nextButtons.insert(id)
                         }
                    case .menu:
                        if touch.phase == .began {
                            SNESSkinManager.shared.nextSkin()
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
             if dpadAngle >= 337.5 || dpadAngle < 22.5 { nextButtons.insert(SNESInput.ID_RIGHT) }
             else if dpadAngle >= 22.5 && dpadAngle < 67.5 { nextButtons.insert(SNESInput.ID_RIGHT); nextButtons.insert(SNESInput.ID_DOWN) }
             else if dpadAngle >= 67.5 && dpadAngle < 112.5 { nextButtons.insert(SNESInput.ID_DOWN) }
             else if dpadAngle >= 112.5 && dpadAngle < 157.5 { nextButtons.insert(SNESInput.ID_DOWN); nextButtons.insert(SNESInput.ID_LEFT) }
             else if dpadAngle >= 157.5 && dpadAngle < 202.5 { nextButtons.insert(SNESInput.ID_LEFT) }
             else if dpadAngle >= 202.5 && dpadAngle < 247.5 { nextButtons.insert(SNESInput.ID_LEFT); nextButtons.insert(SNESInput.ID_UP) }
             else if dpadAngle >= 247.5 && dpadAngle < 292.5 { nextButtons.insert(SNESInput.ID_UP) }
             else if dpadAngle >= 292.5 && dpadAngle < 337.5 { nextButtons.insert(SNESInput.ID_UP); nextButtons.insert(SNESInput.ID_RIGHT) }
        }
        
        for id in activeButtons.subtracting(nextButtons) {
            SNESInput.shared.setButton(id, pressed: false)
        }
        
        for id in nextButtons.subtracting(activeButtons) {
            SNESInput.shared.setButton(id, pressed: true)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        activeButtons = nextButtons
    }
}
