import Foundation
import CoreGraphics

// MARK: - Root Info
public struct NESDeltaSkinInfo: Codable {
    public let name: String
    public let identifier: String
    public let gameTypeIdentifier: String
    public let debug: Bool?
    public let representations: NESSkinRepresentations
}

public struct NESSkinRepresentations: Codable {
    public let iphone: NESSkinDevice?
    public let ipad: NESSkinDevice?
}

public struct NESSkinDevice: Codable {
    public let edgeToEdge: NESSkinOrientations?
    public let standard: NESSkinOrientations?
}

public struct NESSkinOrientations: Codable {
    public let portrait: NESSkinRepresentation?
    public let landscape: NESSkinRepresentation?
}

// MARK: - Representation
public struct NESSkinRepresentation: Codable {
    public let assets: NESSkinAssets
    public let items: [NESSkinItem]
    public let screens: [NESSkinScreen]?
    public let mappingSize: NESSkinSize?
    
    public var backgroundImageName: String {
        return assets.large ?? assets.resizable ?? "unknown"
    }
    
    public var isResizable: Bool {
        return assets.resizable != nil
    }
}

public struct NESSkinAssets: Codable {
    public let large: String?
    public let small: String?
    public let medium: String?
    public let resizable: String?
}

public struct NESSkinSize: Codable {
    public let width: CGFloat
    public let height: CGFloat
}

// MARK: - Items
public struct NESSkinItem: Codable {
    public let inputs: NESSkinInput?
    public let frame: NESSkinFrame
    public let extendedEdges: NESExtendedEdges?
}

public enum NESSkinInput: Codable {
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

public struct NESSkinFrame: Codable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
    
    public var cgRect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct NESExtendedEdges: Codable {
    public let top: CGFloat?
    public let bottom: CGFloat?
    public let left: CGFloat?
    public let right: CGFloat?
}

public struct NESSkinScreen: Codable {
    public let inputFrame: NESSkinFrame
    public let outputFrame: NESSkinFrame
}
