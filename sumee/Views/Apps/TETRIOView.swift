import SwiftUI
import WebKit
import GameController
import Combine

struct TETRIOView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject private var gameController = GameControllerManager.shared
    
    // Notifications
    @State private var showStartSelectNotification: Bool = false
    @State private var showMenuLabel: Bool = true

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
            id: UUID(),
            fileName: "TETR.IO",
            displayName: "TETR.IO",
            console: .ios, // Acts as iOS App / Web App
            dateAdded: Date(),
            fileSize: 0,
            customThumbnailPath: nil
        )
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TETRIOWebViewRepresentable(isInputEnabled: !showMenu)
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
                         isPresented = false
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
        .onChange(of: gameController.showMenu) { _, newValue in
            if newValue {
                showMenu = true
                gameController.isGameplayMode = false
                selectedMenuIndex = 0
                activeMenuPage = .main
              
            } else {
                closeMenu()
            }
        }
        .onChange(of: gameController.lastInputTimestamp) { _, _ in
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
            } else if gameController.dpadDown || gameController.dpadRight {
            
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
             isPresented = false
        default: break
        }
    }
}

struct TETRIOWebViewRepresentable: UIViewRepresentable {
    var isInputEnabled: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        
        // Use GamepadWebView to enable controller support (becomeFirstResponder)
        let webView = GamepadWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false // TETR.IO usually fits screen
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Custom User Agent for Desktop-like behavior
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"
        
        // Inject Input Control Shim
        let script = """
            // Input Control Logic
            window._inputEnabled = true;
            window.setInputEnabled = function(enabled) {
                window._inputEnabled = enabled;
            };
            
            const originalGetGamepads = navigator.getGamepads ? navigator.getGamepads.bind(navigator) : null;
            navigator.getGamepads = function() {
                if (!window._inputEnabled) {
                    return [null, null, null, null];
                }
                if (originalGetGamepads) {
                    return originalGetGamepads.apply(navigator, arguments);
                }
                return [];
            };
        """
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)

        if let url = URL(string: "https://tetr.io/") { // Prevent auto-redirects if needed
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        // Start Controller Discovery
        GCController.startWirelessControllerDiscovery {
             print(" [TETR.IO] Controller discovery started")
        }
        
        // Force focus for gamepad input
        DispatchQueue.main.async {
            webView.becomeFirstResponder()
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update Input State
        let script = "window.setInputEnabled(\(isInputEnabled));"
        uiView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        // Aggressive Cleanup
        uiView.stopLoading()
        uiView.load(URLRequest(url: URL(string: "about:blank")!)) // Force clear content
        uiView.removeFromSuperview()
        
        GCController.stopWirelessControllerDiscovery()
        print("[TETR.IO] WebView dismantled, content cleared, and controller discovery stopped")
    }
}
