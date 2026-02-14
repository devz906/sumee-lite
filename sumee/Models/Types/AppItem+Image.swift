import SwiftUI
import UIKit

extension AppItem {
    // Resolves the best available image for this item to use as a texture.
    func resolveIconImage() -> UIImage? {
        // 1. ROM Cover Art
        if isROM, let rom = romItem, let cover = rom.getThumbnail() {
            return cover
        }
        
        // 2. Custom System Icon
        if let customImage = SettingsManager.shared.getCustomSystemIcon(named: iconName) {
            return customImage
        }
        
        // 3. Asset Image (User-provided bundle assets)
        if let uiImage = UIImage(named: iconName) {
            return uiImage
        }
        
        // 4. System Symbol (SF Symbols) - Rendered to Image
        // We render this to a UIImage so it can be used as a texture
        return UIImage(systemName: iconName)?.withTintColor(UIColor(color), renderingMode: .alwaysOriginal)
    }
}
