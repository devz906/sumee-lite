import SwiftUI

struct ThemeRegistry {
    static var allThemes: [AppTheme] {
        [
            ThemeRegistry.customTheme,
            ThemeRegistry.standard,
            ThemeRegistry.darkMode,
            ThemeRegistry.grid,
            ThemeRegistry.christmas,
            ThemeRegistry.homebrew,
            ThemeRegistry.newYear,
            ThemeRegistry.sumeeXMB,
            ThemeRegistry.sumeeXMBBlack,
        ]
    }
    
    // Default Definitions
    
    static let standard = AppTheme(
        id: "standard",
        displayName: "Standard White",
        icon: "square.fill",
        color: .white,
        backgroundType: .color(.white),
        iconSet: 1,
        musicTrack: "music_background",
        isDark: false
    )
    
    static let darkMode = AppTheme(
        id: "dark_mode",
        displayName: "Dark Mode",
        icon: "moon.fill",
        color: .black,
        backgroundType: .pattern, // Dark pattern logic handled in view
        iconSet: 2,
        musicTrack: "music_background",
        isDark: true
    )
    
    static let grid = AppTheme(
        id: "grid",
        displayName: "Grid Pattern",
        icon: "grid",
        color: .gray.opacity(0.1),
        backgroundType: .pattern,
        iconSet: 1,
        musicTrack: "music_background",
        isDark: false
    )
    
    static let christmas = AppTheme(
        id: "christmas",
        displayName: "Christmas",
        icon: "snowflake",
        color: .red,
        backgroundType: .custom("Snow"),
        iconSet: 1,
        musicTrack: "We Wish You a Merry Christmas - Twin Musicom",
        isDark: false
    )
    
    static let homebrew = AppTheme(
        id: "homebrew",
        displayName: "Bubbles",
        icon: "soap.fill",
        color: .blue,
        backgroundType: .custom("Homebrew"),
        iconSet: 1,
        musicTrack: "music_background",
        isDark: false // Homebrew usually has white bubbles?
    )
    
    static let newYear = AppTheme(
        id: "new_year",
        displayName: "New Year",
        icon: "fireworks",
        color: .yellow,
        backgroundType: .custom("NewYear"),
        iconSet: 1,
        musicTrack: "Parental Controls",
        isDark: true // Often dark background
    )
    
    static let transparentIcons = AppTheme(
        id: "transparent_icons",
        displayName: "Transparent Icons",
        icon: "square.dashed",
        color: .gray.opacity(0.5),
        backgroundType: .pattern, // Default fallback if used alone
        iconSet: 2,
        musicTrack: "bgm",
        isDark: false
    )
    
    

    static let sumeeXMB = AppTheme(
        id: "sumee_xmb",
        displayName: "SUMEE-XMB",
        icon: "wave.3.right",
        color: .blue, // Matches PS Blue feel
        backgroundType: .custom("SUMEE-XMB"),
        iconSet: 2, // Transparent Icons
        musicTrack: "melonx",
        isDark: true
    )
    
    static let sumeeXMBBlack = AppTheme(
        id: "sumee_xmb_black",
        displayName: "SUMEE-XMB Black",
        icon: "wave.3.left",
        color: .gray, // Onyx/Black
        backgroundType: .custom("SUMEE-XMB-Black"),
        iconSet: 2, // Transparent Icons
        musicTrack: "melonx", // Same iconic track
        isDark: true
    )
    
    static var customTheme: AppTheme {
        // Source of Truth: Documents/Themes/current_theme.json
        var color: Color = .purple
        var music: String? = nil
        var isTransparent: Bool = false
        var isDark: Bool = true // Default to Light Text (Dark Theme)
        
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
             let url = documentsDirectory.appendingPathComponent("Themes/current_theme.json")
             if let data = try? Data(contentsOf: url),
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                 
                 // Manual Parse (Robustness)
                 let hue = json["hue"] as? Double ?? 0.0
                 let sat = json["saturation"] as? Double ?? 0.0
                 let bri = json["brightness"] as? Double ?? 1.0
                 color = Color(hue: hue, saturation: sat, brightness: bri)
                 
                 music = json["musicFileName"] as? String
                 isTransparent = json["transparentIcons"] as? Bool ?? false
                 
                 // Fix: Load Text Color Setting
                 if let isDarkVal = json["isDark"] as? Bool {
                     isDark = isDarkVal
                 }
                 
             } else {

         
                 color = .purple // Default Purple
                 music = nil
                 isTransparent = false
                 isDark = true // Default to Light Text
             }
        }

        return AppTheme(
            id: "custom_photo",
            displayName: "Custom Theme",
            icon: "photo.fill",
            color: color, 
            backgroundType: .custom("CustomPhoto"),
            iconSet: isTransparent ? 2 : 1, 
            musicTrack: music,
            isDark: isDark 
        )
    }
    
    // MARK: - Installation Management
    
    static func isInstalled(_ theme: AppTheme) -> Bool {
        return SettingsManager.shared.installedThemeIDs.contains(theme.id)
    }
    
    static func install(_ theme: AppTheme) {
        if !isInstalled(theme) {
            SettingsManager.shared.installedThemeIDs.append(theme.id)
            print(" Installed theme: \(theme.displayName)")
        }
    }
    
    static func uninstall(_ theme: AppTheme) {
        if theme.id == "grid" { return } // Protect default
        if let index = SettingsManager.shared.installedThemeIDs.firstIndex(of: theme.id) {
            SettingsManager.shared.installedThemeIDs.remove(at: index)
            print("Uninstalled theme: \(theme.displayName)")
        }
    }
}
