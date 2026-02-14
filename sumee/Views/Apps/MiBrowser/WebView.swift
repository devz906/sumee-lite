import SwiftUI
import WebKit
import Combine

struct WebView: UIViewRepresentable {
    @Binding var url: URL
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var webViewRef: WKWebView? // To expose for direct control
    @Binding var webThemeColor: Color // New binding for theme color
    
    // Touch Tracking
    @Binding var cursorPosition: CGPoint
    @Binding var isTouchActive: Bool
    var onTapAudio: () -> Void
    var onNewTab: ((URL) -> Void)?
    
    // Audio Control
    var onVideoStateChange: (Bool) -> Void // True = Playing, False = Paused/Ended

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Inject JS for Video Detection & Theme Color Extraction
        let js = """
        window.addEventListener('play', function(e) {
            window.webkit.messageHandlers.videoListener.postMessage('playing');
        }, true);
        window.addEventListener('pause', function(e) {
            window.webkit.messageHandlers.videoListener.postMessage('paused');
        }, true);
        window.addEventListener('ended', function(e) {
            window.webkit.messageHandlers.videoListener.postMessage('paused');
        }, true);
        
        function sendThemeColor() {
            var color = "";
            
            // 1. Try meta theme-color (Mobile Browser Standard)
            var meta = document.querySelector('meta[name="theme-color"]');
            if (meta) {
                color = meta.getAttribute('content');
            }
            
            // 2. If no meta, try exact background colors
            if (!color || color === "transparent" || color === "rgba(0, 0, 0, 0)") {
                 if (document.body) {
                    var style = window.getComputedStyle(document.body);
                    if (style && style.backgroundColor !== 'rgba(0, 0, 0, 0)' && style.backgroundColor !== 'transparent') {
                        color = style.backgroundColor;
                    }
                 }
            }
            
            // 3. Fallback to HTML tag if body is transparent
            if (!color || color === "transparent" || color === "rgba(0, 0, 0, 0)") {
                var htmlStyle = window.getComputedStyle(document.documentElement);
                if (htmlStyle && htmlStyle.backgroundColor !== 'rgba(0, 0, 0, 0)' && htmlStyle.backgroundColor !== 'transparent') {
                    color = htmlStyle.backgroundColor;
                }
            }
            
            // 4. Ultimate Fallback: White (Most webs are white by default)
             if (!color || color === "transparent" || color === "rgba(0, 0, 0, 0)") {
                color = "white"; 
             }
            
            window.webkit.messageHandlers.themeColorListener.postMessage(color);
        }
        
        // Check on load
        if (document.readyState === 'complete') {
            sendThemeColor();
        } else {
            window.addEventListener('load', sendThemeColor);
        }
        
        // Check periodically (SPA navigation changes)
        setInterval(sendThemeColor, 2000);
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(context.coordinator, name: "videoListener")
        config.userContentController.add(context.coordinator, name: "themeColorListener")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // Anti-Bot / "Am I a Robot?" Fix, i got this frome google lol
        // We set a standard Mobile Safari User-Agent to ensure Google and other sites treat this as a legitimate mobile browser.
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1"
        
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .white
        webView.isOpaque = false
        
        // Touch Gesture Recognizers for Cursor Tracking
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.maximumNumberOfTouches = 1
        panGesture.cancelsTouchesInView = false // Allow web interaction
        panGesture.delegate = context.coordinator
        webView.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false // Allow web click
        tapGesture.delegate = context.coordinator
        webView.addGestureRecognizer(tapGesture)
        
        DispatchQueue.main.async {
            self.webViewRef = webView
        }
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Prevent cyclic reloads: Only load if the requested URL is effectively different 
   
        
        let targetURL = url
        
        // Check if we already processed this URL to avoid loop
        if context.coordinator.lastLoadedURL != targetURL {
             context.coordinator.lastLoadedURL = targetURL
             
             // Check if Webview is already there (e.g. Navigation just happened)
             if uiView.url != targetURL {
                 let request = URLRequest(url: targetURL)
                 uiView.load(request)
             }
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate, WKScriptMessageHandler {
        var parent: WebView
        var lastLoadedURL: URL? // State to track last "external" request or sync
        var panStartLocation: CGPoint? // Track pan start for gesture navigation

        init(_ parent: WebView) {
            self.parent = parent
        }
        
        //  Script Messages
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoListener", let body = message.body as? String {
                if body == "playing" {
                    parent.onVideoStateChange(true)
                } else if body == "paused" {
                    parent.onVideoStateChange(false)
                }
            } else if message.name == "themeColorListener", let colorString = message.body as? String {
                DispatchQueue.main.async {
                    if let color = self.parseColor(from: colorString) {
                        withAnimation {
                            self.parent.webThemeColor = Color(uiColor: color)
                        }
                    }
                }
            }
        }
        
        private func parseColor(from string: String) -> UIColor? {
            let cleanString = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            if cleanString.isEmpty || cleanString == "transparent" || cleanString == "rgba(0, 0, 0, 0)" {
                return nil
            }
            
            // Hex
            if cleanString.hasPrefix("#") {
                var hex = cleanString.dropFirst()
                if hex.count == 3 {
                    let r = hex[hex.startIndex]
                    let g = hex[hex.index(hex.startIndex, offsetBy: 1)]
                    let b = hex[hex.index(hex.startIndex, offsetBy: 2)]
                    hex = "\(r)\(r)\(g)\(g)\(b)\(b)"
                }
                
                if hex.count == 6 {
                    let scanner = Scanner(string: String(hex))
                    var hexNumber: UInt64 = 0
                    if scanner.scanHexInt64(&hexNumber) {
                        let r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                        let g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                        let b = CGFloat(hexNumber & 0x0000ff) / 255
                        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
                    }
                }
            }
            
            // RGB
            if cleanString.hasPrefix("rgb") {
                let start = cleanString.firstIndex(of: "(")
                let end = cleanString.firstIndex(of: ")")
                if let start = start, let end = end {
                    let components = cleanString[cleanString.index(after: start)..<end]
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .compactMap { Double($0) }
                    
                    if components.count >= 3 {
                        return UIColor(red: components[0]/255, green: components[1]/255, blue: components[2]/255, alpha: 1.0)
                    }
                }
            }
            
            return nil
        }
        
        //  Gesture Handling
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let location = gesture.location(in: nil) // Window coordinates (global)
            let velocity = gesture.velocity(in: nil)
            
            // Pass to SwiftUI View State
            if gesture.state == .began {
                panStartLocation = gesture.location(in: gesture.view)
                
                DispatchQueue.main.async {
                    self.parent.isTouchActive = true
                    self.parent.cursorPosition = location
                }
            } else if gesture.state == .changed {
                DispatchQueue.main.async {
                    self.parent.isTouchActive = true
                    self.parent.cursorPosition = location
                }
            } else if gesture.state == .ended {
                DispatchQueue.main.async {
                    self.parent.isTouchActive = false
                }
                
                // Custom Swipe Navigation Logic
               
                if abs(velocity.x) > 500 && abs(velocity.y) < 600 {
                    if let start = panStartLocation {
                        let viewWidth =  UIScreen.main.bounds.width
                        
                        // Swipe Right (Go Back)
                        // Trigger if started in the left 35% of the screen (Was only native edge ~5%)
                        if velocity.x > 0 && start.x < (viewWidth * 0.35) {
                            if let webView = gesture.view as? WKWebView, webView.canGoBack {
                                webView.goBack()
                            }
                        }
                        // Swipe Left (Go Forward)
                        // Trigger if started in the right 35%
                         else if velocity.x < 0 && start.x > (viewWidth * 0.65) {
                            if let webView = gesture.view as? WKWebView, webView.canGoForward {
                                webView.goForward()
                            }
                        }
                    }
                }
                panStartLocation = nil
                
            } else if gesture.state == .cancelled {
                 panStartLocation = nil
                 DispatchQueue.main.async {
                    self.parent.isTouchActive = false
                }
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: nil)
            
            if gesture.state == .ended {
                DispatchQueue.main.async {
                    self.parent.cursorPosition = location
                    self.parent.isTouchActive = true // Briefly true to show position
                    self.parent.onTapAudio()
                    
                    // Reset Active shortly after tap
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                         self.parent.isTouchActive = false
                    }
                }
            }
        }
        
        // Allow simultaneous gestures (Web Scroll + Our Pan)
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        // Handle Policy (Prevent External Apps / Universal Links)
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 1. Check if it's a user click
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url,
                   let scheme = url.scheme, (scheme == "http" || scheme == "https") {
                    
                    // 2. Perform manual load to bypass System Universal Link check (App Switching)
                    // This keeps YouTube/Facebook inside the WebView
                    webView.load(navigationAction.request)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        // Handle Target="_blank" / New Window
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                DispatchQueue.main.async {
                    self.parent.onNewTab?(url)
                }
            }
            return nil // Prevent new native window, we handled it
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                
                // Reset Video Audio State on Navigation
                // If we navigate away, any playing video stops, so resume background music.
                self.parent.onVideoStateChange(false)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                
                // Sync internal navigation back to parent binding
                if let currentURL = webView.url {
                     // Check if different to avoid cycle (though binding update should be fine)
                     if self.parent.url != currentURL {
                         self.parent.url = currentURL
                         self.lastLoadedURL = currentURL 
                     }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}
