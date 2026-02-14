import SwiftUI
import WebKit
import GameController
import Combine

struct WebROMPlayerView: View {
    let url: URL
    var onDismiss: () -> Void
    
    @ObservedObject private var gameController = GameControllerManager.shared
    
    // Notifications
    @State private var showStartSelectNotification: Bool = false
    @State private var showMenuLabel: Bool = true // Controls "Menu" text visibility

    // Menu State
    @State private var showMenu = false
    @State private var selectedMenuIndex = 0
    @State private var activeMenuPage: MenuPage = .main
    @State private var menuContentVisible = false
    
    // Dummy / Compatible States for EmulatorMenuView
    @State private var showLoadStateSheet = false
    @State private var selectedLoadStateIndex = 0
    @State private var saveStates: [URL] = []
    @State private var showDeleteConfirmation = false
    @State private var stateToDelete: URL?
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showControllerOptions = false
    
    // Navigation Timer
    @State private var navigationTimer: Timer?
    @State private var navigationDelayTask: DispatchWorkItem?

    // Dummy ROM for Header
    private var dummyROM: ROMItem {
        ROMItem(
            fileName: "Web App",
            console: .web, // Acts as Web App
            fileSize: 0
        )
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            
            // WebView (Contenedor)
            GeometryReader { geometry in
                let isPortrait = geometry.size.height > geometry.size.width
                // Fallback to 50 if safeAreaInsets is 0 (common when ignoring safe area parent)
                let topPadding = geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 54
                
                WebViewContainer(url: url)
                    .padding(.top, isPortrait ? topPadding : 0)
            }
            .ignoresSafeArea()
            .statusBar(hidden: true)
            .persistentSystemOverlays(.hidden)
            
            // Standard Emulator Menu Button (Floating)
            // Hides when menu is open
            VStack {
                HStack(spacing: 12) {
                    // Menu Button
                    ControlCard(actions: [
                        ControlAction(
                            icon: "line.3.horizontal",
                            label: showMenuLabel ? "Menu" : "",
                            action: {
                                withAnimation {
                                    gameController.showMenu = true // Trigger menu
                                }
                            }
                        )
                    ], position: .left)
                    
                    // Controller Notification
                    if showStartSelectNotification && gameController.isControllerConnected {
                        Text("Press Select + Start to open menu")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                            .transition(.opacity)
                    }
                    
                    Spacer()
                }
                .padding(.leading, 60) // Align with D-Pad
                .padding(.top, 40)
                
                Spacer()
            }
            .opacity(showMenu ? 0 : 1)
            .scaleEffect(showMenu ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showMenu)
            .onAppear {
                // Show Controller Notification
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showStartSelectNotification = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    withAnimation { 
                        showStartSelectNotification = false 
                        showMenuLabel = false
                    }
                }
            }
            
            // Full Integrated Emulator Menu
            if showMenu {
                EmulatorMenuView(
                     isVisible: $menuContentVisible,
                     selectedIndex: $selectedMenuIndex,
                     showLoadStateSheet: $showLoadStateSheet,
                     activePage: $activeMenuPage,
                     selectedLoadStateIndex: $selectedLoadStateIndex,
                     saveStates: saveStates,
                     onLoadState: { _ in }, // No-op
                     onDelete: { _ in },    // No-op
                     onRename: { _ in },    // No-op
                     showDeleteConfirmation: $showDeleteConfirmation,
                     stateToDelete: $stateToDelete,
                     isSaving: $isSaving,
                     showSaveSuccess: $showSaveSuccess,
                     rom: dummyROM,
                     onResume: {
                         // Close Menu
                         gameController.showMenu = false
                     },
                     onSave: { }, // No-op
                     onExit: {
                         // Exit App
                         onDismiss()
                     },
                     isControllerConnected: gameController.isControllerConnected,
                     controllerName: gameController.controllerName ?? "Controller",
                     showControllerOptions: $showControllerOptions,
                     isWebApp: true // Enable Simplified Menu
                )
                .onAppear {
                    withAnimation {
                        menuContentVisible = true
                    }
                }
            }
        }
        .onChange(of: gameController.showMenu) { oldValue, newValue in
            if newValue {
                showMenu = true
                gameController.isGameplayMode = false
                selectedMenuIndex = 0
                activeMenuPage = .main
            } else {
                closeMenu()
            }
        }
        .onChange(of: gameController.lastInputTimestamp) { oldValue, newValue in
            guard showMenu else { return }
            
            // Navigation Logic (Simplified from WebEmulatorView)
            let isDirectional = gameController.dpadUp || gameController.dpadDown || gameController.dpadLeft || gameController.dpadRight
            
             // Cancel previous timer
            navigationTimer?.invalidate()
            navigationTimer = nil
            navigationDelayTask?.cancel()
            navigationDelayTask = nil
            
            if isDirectional {
                processNavigation()
                
                // Repeater
                let task = DispatchWorkItem {
                    self.navigationTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
                        self.processNavigation()
                    }
                }
                self.navigationDelayTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
            }
            
            // Menu Selection Logic
            if gameController.buttonAPressed {
                handleMenuSelection()
            } else if gameController.buttonBPressed {
                if activeMenuPage != .main {
                    withAnimation { activeMenuPage = .main }
                } else {
                    gameController.showMenu = false // Resume
                }
            }
        }
    }
    
    func closeMenu() {
        guard showMenu else { return }
        withAnimation(.easeIn(duration: 0.2)) {
            menuContentVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
             showMenu = false
             gameController.showMenu = false
             gameController.isGameplayMode = true
        }
    }
    
    func processNavigation() {
        if activeMenuPage == .main {
            if gameController.dpadUp || gameController.dpadLeft {
                if selectedMenuIndex > 0 {
                    selectedMenuIndex -= 1
                    AudioManager.shared.playMoveSound()
                }
                // Handle horizontal navigation for bottom bar if needed, 
                // but Main Menu is usually vertical.
            } else if gameController.dpadDown || gameController.dpadRight {
                // Max index is 1 for WebApp (Resume, Exit)
                if selectedMenuIndex < 1 {
                    selectedMenuIndex += 1
                    AudioManager.shared.playMoveSound()
                }
            }
        }
    }
    
    func handleMenuSelection() {
        AudioManager.shared.playSelectSound()
        switch selectedMenuIndex {
        case 0: // Resume
            gameController.showMenu = false
        case 1: // Exit
             onDismiss()
        default: break
        }
    }
}

// Subclass to enable Native Gamepad Support
class NativeGamepadWebView: WKWebView {
    override var canBecomeFirstResponder: Bool { true }
}

// Minimal WebView for playback without browser chrome
struct WebViewContainer: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Use custom subclass
        let webView = NativeGamepadWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.isOpaque = false
        
        // Fix: Ensure content fills the screen strictly like a native app
        // This solves the issue where landscape startup respects safe area insets on the right/left
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        // Force First Responder to route Gamepad Events to Web Content
        DispatchQueue.main.async {
            webView.becomeFirstResponder()
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No dynamic updates needed for simple player
    }
}
