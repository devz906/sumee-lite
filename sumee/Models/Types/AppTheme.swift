import SwiftUI

struct AppTheme: Identifiable, Equatable {
    let id: String
    let displayName: String
    let icon: String // SF Symbol
    let color: Color // Accent color for UI
    
    // Configuration
    let backgroundType: BackgroundType
    let iconSet: Int
    let musicTrack: String? // Optional background music filename (without extension)
    let isDark: Bool // Whether text/UI should adapt to dark mode
    let bubbleTintColor: Color? // Optional tint for UI bubbles (overrides default black/white)
    
    init(id: String, displayName: String, icon: String, color: Color, backgroundType: BackgroundType, iconSet: Int, musicTrack: String?, isDark: Bool, bubbleTintColor: Color? = nil) {
        self.id = id
        self.displayName = displayName
        self.icon = icon
        self.color = color
        self.backgroundType = backgroundType
        self.iconSet = iconSet
        self.musicTrack = musicTrack
        self.isDark = isDark
        self.bubbleTintColor = bubbleTintColor
    }
    
    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        return lhs.id == rhs.id &&
               lhs.color == rhs.color &&
               lhs.isDark == rhs.isDark &&
               lhs.backgroundType == rhs.backgroundType &&
               lhs.iconSet == rhs.iconSet &&
               lhs.musicTrack == rhs.musicTrack
    }
}

enum BackgroundType: Equatable {
    case color(Color)
    case pattern // The vector grid
    case custom(String) // For identifying special views like "Snow", "Firework"
}
