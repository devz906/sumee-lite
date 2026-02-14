import SwiftUI
import WebKit
import GameController

struct SlitherIOView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            SlitherWebViewRepresentable()
                .ignoresSafeArea()
                .statusBar(hidden: true)
                .persistentSystemOverlays(.hidden)
            
            // Exit Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding(.top, 40)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
    }
}

struct SlitherWebViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        
        // Use GamepadWebView to enable controller support (becomeFirstResponder)
        let webView = GamepadWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false // Allow background to show if needed
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Custom User Agent for Desktop-like behavior
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"
        
        if let url = URL(string: "https://slither.io/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        // Start Controller Discovery
        GCController.startWirelessControllerDiscovery {
             print(" [Slither.io] Controller discovery started")
        }
        
        // Force focus for gamepad input
        DispatchQueue.main.async {
            webView.becomeFirstResponder()
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        // Aggressive Cleanup
        uiView.stopLoading()
        uiView.load(URLRequest(url: URL(string: "about:blank")!)) // Force clear content
        uiView.removeFromSuperview()
        
        GCController.stopWirelessControllerDiscovery()
        print(" [Slither.io] WebView dismantled, content cleared, and controller discovery stopped")
    }
}
