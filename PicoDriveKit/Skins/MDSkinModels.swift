import Foundation
import CoreGraphics

// MARK: - Root Info
public struct MDDeltaSkinInfo: Codable {
    public let name: String
    public let identifier: String
    public let gameTypeIdentifier: String
    public let debug: Bool?
    public let representations: MDSkinRepresentations
}

public struct MDSkinRepresentations: Codable {
    public let iphone: MDSkinDevice?
    public let ipad: MDSkinDevice?
}

public struct MDSkinDevice: Codable {
    public let edgeToEdge: MDSkinOrientations?
    public let standard: MDSkinOrientations?
}

public struct MDSkinOrientations: Codable {
    public let portrait: MDSkinRepresentation?
    public let landscape: MDSkinRepresentation?
}

// MARK: - Representation
public struct MDSkinRepresentation: Codable {
    public let assets: MDSkinAssets
    public let items: [MDSkinItem]
    public let screens: [MDSkinScreen]?
    public let gameScreenFrame: MDSkinFrame?
    public let mappingSize: MDSkinSize?
    
    public var backgroundImageName: String {
        return assets.large ?? assets.resizable ?? "unknown"
    }
    
    public var isResizable: Bool {
        return assets.resizable != nil
    }
    
    // Synthesize screens from gameScreenFrame if explicit screens are missing
    public var effectiveScreens: [MDSkinScreen] {
        if let explicit = screens { return explicit }
        
        if let frame = gameScreenFrame {

            return [
                MDSkinScreen(
                    inputFrame: MDSkinFrame(x: 0, y: 0, width: 320, height: 224),
                    outputFrame: frame
                )
            ]
        }
        return []
    }
}

public struct MDSkinAssets: Codable {
    public let large: String?
    public let small: String?
    public let medium: String?
    public let resizable: String?
}

public struct MDSkinSize: Codable {
    public let width: CGFloat
    public let height: CGFloat
}

// MARK: - Items
public struct MDSkinItem: Codable {
    public let inputs: MDSkinInput?
    public let frame: MDSkinFrame
    public let extendedEdges: MDExtendedEdges?
}

public enum MDSkinInput: Codable {
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

public struct MDSkinFrame: Codable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
    
    public var cgRect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct MDExtendedEdges: Codable {
    public let top: CGFloat?
    public let bottom: CGFloat?
    public let left: CGFloat?
    public let right: CGFloat?
}

public struct MDSkinScreen: Codable {
    public let inputFrame: MDSkinFrame
    public let outputFrame: MDSkinFrame
}
