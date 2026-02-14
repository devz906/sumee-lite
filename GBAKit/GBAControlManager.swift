import SwiftUI
import Combine

// Estructura de datos para guardar las posiciones (Offsets)
public struct GBAControlPositions: Codable {
    var dpad: CGPoint = .zero
    var abButtons: CGPoint = .zero
    var select: CGPoint = .zero
    var start: CGPoint = .zero
    var l: CGPoint = .zero
    var r: CGPoint = .zero
    
    // PORTRAIT Specific
    var dpadPortrait: CGPoint = .zero
    var abButtonsPortrait: CGPoint = .zero
    var selectPortrait: CGPoint = .zero
    var startPortrait: CGPoint = .zero
    var lPortrait: CGPoint = .zero
    var rPortrait: CGPoint = .zero

    // GBA Screen Bezel Visible
    var showBezel: Bool = true
    
    // LANDSCAPE Specific
    var dpadLandscape: CGPoint = .zero
    var abButtonsLandscape: CGPoint = .zero
    var selectLandscape: CGPoint = .zero
    var startLandscape: CGPoint = .zero
    var lLandscape: CGPoint = .zero
    var rLandscape: CGPoint = .zero
    
    // SCREEN Customization
    var screenScalePortrait: CGFloat = 1.0
    var screenPositionPortrait: CGPoint = .zero
    
    var screenScaleLandscape: CGFloat = 1.0
    var screenPositionLandscape: CGPoint = .zero
}

public class GBAControlManager: ObservableObject {
    public static let shared = GBAControlManager()
    
    @Published public var positions: GBAControlPositions = GBAControlPositions()
    @Published public var isEditing: Bool = false
    
    private let kStorageKey = "GBAControlConfig"
    
    private init() {
        loadConfig()
    }
    
    public func saveConfig() {
        if let data = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(data, forKey: kStorageKey)
            print(" [GBAControls] Configuración guardada.")
        }
    }
    
    public func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: kStorageKey),
           let decoded = try? JSONDecoder().decode(GBAControlPositions.self, from: data) {
            self.positions = decoded
            print(" [GBAControls] Configuración cargada.")
        } else {
            print(" [GBAControls] No hay config guardada, usando defaults.")
        }
    }
    
    public func resetConfig() {
        withAnimation {
            positions = GBAControlPositions()
        }
        saveConfig()
        print("bff [GBAControls] Configuración reseteada a Default.")
    }
    
    public func updatePosition(_ key: WritableKeyPath<GBAControlPositions, CGPoint>, value: CGPoint) {
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
