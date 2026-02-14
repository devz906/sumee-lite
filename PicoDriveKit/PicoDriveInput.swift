import Foundation
import Combine
import GameController

class PicoDriveInput: ObservableObject {
    static let shared = PicoDriveInput()
    
    @Published var isControllerConnected = false
    
    // Masks
    private var touchMask: UInt16 = 0
    private var physicalMask: UInt16 = 0
    
    var buttonMask: UInt16 {
        return touchMask | physicalMask
    }
    
    private var currentController: GCController?
    
    // Libretro Retropad Mapping for Genesis (PicoDrive)
    // Common Defaults:
    // B -> A
    // A -> B
    // Y -> C (or X in 6-button)
    // X -> Y
    // L -> X
    // R -> Z
    // Select -> Mode
    // Start -> Start
    
    static let ID_B: Int = 0      // Genesis A
    static let ID_Y: Int = 1      // Genesis C
    static let ID_SELECT: Int = 2 // Mode
    static let ID_START: Int = 3  // Start
    static let ID_UP: Int = 4
    static let ID_DOWN: Int = 5
    static let ID_LEFT: Int = 6
    static let ID_RIGHT: Int = 7
    static let ID_A: Int = 8      // Genesis B
    static let ID_X: Int = 9      // Genesis Y
    static let ID_L: Int = 10     // Genesis X
    static let ID_R: Int = 11     // Genesis Z
    
    private init() {
        setupControllerObserver()
    }
    
    func updateActionButtons(_ pressedIDs: Set<Int>) {
        touchMask &= ~((UInt16(1) << Self.ID_A) | (UInt16(1) << Self.ID_B) | (UInt16(1) << Self.ID_Y))
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
        print("🎮 [PicoDriveInput] Controller disconnected")
    }
    
    private func setupController(_ controller: GCController) {
        print("🎮 [PicoDriveInput] Controller assigned: \(controller.vendorName ?? "Generic")")
        currentController = controller
        isControllerConnected = true
    }
    
    // Polling Method
    func pollInput() {
        physicalMask = 0
        guard let controller = currentController, let gamepad = controller.extendedGamepad else { return }
        
        // Mapping Physical -> Retropad -> Genesis
        // Xbox A -> Retropad A -> Genesis B
        // Xbox B -> Retropad B -> Genesis A
        // Xbox X -> Retropad Y -> Genesis C
        // Xbox Y -> Retropad X -> Genesis Y
        
        // Mapping Physical -> Retropad -> Genesis
        // Dynamic Mappings via ControllerMappingManager
        
        // Genesis A (ID 0 / Retropad B)
        if ControllerMappingManager.shared.isPressed(GenesisAction.a, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_B) }
        // Genesis B (ID 8 / Retropad A)
        if ControllerMappingManager.shared.isPressed(GenesisAction.b, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_A) }
        // Genesis C (ID 1 / Retropad Y)
        if ControllerMappingManager.shared.isPressed(GenesisAction.c, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_Y) }
        
        // 6-Button Extras
        // Genesis X (ID 10 / Retropad L)
        if ControllerMappingManager.shared.isPressed(GenesisAction.x, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_L) }
        // Genesis Y (ID 9 / Retropad X)
        if ControllerMappingManager.shared.isPressed(GenesisAction.y, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_X) }
        // Genesis Z (ID 11 / Retropad R)
        if ControllerMappingManager.shared.isPressed(GenesisAction.z, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_R) }
        
        if ControllerMappingManager.shared.isPressed(GenesisAction.start, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_START) }
        if ControllerMappingManager.shared.isPressed(GenesisAction.mode, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_SELECT) }
        
        // Directions (Mapped via Manager)
        if ControllerMappingManager.shared.isPressed(GenesisAction.up, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_UP) }
        if ControllerMappingManager.shared.isPressed(GenesisAction.down, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_DOWN) }
        if ControllerMappingManager.shared.isPressed(GenesisAction.left, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_LEFT) }
        if ControllerMappingManager.shared.isPressed(GenesisAction.right, gamepad: gamepad, console: "Sega Genesis") { physicalMask |= (1 << Self.ID_RIGHT) }
    }
}
