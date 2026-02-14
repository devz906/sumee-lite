import SwiftUI

struct GlobalThemeObservers: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    // Trigger value (Observed by parent)
    var activeThemeID: String
    
    // Dependencies (Unobserved - Side Effects Only)
    var settings: SettingsManager
    var audioManager: AudioManager
    var viewModel: HomeViewModel
    
    func body(content: Content) -> some View {
        content
            .onChange(of: colorScheme) { _, newScheme in
                // Automatic Theme Switching based on System Appearance
                if newScheme == .dark {
                    if settings.activeThemeID == "grid" {
                        settings.activeThemeID = "dark_mode"
                    }
                } else {
                    // Light Mode
                    if settings.activeThemeID == "dark_mode" {
                        settings.activeThemeID = "grid"
                    }
                }
            }
            .onChange(of: activeThemeID) { _, newID in
                let theme = settings.activeTheme
                
                // 1. Audio Side Effects
                // Only play theme music if we are on the Home Screen (No app active)
                // This prevents disrupting app-specific music (like PictoMee, Emulator, etc.)
                let isAppOpen = viewModel.activeSystemApp != nil || viewModel.showEmulator || viewModel.isFolderEmulatorActive
                
                if settings.enableBackgroundMusic && !isAppOpen {
                    audioManager.playBackgroundMusic()
                }
                
                // 2. Icon Side Effects
                let iconName: String? = (theme.id == "christmas") ? "ChristmasIcon" : nil
                
                if let icon = iconName {
                    UIApplication.shared.setAlternateIconName(icon) { error in
                        if let error = error { print("Failed to set icon \(icon): \(error.localizedDescription)") }
                    }
                } else {
                    UIApplication.shared.setAlternateIconName(nil) { error in
                         if let error = error { print(" Failed to revert icon: \(error.localizedDescription)") }
                    }
                }
                
                // 3. Icon Set (Standard vs Dark vs Transparent)
                // Skip for Custom Photo theme to allow user override persistence
                if theme.id != "custom_photo" {
                    let themeDefaultSet = theme.iconSet
                    let shouldBeTransparent = (themeDefaultSet == 2)
                    
                    if settings.useTransparentIcons != shouldBeTransparent {
                        settings.useTransparentIcons = shouldBeTransparent
                        print(" Theme \(theme.displayName) changed. Auto-updating Transparent Icons to \(shouldBeTransparent)")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshAppIcons"))) { _ in
                print(" Received Icon Refresh Request")
                viewModel.fixIcons()
            }
    }
}
