import SwiftUI

// HomeView+Overlays.swift

extension HomeView {
    
    // Full Screen Overlays
    
    var fullScreenOverlays: some View {
        Group {
            // Overlay based on Active System App
            if let app = viewModel.activeSystemApp {
                overlay(for: app)
            }
        }

    }
    
    @ViewBuilder
    private func overlay(for app: SystemApp) -> some View {
        switch app {
        case .photos:
            PhotosGalleryInlineView(isPresented: $viewModel.showPhotosGallery)
                .transition(.opacity)
        case .music:
            MusicPlayerInlineView(isPresented: $viewModel.showMusicPlayer, viewModel: viewModel)
                .transition(.opacity)
        case .gameSystems:
            GameSystemsLaunchView(isPresented: $viewModel.showGameSystems, viewModel: viewModel)
                .transition(.opacity)
                .zIndex(100)
        case .store:
            StoreLaunchView(isPresented: $viewModel.showStore, viewModel: viewModel)
                .transition(.opacity)
                .zIndex(100)
        case .discord:
            DiscordLaunchView(isPresented: $viewModel.showDiscord)
                .transition(.opacity)
                .zIndex(100)
        // case .news:
        //    EENewsLaunchView(isPresented: $viewModel.showEENews)
        //        .transition(.opacity)
        //        .zIndex(100)
        case .meloNX:
            MeloNXLaunchView(isPresented: $viewModel.showMeloNX)
                .transition(.opacity)
                .zIndex(100)

        case .miBrowser:
            UniversalWebAppLaunchView(isPresented: $viewModel.showMiBrowser, systemApp: .miBrowser) { binding in
                 MiBrowserView(isPresented: binding)
            }
            .transition(.opacity)
            .zIndex(100)        case .tetris:
            UniversalWebAppLaunchView(
                isPresented: Binding(
                    get: { viewModel.activeSystemApp == .tetris },
                    set: { if !$0 { viewModel.activeSystemApp = nil } }
                ),
                systemApp: .tetris
            ) { binding in
                TETRIOView(isPresented: binding, viewModel: viewModel)
            }
            .transition(.opacity)
            .zIndex(100)
        case .slither:
            UniversalWebAppLaunchView(
                isPresented: Binding(
                    get: { viewModel.activeSystemApp == .slither },
                    set: { if !$0 { viewModel.activeSystemApp = nil } }
                ),
                systemApp: .slither
            ) { binding in
                SlitherIOView(isPresented: binding)
            }
            .transition(.opacity)
            .zIndex(100)

        case .themeManager:
            ThemeManagerView(isPresented: $viewModel.showThemeManager)
                .transition(.opacity)
        case .settings:
            EmptyView()
        }
    }
    
    // Idle Unlock Overlay (PS Vita Style Peel)
    var idleUnlockOverlay: some View {
        Group {
            if viewModel.isIdleMode {
                HomeLockScreenView(viewModel: viewModel)
                    .transition(.opacity)
                    .zIndex(500)
            }
        }
    }

    var settingsOverlay: some View   {
        ZStack(alignment: .trailing) {
            if viewModel.showSettings {
                Color.black.opacity(0.4) // Dim background for focus
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.showSettings = false
                        }
                    }
                    .transition(.opacity)
                
                SettingsInlineView(isPresented: $viewModel.showSettings, viewModel: viewModel)
                    .transition(.opacity)
            }
            
            notificationObservers
        }
        .zIndex(150)
    }
    
    //  Notification Observers
    
    var notificationObservers: some View {
        EmptyView()
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddRomToHome"))) { notification in
                if let rom = notification.object as? ROMItem {
                    print(" HomeView received request to add ROM to Home: \(rom.displayName)")
                    viewModel.addRomToHome(rom)
                }
            }
    }
}
