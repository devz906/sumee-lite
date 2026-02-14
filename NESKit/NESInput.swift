import Foundation
import Combine
import GameController

class NESInput: ObservableObject {
    static let shared = NESInput()
    
    @Published var isControllerConnected = false
    
    // Masks
    private var touchMask: UInt16 = 0
    private var physicalMask: UInt16 = 0
    
    var buttonMask: UInt16 {
        return touchMask | physicalMask
    }
    
    private var currentController: GCController?
    
    // NES RetroPad Mapping
    // B = 0, Y = 1 (unused), Select = 2, Start = 3, Up = 4, Down = 5, Left = 6, Right = 7
    // A = 8, X = 9 (unused), L = 10 (unused), R = 11 (unused)
    static let ID_B: Int = 0
    static let ID_Y: Int = 1      // Not used on NES
    static let ID_SELECT: Int = 2
    static let ID_START: Int = 3
    static let ID_UP: Int = 4
    static let ID_DOWN: Int = 5
    static let ID_LEFT: Int = 6
    static let ID_RIGHT: Int = 7
    static let ID_A: Int = 8
    static let ID_X: Int = 9      // Not used on NES
    static let ID_L: Int = 10     // Not used on NES
    static let ID_R: Int = 11     // Not used on NES
    
    private init() {
        setupControllerObserver()
    }
    
    func updateActionButtons(_ pressedIDs: Set<Int>) {
        touchMask &= ~((UInt16(1) << Self.ID_A) | (UInt16(1) << Self.ID_B))
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
        print(" [NESInput] Controller disconnected")
    }
    
    private func setupController(_ controller: GCController) {
        print(" [NESInput] Controller assigned: \(controller.vendorName ?? "Generic")")
        currentController = controller
        isControllerConnected = true
    }
    
    // Polling Method
    func pollInput() {
        physicalMask = 0
        guard let controller = currentController, let gamepad = controller.extendedGamepad else { return }
        
        // Mapping Physical -> NES
        // Dynamic Mappings via ControllerMappingManager
        
        if ControllerMappingManager.shared.isPressed(NESAction.a, gamepad: gamepad, console: "NES") { physicalMask |= (1 << Self.ID_A) }
        if ControllerMappingManager.shared.isPressed(NESAction.b, gamepad: gamepad, console: "NES") { physicalMask |= (1 << Self.ID_B) }
        
        if ControllerMappingManager.shared.isPressed(NESAction.start, gamepad: gamepad, console: "NES") { physicalMask |= (1 << Self.ID_START) }
        if ControllerMappingManager.shared.isPressed(NESAction.select, gamepad: gamepad, console: "NES") { physicalMask |= (1 << Self.ID_SELECT) }
        
        // Directions (Mapped via Manager)
        if ControllerMappingManager.shared.isPressed(NESAction.up, gamepad: gamepad, console: "NES") { physicalMask |= (1 << Self.ID_UP) }
        if ControllerMappingManager.shared.isPressed(NESAction.down, gamepad: gamepad, console: "NES") { physicalMask |= (1 << Self.ID_DOWN) }
        if ControllerMappingManager.shared.isPressed(NESAction.left, gamepad: gamepad, console: "NES") { physicalMask |= (1 << Self.ID_LEFT) }
        if ControllerMappingManager.shared.isPressed(NESAction.right, gamepad: gamepad, console: "NES") { physicalMask |= (1 << Self.ID_RIGHT) }
    }
}
