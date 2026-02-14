import Foundation
import SwiftUI
import Combine

struct NESControlPositions: Codable {
    var dpad: CGPoint = .zero
    var buttons: CGPoint = .zero
    var start: CGPoint = .zero
    var select: CGPoint = .zero

    // PORTRAIT Specific
    var dpadPortrait: CGPoint = .zero
    var buttonsPortrait: CGPoint = .zero
    var startPortrait: CGPoint = .zero
    var selectPortrait: CGPoint = .zero

    // LANDSCAPE Specific
    var dpadLandscape: CGPoint = .zero
    var buttonsLandscape: CGPoint = .zero
    var startLandscape: CGPoint = .zero
    var selectLandscape: CGPoint = .zero
    
    // SCREEN Customization
    var screenScalePortrait: CGFloat = 1.0
    var screenPositionPortrait: CGPoint = .zero
    
    var screenScaleLandscape: CGFloat = 1.0
    var screenPositionLandscape: CGPoint = .zero
}

class NESControlManager: ObservableObject {
    static let shared = NESControlManager()
    
    @Published var positions = NESControlPositions()
    @Published var isEditing = false
    
    private let key = "nesControlPositions"
    
    init() {
        loadConfig()
    }
    
    func updatePosition(_ keyPath: WritableKeyPath<NESControlPositions, CGPoint>, value: CGPoint) {
        positions[keyPath: keyPath] = value
    }
    
    public func updateScreenScale(isPortrait: Bool, scale: CGFloat) {
        if isPortrait { positions.screenScalePortrait = scale }
        else { positions.screenScaleLandscape = scale }
    }
    
    public func updateScreenPosition(isPortrait: Bool, position: CGPoint) {
        if isPortrait { positions.screenPositionPortrait = position }
        else { positions.screenPositionLandscape = position }
    }
    
    func saveConfig() {
        if let encoded = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(NESControlPositions.self, from: data) {
            positions = decoded
        }
    }
    
    func resetConfig() {
        positions = NESControlPositions()
        saveConfig()
    }
}
