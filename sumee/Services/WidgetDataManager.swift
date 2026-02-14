import Foundation
import UIKit
import WidgetKit

struct SharedDefaultKeys {
    // App Group Name - CHANGE THIS to match your App Group in Xcode
    static let suiteName = "group.com.sumee.shared"
    
    struct LastPlayed {
        static let title = "widget.lastPlayed.title"
        static let console = "widget.lastPlayed.console"
        static let imageData = "widget.lastPlayed.imageData"
        static let romID = "widget.lastPlayed.romID"
    }
    
    struct RandomGame {
        static let title = "widget.randomGame.title"
        static let console = "widget.randomGame.console"
        static let imageData = "widget.randomGame.imageData"
        static let romID = "widget.randomGame.romID"
    }
}

class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let defaults = UserDefaults(suiteName: SharedDefaultKeys.suiteName)
    
    func saveLastPlayed(title: String, console: String, image: UIImage?, romID: String) {
        if defaults == nil {
            print(" WidgetDataManager ERROR: Could not load UserDefaults for suite: \(SharedDefaultKeys.suiteName)")
            print(" Please check 'App Groups' capability in Xcode for the 'sumee' target.")
            return
        }
        
        print(" WidgetDataManager: Saving Last Played -> \(title) (\(console))")
        defaults?.set(title, forKey: SharedDefaultKeys.LastPlayed.title)
        defaults?.set(console, forKey: SharedDefaultKeys.LastPlayed.console)
        defaults?.set(romID, forKey: SharedDefaultKeys.LastPlayed.romID)
        
        if let image = image, let data = image.jpegData(compressionQuality: 0.7) {
            defaults?.set(data, forKey: SharedDefaultKeys.LastPlayed.imageData)
            print(" WidgetDataManager: Saved Image Data (\(data.count) bytes)")
        } else {
            defaults?.removeObject(forKey: SharedDefaultKeys.LastPlayed.imageData)
            print(" WidgetDataManager: No image to save")
        }
        
        // Force write to disk (legacy but helpful for debugging App Groups)
        defaults?.synchronize()
        
        // Force Widget Reload
        WidgetCenter.shared.reloadAllTimelines()
        print(" WidgetDataManager: Requested Widget Reload")
    }
    
    func saveRandomGame(title: String, console: String, image: UIImage?, romID: String) {
        guard let defaults = defaults else { return }
        defaults.set(title, forKey: SharedDefaultKeys.RandomGame.title)
        defaults.set(console, forKey: SharedDefaultKeys.RandomGame.console)
        defaults.set(romID, forKey: SharedDefaultKeys.RandomGame.romID)
        
        if let image = image, let data = image.jpegData(compressionQuality: 0.7) {
            defaults.set(data, forKey: SharedDefaultKeys.RandomGame.imageData)
        }
        
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
