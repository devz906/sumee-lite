import Foundation
import CoreGraphics

// MARK: - Root Info
public struct SNESDeltaSkinInfo: Codable {
    public let name: String
    public let identifier: String
    public let gameTypeIdentifier: String
    public let debug: Bool?
    public let representations: SNESSkinRepresentations
}

public struct SNESSkinRepresentations: Codable {
    public let iphone: SNESSkinDevice?
    public let ipad: SNESSkinDevice?
}

public struct SNESSkinDevice: Codable {
    public let edgeToEdge: SNESSkinOrientations?
    public let standard: SNESSkinOrientations?
}

public struct SNESSkinOrientations: Codable {
    public let portrait: SNESSkinRepresentation?
    public let landscape: SNESSkinRepresentation?
}

// MARK: - Representation
public struct SNESSkinRepresentation: Codable {
    public let assets: SNESSkinAssets
    public let items: [SNESSkinItem]
    public let screens: [SNESSkinScreen]?
    public let gameScreenFrame: SNESSkinFrame? // [NEW] Missing in SNESSkinModels
    public let mappingSize: SNESSkinSize?
    
    public var backgroundImageName: String {
        return assets.large ?? assets.resizable ?? "unknown"
    }
    
    public var isResizable: Bool {
        return assets.resizable != nil
    }
    
    // Synthesize screens from gameScreenFrame if explicit screens are missing
    public var effectiveScreens: [SNESSkinScreen] {
        if let explicit = screens { return explicit }
        
        if let frame = gameScreenFrame {
            // SNES typical resolution 256x224
            return [
                SNESSkinScreen(
                    inputFrame: SNESSkinFrame(x: 0, y: 0, width: 256, height: 224),
                    outputFrame: frame
                )
            ]
        }
        return []
    }
}

public struct SNESSkinAssets: Codable {
    public let large: String?
    public let small: String?
    public let medium: String?
    public let resizable: String?
}

public struct SNESSkinSize: Codable {
    public let width: CGFloat
    public let height: CGFloat
}

// MARK: - Items
public struct SNESSkinItem: Codable {
    public let inputs: SNESSkinInput?
    public let frame: SNESSkinFrame
    public let extendedEdges: SNESExtendedEdges?
}

public enum SNESSkinInput: Codable {
    case distinct([String])
    case directional([String: String])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            self = .distinct(array)
        } else if let dict = try? container.decode([String: String].self) {
            self = .directional(dict)
        } else {
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

public struct SNESSkinFrame: Codable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
    
    public var cgRect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct SNESExtendedEdges: Codable {
    public let top: CGFloat?
    public let bottom: CGFloat?
    public let left: CGFloat?
    public let right: CGFloat?
}

public struct SNESSkinScreen: Codable {
    public let inputFrame: SNESSkinFrame
    public let outputFrame: SNESSkinFrame
}
