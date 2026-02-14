import SwiftUI
import Combine

// --- Interaction State for Visuals ---
class PSXSkinInteractionState: ObservableObject {
    @Published var dpadTilt: (x: CGFloat, y: CGFloat) = (0, 0)
    @Published var leftJoystickOffset: CGSize = .zero
    @Published var rightJoystickOffset: CGSize = .zero
}

struct PSXSkinInputOverlay: View {
    let representation: PSXSkinRepresentation
    let viewSize: CGSize
    let showInputControls: Bool
    
    @StateObject private var interactionState = PSXSkinInteractionState()
    @ObservedObject var input = PSXInput.shared
    
    private func mapInput(_ key: String) -> Int? {
        switch key.lowercased() {
        case "a": return PSXInput.ID_A      // Circle (Right)
        case "b": return PSXInput.ID_B      // Cross (Bottom)
        case "x": return PSXInput.ID_X      // Triangle (Top)
        case "y": return PSXInput.ID_Y      // Square (Left)
        case "l", "l1": return PSXInput.ID_L // L1
        case "r", "r1": return PSXInput.ID_R // R1
        case "l2": return PSXInput.ID_L2    // L2
        case "r2": return PSXInput.ID_R2    // R2
        case "start": return PSXInput.ID_START
        case "select": return PSXInput.ID_SELECT
        case "up": return PSXInput.ID_UP
        case "down": return PSXInput.ID_DOWN
        case "left": return PSXInput.ID_LEFT
        case "right": return PSXInput.ID_RIGHT
        case "menu": return 999
        case "fastforward": return 996
        case "quicksave", "quickload", "toggleanalog": return nil // Ignore for now
        default: return nil
        }
    }

    // Check if an item is currently pressed logic
    private func isItemPressed(_ item: PSXSkinItem) -> Bool {
        guard let inputs = item.inputs else { return false }
        switch inputs {
        case .distinct(let keys):
            // Check if any key maps to a currently pressed ID
            for key in keys {
                if let id = mapInput(key), input.pressedButtons.contains(id) { return true }
                if key == "fastforward" && PSXCore.fastForward { return true } // Visual feedback for toggle
            }
        default: return false
        }
        return false
    }
    
    // Check if item is Left or Right Joystick
    private func isLeftJoystick(_ item: PSXSkinItem) -> Bool {
        guard let inputs = item.inputs else { return false }
        if case .complex(let dict) = inputs {
             let combined = dict.keys.map { $0.lowercased() } + dict.values.map { $0.lowercased() }
             return combined.contains { $0.contains("leftthumbstick") }
        }
        return false
    }

    var body: some View {
        ZStack {
            if showInputControls {
                let screenW = viewSize.width
                let screenH = viewSize.height
                let mapSize = representation.mappingSize ?? PSXSkinSize(width: screenW, height: screenH)
                
                // Fallback to Image Size if avail, else Screen
                let bgImage = PSXSkinManager.shared.resolveAssetImage(named: representation.backgroundImageName)
                let baseMapSize = representation.mappingSize ?? 
                              bgImage.map { PSXSkinSize(width: $0.size.width, height: $0.size.height) } ??
                              PSXSkinSize(width: screenW, height: screenH)
                
                // Check for PDF usage to maintain aspect ratio logic if needed
                let isPDF = representation.backgroundImageName.lowercased().contains(".pdf")
                
                let effectiveMapSize: PSXSkinSize = {
                    if let img = bgImage, isPDF {
                        let imageAR = img.size.width / img.size.height
                        let mapAR = baseMapSize.width / baseMapSize.height
                        if abs(imageAR - mapAR) > 0.1 {
                            return PSXSkinSize(width: baseMapSize.width, height: baseMapSize.width / imageAR)
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
                
                // RENDER SKIN IMAGE (Background) - REMOVED to avoid duplication with PSXScreenLayout (it was my mistke lol maybe i wil do somthing whit it)
                /*
                if let img = bgImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: useAspectFit ? .fit : .fill)
                        .frame(width: finalWidth, height: finalHeight)
                        .position(x: offsetX + finalWidth / 2, y: offsetY + finalHeight / 2)
                }
                */
                
                // RENDER ITEM ASSETS (Buttons, D-Pads, Thumbsticks)
                ForEach(0..<representation.items.count, id: \.self) { index in
                    let item = representation.items[index]
                    
                    let frame = item.frame
                    let itemX = offsetX + frame.x * scaleX
                    let itemY = offsetY + frame.y * scaleY
                    let itemW = frame.width * scaleX
                    let itemH = frame.height * scaleY
                    let centerX = itemX + itemW / 2
                    let centerY = itemY + itemH / 2
                    
                    // 1. Render Background (Static)
                    if let bg = item.background,
                       let bgImg = PSXSkinManager.shared.resolveAssetImage(named: bg.name) {
                         let bgW = bg.width * scaleX
                         let bgH = bg.height * scaleY
                         let bgX = centerX + (bg.offsetX * scaleX)
                         let bgY = centerY + (bg.offsetY * scaleY)
                         
                         Image(uiImage: bgImg)
                             .resizable()
                             .frame(width: bgW, height: bgH)
                             .position(x: bgX, y: bgY)
                    }
                    
                    // 2. Render Standard Asset (Buttons / D-Pad)
                    if let asset = item.asset,
                       let assetName = asset.normal ?? asset.standard ?? asset.resizable ?? asset.small ?? asset.medium ?? asset.large,
                       let itemImg = PSXSkinManager.shared.resolveAssetImage(named: assetName) {
                        
                        // Check if it's a D-Pad for special animation
                        let isDPad = isItemDPad(item)
                        
                        if isDPad {
                            // D-Pad INDEPENDENT Logic (uses visual state, not shared input)
                            let tilt = interactionState.dpadTilt
                             let tiltAngle = (abs(tilt.x) > 0 || abs(tilt.y) > 0) ? 15.0 : 0.0
                            
                            Image(uiImage: itemImg)
                                .resizable()
                                .frame(width: itemW, height: itemH)
                                .rotation3DEffect(
                                    .degrees(tiltAngle),
                                    axis: (x: tilt.x, y: tilt.y, z: 0.0),
                                    perspective: 0.5
                                )
                                .animation(.easeOut(duration: 0.1), value: tilt.x)
                                .animation(.easeOut(duration: 0.1), value: tilt.y)
                                .position(x: centerX, y: centerY)
                        } else {
                            // Standard Button Animation (Shrink)
                            let isPressed = isItemPressed(item)
                            Image(uiImage: itemImg)
                                .resizable()
                                .frame(width: itemW, height: itemH)
                                .scaleEffect(isPressed ? 0.9 : 1.0)
                                .opacity(isPressed ? 0.8 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: isPressed)
                                .position(x: centerX, y: centerY)
                        }
                    }
                    
                    // 3. Render Thumbstick Knob
                    if let stick = item.thumbstick,
                       let stickImg = PSXSkinManager.shared.resolveAssetImage(named: stick.name) {
                        let stickW = stick.width * scaleX
                        let stickH = stick.height * scaleY
                        
                         // Determine which stick
                        let isLeft = isLeftJoystick(item) // Helper needed
                        let offset = isLeft ? interactionState.leftJoystickOffset : interactionState.rightJoystickOffset
                        
                        Image(uiImage: stickImg)
                            .resizable()
                            .frame(width: stickW, height: stickH)
                            .offset(x: offset.width, y: offset.height) // Apply visual follow
                            .position(x: centerX, y: centerY)
                    }
                }
                
                let zones = calculateZones(representation: representation, scaleX: scaleX, scaleY: scaleY, offsetX: offsetX, offsetY: offsetY)
                PSXSkinMultiTouchOverlay(zones: zones, interactionState: interactionState)
            }
        }
        .ignoresSafeArea()
    }
    
    // --- Helpers ---
    private func isItemDPad(_ item: PSXSkinItem) -> Bool {
        if item.thumbstick != nil { return false }
        guard let inputs = item.inputs else { return false }
        switch inputs {
        case .directional: return true
        case .complex(let dict):
            // If it maps directional keys, it is the D-Pad visual
            let keys = dict.keys.map { $0.lowercased() }
            return keys.contains("up") && keys.contains("down")
        default: return false
        }
    }
    //dude, i need to sleep. but this has to work on 3d render efect
    private func calculateZones(representation: PSXSkinRepresentation, scaleX: CGFloat, scaleY: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> [PSXTouchZone] {
        var zones: [PSXTouchZone] = []
        
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
                            zones.append(PSXTouchZone(rect: rect, type: .menu))
                        } else if let id = mapInput(key) {
                            zones.append(PSXTouchZone(rect: rect, type: .button(id)))
                        } else if key == "fastforward" {
                             zones.append(PSXTouchZone(rect: rect, type: .button(996)))
                        }
                    }
                case .complex(let dict):
                     // Check if D-Pad or Joystick
                    if item.thumbstick != nil {
                        // It is a Joystick
                        let isLeft = isLeftJoystick(item)
                        zones.append(PSXTouchZone(rect: rect, type: .joystick(isLeft: isLeft)))
                    } else {
                        // Is D-Pad
                         let keys = dict.keys.map { $0.lowercased() }
                         if keys.contains("up") || keys.contains("down") {
                              let dpadRect = rect.insetBy(dx: -10, dy: -10)
                              zones.append(PSXTouchZone(rect: dpadRect, type: .dpad))
                         } else if keys.contains("menu") {
                             zones.append(PSXTouchZone(rect: rect, type: .menu))
                         }
                    }
                case .directional:
                    let dpadRect = rect.insetBy(dx: -50, dy: -50)
                    zones.append(PSXTouchZone(rect: dpadRect, type: .dpad))
                }
            }
        }
        return zones
    }
}

// --- Multi-Touch Logic ---

struct PSXTouchZone {
    enum ZoneType {
        case button(Int)
        case dpad
        case menu
        case joystick(isLeft: Bool)
    }
    let rect: CGRect
    let type: ZoneType
}

struct PSXSkinMultiTouchOverlay: UIViewRepresentable {
    let zones: [PSXTouchZone]
    @ObservedObject var interactionState: PSXSkinInteractionState
    
    func makeUIView(context: Context) -> PSXSkinMultiTouchView {
        let view = PSXSkinMultiTouchView()
        view.zones = zones
        view.interactionState = interactionState
        view.isMultipleTouchEnabled = true
        return view
    }
    
    func updateUIView(_ uiView: PSXSkinMultiTouchView, context: Context) {
        uiView.zones = zones
        uiView.interactionState = interactionState
    }
}

class PSXSkinMultiTouchView: UIView {
    var zones: [PSXTouchZone] = []
    var interactionState: PSXSkinInteractionState?
    
    // Track captured touches for Joysticks (Touch -> IsLeft)
    // If a touch is in this dict, it is EXCLUSIVE to that joystick.
    private var capturedJoysticks: [UITouch: Bool] = [:]
    
    private var activeButtons: Set<Int> = []
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Check for new joystick captures
        for touch in touches {
            let loc = touch.location(in: self)
            for zone in zones {
                if case .joystick(let isLeft) = zone.type, zone.rect.contains(loc) {
                    capturedJoysticks[touch] = isLeft
                    break 
                }
            }
        }
        updateInputs(touches: event?.allTouches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { updateInputs(touches: event?.allTouches) }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Release captures
        for touch in touches {
            capturedJoysticks.removeValue(forKey: touch)
        }
        updateInputs(touches: event?.allTouches)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            capturedJoysticks.removeValue(forKey: touch)
        }
        updateInputs(touches: event?.allTouches)
    }
    
    private func updateInputs(touches: Set<UITouch>?) {
        guard let touches = touches else { return }
        
        var nextButtons: Set<Int> = []
        var dpadPressed = false
        var dpadX: CGFloat = 0
        var dpadY: CGFloat = 0
        
        var leftStickOffset: CGSize = .zero
        var rightStickOffset: CGSize = .zero
        
        for touch in touches {
            let loc = touch.location(in: self)
            if touch.phase == .ended || touch.phase == .cancelled { continue }
            
            // 1. Is this touch captured by a Joystick?
            if let isLeft = capturedJoysticks[touch] {
                // Find the zone for this joystick to calculate offset
    
                for zone in zones {
                    if case .joystick(let left) = zone.type, left == isLeft {
                        // Joystick Logic
                        let center = CGPoint(x: zone.rect.midX, y: zone.rect.midY)
                        var dx = loc.x - center.x
                        var dy = loc.y - center.y
                        
                        let maxRadius = zone.rect.width / 2
                        let dist = hypot(dx, dy)
                        if dist > maxRadius {
                            dx = dx / dist * maxRadius
                            dy = dy / dist * maxRadius
                        }
                        
                        if isLeft { leftStickOffset = CGSize(width: dx, height: dy) }
                        else { rightStickOffset = CGSize(width: dx, height: dy) }
                        
                        // Input Mapping (Threshold)
                        if dist > 10 {
                            if abs(dx) > abs(dy) {
                                if dx > 0 { nextButtons.insert(PSXInput.ID_RIGHT) }
                                else { nextButtons.insert(PSXInput.ID_LEFT) }
                            } else {
                                if dy > 0 { nextButtons.insert(PSXInput.ID_DOWN) }
                                else { nextButtons.insert(PSXInput.ID_UP) }
                            }
                        }
                        break
                    }
                }
                continue
            }
            
            // 2. Standard Touch (Buttons, D-Pad) - Ignore Joystick Zones
            for zone in zones {
                if zone.rect.contains(loc) {
                    switch zone.type {
                    case .button(let id):
                         if id == 996 {
                            if touch.phase == .began {
                                if PSXCore.fastForward {
                                    PSXCore.fastForward = false
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } else {
                                    PSXCore.fastForward = true
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            }
                        } else {
                            nextButtons.insert(id)
                        }
                    case .menu:
                        if touch.phase == .began {
                            PSXSkinManager.shared.nextSkin()
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
                            
                             // Map D-Pad Directions and Visual Tilt
                            if angle >= 337.5 || angle < 22.5 { nextButtons.insert(PSXInput.ID_RIGHT); dpadY += 1 } 
                            else if angle >= 22.5 && angle < 67.5 { nextButtons.insert(PSXInput.ID_RIGHT); nextButtons.insert(PSXInput.ID_DOWN); dpadY+=1; dpadX -= 1 }
                            else if angle >= 67.5 && angle < 112.5 { nextButtons.insert(PSXInput.ID_DOWN); dpadX -= 1 } 
                            else if angle >= 112.5 && angle < 157.5 { nextButtons.insert(PSXInput.ID_DOWN); nextButtons.insert(PSXInput.ID_LEFT); dpadX -= 1; dpadY -= 1 }
                            else if angle >= 157.5 && angle < 202.5 { nextButtons.insert(PSXInput.ID_LEFT); dpadY -= 1 } 
                            else if angle >= 202.5 && angle < 247.5 { nextButtons.insert(PSXInput.ID_LEFT); nextButtons.insert(PSXInput.ID_UP); dpadY -= 1; dpadX += 1 }
                            else if angle >= 247.5 && angle < 292.5 { nextButtons.insert(PSXInput.ID_UP); dpadX += 1 } 
                            else if angle >= 292.5 && angle < 337.5 { nextButtons.insert(PSXInput.ID_UP); nextButtons.insert(PSXInput.ID_RIGHT); dpadX += 1; dpadY += 1 }
                        }
                     case .joystick:
                        // Ignore joysticks for non-captured touches to prevent accidental grabs lol i dont know how to  fix this on ther way
                        break
                    }
                }
            }
        }
        
        // Update Visual State (Main Thread)
        if let state = interactionState {
            DispatchQueue.main.async {
                state.dpadTilt = (x: dpadX, y: dpadY)
                state.leftJoystickOffset = leftStickOffset
                state.rightJoystickOffset = rightStickOffset
            }
        }
        
        // --- Input Sync Logic ---
        for id in activeButtons.subtracting(nextButtons) {
            PSXInput.shared.setButton(id, pressed: false)
        }
        
        for id in nextButtons.subtracting(activeButtons) {
            PSXInput.shared.setButton(id, pressed: true)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        activeButtons = nextButtons
    }
}
