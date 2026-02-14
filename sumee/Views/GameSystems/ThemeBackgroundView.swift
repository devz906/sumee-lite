import SwiftUI

struct ThemeBackgroundView: View {
    let theme: AppTheme
    var isAnimatePaused: Bool = false
    
    var body: some View {
        Group {
            switch theme.backgroundType {
            case .color(let color):
                color.ignoresSafeArea()
            case .pattern:
                // Pattern view handles its own animation state
                // If paused (emulator showing), stop animating
                BackgroundPatternView(
                    isAnimating: !isAnimatePaused,
                    isPaused: isAnimatePaused
                )
                .ignoresSafeArea()
            case .custom(let type):
                if type == "Snow" {
                    SnowBackgroundView(isPaused: isAnimatePaused)
                } else if type == "Homebrew" {
                    HomebrewBackgroundView()
                } else if type == "NewYear" {
                    NewYearBackgroundView(isPaused: isAnimatePaused)
                } else if type == "SUMEE-XMB" {
                    SUMEEXMBBackgroundView(isAnimatePaused: isAnimatePaused, variant: .blue)
                } else if type == "SUMEE-XMB-Black" {
                    SUMEEXMBBackgroundView(isAnimatePaused: isAnimatePaused, variant: .black)
                } else if type == "CustomPhoto" {
                    CustomThemeView()
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
        }
    }
}
