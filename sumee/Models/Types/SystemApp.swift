import SwiftUI

enum SystemApp: String, CaseIterable, Codable, Identifiable {
    case photos = "Photos"
    case music = "Music"
    case gameSystems = "Game Systems"
    case settings = "Settings"
    case store = "App Store"
    case discord = "Discord"
    case meloNX = "MeloNX"
    case themeManager = "Themes"

    case miBrowser = "MiBrowser" // New App
    // case news = "EENews" // Removed
    case tetris = "TETR.IO"
    case slither = "Slither.io"

    
    var id: String { self.rawValue }
    
    // MARK: - App Registry Metadata (Store & System)
    
    var isPreinstalled: Bool {
        switch self {
        case .tetris, .slither, .meloNX, .miBrowser: return false
        default: return true
        }
    }
    
    var developer: String {
        switch self {
        case .photos, .music, .settings, .store: return "System"
        case .gameSystems: return "System"
        case .discord: return "Discord Inc."
        case .meloNX: return "MeloNX Team"
        case .miBrowser: return "System"
        // case .news: return "EE News" // Removed
        case .tetris: return "Classic Games"
        case .slither: return "Lowtech Studios"
        case .themeManager: return "System"

        }
    }
    
    var description: String {
        switch self {
        case .tetris: return "Fast-paced competitive puzzle game."
        case .slither: return "Play against other people online! Can you become the longest player?"
        case .themeManager: return "Customize your SUMEE experience with new themes."
        case .miBrowser: return "Browse the web."

        default: return "System Application."
        }
    }
    
    var downloadSize: String {
        switch self {
        case .tetris: return "0 MB"
        case .slither: return "0 MB"
        case .themeManager: return "5 MB"
        case .meloNX: return "0 MB"

        case .miBrowser: return "2 MB"
        default: return "N/A"
        }
    }
    
    // MARK: - Navigation Configuration (Zero-Touch)
    
    var pausesAudio: Bool {
        switch self {
        case .tetris, .slither: return true
        default: return false
        }
    }
    
    var disablesHomeNavigation: Bool {
        switch self {
        case .tetris, .slither, .themeManager, .miBrowser, .gameSystems: return true
        default: return false
        }
    }
    
    var transitionDuration: Double {
        switch self {
        case .themeManager, .miBrowser: return 0.3
        default: return 0.4
        }
    }

    
    var defaultName: String {
        switch self {
        case .store: return "Add ons"
        default: return self.rawValue
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .photos: return .blue
        case .music: return .purple
        case .gameSystems: return .red
        case .settings: return .gray
        case .store: return .blue
        case .discord: return .purple
        case .meloNX: return .purple
        case .themeManager: return .purple
        // case .news: return .red
        case .tetris: return .orange
        case .slither: return .green
        case .miBrowser: return .white  

        }
    }
    
    var iconName: String {
        return iconName(for: ProfileManager.shared.iconSet)
    }
    
    func iconName(for set: Int) -> String {
        // Helper
        func icon(_ regular: String, _ set2: String) -> String {
            return (set == 2) ? set2 : regular
        }
        
        switch self {
        case .photos:
             return icon("icon_photos", "icon2_photos")
        case .music:
             return icon("icon_music", "icon2_music")
        case .gameSystems:
             return icon("icon_gamepad", "icon2_gamepad")
        case .settings:
             return icon("icon_settings", "icon2_settings")
        case .store:
            // Return SF Symbol to avoid Bag/Cart iconography
            return icon("icon_Addons", "icon2_Addons")
        case .discord:
            return icon("icon_discord", "icon_discord")
        case .meloNX:
            return icon("icon_melonx", "icon2_melonx")
        case .themeManager:
            return icon("icon_theme", "icon2_theme")
        case .miBrowser:
            return icon("icon_MiBrowser", "icon2_MiBrowser")
        // case .news:
        //     return icon("icon_EENews", "icon_EENews")
        case .tetris:
            return icon("icon_tetrio", "icon2_tetrio")
        case .slither:
            return icon("icon_slither", "icon2_slither")

        }
    }
    
    var isFolder: Bool {
        switch self {
        default: return false
        }
    }
    
    var folderType: AppItem.FolderType? {
        switch self {
        default: return nil
        }
    }
    
    // MARK: - Store Classification
    
    enum StoreCategory {
        case app
        case game
    }
    
    var category: StoreCategory {
        switch self {
        case .tetris, .slither:
            return .game
        default:
            return .app
        }
    }
}
