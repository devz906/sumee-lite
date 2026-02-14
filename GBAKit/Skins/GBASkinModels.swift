import Foundation
import CoreGraphics

// MARK: - Root Info
public struct GBADeltaSkinInfo: Codable {
    public let name: String
    public let identifier: String
    public let gameTypeIdentifier: String
    public let debug: Bool?
    public let representations: GBASkinRepresentations
}

public struct GBASkinRepresentations: Codable {
    public let iphone: GBASkinDevice?
    public let ipad: GBASkinDevice?
}

public struct GBASkinDevice: Codable {
    public let edgeToEdge: GBASkinOrientations?
    public let standard: GBASkinOrientations?
}

public struct GBASkinOrientations: Codable {
    public let portrait: GBASkinRepresentation?
    public let landscape: GBASkinRepresentation?
}

// MARK: - Representation
public struct GBASkinRepresentation: Codable {
    public let assets: GBASkinAssets
    public let items: [GBASkinItem]
    public let screens: [GBASkinScreen]?
    public let mappingSize: GBASkinSize?
    
    public var backgroundImageName: String {
        return assets.large ?? assets.resizable ?? "unknown"
    }
}

public struct GBASkinAssets: Codable {
    public let large: String?
    public let small: String?
    public let medium: String?
    public let resizable: String?
}

public struct GBASkinSize: Codable {
    public let width: CGFloat
    public let height: CGFloat
}

// MARK: - Items
public struct GBASkinItem: Codable {
    public let inputs: GBASkinInput?
    public let frame: GBASkinFrame
    public let extendedEdges: GBAExtendedEdges?
}

public enum GBASkinInput: Codable {
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

public struct GBASkinFrame: Codable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
    
    public var cgRect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct GBAExtendedEdges: Codable {
    public let top: CGFloat?
    public let bottom: CGFloat?
    public let left: CGFloat?
    public let right: CGFloat?
}

public struct GBASkinScreen: Codable {
    public let inputFrame: GBASkinFrame
    public let outputFrame: GBASkinFrame
}
