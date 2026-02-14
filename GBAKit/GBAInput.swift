import Foundation
import Combine
import GameController


class GBAInput: ObservableObject {
    static let shared = GBAInput()
    
    @Published var isControllerConnected = false
    var buttonMask: UInt16 = 0
    private var virtualButtonMask: UInt16 = 0
    
  
    private var currentController: GCController?
    
    // IDs RetroPad
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
        virtualButtonMask &= ~((1 << Self.ID_A) | (1 << Self.ID_B)) 
        for id in pressedIDs {
            virtualButtonMask |= (1 << id)
        }
    }

    func setButton(_ id: Int, pressed: Bool) {
        if pressed {
            virtualButtonMask |= (1 << id)
        } else {
            virtualButtonMask &= ~(1 << id)
        }
    }
    
    func pollInput() {
        var mask: UInt16 = 0
        

        for controller in GCController.controllers() {
            guard let gamepad = controller.extendedGamepad else { continue }
            
            // Buttons

            if ControllerMappingManager.shared.isPressed(GBAAction.a, gamepad: gamepad, console: "Game Boy Advance") { mask |= (1 << Self.ID_A) }
            if ControllerMappingManager.shared.isPressed(GBAAction.b, gamepad: gamepad, console: "Game Boy Advance") { mask |= (1 << Self.ID_B) }
            if ControllerMappingManager.shared.isPressed(GBAAction.l, gamepad: gamepad, console: "Game Boy Advance") { mask |= (1 << Self.ID_L) }
            if ControllerMappingManager.shared.isPressed(GBAAction.r, gamepad: gamepad, console: "Game Boy Advance") { mask |= (1 << Self.ID_R) }
            if ControllerMappingManager.shared.isPressed(GBAAction.start, gamepad: gamepad, console: "Game Boy Advance") { mask |= (1 << Self.ID_START) }
            if ControllerMappingManager.shared.isPressed(GBAAction.select, gamepad: gamepad, console: "Game Boy Advance") { mask |= (1 << Self.ID_SELECT) }
            
            // Directions
            if ControllerMappingManager.shared.isPressed(GBAAction.up, gamepad: gamepad, console: "Game Boy Advance") { mask |= (1 << Self.ID_UP) }
            if ControllerMappingManager.shared.isPressed(GBAAction.down, gamepad: gamepad, console: "Game Boy Advance") { mask |= (1 << Self.ID_DOWN) }
            if ControllerMappingManager.shared.isPressed(GBAAction.left, gamepad: gamepad, console: "Game Boy Advance") { mask |= (1 << Self.ID_LEFT) }
            if ControllerMappingManager.shared.isPressed(GBAAction.right, gamepad: gamepad, console: "Game Boy Advance") { mask |= (1 << Self.ID_RIGHT) }
        }
        
     
        self.buttonMask = mask | virtualButtonMask
    }
    
    // ---   GameController ---
    
    private func setupControllerObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDidConnect), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDidDisconnect), name: .GCControllerDidDisconnect, object: nil)
        
        if let controller = GCController.controllers().first {
            setupController(controller)
        }
    }
    
    @objc private func controllerDidConnect(_ notification: Notification) {
        checkConnections()
    }
    
    @objc private func controllerDidDisconnect(_ notification: Notification) {
        checkConnections()
    }
    
    private func setupController(_ controller: GCController) {
        // Legacy method kept for structure, but main logic is in checkConnections
        checkConnections()
    }
    
    private func checkConnections() {
        let controllers = GCController.controllers()
        isControllerConnected = !controllers.isEmpty
        currentController = controllers.first
        if isControllerConnected {
             print(" [GBAInput] Controladores activos: \(controllers.count)")
        } else {
             print(" [GBAInput] Sin controladores.")
        }
    }
}
