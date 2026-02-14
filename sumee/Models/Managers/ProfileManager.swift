import SwiftUI
import Combine

class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @Published var profileImage: UIImage?
    @Published var username: String = UserDefaults.standard.string(forKey: "user_profile_name") ?? "Type your user name" {
        didSet {
            UserDefaults.standard.set(username, forKey: "user_profile_name")
        }
    }
    
    @Published var iconSet: Int = UserDefaults.standard.integer(forKey: "user_icon_set") == 0 ? 1 : UserDefaults.standard.integer(forKey: "user_icon_set") {
        didSet {
            UserDefaults.standard.set(iconSet, forKey: "user_icon_set")
        }
    }
    
    private let profileImageFileName = "user_profile_image.png"
    private let wallpaperImageFileName = "user_profile_wallpaper.png"
    
    @Published var wallpaperImage: UIImage?
    
    private init() {
        loadProfileImage()
        loadWallpaperImage()
    }
    
    func saveImage(_ image: UIImage) {
        if let data = image.pngData() {
            let url = getDocumentsDirectory().appendingPathComponent(profileImageFileName)
            try? data.write(to: url)
            self.profileImage = image
        }
    }
    
    func saveWallpaper(_ image: UIImage) {
        if let data = image.pngData() {
            let url = getDocumentsDirectory().appendingPathComponent(wallpaperImageFileName)
            try? data.write(to: url)
            self.wallpaperImage = image
        }
    }
    
    func removeWallpaper() {
        let url = getDocumentsDirectory().appendingPathComponent(wallpaperImageFileName)
        try? FileManager.default.removeItem(at: url)
        self.wallpaperImage = nil
    }
    
    private func loadProfileImage() {
        let url = getDocumentsDirectory().appendingPathComponent(profileImageFileName)
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            self.profileImage = downsample(image: image, to: 300)
        } else {
            self.profileImage = UIImage(named: "icono_perfil")
        }
    }
    
    private func loadWallpaperImage() {
        let url = getDocumentsDirectory().appendingPathComponent(wallpaperImageFileName)
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            self.wallpaperImage = downsample(image: image, to: 1080)
        }
    }
    
    // Performance Optimization: Downsample images to reduce memory usage and render time
    private func downsample(image: UIImage, to pointSize: CGFloat) -> UIImage {
        let ratio = min(pointSize / image.size.width, pointSize / image.size.height)
        if ratio >= 1.0 { return image } // No need to downsample
        
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
