import Foundation
import UIKit

// --- PSX Skin Data Models (Delta Format) ---

struct PSXDeltaSkinInfo: Codable {
    let name: String
    let identifier: String
    let gameTypeIdentifier: String
    let debug: Bool?
    let representations: PSXSkinRepresentations
}

struct PSXSkinRepresentations: Codable {
    let iphone: PSXSkinDevice
    let ipad: PSXSkinDevice?
}

struct PSXSkinDevice: Codable {
    let standard: PSXSkinOrientations?
    let edgeToEdge: PSXSkinOrientations?
}

struct PSXSkinOrientations: Codable {
    let portrait: PSXSkinRepresentation?
    let landscape: PSXSkinRepresentation?
}

struct PSXSkinRepresentation: Codable {
    let assets: PSXSkinAssets
    let items: [PSXSkinItem]
    let mappingSize: PSXSkinSize?
    let screens: [PSXSkinScreen]?
    let gameScreenFrame: PSXSkinFrame?
    
    var backgroundImageName: String {
        return assets.resizable ?? assets.standard ?? assets.large ?? assets.medium ?? assets.small ?? ""
    }
    
    // Synthesize screens from gameScreenFrame if explicit screens are missing
    var effectiveScreens: [PSXSkinScreen] {
        if let explicit = screens { return explicit }
        
        if let frame = gameScreenFrame {
            return [
                PSXSkinScreen(
                    outputFrame: frame
                )
            ]
        }
        return []
    }
}

struct PSXSkinAssets: Codable {
    let standard: String?
    let resizable: String?
    let small: String?
    let medium: String?
    let large: String?
    let normal: String? // Common for buttons in Delta skins
}

struct PSXSkinSize: Codable {
    let width: CGFloat
    let height: CGFloat
}

struct PSXSkinItem: Codable {
    let frame: PSXSkinFrame
    let extendedEdges: PSXExtendedEdges?
    let inputs: PSXSkinInput?
    let asset: PSXSkinAssets? // Item-specific asset (e.g. button image)

    let thumbstick: PSXSkinThumbstick?
    let background: PSXSkinItemBackground?
}

struct PSXSkinThumbstick: Codable {
    let name: String
    let width: CGFloat
    let height: CGFloat
}

struct PSXSkinItemBackground: Codable {
    let name: String
    let width: CGFloat
    let height: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
}

// Helper enum to handle "inputs" being either a string array, a dictionary, or specific object input
enum PSXSkinInput: Codable {
    case distinct([String])
    case directional // Legacy/Generic
    case complex([String: String]) // For Thumbsticks/D-Pads defined as "up": "leftThumbstickUp"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // 1. Array of Strings ["a", "b"]
        if let keys = try? container.decode([String].self) {
            self = .distinct(keys)
            return
        }
        
        // 2. Dictionary {"up": "...", "down": "..."}
        if let dict = try? container.decode([String: String].self) {
             self = .complex(dict)
             return
        }
        
        throw DecodingError.typeMismatch(PSXSkinInput.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected array or dictionary"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .distinct(let keys):
            try container.encode(keys)
        case .complex(let dict):
            try container.encode(dict)
        case .directional:
            try container.encode(["up", "down", "left", "right"])
        }
    }
}

struct PSXSkinFrame: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

struct PSXExtendedEdges: Codable {
    let top: CGFloat?
    let bottom: CGFloat?
    let left: CGFloat?
    let right: CGFloat?
}

// For Screen Rendering if skin defines it
struct PSXSkinScreen: Codable {
    let outputFrame: PSXSkinFrame
}
//i will never to this any more
