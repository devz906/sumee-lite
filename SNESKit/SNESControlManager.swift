import SwiftUI
import Combine

public struct SNESControlPositions: Codable {
    var dpad: CGPoint = .zero
    var buttons: CGPoint = .zero
    var select: CGPoint = .zero
    var start: CGPoint = .zero
    var l: CGPoint = .zero
    var r: CGPoint = .zero

    // PORTRAIT Specific
    var dpadPortrait: CGPoint = .zero
    var buttonsPortrait: CGPoint = .zero
    var selectPortrait: CGPoint = .zero
    var startPortrait: CGPoint = .zero
    var lPortrait: CGPoint = .zero
    var rPortrait: CGPoint = .zero

    // LANDSCAPE Specific
    var dpadLandscape: CGPoint = .zero
    var buttonsLandscape: CGPoint = .zero
    var selectLandscape: CGPoint = .zero
    var startLandscape: CGPoint = .zero
    var lLandscape: CGPoint = .zero
    var rLandscape: CGPoint = .zero
}

public class SNESControlManager: ObservableObject {
    public static let shared = SNESControlManager()
    
    @Published public var positions: SNESControlPositions = SNESControlPositions()
    @Published public var isEditing: Bool = false
    
    private let kStorageKey = "SNESControlConfig"
    
    private init() {
        loadConfig()
    }
    
    public func saveConfig() {
        if let data = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(data, forKey: kStorageKey)
            print(" [SNESControls] Config saved.")
        }
    }
    
    public func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: kStorageKey),
           let decoded = try? JSONDecoder().decode(SNESControlPositions.self, from: data) {
            self.positions = decoded
            print(" [SNESControls] Config loaded.")
        } else {
            print(" [SNESControls] No saved config, using defaults.")
        }
    }
    
    public func resetConfig() {
        withAnimation {
            positions = SNESControlPositions()
        }
        saveConfig()
        print("bff [SNESControls] Config reset to Default.")
    }
    
    public func updatePosition(_ key: WritableKeyPath<SNESControlPositions, CGPoint>, value: CGPoint) {
        positions[keyPath: key] = value
    }
}
