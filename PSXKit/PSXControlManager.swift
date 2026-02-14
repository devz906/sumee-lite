import SwiftUI
import Combine

public struct PSXControlPositions: Codable {
    var dpad: CGPoint = .zero
    var faceButtons: CGPoint = .zero
    var select: CGPoint = .zero
    var start: CGPoint = .zero
    var lCluster: CGPoint = .zero // L1 + L2
    var rCluster: CGPoint = .zero // R1 + R2
    
    // PORTRAIT Specific
    var dpadPortrait: CGPoint = .zero
    var faceButtonsPortrait: CGPoint = .zero
    var selectPortrait: CGPoint = .zero
    var startPortrait: CGPoint = .zero
    var lClusterPortrait: CGPoint = .zero
    var rClusterPortrait: CGPoint = .zero
    
    // LANDSCAPE Specific
    var dpadLandscape: CGPoint = .zero
    var faceButtonsLandscape: CGPoint = .zero
    var selectLandscape: CGPoint = .zero
    var startLandscape: CGPoint = .zero
    var lClusterLandscape: CGPoint = .zero
    var rClusterLandscape: CGPoint = .zero
    
    // SCREEN Customization
    var screenScalePortrait: CGFloat = 1.0
    var screenPositionPortrait: CGPoint = .zero
    
    var screenScaleLandscape: CGFloat = 1.0
    var screenPositionLandscape: CGPoint = .zero
}

public class PSXControlManager: ObservableObject {
    public static let shared = PSXControlManager()
    
    @Published public var positions: PSXControlPositions = PSXControlPositions()
    @Published public var isEditing: Bool = false
    
    private let kStorageKey = "PSXControlConfig"
    
    private init() {
        loadConfig()
    }
    
    public func saveConfig() {
        if let data = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(data, forKey: kStorageKey)
            print(" [PSXControls] Config saved.")
        }
    }
    
    public func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: kStorageKey),
           let decoded = try? JSONDecoder().decode(PSXControlPositions.self, from: data) {
            self.positions = decoded
            print(" [PSXControls] Config loaded.")
        } else {
            print(" [PSXControls] No saved config, using defaults.")
        }
    }
    
    public func resetConfig() {
        withAnimation {
            positions = PSXControlPositions()
        }
        saveConfig()
        print("bff [PSXControls] Config reset to Default.")
    }
    
    public func updatePosition(_ key: WritableKeyPath<PSXControlPositions, CGPoint>, value: CGPoint) {
        positions[keyPath: key] = value
    }
    
    public func updateScreenScale(isPortrait: Bool, scale: CGFloat) {
        if isPortrait { positions.screenScalePortrait = scale }
        else { positions.screenScaleLandscape = scale }
    }
    
    public func updateScreenPosition(isPortrait: Bool, position: CGPoint) {
        if isPortrait { positions.screenPositionPortrait = position }
        else { positions.screenPositionLandscape = position }
    }
}
