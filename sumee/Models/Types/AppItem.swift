import SwiftUI
import UIKit

struct AppItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var iconName: String
    // Restored properties
    private var codableColor: CodableColor
    let folderType: FolderType?
    var isFolder: Bool = false
    var isWidget: Bool = false
    var isROM: Bool = false
    var romItem: ROMItem? = nil
    var systemApp: SystemApp? = nil // Link to SystemApp enum
    var folderItems: [AppItem] = []
    
    // Custom Image Support
    var isCustomImage: Bool = false
    var customImagePath: String? = nil
    
    var color: Color {
        codableColor.color
    }
    
    // Widget Resizing
    enum WidgetSize: String, Codable {
        case small    // 1x1
        case medium   // 2x1 (Horizontal)
        case large    // 2x2 (Square)
        
        var span: Int {
            switch self {
            case .small: return 1
            case .medium: return 2
            case .large: return 2 // Occupies 2 columns, 2 rows logic handled by spacer placement
            }
        }
    }
    
    var widgetSize: WidgetSize = .small
    var isSpacer: Bool = false
    var ownerId: UUID? = nil // For spacers to point back to owner
    var isNewInstallation: Bool = false
    
    // Grid Dimensions Helper
    var width: Int {
        switch widgetSize {
        case .small: return 1
        case .medium: return 2
        case .large: return 2
        }
    }
    
    var height: Int {
        switch widgetSize {
        case .small: return 1
        case .medium: return 1
        case .large: return 2
        }
    }
    
    enum FolderType: String, Codable {
        // Deprecated: gameboy
        case unknown 
    }
    
    init(name: String, iconName: String, color: Color, isWidget: Bool = false, isFolder: Bool = false, folderType: FolderType? = nil, isROM: Bool = false, romItem: ROMItem? = nil, systemApp: SystemApp? = nil, isCustomImage: Bool = false, customImagePath: String? = nil, widgetSize: WidgetSize = .small, isSpacer: Bool = false, ownerId: UUID? = nil) {
        self.name = name
        self.iconName = iconName
        self.codableColor = CodableColor(color: color)
        self.isWidget = isWidget
        self.isFolder = isFolder
        self.folderType = folderType
        self.isROM = isROM
        self.romItem = romItem
        self.systemApp = systemApp
        self.isCustomImage = isCustomImage
        self.customImagePath = customImagePath
        self.widgetSize = widgetSize
        self.isSpacer = isSpacer
        self.ownerId = ownerId
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, iconName, codableColor, isFolder, isWidget, isROM, romItem, folderItems, folderType, isCustomImage, customImagePath, widgetSize, isSpacer, ownerId, systemApp, isNewInstallation
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        codableColor = try container.decode(CodableColor.self, forKey: .codableColor)
        isFolder = try container.decode(Bool.self, forKey: .isFolder)
        isWidget = try container.decode(Bool.self, forKey: .isWidget)
        isROM = try container.decode(Bool.self, forKey: .isROM)
        romItem = try container.decodeIfPresent(ROMItem.self, forKey: .romItem)
        folderItems = try container.decodeIfPresent([AppItem].self, forKey: .folderItems) ?? []
        if let folderTypeString = try? container.decode(String.self, forKey: .folderType) {
            folderType = FolderType(rawValue: folderTypeString)
        } else {
            folderType = nil
        }
        

        // Handle new properties with default values for backward compatibility
        // Safe decoding for systemApp to prevent crash/reset if an app is removed from the enum
        if let systemAppString = try? container.decode(String.self, forKey: .systemApp) {
            self.systemApp = SystemApp(rawValue: systemAppString)
        } else {
            self.systemApp = nil
        }
        // systemApp = try container.decodeIfPresent(SystemApp.self, forKey: .systemApp)
        isCustomImage = try container.decodeIfPresent(Bool.self, forKey: .isCustomImage) ?? false
        customImagePath = try container.decodeIfPresent(String.self, forKey: .customImagePath)
        widgetSize = try container.decodeIfPresent(WidgetSize.self, forKey: .widgetSize) ?? .small
        isSpacer = try container.decodeIfPresent(Bool.self, forKey: .isSpacer) ?? false
        ownerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId)
        isNewInstallation = try container.decodeIfPresent(Bool.self, forKey: .isNewInstallation) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(codableColor, forKey: .codableColor)
        try container.encode(isFolder, forKey: .isFolder)
        try container.encode(isWidget, forKey: .isWidget)
        try container.encode(isROM, forKey: .isROM)
        try container.encodeIfPresent(romItem, forKey: .romItem)
        try container.encodeIfPresent(systemApp, forKey: .systemApp)
        try container.encode(folderItems, forKey: .folderItems)
        try container.encodeIfPresent(folderType, forKey: .folderType)
        try container.encode(isCustomImage, forKey: .isCustomImage)
        try container.encodeIfPresent(customImagePath, forKey: .customImagePath)
        try container.encode(widgetSize, forKey: .widgetSize)
        try container.encode(isSpacer, forKey: .isSpacer)
        try container.encode(isNewInstallation, forKey: .isNewInstallation)
        try container.encodeIfPresent(ownerId, forKey: .ownerId)
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.iconName == rhs.iconName &&
               lhs.codableColor == rhs.codableColor &&
               lhs.isWidget == rhs.isWidget &&
               lhs.isFolder == rhs.isFolder &&
               lhs.folderType == rhs.folderType &&
               lhs.isROM == rhs.isROM &&
               lhs.romItem == rhs.romItem &&
               lhs.systemApp == rhs.systemApp &&
               lhs.isCustomImage == rhs.isCustomImage &&
               lhs.customImagePath == rhs.customImagePath &&
               lhs.widgetSize == rhs.widgetSize &&
               lhs.isSpacer == rhs.isSpacer &&
               lhs.isNewInstallation == rhs.isNewInstallation
    }
}

struct CodableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
    
    init(color: Color) {
        // Use UIColor to extract components
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}
