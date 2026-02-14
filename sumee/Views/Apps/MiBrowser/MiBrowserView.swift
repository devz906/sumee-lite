import SwiftUI
import WebKit
import GameController
import Combine

struct MiBrowserView: View {
    @Binding var isPresented: Bool
    
    // Dependencies
    @ObservedObject private var gameController = GameControllerManager.shared
    
    // Tabs State
    @State private var tabs: [BrowserTab] = [
        BrowserTab(title: "Home", url: URL(string: "https://www.sumee.online")!, urlString: "https://www.sumee.online")
    ]
    @State private var activeTabId: UUID?
    
    // Web State
    @State private var urlString: String = "https://www.sumee.online"
    @State private var currentURL: URL = URL(string: "https://www.sumee.online")!
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webViewRef: WKWebView?
    
    // Cursor State
    @State private var cursorPosition: CGPoint = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
    @State private var isCursorHoveringLink = false 
    
    // UI State
    @State private var hoveredButton: BrowserButton? = nil
    @State private var hoveredUIElement: String? = nil
    @State private var showAddressBar = true
    @State private var areTabsVisible = false
    @State private var isToolbarExpanded = false
    @State private var isWorkInProgressAlertPresented = false
    @State private var isKeyboardPresented = false
    @State private var isMusicMuted = false
    @FocusState private var isAddressFocused: Bool
    
    // Zoom State
    @State private var currentZoom: CGFloat = 1.0
    
    // Theme Color (Start transparent, only show glow when site loads)
    @State private var webThemeColor: Color = .clear
    @State private var ambientGlowImage: UIImage? = nil // For "Sangrado" effect
    @State private var isSnapshotting = false
    
    // History Navigation State
    @State private var wasL1Pressed = false
    @State private var wasR1Pressed = false
    @State private var wasBPressed = false
    @State private var wasYPressed = false
    
    // UI Frames Tracking
    @State private var uiElementFrames: [String: CGRect] = [:]
    
    // Loop
    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    
    // Constants
    let cursorSpeed: CGFloat = 10.0
    let scrollSpeed: CGFloat = 20.0
    
    enum BrowserButton: String {
        case back, forward, refresh, home, bookmarks, saveRom
    }
    
    @State private var showSaveConfirmation = false
    @State private var showCreateROMAlert = false // Confirmation before creating ROM
    @State private var isWebRomMode = false // Full screen mode for Web ROMs
    
    @State private var isTouchActive = false 
    @State private var tapAnimationTrigger = false

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // 1. Background (Wii U Style Grid)
                WiiUBackground()
                    .onTapGesture {
                         isAddressFocused = false
                    }
                
                // 2. WebView
                WebView(
                    url: $currentURL,
                    isLoading: $isLoading,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    webViewRef: $webViewRef,
                    webThemeColor: $webThemeColor,
                    cursorPosition: $cursorPosition,
                    isTouchActive: $isTouchActive,
                    onTapAudio: {
                        tapAnimationTrigger = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            tapAnimationTrigger = false
                        }
                    },
                    onNewTab: { newUrl in
                        withAnimation {
                            addNewTab(with: newUrl)
                        }
                    },
                    onVideoStateChange: { isPlaying in
                        if isPlaying {
                            AudioManager.shared.pauseCurrentMusic()
                        } else {
                            AudioManager.shared.resumeCurrentMusic()
                        }
                    }
                )
                
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .background(
                    Group {
                        if let image = ambientGlowImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 50)
                                .opacity(0.9) // Stronger opacity for more vivid glow
                                .saturation(1.2) // Slightly boost saturation
                                .scaleEffect(1.25) // Scale up to bleed out
                        }
                    }
                )
                .padding(.top, isWebRomMode ? 0 : (isLandscape ? 70 : (geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 44) + 80) + (areTabsVisible ? 50 : 0)) // Dynamic padding for tabs
                // Adjust bottom padding dynamically
                // In Landscape: Small padding so it doesn't touch the very edge
                // In Portrait: Padding matches Dock height to avoid obscuring content
                .padding(.bottom, isWebRomMode ? 0 : (isLandscape ? 30: (isToolbarExpanded ? 130 : 60))) 
                .padding(.horizontal, isWebRomMode ? 0 : 16)
                // Use a default shadow if no glow image yet, otherwise let image glow
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .onReceive(timer) { _ in
                    updateLoop()
                    updateAmbientGlow()
                }

                
                // 3. Top Address Bar
                if !isWebRomMode {
                    VStack {
                        HStack {
                            // Address Pill
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                TextField("Search or enter website name", text: $urlString, onCommit: {
                                    loadUrl(from: urlString)
                                })
                                .disabled(true) // Disable system input
                                .focused($isAddressFocused)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .foregroundColor(.black)
                                
                                if isLoading {
                                    WiiULoadingSpinner()
                                }
                            }
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(30)
                            .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                            .overlay(
                                 RoundedRectangle(cornerRadius: 30)
                                    .stroke(isAddressFocused || hoveredUIElement == "addressBar" ? Color.blue : Color.blue.opacity(0.3), lineWidth: 2)
                            )
                            .scaleEffect(hoveredUIElement == "addressBar" ? 1.02 : 1.0)
                            .animation(.spring(), value: hoveredUIElement)
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: ViewFrameKey.self, value: ["addressBar": geo.frame(in: .global)])
                            })
                            .onTapGesture {
                                withAnimation {
                                    isKeyboardPresented = true
                                }
                            }
                            
                            // Show Tabs Button (When Hidden)
                            if !areTabsVisible {
                                Button(action: { withAnimation { areTabsVisible = true } }) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(gradient: Gradient(colors: [Color.white, Color(red: 0.92, green: 0.94, blue: 0.98)]), startPoint: .top, endPoint: .bottom)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                            )
                                            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.blue)
                                    }
                                    .frame(width: 44, height: 44)
                                }
                                .background(GeometryReader { geo in
                                    Color.clear.preference(key: ViewFrameKey.self, value: ["btn_show_tabs": geo.frame(in: .global)])
                                })
                                .scaleEffect(hoveredUIElement == "btn_show_tabs" ? 1.2 : 1.0)
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Right Side Buttons (Close)
                            Button(action: { isPresented = false }) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(gradient: Gradient(colors: [Color.white, Color(red: 0.92, green: 0.94, blue: 0.98)]), startPoint: .top, endPoint: .bottom)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                                    
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color(white: 0.3))
                                }
                                .frame(width: 44, height: 44)
                            }
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: ViewFrameKey.self, value: ["close": geo.frame(in: .global)])
                            })
                            .scaleEffect(hoveredUIElement == "close" ? 1.2 : 1.0)
                            
                        }
                        .padding(.horizontal)
                        .padding(.top, isLandscape ? 16 : (geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 44) + 10)
                        
                        // --- TAB BAR ---
                        if areTabsVisible {
                            HStack {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(tabs) { tab in
                                            HStack(spacing: 6) {
                                                Text(tab.title.isEmpty ? "Tab" : tab.title)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(activeTabId == tab.id ? .blue : .gray)
                                                    .lineLimit(1)
                                                    .frame(maxWidth: 120)
                                                
                                                Button(action: { withAnimation { closeTab(tab) } }) {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(activeTabId == tab.id ? .blue.opacity(0.6) : .gray.opacity(0.6))
                                                        .padding(4)
                                                        .background(Color.black.opacity(0.05))
                                                        .clipShape(Circle())
                                                }
                                                .background(GeometryReader { geo in
                                                    Color.clear.preference(key: ViewFrameKey.self, value: ["tab_close_\(tab.id.uuidString)": geo.frame(in: .global)])
                                                })
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(
                                                ZStack {
                                                    if activeTabId == tab.id {
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .fill(Color.white)
                                                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                                            )
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .fill(Color.white.opacity(0.4))
                                                            .border(Color.clear, width: 0) // Fix for tap area
                                                    }
                                                }
                                            )
                                            .background(GeometryReader { geo in
                                                Color.clear.preference(key: ViewFrameKey.self, value: ["tab_select_\(tab.id.uuidString)": geo.frame(in: .global)])
                                            })
                                            .onTapGesture {
                                                withAnimation { switchToTab(tab) }
                                            }
                                        }
                                        
                                        // New Tab Button
                                        Button(action: { withAnimation { addNewTab() } }) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.blue)
                                                .padding(8)
                                                .background(Color.white.opacity(0.6))
                                                .clipShape(Circle())
                                        }
                                        .background(GeometryReader { geo in
                                            Color.clear.preference(key: ViewFrameKey.self, value: ["btn_new_tab": geo.frame(in: .global)])
                                        })
                                        .padding(.leading, 4)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                                }
                                
                                // Mute Button
                                Button(action: {
                                    isMusicMuted.toggle()
                                    if isMusicMuted {
                                        AudioManager.shared.pauseCurrentMusic()
                                    } else {
                                        AudioManager.shared.playBrowserMusic()
                                    }
                                }) {
                                    Image(systemName: isMusicMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(isMusicMuted ? .gray : .blue.opacity(0.7))
                                        .padding(10)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.8))
                                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                        )
                                }
                                .background(GeometryReader { geo in
                                    Color.clear.preference(key: ViewFrameKey.self, value: ["btn_mute": geo.frame(in: .global)])
                                })
                                .padding(.bottom, 8)
                                
                                // Hide Tabs Button (Right Side)
                                Button(action: { withAnimation { areTabsVisible = false } }) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.blue.opacity(0.7))
                                        .padding(10)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.8))
                                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                        )
                                }
                                .background(GeometryReader { geo in
                                    Color.clear.preference(key: ViewFrameKey.self, value: ["btn_hide_tabs": geo.frame(in: .global)])
                                })
                                .padding(.trailing, 16)
                                .padding(.bottom, 8)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        } 
                        // Removed bottom handle, moved to header
                        
                        Spacer()
                    }
                    .onChange(of: currentURL) { newUrl in
                       if !isAddressFocused {
                           urlString = newUrl.absoluteString
                       }
                    }
                }
                
                // 4. Bottom Toolbar (Wii U Dock)
                if !isWebRomMode {
                    VStack {
                        Spacer()
                        if isToolbarExpanded {
                            VStack(spacing: 0) {
                                 // Collapse Button (Tab-like)
                                 Button(action: { withAnimation { isToolbarExpanded = false }}) {
                                     Image(systemName: "chevron.compact.down")
                                         .font(.system(size: 20, weight: .bold))
                                         .foregroundColor(.blue)
                                         .padding(.horizontal, 40)
                                         .padding(.vertical, 8)
                                         .background(
                                             Capsule() // More rounded
                                                 .fill(Color(white: 0.95))
                                                 .shadow(color: .black.opacity(0.1), radius: 2, y: -2)
                                         )
                                 }
                                 .background(GeometryReader { geo in
                                    Color.clear.preference(key: ViewFrameKey.self, value: ["btn_collapse": geo.frame(in: .global)])
                                 })
                                 .offset(y: 1) // Merge with dock

                                 // Main Dock
                                 let btnSize: CGFloat = isLandscape ? 46 : 42
                                 let dockSpacing: CGFloat = isLandscape ? 20 : 12
                                 let dockPadding: CGFloat = isLandscape ? 18 : 16
                                 
                                 HStack(spacing: dockSpacing) {
                                    BrowserToolbarButton(icon: "arrow.left", type: .back, isHovered: hoveredButton == .back, buttonSize: btnSize) {
                                        webViewRef?.goBack()
                                    }
                                    .opacity(canGoBack ? 1.0 : 0.5)
                                    .background(GeometryReader { geo in
                                        Color.clear.preference(key: ViewFrameKey.self, value: ["btn_back": geo.frame(in: .global)])
                                    })
                                    
                                    BrowserToolbarButton(icon: "arrow.right", type: .forward, isHovered: hoveredButton == .forward, buttonSize: btnSize) {
                                        webViewRef?.goForward()
                                    }
                                    .opacity(canGoForward ? 1.0 : 0.5)
                                    .background(GeometryReader { geo in
                                        Color.clear.preference(key: ViewFrameKey.self, value: ["btn_forward": geo.frame(in: .global)])
                                    })
                                    
                                    BrowserToolbarButton(icon: "arrow.clockwise", type: .refresh, isHovered: hoveredButton == .refresh, buttonSize: btnSize) {
                                        webViewRef?.reload()
                                    }
                                    .background(GeometryReader { geo in
                                        Color.clear.preference(key: ViewFrameKey.self, value: ["btn_refresh": geo.frame(in: .global)])
                                    })
                                    
                                    BrowserToolbarButton(icon: "house.fill", type: .home, isHovered: hoveredButton == .home, buttonSize: btnSize) {
                                         loadUrl(from: "https://www.google.com")
                                    }
                                    .background(GeometryReader { geo in
                                        Color.clear.preference(key: ViewFrameKey.self, value: ["btn_home": geo.frame(in: .global)])
                                    })
                                    
                                    BrowserToolbarButton(icon: "star.fill", type: .bookmarks, isHovered: hoveredButton == .bookmarks, buttonSize: btnSize) {
                                        isWorkInProgressAlertPresented = true
                                    }
                                    .background(GeometryReader { geo in
                                        Color.clear.preference(key: ViewFrameKey.self, value: ["btn_bookmarks": geo.frame(in: .global)])
                                    })
                                    
                                    // Save as ROM
                                    BrowserToolbarButton(icon: "gamecontroller", type: .saveRom, isHovered: hoveredButton == .saveRom, buttonSize: btnSize) {
                                        showCreateROMAlert = true
                                    }
                                    .background(GeometryReader { geo in
                                        Color.clear.preference(key: ViewFrameKey.self, value: ["btn_saveRom": geo.frame(in: .global)])
                                    })
                                    .alert("Create Web ROM", isPresented: $showCreateROMAlert) {
                                        Button("Create", role: .none) {
                                            saveAsWebROM()
                                        }
                                        Button("Cancel", role: .cancel) { }
                                    } message: {
                                        Text("Do you want to save this page as a Web Game in your library?")
                                    }
                                    
                                    .alert("Coming Soon", isPresented: $isWorkInProgressAlertPresented) {
                                        Button("OK", role: .cancel) { }
                                    } message: {
                                        Text("We are working on this feature.")
                                    }
                                }
                                .padding(dockPadding)
                                .background(
                                    Capsule() 
                                        .fill(LinearGradient(gradient: Gradient(colors: [Color(white: 0.95), Color(white: 0.9)]), startPoint: .top, endPoint: .bottom))
                                        .shadow(color: .black.opacity(0.2), radius: 10, y: -5)
                                )
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            // Collapsed State (Stylish Handle Bar)
                             Button(action: { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { isToolbarExpanded = true }}) {
                                Capsule()
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color(hex: "E0E0FF") ?? .blue.opacity(0.1)]), startPoint: .top, endPoint: .bottom))
                                    .frame(width: 120, height: 8) // Wide, thin Handle
                                    .overlay(
                                        Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                    .padding(20) // Hit area padding
                            }
                            .scaleEffect(hoveredUIElement == "btn_expand" ? 1.2 : 1.0)
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: ViewFrameKey.self, value: ["btn_expand": geo.frame(in: .global)])
                            })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 20) // Reset padding
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isToolbarExpanded)
                }
                
                // 5. Virtual Cursor (Top Layer)
                ZStack {
                    // Interaction Point (Hidden logic, Visual Hand Only)
                    
                    // The Hand Image
                    Image(systemName: "hand.point.up.left.fill") // Wii U style hand
                        .resizable()
                        .frame(width: 45, height: 45)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                        .overlay(
                            Image(systemName: "hand.point.up.left")
                                .resizable()
                                .frame(width: 45, height: 45)
                                .foregroundColor(.black.opacity(0.8))
                        )
                        // Align Tip (Top-Left) to Interaction Point
                        // Frame 45x45. Center relative to position is (0,0).
                        // Image Top-Left is at (-22.5, -22.5).
                        // SF Symbol "hand.point.up.left" tip is at roughly (0,0) of its bounds.
                        // We want Tip at (0,0) global (which matches cursorPosition).
                        // So we need to shift image so its Top-Left is at (0,0).
                        // Move Right/Down by Half Size.
                        .offset(x: 22, y: 22)
                        .position(cursorPosition)
                        .scaleEffect((gameController.buttonAPressed || tapAnimationTrigger) ? 0.9 : 1.0)
                        .animation(.linear(duration: 0.1), value: gameController.buttonAPressed)
                        .animation(.linear(duration: 0.1), value: tapAnimationTrigger)
                }
                .allowsHitTesting(false) // Pass through clicks
            }
            // 6. Virtual Keyboard Overlay
            if isKeyboardPresented {
                VirtualKeyboard(
                    text: $urlString,
                    isPresented: $isKeyboardPresented,
                    onCommit: {
                        loadUrl(from: urlString)
                    }
                )
                .zIndex(90) // Below cursor (100+) but above webview/UI
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            // 7. Web ROM Explorer Overlay
            // 8. Save Confirmation Toast
            if showSaveConfirmation {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.green)
                        Text("Saved as Web ROM")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                    .padding(.bottom, 150)
                }
                .zIndex(100)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .ignoresSafeArea() // Critical Fix: Aligns local coordinates (0,0) with Global Screen (0,0) preventing cursor misalignment
        .onPreferenceChange(ViewFrameKey.self) { frames in
            self.uiElementFrames = frames
        }
        .onReceive(timer) { _ in
            updateLoop()
        }
        .onChange(of: gameController.buttonAPressed) { pressed in
            if pressed && !isKeyboardPresented {
                handleClick()
            }
        }
        .onAppear {
            loadBrowserState()
            
            if activeTabId == nil {
                activeTabId = tabs.first?.id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                gameController.disableHomeNavigation = true
                AudioManager.shared.playBrowserMusic()
            }
        }
        .onChange(of: tabs) { _ in saveBrowserState() }
        .onChange(of: activeTabId) { _ in saveBrowserState() }
        .onDisappear {
            gameController.disableHomeNavigation = false
            AudioManager.shared.restoreBackgroundMusic()
        }
    }
    
    // MARK: - Logic
    
    func loadUrl(from string: String) {
        isAddressFocused = false // Dismiss keyboard
        var cleanUrl = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanUrl.lowercased().hasPrefix("http") {
            if cleanUrl.contains(".") {
                cleanUrl = "https://" + cleanUrl
            } else {
                cleanUrl = "https://www.google.com/search?q=" + cleanUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }
        
        if let url = URL(string: cleanUrl) {
            currentURL = url
            urlString = cleanUrl // Update text field
            currentZoom = 1.0 // Reset Zoom on navigation
            
            // Sync with Tab Data
            if let index = tabs.firstIndex(where: { $0.id == activeTabId }) {
                tabs[index].url = url
                tabs[index].urlString = cleanUrl
            }
            
            // Reset "Sangrado" effect on new page load so it doesn't linger
            withAnimation {
                self.ambientGlowImage = nil
            }
        }
    }

    func saveAsWebROM() {
        // currentURL is not optional, so we remove it from guard let
        guard let webView = webViewRef else { return }
        
        let title = webView.title ?? "Web Page"
        // Generate a unique virtual ROM without snapshot
        let rom = ROMItem(
            id: UUID(),
            fileName: "web_\(UUID().uuidString).webrom", // .webrom extension
            displayName: title,
            console: .web, // CORRECT: Use .web console type
            dateAdded: Date(),
            fileSize: 0,
            customThumbnailPath: nil,
            externalLaunchURL: self.currentURL.absoluteString
        )
        
        // Save to Storage
        ROMStorageManager.shared.addIOSROM(rom) // Reuse this method as it just appends
        
        // Show Feedback
        withAnimation { showSaveConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSaveConfirmation = false }
        }
    }
    
    // MARK: - Tab Management
    
    func switchToTab(_ tab: BrowserTab) {
        // Save state of current tab
        if let currentId = activeTabId, let index = tabs.firstIndex(where: { $0.id == currentId }) {
            tabs[index].url = currentURL
            tabs[index].urlString = urlString
            if let title = webViewRef?.title, !title.isEmpty {
                tabs[index].title = title
            }
        }
        
        // Switch
        activeTabId = tab.id
        currentURL = tab.url
        urlString = tab.urlString
    }
    
    func addNewTab(with url: URL? = nil) {
        // Save current first
        if let currentId = activeTabId, let index = tabs.firstIndex(where: { $0.id == currentId }) {
            tabs[index].url = currentURL
            tabs[index].urlString = urlString
            if let title = webViewRef?.title, !title.isEmpty {
                 tabs[index].title = title
             }
        }
        
        let startURL = url ?? URL(string: "https://www.google.com")!
        let newTab = BrowserTab(title: "New Tab", url: startURL, urlString: startURL.absoluteString)
        tabs.append(newTab)
        
   
        if !areTabsVisible {
            areTabsVisible = true
        }
        
        // Switch
        activeTabId = newTab.id
        currentURL = newTab.url
        urlString = newTab.urlString
    }
    
    func closeTab(_ tab: BrowserTab) {
        guard tabs.count > 1 else { return }
        
        // If closing the active tab
        if tab.id == activeTabId {
            // Find another tab to switch to
            if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
                // Try previous, else next
                let newIndex = index > 0 ? index - 1 : index + 1
                if newIndex < tabs.count {
                    let newTab = tabs[newIndex]
                    switchToTab(newTab) // This saves current (closing) tab unnecessarily but safe
           

                }
            }
        }
        
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs.remove(at: index)
        }
    }
    
    // MARK: - Persistence
    
    func getBrowserStorageDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("system/browser")
    }
    
    func saveBrowserState() {
        let state = SavedBrowserState(tabs: tabs, activeTabId: activeTabId)
        let folder = getBrowserStorageDirectory()
        let filename = folder.appendingPathComponent("session.json")
        
        DispatchQueue.global(qos: .background).async {
            do {
                // Create folder if it doesn't exist
                if !FileManager.default.fileExists(atPath: folder.path) {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
                }
                
                let data = try JSONEncoder().encode(state)
                try data.write(to: filename, options: [.atomicWrite, .completeFileProtection])
            } catch {
                print("Failed to save browser state: \(error)")
            }
        }
    }
    
    func loadBrowserState() {
        let filename = getBrowserStorageDirectory().appendingPathComponent("session.json")
        
        do {
            let data = try Data(contentsOf: filename)
            let state = try JSONDecoder().decode(SavedBrowserState.self, from: data)
            self.tabs = state.tabs
            self.activeTabId = state.activeTabId
            
            // Restore current URL from active tab
            if let activeId = state.activeTabId, let tab = state.tabs.first(where: { $0.id == activeId }) {
                self.currentURL = tab.url
                self.urlString = tab.urlString
            }
        } catch {
            print("No saved state found or failed to load")
        }
    }
    
    // MARK: - Ambient Effect
    private func updateAmbientGlow() {
        // Removed !isLoading check so we get a glow even during load (if content is visible) or if logic is stuck
        guard let webView = webViewRef, !isSnapshotting else { return }
        
        isSnapshotting = true
        
        let config = WKSnapshotConfiguration()
        // Capture a smaller width for performance – we blur it anyway
        config.snapshotWidth = 150
        
        webView.takeSnapshot(with: config) { image, error in
            if let image = image {
                // Update directly without animation to avoid flickering/pulsing
                self.ambientGlowImage = image
            }
            // Cooldown: 0.5s for more responsive updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSnapshotting = false
            }
        }
    }
    
    func updateLoop() {
        // ... Existing loop ...
        
        // 0. Global Browser Shortcuts
        // Toggle WebROM Mode (Exit) if Start is pressed

        if gameController.buttonStartPressed && isWebRomMode {
             withAnimation { isWebRomMode = false }
        }

        // If keyboard is open, disable browser controls (Exclusive Mode)
        if isKeyboardPresented { return }
        
        guard let controller = gameController.currentController?.extendedGamepad else { return }
        
        // --- ZOOM CONTROL (L2/R2) ---
        var zoomChanged = false
        if gameController.buttonR2Pressed {
            currentZoom += 0.02
            if currentZoom > 3.0 { currentZoom = 3.0 }
            zoomChanged = true
        }
        if gameController.buttonL2Pressed {
            currentZoom -= 0.02
            if currentZoom < 0.5 { currentZoom = 0.5 }
            zoomChanged = true
        }
        
        if zoomChanged {
            // Apply Zoom via JS
            webViewRef?.evaluateJavaScript("document.body.style.zoom = '\(currentZoom)'")
        }
        
        // --- TAB NAVIGATION (L1/R1) ---
        if gameController.buttonL1Pressed {
            if !wasL1Pressed {
                // Prev Tab
                if let currentId = activeTabId, let index = tabs.firstIndex(where: { $0.id == currentId }) {
                    let prevIndex = (index - 1 + tabs.count) % tabs.count
                    switchToTab(tabs[prevIndex])
                }
                wasL1Pressed = true
            }
        } else {
            wasL1Pressed = false
        }
        
        if gameController.buttonR1Pressed {
            if !wasR1Pressed {
                // Next Tab
                if let currentId = activeTabId, let index = tabs.firstIndex(where: { $0.id == currentId }) {
                    let nextIndex = (index + 1) % tabs.count
                    switchToTab(tabs[nextIndex])
                }
                wasR1Pressed = true
            }
        } else {
            wasR1Pressed = false
        }
        
        // --- WEB HISTORY (B: Back, Y: Forward) ---
        if gameController.buttonBPressed {
             if !wasBPressed {
                 webViewRef?.goBack()
                 wasBPressed = true
             }
        } else {
             wasBPressed = false
        }
        
        if gameController.buttonYPressed {
             if !wasYPressed {
                 webViewRef?.goForward()
                 wasYPressed = true
             }
        } else {
             wasYPressed = false
        }
        
        // 1. Move Cursor (Left Stick) - Use Calibrated Values from Manager
        let dx = CGFloat(gameController.leftThumbstickX) * cursorSpeed
        let dy = CGFloat(gameController.leftThumbstickY) * -1 * cursorSpeed // Invert Y
        
        if abs(dx) > 0.1 || abs(dy) > 0.1 {
            var newX = cursorPosition.x + dx
       
            var newY = cursorPosition.y + dy
            
            // Clamp to screen
            // Since we ignoreSafeArea now, bounds are full screen.
            let bounds = UIScreen.main.bounds
            newX = min(max(newX, 0), bounds.width)
            newY = min(max(newY, 0), bounds.height)
            
            cursorPosition = CGPoint(x: newX, y: newY)
        }
        
        // 2. Scroll Page (Right Stick) - Use Calibrated Values from Manager
        let scrollY = CGFloat(gameController.rightThumbstickY) * -1 * scrollSpeed
        if abs(scrollY) > 2.0 {
            webViewRef?.evaluateJavaScript("window.scrollBy(0, \(scrollY));")
        }
        
        // 3. Collision Detection for Buttons
        checkButtonHover()
        
        // 4. Update Ambient Glow (Sangrado)
        updateAmbientGlow()
    }
    
    func checkButtonHover() {
        // Reset
        hoveredButton = nil
        hoveredUIElement = nil
        
        // Check UI Elements
        for (key, frame) in uiElementFrames {
            if frame.contains(cursorPosition) {
                hoveredUIElement = key
                
                // Map to BrowserButton enum for specific hover effects
                if key == "btn_back" { hoveredButton = .back }
                else if key == "btn_forward" { hoveredButton = .forward }
                else if key == "btn_refresh" { hoveredButton = .refresh }
                else if key == "btn_home" { hoveredButton = .home }
                else if key == "btn_bookmarks" { hoveredButton = .bookmarks }
                else if key == "btn_saveRom" { hoveredButton = .saveRom }
                return
            }
        }
    }
    
    func handleClick() {
        // 1. Check UI Elements High Priority
        if let key = hoveredUIElement {
             handleUIClick(key)
             return
        }
        
        // 2. Fallback to WebView Click
        // Calculate WebView Frame roughly
        let bounds = UIScreen.main.bounds
        let webViewFrame = CGRect(
            x: 16,
            y: 70,
            width: bounds.width - 32,
            height: bounds.height - 150
        )
        
        if webViewFrame.contains(cursorPosition) {
            let localX = cursorPosition.x - webViewFrame.origin.x
            let localY = cursorPosition.y - webViewFrame.origin.y
            
            // Inject Click
            let js = """
            var elem = document.elementFromPoint(\(localX), \(localY));
            if (elem) {
                elem.click();
                elem.focus();
            }
            """
            webViewRef?.evaluateJavaScript(js)
             //  dismiss keyboard if clicking webview
             isAddressFocused = false
        }
    }
    
    func handleUIClick(_ key: String) {
        switch key {
        case "addressBar":
            // Show Virtual Keyboard instead of system keyboard if desired
            withAnimation {
                isKeyboardPresented = true
            }
        case "close":
            isPresented = false
        case "btn_expand":
            withAnimation { isToolbarExpanded = true }
        case "btn_collapse":
            withAnimation { isToolbarExpanded = false }
        case "btn_back":
            webViewRef?.goBack()
        case "btn_forward":
            webViewRef?.goForward()
        case "btn_refresh":
            webViewRef?.reload()
        case "btn_home":
             loadUrl(from: "https://www.google.com")
        case "btn_bookmarks":
             isWorkInProgressAlertPresented = true
        case "btn_new_tab":
             withAnimation { addNewTab() }
        case "btn_hide_tabs":
             withAnimation { areTabsVisible = false }
        case "btn_show_tabs":
             withAnimation { areTabsVisible = true }
        case "btn_mute":
            isMusicMuted.toggle()
            if isMusicMuted {
                AudioManager.shared.pauseCurrentMusic()
            } else {
                AudioManager.shared.playBrowserMusic()
            }
        default:
            // Dynamic Keys for Tabs
            if key.starts(with: "tab_select_") {
                let idString = key.replacingOccurrences(of: "tab_select_", with: "")
                if let uuid = UUID(uuidString: idString),
                   let tab = tabs.first(where: { $0.id == uuid }) {
                    withAnimation { switchToTab(tab) }
                }
            }
            else if key.starts(with: "tab_close_") {
                let idString = key.replacingOccurrences(of: "tab_close_", with: "")
                if let uuid = UUID(uuidString: idString),
                   let tab = tabs.first(where: { $0.id == uuid }) {
                    withAnimation { closeTab(tab) }
                }
            }
            break
        }
    }
}

// MARK: - Subviews & Helpers

struct SavedBrowserState: Codable {
    var tabs: [BrowserTab]
    var activeTabId: UUID?
}

struct BrowserTab: Identifiable, Equatable, Codable {
    var id: UUID
    var title: String
    var url: URL
    var urlString: String
    
    init(id: UUID = UUID(), title: String, url: URL, urlString: String) {
        self.id = id
        self.title = title
        self.url = url
        self.urlString = urlString
    }
}

struct ViewFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct WiiUBackground: View {
    var body: some View {
        ZStack {
            Color(white: 0.92)
                .ignoresSafeArea()
            
            // Grid
            GeometryReader { geometry in
                Path { path in
                    let step: CGFloat = 40
                    for x in stride(from: 0, to: geometry.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    for y in stride(from: 0, to: geometry.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            }
        }
    }
}

struct BrowserToolbarButton: View {
    let icon: String
    let type: MiBrowserView.BrowserButton
    var isHovered: Bool
    var buttonSize: CGFloat = 50
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.white, Color(hex: "E0E0FF") ?? .white]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                    .overlay(
                        Circle()
                            .stroke( isHovered ? Color.blue : Color.blue.opacity(0.3), lineWidth: isHovered ? 3 : 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: buttonSize * 0.4, weight: .bold))
                    .foregroundColor(isHovered ? .blue : .gray)
            }
            .scaleEffect(isHovered ? 1.2 : 1.0)
            .animation(.spring(), value: isHovered)
        }
    }
}

// MARK: - Custom Wii U Loader
struct WiiULoadingSpinner: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 4)
                    .offset(y: -8) // Fixed distance from center
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .rotationEffect(.degrees(rotation)) // Rotate the whole ring uniformly
        .frame(width: 24, height: 24)
        .onAppear {
            withAnimation(Animation.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

