import Foundation
import GameController
import SwiftUI
import Combine



// Identifiers for physical controller inputs
public enum ControllerInput: String, CaseIterable, Codable {
    case none = "None"
    case buttonA = "Button A"
    case buttonB = "Button B"
    case buttonX = "Button X"
    case buttonY = "Button Y"
    case leftShoulder = "Left Shoulder (L1)"
    case rightShoulder = "Right Shoulder (R1)"
    case leftTrigger = "Left Trigger (L2)"
    case rightTrigger = "Right Trigger (R2)"
    case buttonMenu = "Menu / Start"
    case buttonOptions = "Options / Select"
    case dpadUp = "D-Pad Up"
    case dpadDown = "D-Pad Down"
    case dpadLeft = "D-Pad Left"
    case dpadRight = "D-Pad Right"
    case leftThumbstickUp = "Left Stick Up"
    case leftThumbstickDown = "Left Stick Down"
    case leftThumbstickLeft = "Left Stick Left"
    case leftThumbstickRight = "Left Stick Right"
    case leftThumbstickButton = "L3 (Stick Button)"
    case rightThumbstickButton = "R3 (Stick Button)"
    
    // Helper to check state on a gamepad
    func isPressed(on gamepad: GCExtendedGamepad) -> Bool {
        switch self {
        case .none: return false
        case .buttonA: return gamepad.buttonA.isPressed
        case .buttonB: return gamepad.buttonB.isPressed
        case .buttonX: return gamepad.buttonX.isPressed
        case .buttonY: return gamepad.buttonY.isPressed
        case .leftShoulder: return gamepad.leftShoulder.isPressed
        case .rightShoulder: return gamepad.rightShoulder.isPressed
        case .leftTrigger: return gamepad.leftTrigger.isPressed
        case .rightTrigger: return gamepad.rightTrigger.isPressed
        case .buttonMenu: return gamepad.buttonMenu.isPressed
        case .buttonOptions: return gamepad.buttonOptions?.isPressed == true
        case .dpadUp: return gamepad.dpad.up.isPressed
        case .dpadDown: return gamepad.dpad.down.isPressed
        case .dpadLeft: return gamepad.dpad.left.isPressed
        case .dpadRight: return gamepad.dpad.right.isPressed
        // Increased threshold from 0.5 to 0.65 to prevent accidental diagonals (e.g. slight Up when moving Right)
        case .leftThumbstickUp: return gamepad.leftThumbstick.yAxis.value > 0.65
        case .leftThumbstickDown: return gamepad.leftThumbstick.yAxis.value < -0.65
        case .leftThumbstickLeft: return gamepad.leftThumbstick.xAxis.value < -0.65
        case .leftThumbstickRight: return gamepad.leftThumbstick.xAxis.value > 0.65
        case .leftThumbstickButton: return gamepad.leftThumbstickButton?.isPressed ?? false
        case .rightThumbstickButton: return gamepad.rightThumbstickButton?.isPressed ?? false
        }
    }
}

// Helper Protocol for Actions
public protocol ConsoleAction: RawRepresentable, CaseIterable, Identifiable where RawValue == Int {
    var name: String { get }
    var defaultInput: ControllerInput { get }
    var secondaryDefaultInput: ControllerInput? { get }
}

// Actions specific to GBA
public enum GBAAction: Int, ConsoleAction, Codable {
    case a = 0
    case b = 1
    case l = 2
    case r = 3
    case start = 4
    case select = 5
    case up = 6
    case down = 7
    case left = 8
    case right = 9
    case fastForward = 10
    
    public var id: Int { rawValue }
    
    public var name: String {
        switch self {
        case .a: return "Button A"
        case .b: return "Button B"
        case .l: return "L Button"
        case .r: return "R Button"
        case .start: return "Start"
        case .select: return "Select"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .fastForward: return "Fast Forward"
        }
    }
    
    // Default mappings (Smart Layout)
    public var defaultInput: ControllerInput {
        switch self {
        case .a: return .buttonB // Xbox B -> GBA A (East)
        case .b: return .buttonA // Xbox A -> GBA B (South)
        case .l: return .leftShoulder
        case .r: return .rightShoulder
        case .start: return .buttonMenu
        case .select: return .buttonOptions
        case .up: return .dpadUp
        case .down: return .dpadDown
        case .left: return .dpadLeft
        case .right: return .dpadRight
        case .fastForward: return .none
        }
    }
    
    public var secondaryDefaultInput: ControllerInput? {
        switch self {
        case .a: return .buttonY // Xbox Y -> GBA A (North)
        case .b: return .buttonX // Xbox X -> GBA B (West)
        case .up: return .leftThumbstickUp
        case .down: return .leftThumbstickDown
        case .left: return .leftThumbstickLeft
        case .right: return .leftThumbstickRight
        case .fastForward: return nil
        default: return nil
        }
    }
}

// Actions specific to DS
public enum DSAction: Int, ConsoleAction, Codable {
    case a = 0
    case b = 1
    case x = 2
    case y = 3
    case l = 4
    case r = 5
    case start = 6
    case select = 7
    case up = 8
    case down = 9
    case left = 10
    case right = 11
    case fastForward = 12
    
    public var id: Int { rawValue }
    
    public var name: String {
        switch self {
        case .a: return "Button A"
        case .b: return "Button B"
        case .x: return "Button X"
        case .y: return "Button Y"
        case .l: return "L Button"
        case .r: return "R Button"
        case .start: return "Start"
        case .select: return "Select"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .fastForward: return "Fast Forward"
        }
    }
    
    public var defaultInput: ControllerInput {
        switch self {
        case .a: return .buttonB // Xbox B -> DS A (East)
        case .b: return .buttonA // Xbox A -> DS B (South)
        case .x: return .buttonY // Xbox Y -> DS X (North)
        case .y: return .buttonX // Xbox X -> DS Y (West)
        case .l: return .leftShoulder
        case .r: return .rightShoulder
        case .start: return .buttonMenu
        case .select: return .buttonOptions
        case .up: return .dpadUp
        case .down: return .dpadDown
        case .left: return .dpadLeft
        case .right: return .dpadRight
        case .fastForward: return .none
        }
    }
    
    public var secondaryDefaultInput: ControllerInput? {
        switch self {
        case .up: return .leftThumbstickUp
        case .down: return .leftThumbstickDown
        case .left: return .leftThumbstickLeft
        case .right: return .leftThumbstickRight
        case .fastForward: return nil
        default: return nil
        }
    }
}

// Actions specific to NES
public enum NESAction: Int, ConsoleAction, Codable {
    case a = 0
    case b = 1
    case start = 2
    case select = 3
    case up = 4
    case down = 5
    case left = 6
    case right = 7
    case fastForward = 8
    
    public var id: Int { rawValue }
    
    public var name: String {
        switch self {
        case .a: return "Button A"
        case .b: return "Button B"
        case .start: return "Start"
        case .select: return "Select"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .fastForward: return "Fast Forward"
        }
    }
    
    public var defaultInput: ControllerInput {
        switch self {
        case .a: return .buttonB // Xbox B -> NES A (East)
        case .b: return .buttonA // Xbox A -> NES B (South)
        case .start: return .buttonMenu
        case .select: return .buttonOptions
        case .up: return .dpadUp
        case .down: return .dpadDown
        case .left: return .dpadLeft
        case .right: return .dpadRight
        case .fastForward: return .none
        }
    }
    
    public var secondaryDefaultInput: ControllerInput? {
        switch self {
        case .a: return .buttonY // Xbox Y -> NES A (North)
        case .b: return .buttonX // Xbox X -> NES B (West)
        case .up: return .leftThumbstickUp
        case .down: return .leftThumbstickDown
        case .left: return .leftThumbstickLeft
        case .right: return .leftThumbstickRight
        case .fastForward: return nil
        default: return nil
        }
    }
}

// Actions specific to SNES
public enum SNESAction: Int, ConsoleAction, Codable {
    case a = 0
    case b = 1
    case x = 2
    case y = 3
    case l = 4
    case r = 5
    case start = 6
    case select = 7
    case up = 8
    case down = 9
    case left = 10
    case right = 11
    case fastForward = 12
    
    public var id: Int { rawValue }
    
    public var name: String {
        switch self {
        case .a: return "Button A"
        case .b: return "Button B"
        case .x: return "Button X"
        case .y: return "Button Y"
        case .l: return "L Button"
        case .r: return "R Button"
        case .start: return "Start"
        case .select: return "Select"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .fastForward: return "Fast Forward"
        }
    }
    
    public var defaultInput: ControllerInput {
        switch self {
        case .a: return .buttonB
        case .b: return .buttonA
        case .x: return .buttonY
        case .y: return .buttonX
        case .l: return .leftShoulder
        case .r: return .rightShoulder
        case .start: return .buttonMenu
        case .select: return .buttonOptions
        case .up: return .dpadUp
        case .down: return .dpadDown
        case .left: return .dpadLeft
        case .right: return .dpadRight
        case .fastForward: return .none
        }
    }
    
    public var secondaryDefaultInput: ControllerInput? {
        switch self {
        case .up: return .leftThumbstickUp
        case .down: return .leftThumbstickDown
        case .left: return .leftThumbstickLeft
        case .right: return .leftThumbstickRight
        case .fastForward: return nil
        default: return nil
        }
    }
}

// Actions specific to PlayStation
public enum PSXAction: Int, ConsoleAction, Codable {
    case cross = 0
    case circle = 1
    case square = 2
    case triangle = 3
    case l1 = 4
    case r1 = 5
    case l2 = 6
    case r2 = 7
    case start = 8
    case select = 9
    case l3 = 10
    case r3 = 11
    case up = 12
    case down = 13
    case left = 14
    case right = 15
    case fastForward = 16
    
    public var id: Int { rawValue }
    
    public var name: String {
        switch self {
        case .cross: return "Cross (X)"
        case .circle: return "Circle (O)"
        case .square: return "Square ([])"
        case .triangle: return "Triangle (^)"
        case .l1: return "L1 Button"
        case .r1: return "R1 Button"
        case .l2: return "L2 Button"
        case .r2: return "R2 Button"
        case .start: return "Start"
        case .select: return "Select"
        case .l3: return "L3 (Left Stick)"
        case .r3: return "R3 (Right Stick)"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .fastForward: return "Fast Forward"
        }
    }
    
    public var defaultInput: ControllerInput {
        switch self {
        case .cross: return .buttonA      // Xbox A -> PS Cross
        case .circle: return .buttonB     // Xbox B -> PS Circle
        case .square: return .buttonX     // Xbox X -> PS Square
        case .triangle: return .buttonY   // Xbox Y -> PS Triangle
        case .l1: return .leftShoulder
        case .r1: return .rightShoulder
        case .l2: return .leftTrigger
        case .r2: return .rightTrigger
        case .start: return .buttonMenu
        case .select: return .buttonOptions
        case .l3: return .leftThumbstickButton
        case .r3: return .rightThumbstickButton
        case .up: return .dpadUp
        case .down: return .dpadDown
        case .left: return .dpadLeft
        case .right: return .dpadRight
        case .fastForward: return .none
        }
    }
    
    public var secondaryDefaultInput: ControllerInput? {
        switch self {
        case .up: return .leftThumbstickUp
        case .down: return .leftThumbstickDown
        case .left: return .leftThumbstickLeft
        case .right: return .leftThumbstickRight
        case .fastForward: return nil
        default: return nil
        }
    }
}

// Actions specific to Sega Genesis / Mega Drive (PicoDrive)
public enum GenesisAction: Int, ConsoleAction, Codable {
    case a = 0
    case b = 1
    case c = 2
    case x = 3
    case y = 4
    case z = 5
    case start = 6
    case mode = 7
    case up = 8
    case down = 9
    case left = 10
    case right = 11
    case fastForward = 12
    
    public var id: Int { rawValue }
    
    public var name: String {
        switch self {
        case .a: return "Button A"
        case .b: return "Button B"
        case .c: return "Button C"
        case .x: return "Button X"
        case .y: return "Button Y"
        case .z: return "Button Z"
        case .start: return "Start"
        case .mode: return "Mode"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .fastForward: return "Fast Forward"
        }
    }
    
    public var defaultInput: ControllerInput {
        switch self {
        case .a: return .buttonB       // Xbox B -> Genesis A
        case .b: return .buttonA       // Xbox A -> Genesis B
        case .c: return .buttonX       // Xbox X -> Genesis C
        case .x: return .leftShoulder  // L1 -> Genesis X
        case .y: return .buttonY       // Xbox Y -> Genesis Y
        case .z: return .rightShoulder // R1 -> Genesis Z
        case .start: return .buttonMenu
        case .mode: return .buttonOptions
        case .up: return .dpadUp
        case .down: return .dpadDown
        case .left: return .dpadLeft
        case .right: return .dpadRight
        case .fastForward: return .none
        }
    }
    
    public var secondaryDefaultInput: ControllerInput? {
        // Allow Stick as Secondary for Directions
        switch self {
        case .up: return .leftThumbstickUp
        case .down: return .leftThumbstickDown
        case .left: return .leftThumbstickLeft
        case .right: return .leftThumbstickRight
        case .fastForward: return nil
        default: return nil
        }
    }
}

class ControllerMappingManager: ObservableObject {
    static let shared = ControllerMappingManager()
    
    // Storage: [ConsoleName : [ActionID : [ControllerInput]]] (Array for Combo support)
    @Published var mappings: [String : [Int : [ControllerInput]]] = [:]
    
    private let kStorageKey = "ControllerMappings"
    private let kFileName = "controller_mappings.json"
    
    // File URL for JSON storage
    private var mappingsFileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documentsDirectory.appendingPathComponent(kFileName)
    }
    
    private init() {
        loadMappings()
    }
    
    func loadMappings() {
        // 1. Try loading from JSON File (New Standard)
        if let url = mappingsFileURL, let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode([String : [Int : [ControllerInput]]].self, from: data) {
                self.mappings = decoded
                print("[ControllerMappingManager] Loaded mappings from JSON file.")
                return
            }
        }
        
  
        // If file doesn't exist, we start fresh (empty mappings = defaults).
        print(" [ControllerMappingManager] No custom mappings file found. Using defaults.")
    }
    
    func saveMappings() {
        guard let url = mappingsFileURL else { return }
        
       
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        if let data = try? encoder.encode(mappings) {
            do {
                try data.write(to: url)
              
                print(" [ControllerMappingManager] Saved mappings to \(url.path)")
            } catch {
                print(" [ControllerMappingManager] Failed to save mappings: \(error.localizedDescription)")
            }
        }
    }
    
    // Get Mapped Inputs (Returns Array)
    func getInputs<T: ConsoleAction>(for action: T, console: String) -> [ControllerInput] {
        if let customInputs = mappings[console]?[action.rawValue] {
            return customInputs
        }
        return [action.defaultInput]
    }
    
    // Helper for UI Label (e.g. "Button A + Button B")
    func getInputLabel<T: ConsoleAction>(for action: T, console: String) -> String {
        let inputs = getInputs(for: action, console: console)
        if inputs.isEmpty { return "None" }
        return inputs.map { $0.rawValue }.joined(separator: " + ")
    }
    
    // Check if Action is Pressed (Supports Combos)
    func isPressed<T: ConsoleAction>(_ action: T, gamepad: GCExtendedGamepad, console: String) -> Bool {
        // 1. Check Custom Mapping
        if let customInputs = mappings[console]?[action.rawValue] {
             if customInputs.isEmpty { return false }
             // ALL inputs must be pressed for a combo to trigger
             return customInputs.allSatisfy { $0.isPressed(on: gamepad) }
        }
        
        // 2. Default Defaults
        // Check primary default
        if action.defaultInput.isPressed(on: gamepad) { return true }
        
        // Check secondary default (if exists)
        if let secondary = action.secondaryDefaultInput, secondary.isPressed(on: gamepad) { return true }
        
        return false
    }
    
    // Set Mapping (Supports Arrays)
    func setMapping<T: ConsoleAction>(for action: T, inputs: [ControllerInput], console: String) {
        if mappings[console] == nil {
            mappings[console] = [:]
        }
        mappings[console]?[action.rawValue] = inputs
        saveMappings()
    }
    
    func resetToDefaults(console: String) {
        mappings[console] = nil
        saveMappings()
    }
}
