import SwiftUI
import Combine

class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()
    
    @Published var screenshots: [Screenshot] = []
    
    private let storageKey = "app.screenshots_v2" // Changed key to avoid migration crash
    private var cancellable: AnyCancellable?
    
    // Need a cancellables set for the singleton
    private static var cancellables = Set<AnyCancellable>()
    
    private init() {
        createScreenshotsDirectory()
        loadScreenshots()
        setupScreenshotDetection()
    }
    
    private func setupScreenshotDetection() {
        cancellable = NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)
            .sink { [weak self] _ in
                self?.captureAppWindow()
            }
    }
    
    private func captureAppWindow() {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow }) else {
                print(" No key window found")
                return
            }
            
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let image = renderer.image { context in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            
            self.saveScreenshot(image)
            AppStatusManager.shared.show("Screenshot saved", icon: "camera.fill")
        }
    }
    
    //  File Management
    
    private func getScreenshotsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("Screenshots")
    }
    
    private func createScreenshotsDirectory() {
        let url = getScreenshotsDirectory()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    func saveScreenshot(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let fileURL = getScreenshotsDirectory().appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("Screenshot saved to disk: \(fileName) (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))")
            
            let screenshot = Screenshot(id: id, date: Date(), fileName: fileName)
            screenshots.insert(screenshot, at: 0) // Most recent first
            
            // Keep only last 50 screenshots logic
            if screenshots.count > 50 {
                let toRemove = screenshots.suffix(from: 50)
                // Cleanup files for removed items
                for item in toRemove {
                    removeFile(for: item)
                }
                screenshots = Array(screenshots.prefix(50))
            }
            
            persistScreenshots()
        } catch {
            print("Failed to save screenshot to disk: \(error)")
        }
    }
    
    func deleteScreenshot(_ screenshot: Screenshot) {
        // Remove from array
        screenshots.removeAll { $0.id == screenshot.id }
        persistScreenshots()
        
        // Remove actual file
        removeFile(for: screenshot)
        
        AppStatusManager.shared.show("Screenshot deleted", icon: "trash")
    }
    
    private func removeFile(for screenshot: Screenshot) {
        let fileURL = getScreenshotsDirectory().appendingPathComponent(screenshot.fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    private func persistScreenshots() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(screenshots) {
            UserDefaults.standard.set(data, forKey: storageKey)
            NotificationCenter.default.post(name: .screenshotsUpdated, object: nil)
        }
    }
    
    private func loadScreenshots() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([Screenshot].self, from: data) {
            screenshots = decoded
            print("Loaded \(screenshots.count) screenshots (Disk-based)")
        } else {
             print(" Failed to decode screenshots list (possibly format change)")
        }
    }
}

struct Screenshot: Identifiable, Codable {
    let id: UUID
    let date: Date
    let fileName: String
    
    var image: UIImage? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let fileURL = documentsDirectory.appendingPathComponent("Screenshots").appendingPathComponent(fileName)
        
        // Use contentsOfFile for better memory management than Data(contentsOf:)
        if let image = UIImage(contentsOfFile: fileURL.path) {
            return image
        }
        return nil
    }
}

extension Notification.Name {
    static let screenshotsUpdated = Notification.Name("ScreenshotsUpdatedNotification")
}
