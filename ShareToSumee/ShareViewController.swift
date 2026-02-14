import UIKit
import Social
import MobileCoreServices

class ShareViewController: UIViewController {

    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let container = UIView()
    private let backgroundView = UIView() // Explicit background view for fading

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 1. Entrance Animation
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.backgroundView.alpha = 1.0
            self.container.alpha = 1.0
            self.container.transform = .identity
        } completion: { _ in
            // 2. Process Content
            self.handleSharedContent()
        }
    }
    
    private func setupUI() {
        self.view.backgroundColor = .clear
        
        // Background Dimming View
        backgroundView.frame = view.bounds
        backgroundView.backgroundColor = UIColor(white: 0, alpha: 0.6)
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.alpha = 0 // Start invisible
        view.addSubview(backgroundView)
        
        // Floating Container
        container.backgroundColor = .secondarySystemGroupedBackground
        container.layer.cornerRadius = 16
        // Shadow for depth
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.2
        container.layer.shadowOffset = CGSize(width: 0, height: 4)
        container.layer.shadowRadius = 10
        
        container.translatesAutoresizingMaskIntoConstraints = false
        // Start state for entry animation
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        view.addSubview(container)
        
        let stack = UIStackView(arrangedSubviews: [activityIndicator, statusLabel])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        statusLabel.text = "Importing..."
        statusLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        statusLabel.textColor = .label
        
        activityIndicator.startAnimating()
        
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            container.heightAnchor.constraint(equalToConstant: 70),
            
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }
    
    private func handleSharedContent() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem],
              let item = items.first,
              let attachments = item.attachments else {
            self.animateAndClose()
            return
        }
        
        var found = false
        
        // We will execute close after a minimum duration to let the user see the animation
        let minimumDuration: TimeInterval = 1.5
        let startTime = Date()
        
        func finish() {
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(0, minimumDuration - elapsed)
            
            // Wait for the remaining time before closing
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                self.animateAndClose()
            }
        }
        
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier("public.url") {
                found = true
                provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (urlItem, error) in
                    if let url = urlItem as? URL {
                        self?.saveSharedURL(url)
                    } else if let urlString = urlItem as? String, let url = URL(string: urlString) {
                         self?.saveSharedURL(url)
                    }
                    finish()
                }
                break
            }
        }
        
        if !found {
            finish()
        }
    }
    
    private func animateAndClose() {
        // 3. Exit Animation
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.backgroundView.alpha = 0
            self.container.alpha = 0
            self.container.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    private func saveSharedURL(_ url: URL) {
        let suiteName = "group.com.sumee.shared"
        if let sharedDefaults = UserDefaults(suiteName: suiteName) {
            print(" Saving URL to App Group: \(url.absoluteString)")
            sharedDefaults.set(url.absoluteString, forKey: "sharedURL")
            sharedDefaults.synchronize()
            
            // Post Darwin Notification to wake up/notify main app
            let notificationName = CFNotificationName("com.sumee.sharedContentAvailable" as CFString)
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                notificationName,
                nil,
                nil,
                true
            )
        }
    }
}
