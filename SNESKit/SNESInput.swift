import Foundation
import Combine
import GameController

class SNESInput: ObservableObject {
    static let shared = SNESInput()
    
    @Published var isControllerConnected = false
    
    // Masks
    private var touchMask: UInt16 = 0
    private var physicalMask: UInt16 = 0
    
    var buttonMask: UInt16 {
        return touchMask | physicalMask
    }
    
    private var currentController: GCController?
    
 
    // https://docs.libretro.com/library/snes9x/

    static let ID_B: Int = 0
    static let ID_Y: Int = 1
    static let ID_SELECT: Int = 2
    static let ID_START: Int = 3
    static let ID_UP: Int = 4
    static let ID_DOWN: Int = 5
    static let ID_LEFT: Int = 6
    static let ID_RIGHT: Int = 7
    static let ID_A: Int = 8
    static let ID_X: Int = 9
    static let ID_L: Int = 10
    static let ID_R: Int = 11
    
    private init() {
        setupControllerObserver()
    }
    
    func updateActionButtons(_ pressedIDs: Set<Int>) {
        // Clear A, B, X, Y
        touchMask &= ~((UInt16(1) << Self.ID_B) | (UInt16(1) << Self.ID_Y) | (UInt16(1) << Self.ID_A) | (UInt16(1) << Self.ID_X))
        
        // Set new buttons
        for id in pressedIDs {
            touchMask |= (UInt16(1) << id)
        }
    }
    
    func setButton(_ id: Int, pressed: Bool) {
        if pressed {
            touchMask |= (UInt16(1) << id)
        } else {
            touchMask &= ~(UInt16(1) << id)
        }
    }
    
    // MARK: - GameController Support
    
    private func setupControllerObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDidConnect), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDidDisconnect), name: .GCControllerDidDisconnect, object: nil)
        
        if let controller = GCController.controllers().first {
            setupController(controller)
        }
    }
    
    @objc private func controllerDidConnect(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            setupController(controller)
        }
    }
    
    @objc private func controllerDidDisconnect(_ notification: Notification) {
        isControllerConnected = false
        currentController = nil
        print("🎮 [SNESInput] Controller disconnected")
    }
    
    private func setupController(_ controller: GCController) {
        print("🎮 [SNESInput] Controller assigned: \(controller.vendorName ?? "Generic")")
        currentController = controller
        isControllerConnected = true
    }
    
    // Polling Method
    func pollInput() {
        physicalMask = 0
        guard let controller = currentController, let gamepad = controller.extendedGamepad else { return }
        
        // Mapping Physical -> SNES
        // Dynamic Mappings via ControllerMappingManager
        
        if ControllerMappingManager.shared.isPressed(SNESAction.a, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_A) }
        if ControllerMappingManager.shared.isPressed(SNESAction.b, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_B) }
        if ControllerMappingManager.shared.isPressed(SNESAction.x, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_X) }
        if ControllerMappingManager.shared.isPressed(SNESAction.y, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_Y) }
        
        if ControllerMappingManager.shared.isPressed(SNESAction.l, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_L) }
        if ControllerMappingManager.shared.isPressed(SNESAction.r, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_R) }
        
        if ControllerMappingManager.shared.isPressed(SNESAction.start, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_START) }
        if ControllerMappingManager.shared.isPressed(SNESAction.select, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_SELECT) }
        
        // Directions (Mapped via Manager)
        if ControllerMappingManager.shared.isPressed(SNESAction.up, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_UP) }
        if ControllerMappingManager.shared.isPressed(SNESAction.down, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_DOWN) }
        if ControllerMappingManager.shared.isPressed(SNESAction.left, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_LEFT) }
        if ControllerMappingManager.shared.isPressed(SNESAction.right, gamepad: gamepad, console: "SNES") { physicalMask |= (1 << Self.ID_RIGHT) }
        
        // Fast Forward (Non-Standard Input)

        if ControllerMappingManager.shared.isPressed(SNESAction.fastForward, gamepad: gamepad, console: "SNES") {
            SNESCore.fastForward = true
        } else if SNESCore.fastForward {

            SNESCore.fastForward = false
        }
    }
}
