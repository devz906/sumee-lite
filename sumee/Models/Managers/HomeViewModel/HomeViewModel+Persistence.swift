import SwiftUI
import Combine

// HomeViewModel+Persistence.swift

extension HomeViewModel {
    
    // Trigger save with debounce
    func saveLayout() {
        triggerSaveLayout()
    }
    
    func triggerSaveLayout() {
        saveLayoutSubject.send()
    }
    
    func loadLayout() {
        if let data = UserDefaults.standard.data(forKey: "savedLayout") {
            print("Loading Layout. Data Size: \(data.count) bytes")
            if let decoded = try? JSONDecoder().decode([[AppItem]].self, from: data) {
                // HOTFIX: Filter out legacy "Game Boy" items AND all Widgets from persistence
                pages = decoded.map { page in
                    page.filter { item in
                        // Remove item if it's the legacy Game Boy folder
                        if item.name == "Game Boy" && item.isFolder { return false }
                        
                        // Remove all Widgets (Clean up)
                        if item.isWidget { return false }
                        
                        // Remove specific legacy widget names in case isWidget flag is missing/false
                        let widgetNames = ["Last Played", "Random Game", "Music Player", "News Widget"]
                        if widgetNames.contains(item.name) { return false }
                        
                        // Remove Manual "Empty" Drops/Spacers
                        if item.name == "Empty" { return false }
                        
                        return true
                    }
                }
                // Save immediately to clean disk
                triggerSaveLayout()
                
                print("Layout Loaded. Pages: \(pages.count)")
                if let firstPage = pages.first, let firstWidget = firstPage.first(where: { $0.isWidget }) {
                    print(" Debug Load: First Widget (\(firstWidget.name)) Size: \(firstWidget.widgetSize)")
                }
            } else {
                print("Failed to decode layout data!")
                // Print specific decoding error if possible
                do {
                    _ = try JSONDecoder().decode([[AppItem]].self, from: data)
                } catch {
                    print(" Decoding Error: \(error)")
                }
            }
        } else {
            print("No saved layout found in UserDefaults. Initializing default.")
        }
    }
}
