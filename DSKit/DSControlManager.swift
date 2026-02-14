import SwiftUI
import Combine

// Estructura de datos para guardar las posiciones (Offsets)
public struct DSControlPositions: Codable {
    // Shared (Deprecated, kept for migration if needed, but we will use specific ones)
    var dpad: CGPoint = .zero
    var buttons: CGPoint = .zero
    var select: CGPoint = .zero
    var start: CGPoint = .zero
    var l: CGPoint = .zero
    var r: CGPoint = .zero
    var menu: CGPoint = .zero 
    
    // PORTRAIT Specific
    var dpadPortrait: CGPoint = .zero
    var buttonsPortrait: CGPoint = .zero
    var selectPortrait: CGPoint = .zero
    var startPortrait: CGPoint = .zero
    var lPortrait: CGPoint = .zero
    var rPortrait: CGPoint = .zero
    var menuPortrait: CGPoint = .zero
    
    // LANDSCAPE Specific
    var dpadLandscape: CGPoint = .zero
    var buttonsLandscape: CGPoint = .zero
    var selectLandscape: CGPoint = .zero
    var startLandscape: CGPoint = .zero
    var lLandscape: CGPoint = .zero
    var rLandscape: CGPoint = .zero
    var menuLandscape: CGPoint = .zero
    
    // SCREEN Customization
    var screenScalePortrait: CGFloat = 1.0
    var screenPositionPortrait: CGPoint = .zero
    
    var screenScaleLandscape: CGFloat = 1.0
    var screenPositionLandscape: CGPoint = .zero

    // Visual Options
    var showBezel: Bool = true
}

public class DSControlManager: ObservableObject {
    public static let shared = DSControlManager()
    
    @Published public var positions: DSControlPositions = DSControlPositions()
    @Published public var isEditing: Bool = false
    
    private let kStorageKey = "DSControlConfig"
    
    private init() {
        loadConfig()
    }
    
    public func saveConfig() {
        if let data = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(data, forKey: kStorageKey)
            print("[DSControls] Configuración guardada.")
        }
    }
    
    public func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: kStorageKey),
           let decoded = try? JSONDecoder().decode(DSControlPositions.self, from: data) {
            self.positions = decoded
            print("[DSControls] Configuración cargada.")
        } else {
            print("[DSControls] No hay config guardada, usando defaults.")
        }
    }
    
    public func resetConfig() {
        withAnimation {
            positions = DSControlPositions()
        }
        saveConfig()
        print("bff [DSControls] Configuración reseteada a Default.")
    }
    
    public func updatePosition(_ key: WritableKeyPath<DSControlPositions, CGPoint>, value: CGPoint) {
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
