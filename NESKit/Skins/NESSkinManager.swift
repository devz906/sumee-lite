import Foundation
import UIKit
import Combine

public class NESSkinManager: ObservableObject {
    public static let shared = NESSkinManager()
    
    @Published public var currentSkin: NESDeltaSkinInfo?
    @Published public var skinDirectory: URL?
    
    private var imageCache: [String: UIImage] = [:]
    
    // Track available skins
    private var availableSkinDirectories: [URL] = []
    
    private let kLastSkinKey = "NES_LastUsedSkin"
    
    private init() {
        scanForSkins()
    }
    
    public func loadSkin(from directory: URL) {
        let infoURL = directory.appendingPathComponent("info.json")
        
        do {
            let data = try Data(contentsOf: infoURL)
            let decoder = JSONDecoder()
            let skinInfo = try decoder.decode(NESDeltaSkinInfo.self, from: data)
            
            DispatchQueue.main.async {
                self.skinDirectory = directory
                self.currentSkin = skinInfo
                self.imageCache.removeAll()
                UserDefaults.standard.set(directory.lastPathComponent, forKey: self.kLastSkinKey)
                print(" [NESSkinManager] Loaded Skin: \(skinInfo.name)")
            }
        } catch {
            print(" [NESSkinManager] Failed to load skin: \(error)")
        }
    }
    
    public func resetSkin() {
        DispatchQueue.main.async {
            self.skinDirectory = nil
            self.currentSkin = nil
            self.imageCache.removeAll()
            UserDefaults.standard.set("NONE", forKey: self.kLastSkinKey)
            print(" [NESSkinManager] Skin reset to default.")
        }
    }
    
    public func resolveAssetImage(named name: String) -> UIImage? {
        if let cached = imageCache[name] { return cached }
        
        guard let dir = skinDirectory else { return nil }
        let fileURL = dir.appendingPathComponent(name)
        
        if FileManager.default.fileExists(atPath: fileURL.path) == false {
             return nil
        }
        
        // Check if PDF
        if fileURL.pathExtension.lowercased() == "pdf" {
            if let image = renderPDF(from: fileURL) {
                imageCache[name] = image
                return image
            }
        }
        
        if let image = UIImage(contentsOfFile: fileURL.path) {
            imageCache[name] = image
            return image
        }
        return nil
    }
    
    private func renderPDF(from url: URL) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else { return nil }
        
        let pageRect = page.getBoxRect(.mediaBox)
        
        // Determine Target Size (Max resolution based on screen, but preserving PDF Aspect Ratio)
        let screenSize = UIScreen.main.bounds.size
        let maxScreenDim = max(screenSize.width, screenSize.height)
        
        // Calculate scale to fit the largest dimension of the screen (High Quality)
        let scale = maxScreenDim / max(pageRect.width, pageRect.height)
        
        let targetSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { ctx in
            UIColor.clear.set()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            
            // Flip Context
            ctx.cgContext.translateBy(x: 0.0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            // Scale uniformly
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.drawPDFPage(page)
        }
    }
    
    public func currentRepresentation(portrait: Bool) -> NESSkinRepresentation? {
        if NESInput.shared.isControllerConnected { return nil }
        
        guard let skin = currentSkin, let iphone = skin.representations.iphone else { return nil }
        
        // Prefer Edge-to-Edge, then Standard
        let orientations = iphone.edgeToEdge ?? iphone.standard
        return portrait ? orientations?.portrait : orientations?.landscape
    }
    
    public func nextSkin() {
        // Deduplicate and refresh list if needed
        let uniqueSkins = Array(Set(availableSkinDirectories)).sorted { $0.path < $1.path }
        guard !uniqueSkins.isEmpty else { return }
        
        if let current = skinDirectory,
           let index = uniqueSkins.firstIndex(of: current) {
            let nextIndex = (index + 1) % uniqueSkins.count
            loadSkin(from: uniqueSkins[nextIndex])
        } else {
            loadSkin(from: uniqueSkins[0])
        }
    }
    
    public func scanForSkins() {
        availableSkinDirectories.removeAll()
        var seenPaths = Set<String>()
        
        let fileManager = FileManager.default
        
        // Helper to scan a specific path safely
        func scanPath(_ path: String, in base: URL) {
            let url = base.appendingPathComponent(path)
            scanDirectory(url, seenPaths: &seenPaths)
        }
        
        // 1. Documents (User Imported)
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            scanPath("skins/nes", in: documents)
            scanPath("skins/NES", in: documents)
        }
        
        // 2. Bundle (Built-in)
        let bundle = Bundle.main.bundleURL
        
        // Try standard paths
        scanPath("skins/nes", in: bundle)
        scanPath("skins/NES", in: bundle)
        
        // Try capitalized paths (common in Xcode groups)
        scanPath("Skins/nes", in: bundle)
        scanPath("Skins/NES", in: bundle)
        
        // Fallback: Try scanning "Skins" directly (if 'nes' folder is missing)
        scanPath("Skins", in: bundle)
        
        // Fallback: Try "NESKit/Skins" (if folder structure is preserved)
        scanPath("NESKit/Skins", in: bundle)
        
        // --- SPECIFIC FALLBACK FOR KNOWN DEFAULT SKIN ---
        // Check root level
        if let path = Bundle.main.path(forResource: "info", ofType: "json", inDirectory: "NES Solo Plastic Black") {
            let url = URL(fileURLWithPath: path).deletingLastPathComponent()
            if !seenPaths.contains(url.path) {
                print(" [NESSkinManager] Found specific skin at root: \(url.lastPathComponent)")
                availableSkinDirectories.append(url)
                seenPaths.insert(url.path)
            }
        }
        
        // Check inside Skins folder
        if let path = Bundle.main.path(forResource: "info", ofType: "json", inDirectory: "Skins/NES Solo Plastic Black") {
            let url = URL(fileURLWithPath: path).deletingLastPathComponent()
            if !seenPaths.contains(url.path) {
                print(" [NESSkinManager] Found specific skin in Skins/: \(url.lastPathComponent)")
                availableSkinDirectories.append(url)
                seenPaths.insert(url.path)
            }
        }
        
        restoreLastSkin()
    }
    
    private func scanDirectory(_ url: URL, seenPaths: inout Set<String>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
        
        for item in contents {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                let infoURL = item.appendingPathComponent("info.json")
                if FileManager.default.fileExists(atPath: infoURL.path) {
                    if !seenPaths.contains(item.path) {
                        print(" [NESSkinManager] Found skin: \(item.lastPathComponent)")
                        availableSkinDirectories.append(item)
                        seenPaths.insert(item.path)
                    }
                }
            }
        }
    }
    
    private func restoreLastSkin() {
        guard let lastSkinName = UserDefaults.standard.string(forKey: kLastSkinKey) else {
             // First Run: Default to first available skin
            if let first = availableSkinDirectories.first {
                loadSkin(from: first)
            }
            return
        }
        
        if lastSkinName == "NONE" {
             // User chose Default/No Skin
            return
        }
        
        if let match = availableSkinDirectories.first(where: { $0.lastPathComponent == lastSkinName }) {
            loadSkin(from: match)
        } else if let first = availableSkinDirectories.first {
            loadSkin(from: first)
        }
    }
}
