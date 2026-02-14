import Foundation
import UIKit
import StoreKit
import SwiftUI
import Combine

//Remade for apple standarts (no private api this time)

class AppLauncher: ObservableObject {
    
    static let shared = AppLauncher()
    
    @Published var showStoreOverlay: Bool = false
    @Published var storeOverlayAppID: String? = nil
    
    // Helper to trigger the overlay from anywhere
    func presentStoreOverlay(from urlString: String) {
        guard let appID = extractAppID(from: urlString) else {
            print(" AppLauncher: Could not extract App ID from \(urlString)")
            // Fallback to regular open if extraction fails ??
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
            return
        }
        
        print(" AppLauncher: Requesting Store Overlay for ID: \(appID)")
        DispatchQueue.main.async {
            self.storeOverlayAppID = appID
            self.showStoreOverlay = true
        }
    }

    private func extractAppID(from url: String) -> String? {
        // Regex to find id<numbers>
        // e.g. https://apps.apple.com/us/app/name/id123456789
        do {
            let regex = try NSRegularExpression(pattern: "id(\\d+)", options: [])
            let nsString = url as NSString
            let results = regex.matches(in: url, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = results.first, match.numberOfRanges > 1 {
                return nsString.substring(with: match.range(at: 1))
            }
        } catch {
            print("Regex error: \(error)")
        }
        return nil
    }
    
    // Kept for direct launching of schemes
    func openURLScheme(_ urlString: String) {
         // Clean spaces
         let cleanString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
         guard let url = URL(string: cleanString) else {
             print(" Invalid URL Scheme: \(urlString)")
             return 
         }
         
         UIApplication.shared.open(url, options: [:]) { success in
             if !success {
                 print(" Failed to open URL Scheme: \(url)")
             } else {
                 print(" Opened URL Scheme: \(url)")
             }
         }
    }
}


