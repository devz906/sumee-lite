import Foundation
import CoreGraphics

// MARK: - Root Info
public struct DeltaSkinInfo: Codable {
    public let name: String
    public let identifier: String
    public let gameTypeIdentifier: String
    public let debug: Bool?
    public let representations: SkinRepresentations
}

public struct SkinRepresentations: Codable {
    public let iphone: SkinDevice?
    // iPad support can be added later
}

public struct SkinDevice: Codable {
    public let edgeToEdge: SkinOrientations?
    public let standard: SkinOrientations? // Fallback for non-edge-to-edge screens if needed
}

public struct SkinOrientations: Codable {
    public let portrait: SkinRepresentation?
    public let landscape: SkinRepresentation?
}

// MARK: - Representation (The actual skin layout)
public struct SkinRepresentation: Codable {
    public let assets: SkinAssets
    public let items: [SkinItem]
    public let screens: [SkinScreen]?
    public let gameScreenFrame: SkinFrame?
    public let mappingSize: SkinSize?
    
    // Helper to get background image name
    public var backgroundImageName: String {
        return assets.large ?? assets.resizable ?? "unknown"
    }
    
    // Helper to normalize screens (some skins use 'screens' array, others 'gameScreenFrame')
    public var effectiveScreens: [SkinScreen] {
        if let explicitScreens = screens {
            return explicitScreens
        }
        
        // Synthesize screens from gameScreenFrame (Vertical Split)
        if let frame = gameScreenFrame {
            let halfHeight = frame.height / 2
            
            let topScreen = SkinScreen(
                inputFrame: SkinFrame(x: 0, y: 0, width: 256, height: 192),
                outputFrame: SkinFrame(x: frame.x, y: frame.y, width: frame.width, height: halfHeight)
            )
            
            let bottomScreen = SkinScreen(
                inputFrame: SkinFrame(x: 0, y: 192, width: 256, height: 192),
                outputFrame: SkinFrame(x: frame.x, y: frame.y + halfHeight, width: frame.width, height: halfHeight)
            )
            
            return [topScreen, bottomScreen]
        }
        
        return []
    }
}

public struct SkinAssets: Codable {
    public let large: String?
    public let small: String?
    public let medium: String?
    public let resizable: String?
}

public struct SkinSize: Codable {
    public let width: CGFloat
    public let height: CGFloat
}

// MARK: - Items (Buttons/Inputs)
public struct SkinItem: Codable {

    
    public let inputs: SkinInput?
    public let frame: SkinFrame
    public let extendedEdges: ExtendedEdges?
    
    // Thumbstick specific
    public let thumbstick: SkinThumbstick?
}

public enum SkinInput: Codable {
    case distinct([String])
    case directional([String: String])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            self = .distinct(array)
        } else if let dict = try? container.decode([String: String].self) {
            self = .directional(dict)
        } else {
             // Fallback or empty
             self = .distinct([])
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .distinct(let arr): try container.encode(arr)
        case .directional(let dict): try container.encode(dict)
        }
    }
}

public struct SkinFrame: Codable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
    
    public var cgRect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct ExtendedEdges: Codable {
    public let top: CGFloat?
    public let bottom: CGFloat?
    public let left: CGFloat?
    public let right: CGFloat?
}

public struct SkinThumbstick: Codable {
    public let name: String
    public let width: CGFloat
    public let height: CGFloat
}

// MARK: - Screens
public struct SkinScreen: Codable {
    public let inputFrame: SkinFrame // Source (e.g. 0,0,256,192 for Top Screen)
    public let outputFrame: SkinFrame // Destination on Skin
    
    // Helper to identify which screen this is based on Y coordinate commonly
    public var isTouchScreen: Bool {

        return inputFrame.y >= 190
    }
}
