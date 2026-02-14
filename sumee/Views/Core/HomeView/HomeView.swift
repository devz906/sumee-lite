import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import StoreKit

struct HomeView: View {
    @Binding var appLoading: Bool
    @StateObject var viewModel = HomeViewModel()
    @ObservedObject var gameController = GameControllerManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var audioManager = AudioManager.shared
    @ObservedObject var musicPlayer = MusicPlayerManager.shared
    @ObservedObject var screenshotManager = ScreenshotManager.shared
    @ObservedObject var appLauncher = AppLauncher.shared // Connect to AppLauncher for overlays
    @Namespace var pageTransition
    
    @State var showBubbles = false
    @State var showIcons = false
    @State var showCartridges = false
    @State var showChatBubbles = false
    @State var animateEntrance = false
    @State var shakeAttempts: Int = 0 // Counter to drive shake animation

    var body: some View  {
        mainContent
            .overlay(StatusToastView())
            .overlay(fullScreenOverlays)
            .overlay(idleUnlockOverlay) // Restored Idle Indicators

            // Conditional Animation: Slow Fade for Idle, Snappy Spring for Apps/Wakeup
            .animation(
                viewModel.isIdleMode ? .easeInOut(duration: 1.5) : .spring(response: 0.55, dampingFraction: 0.8),
                value: viewModel.isUIHidden
            )
            .overlay(settingsOverlay)
            .overlay(headerOverlay)
            .overlay(musicNotificationOverlay)
            .overlay(miniPlayerControlOverlay)
            .overlay {
                launchAnimationOverlay
            }
            .overlay {
                importAnimationOverlay
            }
            .overlay {
                fullMediaControlsOverlay
            }
            // Global Input Detection for Idle Mode
            // Moved to Background ZStack to prevent overlay conflict

            .onAppear {
                viewModel.onAppear()
                
                // Enforce landscape lock if controller is already connected
                if gameController.isControllerConnected {
                     AppDelegate.orientationLock = .landscape
                     updateInterfaceOrientation(.landscapeRight)
                }
                
                // Initialize based on showContent
                if viewModel.showContent {
                     // Assuming viewModel.showContent drives the initial state
                }
            }
            .onDisappear {
                viewModel.onDisappear()
            }

            .modifier(HomeEventModifiers(
                viewModel: viewModel,
                gameController: gameController,
                audioManager: audioManager,
                appLoading: $appLoading,
                updateInterfaceOrientation: updateInterfaceOrientation,
                handleDeepLink: handleDeepLink
            ))
            .onChange(of: viewModel.showContent) { _, newValue in
                if newValue {
                    DispatchQueue.main.async {
                        animateEntrance = true
                    }
                    // Staggered Animation Sequence
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showBubbles = true
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation { // Animation handled in AppGridPage
                            showIcons = true
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeOut(duration: 1.0)) {
                            showCartridges = true
                            showChatBubbles = true
                        }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        animateEntrance = false
                        showBubbles = false
                        showIcons = false
                        showCartridges = false
                        showChatBubbles = false
                    }
                }
            }
        // Global Theme Observers
        .modifier(GlobalThemeObservers(
            activeThemeID: settings.activeThemeID,
            settings: settings,
            audioManager: audioManager,
            viewModel: viewModel
        ))
        //App Store Overlay (Toast)
        .appStoreOverlay(isPresented: $appLauncher.showStoreOverlay) {
            SKOverlay.AppConfiguration(appIdentifier: appLauncher.storeOverlayAppID ?? "", position: .bottom)
        }
    }

    var mainContent: some View {
        ZStack {
            // BASE LAYER: Ensure ZStack allows overlays to fill screen even if content is hidden
            Color.clear.ignoresSafeArea()

            // 1. Background Layer
            backgroundLayer
            
            // 2. Main Dashboard Content
            dashboardContent
            
            // Emulator Overlay (Custom Launch Animation)
            if viewModel.showEmulator, let rom = viewModel.selectedROM {
                // FIXED: Arguments updated to match current GameLaunchView definition
                GameLaunchView(
                    rom: rom,
                    launchMode: viewModel.gameLaunchMode,
                    sourceRect: viewModel.launchSourceRect,
                    launchImage: viewModel.launchImage,
                    onDismiss: {
                        withAnimation {
                            viewModel.showEmulator = false
                        }
                    },
                    shouldRestoreHomeNavigation: true
                )
                .zIndex(100)
                .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
        }
    }

    var headerOverlay: some View {
        GeometryReader { geo in
            if !viewModel.showEmulator && !viewModel.isFolderEmulatorActive {
                headerView(isPortrait: geo.size.height > geo.size.width)
                    .opacity((viewModel.showContent && !viewModel.isIdleMode) ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: viewModel.showSettings)
                    .padding(.top, -18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    var musicNotificationOverlay: some View {
        VStack {
            if audioManager.showTrackNotification,
               let track = audioManager.currentTrackInfo,
               !viewModel.showMusicPlayer { // Hide banner if player is open
                MusicNotificationBanner(track: track)
                    .padding(.top, 90) // Below header
                    .padding(.trailing, 20)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(200) // Ensure it's on top
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    var miniPlayerControlOverlay: some View {
        // Mini Player Overlay
        GeometryReader { geo in
            if geo.size.height > geo.size.width {
                VStack {
                    Spacer()
                    MiniMusicPlayerOverlay()
                        .padding(.bottom, 80) // Float above bottom controls/indicator
                        .zIndex(190)
                }
            }
        }
    }
    
    //Subviews
    
    //Subviews
    // Moved to HomeView+Controls.swift
    
    // Subviews
    // Moved to HomeView+Controls.swift
    
    // DragOffset moved to PagedAppGrid for performance isolation
    let pageSpacing: CGFloat = 40 
    
    //  Grid & Layout
    // Moved to HomeView+Grid.swift
    
    //  Overlays
    // Moved to HomeView+Overlays.swift
    
    // Control Card Components



    // Extracted Overlays
    
    @ViewBuilder
    var launchAnimationOverlay: some View {
        if viewModel.isAnimatingLaunch, let rom = viewModel.launchingROM {
            GeometryReader { geo in
                IconLaunchAnimationView(
                    rom: rom,
                    sourceRect: viewModel.launchSourceRect,
                    targetRect: CGRect(x: geo.size.width / 2, y: geo.size.height / 2, width: 0, height: 0),
                    isAnimating: $viewModel.isAnimatingLaunch
                )
            }
            .zIndex(500)
        }
    }

    @ViewBuilder
    var importAnimationOverlay: some View {
        if let newGame = viewModel.newlyImportedGame {
            ImportAnimationView(rom: newGame, onDismiss: {
                viewModel.newlyImportedGame = nil
            })
            .zIndex(999)
            .transition(.identity)
        }
    }
    
    @ViewBuilder
    var backgroundLayer: some View {
        ZStack {
            // Background Visibility Logic
            if viewModel.activeSystemApp == nil ||
               viewModel.activeSystemApp == .gameSystems ||
               viewModel.activeSystemApp == .music ||
               viewModel.activeSystemApp == .photos ||
               viewModel.activeSystemApp == .settings ||
               viewModel.activeSystemApp == .themeManager {
                // 1. Background Layers
                if let song = musicPlayer.currentSong,
                   let artwork = song.artwork,
                   musicPlayer.isSessionActive {
                    // A. Music Background
                    GeometryReader { geo in
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .blur(radius: 20)
                            .overlay(Color.black.opacity(0.3))
                            .clipped()
                    }
                    .drawingGroup()
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut(duration: 0.8)))
                    .zIndex(1)
                } else {
                    // B. Standard Theme Backgrounds
                    ThemeBackgroundView(
                        theme: settings.activeTheme,
                        isAnimatePaused: viewModel.showEmulator || viewModel.isFolderEmulatorActive
                    )
                    .transition(.opacity)
                    .zIndex(0)
                }
                
                if !viewModel.showEmulator && !viewModel.isFolderEmulatorActive && settings.showFloatingCartridges && showCartridges {
                    FloatingCartridgesView(isPaused: viewModel.showEmulator)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                
            
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in viewModel.resetIdleTimer() }
        )
    }

    @ViewBuilder
    var dashboardContent: some View {
        if viewModel.activeSystemApp == nil {
            GeometryReader { geometry in
                // Unified Vertical Paging Grid
                // We keep this visible (covered by zIndex) to prevent layout shifts/z-fighting during emulator launch
                unifiedGridLayout
                        .padding(.top, 35)
                        .ignoresSafeArea()
                        .overlay(alignment: .leading) {
                            if viewModel.mainInterfaceIndex == 0 {
                                if geometry.size.height < geometry.size.width {
                                    verticalPageIndicators
                                        .padding(.leading, 4)
                                }
                            }
                        }
                        .overlay(alignment: .trailing) {
                            if viewModel.mainInterfaceIndex == 0 {
                                if geometry.size.height > geometry.size.width {
                                    verticalPageIndicators
                                        .padding(.trailing, 4)
                                }
                            }
                        }
            }
            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            .opacity(viewModel.isIdleMode ? 0 : 1)
            .allowsHitTesting(!viewModel.isIdleMode)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in viewModel.resetIdleTimer() }
            )
        }
    }
    
    @ViewBuilder
    var fullMediaControlsOverlay: some View {
        if viewModel.showFullMediaControls {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { viewModel.showFullMediaControls = false }
                    }
                
                FullMediaControlsView(isPresented: $viewModel.showFullMediaControls)
            }
            .transition(.opacity)
            .zIndex(2000)
        }
    }

    // Helper to force orientation update
    private func updateInterfaceOrientation(_ orientation: UIInterfaceOrientationMask) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        // Force the view controller to read the new lock value from AppDelegate
        if let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        
        if orientation == .landscapeRight {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        } else {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print(" Start handling Deep Link: \(url.absoluteString)")
        
        // Handle 'sumee://play?id=UUID'
        if url.scheme == "sumee" && url.host == "play" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let queryItems = components.queryItems,
                  let idString = queryItems.first(where: { $0.name == "id" })?.value,
                  let uuid = UUID(uuidString: idString) else {
                print(" Invalid Deep Link Format")
                return
            }
            
            // Find ROM in Storage
            if let rom = ROMStorageManager.shared.roms.first(where: { $0.id == uuid }) {
                print(" Found ROM for Deep Link: \(rom.displayName)")
                
                // Launch immediately on main thread
                DispatchQueue.main.async {
                    // Ensure app is marked as loaded so overlay can appear
                    self.appLoading = false
                    
                    viewModel.selectedROM = rom
                    withAnimation {
                        viewModel.showEmulator = true
                    }
                }
            } else {
                print(" ROM not found for ID: \(uuid)")
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(appLoading: .constant(false))
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
//  Animations

struct Shake: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        return ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}


