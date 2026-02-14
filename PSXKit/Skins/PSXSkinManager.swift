import Foundation
import UIKit
import Combine
//okey so skins of manic are more complicated, well... i just go ahead, they are pretty cool to not inlcude
class PSXSkinManager: ObservableObject {
    static let shared = PSXSkinManager()
    
    @Published var currentSkin: PSXDeltaSkinInfo?
    @Published var skinDirectory: URL?
    
    private let fileManager = FileManager.default
    private var imageCache: [String: UIImage] = [:]
    
    // Default system fallback skins
    private let defaultPortraitSkinName = "PSX - Portrait" 
    private let defaultLandscapeSkinName = "PSX - Landscape"
    
    private var availableSkinDirectories: [URL] = []
    private let kLastSkinKey = "PSX_LastUsedSkin"
    
    private init() {}
    
    func scanForSkins() {
        print(" [PSXSkinManager] Scanning for skins...")
        availableSkinDirectories.removeAll()
        
        // 1. Documents Directory
        if let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            // Update to "psx" to match GameSkinManagerView logic
            let skinsDir = docDir.appendingPathComponent("skins/psx") 
            scanDirectory(skinsDir)
        }
        
        if let bundleDir = Bundle.main.resourceURL?.appendingPathComponent("Skins/PSX") {
            scanDirectory(bundleDir)
        }
        
        restoreLastSkin()
    }
    
    private func scanDirectory(_ url: URL) {
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }
        
        for item in contents {
            if item.hasDirectoryPath {
                let infoURL = item.appendingPathComponent("info.json")
                if fileManager.fileExists(atPath: infoURL.path) {
                    availableSkinDirectories.append(item)
                }
            }
        }
    }
    
    func loadSkin(from url: URL) {
        print("[PSXSkinManager] Attempting to load skin from: \(url.path)")
        let infoURL = url.appendingPathComponent("info.json")
        guard let data = try? Data(contentsOf: infoURL) else {
            print(" [PSXSkinManager] No info.json found at \(url.path)")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let skinInfo = try decoder.decode(PSXDeltaSkinInfo.self, from: data)
            
            DispatchQueue.main.async {
                self.currentSkin = skinInfo
                self.skinDirectory = url
                self.imageCache.removeAll() // Clear cache for new skin
                UserDefaults.standard.set(url.lastPathComponent, forKey: self.kLastSkinKey)
                print(" [PSXSkinManager] Successfully LOADED skin: \(skinInfo.name)")
            }
        } catch let DecodingError.dataCorrupted(context) {
            print(" [PSXSkinManager] Data corrupted: \(context)")
        } catch let DecodingError.keyNotFound(key, context) {
            print("[PSXSkinManager] Key '\(key)' not found: \(context.debugDescription)")
            print("codingPath: \(context.codingPath)")
        } catch let DecodingError.valueNotFound(value, context) {
            print("[PSXSkinManager] Value '\(value)' not found: \(context.debugDescription)")
            print("codingPath: \(context.codingPath)")
        } catch let DecodingError.typeMismatch(type, context) {
            print(" [PSXSkinManager] Type '\(type)' mismatch: \(context.debugDescription)")
            print("codingPath: \(context.codingPath)")
        } catch {
            print(" [PSXSkinManager] Failed to parse skin: \(error)")
        }
    }
    
    func resetSkin() {
        DispatchQueue.main.async {
            self.currentSkin = nil
            self.skinDirectory = nil
            self.imageCache.removeAll()
            UserDefaults.standard.set("NONE", forKey: self.kLastSkinKey)
            print(" [PSXSkinManager] Skin reset to default")
        }
    }
    
    // Retrieve Image (PNG or PDF render)
    func resolveAssetImage(named name: String) -> UIImage? {
        guard let skinDir = skinDirectory else { return nil }
        
        // Check Cache
        if let cached = imageCache[name] { return cached }
        
        let distinctURL = skinDir.appendingPathComponent(name)
        
        // 1. If it's explicitly a PDF, go straight to renderer
        if name.lowercased().hasSuffix(".pdf") {
            if fileManager.fileExists(atPath: distinctURL.path) {
                if let rendered = renderPDF(from: distinctURL) {
                    imageCache[name] = rendered
                    return rendered
                }
            }
        }
        
        // 2. Try standard UIImage load (PNG, JPG, etc)
        if let img = UIImage(contentsOfFile: distinctURL.path) {
            imageCache[name] = img
            return img
        }
        
        // 3. Try finding a PDF alternative for a PNG request
     
        let pdfName = name.replacingOccurrences(of: ".png", with: "") + ".pdf"
        // Avoid "file.pdf.pdf" if name was already .pdf (though step 1 handles that)
        if !pdfName.hasSuffix(".pdf.pdf") {
            let pdfURL = skinDir.appendingPathComponent(pdfName)
            if fileManager.fileExists(atPath: pdfURL.path) {
                if let rendered = renderPDF(from: pdfURL) {
                    imageCache[name] = rendered
                    return rendered
                }
            }
        }
        
        print(" [PSXSkinManager] Asset not found: \(name) at \(distinctURL.path)")
        return nil
    }
    
    private func renderPDF(from url: URL) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else { return nil }
        
        let pageRect = page.getBoxRect(.mediaBox)
        let scale = UIScreen.main.scale
        // Render at native screen width logic roughly or just high res

        let renderScale: CGFloat = 3.0 
        
        let destSize = CGSize(width: pageRect.width * renderScale, height: pageRect.height * renderScale)
        
        let renderer = UIGraphicsImageRenderer(size: destSize)
        return renderer.image { ctx in
            UIColor.clear.set()
            ctx.fill(CGRect(origin: .zero, size: destSize))
            
            ctx.cgContext.translateBy(x: 0.0, y: destSize.height)
            ctx.cgContext.scaleBy(x: renderScale, y: -renderScale)
            ctx.cgContext.drawPDFPage(page)
        }
    }
    
    func currentRepresentation(portrait: Bool) -> PSXSkinRepresentation? {
        guard let skin = currentSkin else { return nil }
        let device = skin.representations.iphone // Assuming iPhone for now
        let orientations = device.edgeToEdge ?? device.standard
        
        return portrait ? orientations?.portrait : orientations?.landscape
    }
    
    func nextSkin() {
        // Placeholder for cycling skins if we maintain a list
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
