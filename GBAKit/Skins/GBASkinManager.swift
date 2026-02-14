import Foundation
import UIKit
import Combine

public class GBASkinManager: ObservableObject {
    public static let shared = GBASkinManager()
    
    @Published public var currentSkin: GBADeltaSkinInfo?
    @Published public var skinDirectory: URL?
    
    private var imageCache: [String: UIImage] = [:]
    
    // Track available skins
    private var availableSkinDirectories: [URL] = []
    
    private let kLastSkinKey = "GBA_LastUsedSkin"
    
    // Fallback logic for GBA vs GBC if needed, but for now scan generic
    
    private init() {
        scanForSkins()
    }
    
    public func loadSkin(from directory: URL) {
        let infoURL = directory.appendingPathComponent("info.json")
        
        do {
            let data = try Data(contentsOf: infoURL)
            let decoder = JSONDecoder()
            let skinInfo = try decoder.decode(GBADeltaSkinInfo.self, from: data)
            
            DispatchQueue.main.async {
                self.skinDirectory = directory
                self.currentSkin = skinInfo
                self.imageCache.removeAll()
                UserDefaults.standard.set(directory.lastPathComponent, forKey: self.kLastSkinKey)
                print("[GBASkinManager] Loaded Skin: \(skinInfo.name)")
            }
        } catch {
            print("[GBASkinManager] Failed to load skin: \(error)")
        }
    }
    
    public func resetSkin() {
        DispatchQueue.main.async {
            self.skinDirectory = nil
            self.currentSkin = nil
            self.imageCache.removeAll()
            UserDefaults.standard.set("NONE", forKey: self.kLastSkinKey)
            print(" [GBASkinManager] Skin reset to default.")
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
    
    public func currentRepresentation(portrait: Bool) -> GBASkinRepresentation? {
        if GBAInput.shared.isControllerConnected { return nil }
        
        guard let skin = currentSkin, let iphone = skin.representations.iphone else { return nil }
        let orientations = iphone.edgeToEdge ?? iphone.standard
        return portrait ? orientations?.portrait : orientations?.landscape
    }
    
    public func scanForSkins() {
        availableSkinDirectories.removeAll()
        
        // 1. Documents (skins/gba)
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let skinsURL = documents.appendingPathComponent("skins/gba")
            try? FileManager.default.createDirectory(at: skinsURL, withIntermediateDirectories: true)
            scanDirectory(skinsURL)
        }
        
        // 2. Bundle (skins/gba)
        let bundleSkinsURL = Bundle.main.bundleURL.appendingPathComponent("skins/gba")
        scanDirectory(bundleSkinsURL)
        
        restoreLastSkin()
    }
    
    private func scanDirectory(_ url: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
        
        for item in contents {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                let infoURL = item.appendingPathComponent("info.json")
                if FileManager.default.fileExists(atPath: infoURL.path) {
                    print("[GBASkinManager] Found skin: \(item.lastPathComponent)")
                    availableSkinDirectories.append(item)
                }
            }
        }
    }
    
    public func nextSkin() {
        guard !availableSkinDirectories.isEmpty else { return }
        
        if let current = skinDirectory,
           let index = availableSkinDirectories.firstIndex(of: current) {
            let nextIndex = (index + 1) % availableSkinDirectories.count
            loadSkin(from: availableSkinDirectories[nextIndex])
        } else {
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
