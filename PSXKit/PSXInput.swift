import Foundation
import Combine
import GameController


class PSXInput: ObservableObject {
    static let shared = PSXInput()
    
    @Published var isControllerConnected = false
    
    @Published var pressedButtons: Set<Int> = []
    
    // Split masks to allow mixed input (Touch + Physical)
    private var touchMask: UInt16 = 0
    private var physicalMask: UInt16 = 0
    
    // Computed property used by the Core
    var buttonMask: UInt16 {
        return touchMask | physicalMask
    }
    

    private var currentController: GCController?
    
    // IDs de RetroPad (estándar Libretro for PSX)
    // https://docs.libretro.com/guides/input-and-controls/
    static let ID_B: Int = 0        // Cross (X)
    static let ID_Y: Int = 1        // Square (Cuadrado)
    static let ID_SELECT: Int = 2
    static let ID_START: Int = 3
    static let ID_UP: Int = 4
    static let ID_DOWN: Int = 5
    static let ID_LEFT: Int = 6
    static let ID_RIGHT: Int = 7
    static let ID_A: Int = 8        // Circle (Círculo)
    static let ID_X: Int = 9        // Triangle (Triángulo)
    static let ID_L: Int = 10       // L1
    static let ID_R: Int = 11       // R1
    static let ID_L2: Int = 12      // L2
    static let ID_R2: Int = 13      // R2
    static let ID_L3: Int = 14      // L3 (Click Stick Izq)
    static let ID_R3: Int = 15      // R3 (Click Stick Der)
    
    private init() {
        setupControllerObserver()
    }
    
    func updateActionButtons(_ pressedIDs: Set<Int>) {
        // Clear Action Buttons (Cross, Square, Circle, Triangle)
        touchMask &= ~((1 << Self.ID_B) | (1 << Self.ID_Y) | (1 << Self.ID_A) | (1 << Self.ID_X))
        
        // Remove from pressedButtons first
        pressedButtons.remove(Self.ID_B)
        pressedButtons.remove(Self.ID_Y)
        pressedButtons.remove(Self.ID_A)
        pressedButtons.remove(Self.ID_X)
        
        // Set Active Buttons
        for id in pressedIDs {
            touchMask |= (1 << id)
            pressedButtons.insert(id)
        }
    }
    
    func setButton(_ id: Int, pressed: Bool) {
        if pressed {
            touchMask |= (1 << id)
            pressedButtons.insert(id)
        } else {
            touchMask &= ~(1 << id)
            pressedButtons.remove(id)
        }
    }
    

    
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
        print(" [PSXInput] Mando desconectado")
    }
    
    private func setupController(_ controller: GCController) {
        print(" [PSXInput] Controller assigned for Polling: \(controller.vendorName ?? "Generic")")
        currentController = controller
        isControllerConnected = true
    }
    
    // Polling Method called by Core every frame
    func pollInput() {
        physicalMask = 0
        guard let controller = currentController, let gamepad = controller.extendedGamepad else { return }
        
        // Mapeo Físico -> RetroPad (PSX)
        // Dynamic Mappings via ControllerMappingManager
        
        if ControllerMappingManager.shared.isPressed(PSXAction.cross, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_B) }
        if ControllerMappingManager.shared.isPressed(PSXAction.circle, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_A) }
        if ControllerMappingManager.shared.isPressed(PSXAction.square, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_Y) }
        if ControllerMappingManager.shared.isPressed(PSXAction.triangle, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_X) }
        
        if ControllerMappingManager.shared.isPressed(PSXAction.l1, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_L) }
        if ControllerMappingManager.shared.isPressed(PSXAction.r1, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_R) }
        
        if ControllerMappingManager.shared.isPressed(PSXAction.l2, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_L2) }
        if ControllerMappingManager.shared.isPressed(PSXAction.r2, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_R2) }
        
        if ControllerMappingManager.shared.isPressed(PSXAction.start, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_START) }
        if ControllerMappingManager.shared.isPressed(PSXAction.select, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_SELECT) }
        
        // Directions (Mapped via Manager)
        if ControllerMappingManager.shared.isPressed(PSXAction.up, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_UP) }
        if ControllerMappingManager.shared.isPressed(PSXAction.down, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_DOWN) }
        if ControllerMappingManager.shared.isPressed(PSXAction.left, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_LEFT) }
        if ControllerMappingManager.shared.isPressed(PSXAction.right, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_RIGHT) }
        
        if ControllerMappingManager.shared.isPressed(PSXAction.l3, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_L3) }
        if ControllerMappingManager.shared.isPressed(PSXAction.r3, gamepad: gamepad, console: "PlayStation") { physicalMask |= (1 << Self.ID_R3) }
    }
}
