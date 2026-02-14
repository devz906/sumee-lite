import Foundation
import UIKit
import Combine

public class DSSkinManager: ObservableObject {
    public static let shared = DSSkinManager()
    
    @Published public var currentSkin: DeltaSkinInfo?
    @Published public var skinDirectory: URL?
    
    // Cache for images to avoid reloading from disk frequently
    private var imageCache: [String: UIImage] = [:]
    
    // Track available skins for cycling
    private var availableSkinDirectories: [URL] = []
    
    private let kLastSkinKey = "DS_LastUsedSkin"
    
    private init() {
        scanForSkins()
    }
    
    public func loadSkin(from directory: URL) {
        let infoURL = directory.appendingPathComponent("info.json")
        
        do {
            let data = try Data(contentsOf: infoURL)
            let decoder = JSONDecoder()
            let skinInfo = try decoder.decode(DeltaSkinInfo.self, from: data)
            
            DispatchQueue.main.async {
                self.skinDirectory = directory
                self.currentSkin = skinInfo
                self.imageCache.removeAll() // Clear cache on new skin load
                UserDefaults.standard.set(directory.lastPathComponent, forKey: self.kLastSkinKey)
                print(" [DSSkinManager] Loaded Skin: \(skinInfo.name)")
            }
        } catch {
            print(" [DSSkinManager] Failed to load skin: \(error)")
            if let data = try? Data(contentsOf: infoURL) {
                print("   Data size: \(data.count) bytes")
                if let str = String(data: data, encoding: .utf8) {
                    print("   JSON Snippet: \(str.prefix(100))...")
                }
            } else {
                 print("   Could not read data from URL.")
            }
        }
    }
    
    public func resetSkin() {
        DispatchQueue.main.async {
            self.skinDirectory = nil
            self.currentSkin = nil
            self.imageCache.removeAll()
            UserDefaults.standard.set("NONE", forKey: self.kLastSkinKey)
            print(" [DSSkinManager] Skin reset to default.")
        }
    }
    
    public func resolveAssetImage(named name: String) -> UIImage? {
        // Check Cache
        if let cached = imageCache[name] {
            return cached
        }
        
        guard let dir = skinDirectory else {
            print(" [DSSkinManager] No skin directory set.")
            return nil 
        }
        
        let fileURL = dir.appendingPathComponent(name)
        
        if FileManager.default.fileExists(atPath: fileURL.path) == false {
             print(" [DSSkinManager] Asset file does not exist at path: \(fileURL.path)")
             return nil
        }
        
        // Check if PDF
        if fileURL.pathExtension.lowercased() == "pdf" {
            if let image = renderPDF(from: fileURL) {
                print(" [DSSkinManager] PDF Loaded & Rendered: \(name)")
                imageCache[name] = image
                return image
            } else {
                 print(" [DSSkinManager] Failed to render PDF: \(fileURL.path)")
            }
        }
        
        // Try loading as UIImage
        if let image = UIImage(contentsOfFile: fileURL.path) {
            print(" [DSSkinManager] Loaded asset: \(name)")
            imageCache[name] = image
            return image
        } else {
            print(" [DSSkinManager] FileManager found file but UIImage failed to load: \(fileURL.path)")
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
    
    // Helper to get correct representation for current device/orientation
 
    public func currentRepresentation(portrait: Bool) -> SkinRepresentation? {
        // Feature: Disable skin if physical controller is connected
        if DSInput.shared.isControllerConnected {
            return nil
        }
        
        guard let skin = currentSkin, let iphone = skin.representations.iphone else { return nil }
        
        // Prefer edgeToEdge (modern iPhones) -> standard (fallback)
        let orientations = iphone.edgeToEdge ?? iphone.standard
        
        return portrait ? orientations?.portrait : orientations?.landscape
    }
    
    // Suggest loading from Documents/skins
    public func scanForSkins() {
        availableSkinDirectories.removeAll()
        
        // 1. Check Documents (skins/ds)
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let skinsURL = documents.appendingPathComponent("skins/ds")
            try? FileManager.default.createDirectory(at: skinsURL, withIntermediateDirectories: true)
            scanDirectory(skinsURL)
        }
        
        // 2. Check Bundle (skins/ds)
        print("🔍 [DSSkinManager] Scanning Bundle for skins/ds...")
        let bundleSkinsURL = Bundle.main.bundleURL.appendingPathComponent("skins/ds")
        scanDirectory(bundleSkinsURL)
        
        restoreLastSkin()
    }
    
    private func scanDirectory(_ url: URL) {
        print(" [DSSkinManager] Scanning for skins at: \(url.path)")
        
        // Look for subdirectories containing info.json
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { 
            print(" [DSSkinManager] Could not read contents of skins directory.")
            return 
        }
        
        print(" [DSSkinManager] Found \(contents.count) items in skins directory.")
        
        for item in contents {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                print("checking folder: \(item.lastPathComponent)")
                
                let infoURL = item.appendingPathComponent("info.json")
                if FileManager.default.fileExists(atPath: infoURL.path) {
                    print("Found info.json in \(item.lastPathComponent). Adding to available skins...")
                    availableSkinDirectories.append(item)
                } else {
                    print("No info.json found in \(item.lastPathComponent)")
                }
            } else {
                print("ignoring file: \(item.lastPathComponent)")
            }
        }
    }
    
    public func loadDefaultSkin() {
        scanForSkins()
    }
    
    public func nextSkin() {
        guard !availableSkinDirectories.isEmpty else { return }
        
        if let current = skinDirectory,
           let index = availableSkinDirectories.firstIndex(of: current) {
            let nextIndex = (index + 1) % availableSkinDirectories.count
            loadSkin(from: availableSkinDirectories[nextIndex])
        } else {
            // Default to first
            loadSkin(from: availableSkinDirectories[0])
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
