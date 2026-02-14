import Foundation
import UIKit
import Combine

class ThumbnailCache {
    static let shared = NSCache<NSString, UIImage>()
}

struct ROMItem: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let displayName: String
    let console: Console
    let dateAdded: Date

    let fileSize: Int
    var customThumbnailPath: String? // Path relative to BoxArt directory
    var refreshId: UUID = UUID() // Token to force refresh on updates
    var externalLaunchURL: String? // URL Scheme or App Store Link for non-ROM games (e.g. iOS Apps)
    
    // Derived path for autosave visual
    var autoSaveScreenshotURL: URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        // Match logic from WebEmulatorView.getStatesDirectory
        let statesDir = documents.appendingPathComponent("states").appendingPathComponent(displayName)
        let file = statesDir.appendingPathComponent("autosave.png")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }
    
    static func == (lhs: ROMItem, rhs: ROMItem) -> Bool {
        return lhs.id == rhs.id && lhs.refreshId == rhs.refreshId
    }
    
    // Manual Codable implementation for Migration
    enum CodingKeys: String, CodingKey {
        case id, fileName, displayName, console, dateAdded, fileSize, customThumbnailPath, refreshId, externalLaunchURL
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        displayName = try container.decode(String.self, forKey: .displayName)
        console = try container.decode(Console.self, forKey: .console)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        fileSize = try container.decode(Int.self, forKey: .fileSize)
        customThumbnailPath = try container.decodeIfPresent(String.self, forKey: .customThumbnailPath)
        // If refreshId is missing (old data), generate a new one
        refreshId = try container.decodeIfPresent(UUID.self, forKey: .refreshId) ?? UUID()
        externalLaunchURL = try container.decodeIfPresent(String.self, forKey: .externalLaunchURL)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(console, forKey: .console)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encodeIfPresent(customThumbnailPath, forKey: .customThumbnailPath)
        try container.encode(refreshId, forKey: .refreshId)
        try container.encodeIfPresent(externalLaunchURL, forKey: .externalLaunchURL)
    }

    // Add private init for updating
    init(id: UUID, fileName: String, displayName: String, console: Console, dateAdded: Date, fileSize: Int, customThumbnailPath: String?, refreshId: UUID = UUID(), externalLaunchURL: String? = nil) {
        self.id = id
        self.fileName = fileName
        self.displayName = displayName
        self.console = console
        self.dateAdded = dateAdded
        self.fileSize = fileSize
        self.customThumbnailPath = customThumbnailPath
        self.refreshId = refreshId
        self.externalLaunchURL = externalLaunchURL
    }
    
    enum Console: String, Codable, CaseIterable {
        case gameboy = "Game Boy"
        case gameboyColor = "Game Boy Color"
        case gameboyAdvance = "Game Boy Advance"
        case nes = "NES"
        case snes = "Super NES"
        case nintendoDS = "Nintendo DS"
        case nintendo64 = "Nintendo 64"
        case playstation = "PlayStation"
        case psp = "PSP"
        case segaGenesis = "Sega Genesis"
        case web = "Web"
        case ios = "iOS"
        case meloNX = "MeloNX"
        case manicEmu = "ManicEmu"
        
        var isAppOrWeb: Bool {
            return self == .web || self == .ios || self == .meloNX || self == .manicEmu
        }
        
        var folderName: String {
            switch self {
            case .gameboy, .gameboyColor:
                return "GameBoy"
            case .gameboyAdvance:
                return "GBA"
            case .nes:
                return "NES"
            case .snes:
                return "SNES"
            case .nintendoDS:
                return "NDS"
            case .nintendo64:
                return "N64"
            case .playstation:
                return "PSX"
            case .psp:
                return "PSP"
            case .segaGenesis:
                return "Genesis"
            case .web:
                return "WebROMs"
            case .ios:
                return "iOS"
            case .meloNX:
                return "MeloNX"
            case .manicEmu:
                return "ManicEmu"
            }
        }
        
        var systemName: String {
            switch self {
            case .meloNX: return "Nintendo Switch"
            case .gameboyAdvance: return "GBA"
            case .gameboyColor: return "GBC"
            default: return rawValue
            }
        }
    }
    
    init(fileName: String, console: Console, fileSize: Int) {
        self.id = UUID()
        self.fileName = fileName
        // Safely remove extension using URL methods to avoid replacing substrings like ".gb" inside ".gba"
        self.displayName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        self.console = console
        self.dateAdded = Date()

        self.fileSize = fileSize
        self.customThumbnailPath = nil
        self.externalLaunchURL = nil
    }
}

class ROMStorageManager: ObservableObject {
    static let shared = ROMStorageManager()
    
    @Published var roms: [ROMItem] = []
    
    private let romsKey = "savedROMs"
    
    private init() {
        loadROMs()
        scanFileSystem() // Initial scan
        startObserving()
    }
    
    private func startObserving() {
        // Foreground Observer
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            print(" App foregrounded - Scanning file system and checking shared links...")
            self?.scanFileSystem()
            self?.checkForPendingSharedLinks()
        }
        
        // Darwin Notification Observer (Cross-process from Share Extension)
        let notificationName = "com.sumee.sharedContentAvailable" as CFString
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { (_, observer, _, _, _) in
                // C-style callback to Swift instance
                guard let observer = observer else { return }
                let manager = Unmanaged<ROMStorageManager>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    print(" Received Darwin Notification: Shared Content Available")
                    manager.checkForPendingSharedLinks()
                }
            },
            notificationName,
            nil,
            .deliverImmediately
        )
    }
    
    func scanFileSystem() {
        print(" Scanning File System for ROMs...")
        let fileManager = FileManager.default
        var newROMsAdded = 0
        var missingROMsRemoved = 0
        
        // 0. PSX Consolidation: Retroactive Cleanup
        // Remove .bin/.img entries if a .cue with the same name exists
        let psxRoms = roms.filter { $0.console == .playstation }
        let cueNames = Set(psxRoms.filter { $0.fileName.lowercased().hasSuffix(".cue") }
                                  .map { ($0.fileName as NSString).deletingPathExtension })
        
        if !cueNames.isEmpty {
            let idsToRemove = psxRoms.filter { item in
                let ext = (item.fileName as NSString).pathExtension.lowercased()
                let base = (item.fileName as NSString).deletingPathExtension
                // Hide .bin (or .img) if .cue exists
                return (ext == "bin" || ext == "img") && cueNames.contains(base)
            }.map { $0.id }
            
            if !idsToRemove.isEmpty {
                roms.removeAll { idsToRemove.contains($0.id) }
                missingROMsRemoved += idsToRemove.count
                print("🧹 Consolidating PSX: Removed \(idsToRemove.count) redundant .bin files (superseded by .cue)")
            }
        }
        
        // 1. Snapshot existing ROMs to detect deletions
        // (We check if files for existing ROMs still exist)
        var romsToKeep: [ROMItem] = []
        for rom in roms {
             let fileURL = getROMFileURL(for: rom)
             // iOS App Shortcuts don't have files on disk
             // Assuming .ios console items are purely virtual or handled differently.
             // If console is .ios, skip file check for now unless we store a dummy file.
             if rom.console == .ios || rom.console == .meloNX || rom.console == .manicEmu || rom.console == .web {
                 romsToKeep.append(rom)
                 continue
             }
             
             if fileManager.fileExists(atPath: fileURL.path) {
                 romsToKeep.append(rom)
             } else {
                 print(" File not found for ROM: \(rom.displayName) - Removing from library.")
                 missingROMsRemoved += 1
             }
        }
        
        // Update list if deletions found
        if missingROMsRemoved > 0 {
            roms = romsToKeep
            saveROMs()
        }
        
        // 2. Scan directories for NEW files
        for console in ROMItem.Console.allCases {
            // Skip iOS as it's not file-based in ROMs folder usually
            if console == .ios { continue }
            
            let consoleDir = getConsoleDirectory(for: console)
            // Ensure dir exists
            if !fileManager.fileExists(atPath: consoleDir.path) { continue }
            
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: consoleDir, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles)
                
                // PSX Consolidation: Build Ignore List for this directory
                var ignoredBasenames: Set<String> = []
                if console == .playstation {
                    let cues = fileURLs.filter { $0.pathExtension.lowercased() == "cue" }
                    ignoredBasenames = Set(cues.map { $0.deletingPathExtension().lastPathComponent })
                }
                
                for url in fileURLs {
                    let fileName = url.lastPathComponent
                    
                    // Filter by extensions
                    // Let's filter common extensions to avoid junk
                    let ext = url.pathExtension.lowercased()
                    let validExtensions: [String]
                    switch console {
                    case .gameboy: validExtensions = ["gb"]
                    case .gameboyColor: validExtensions = ["gbc"]
                    case .gameboyAdvance: validExtensions = ["gba"]
                    case .nes: validExtensions = ["nes"]
                    case .snes: validExtensions = ["sfc", "smc"]
                    case .nintendoDS: validExtensions = ["nds", "srl"] // .srl is valid too
                    case .nintendo64: validExtensions = ["n64", "z64", "v64"]
                    case .playstation: validExtensions = ["bin", "iso", "img", "pbp", "chd", "cue"] // Expanded PSX support
                    case .psp: validExtensions = ["iso", "cso"]
                    case .segaGenesis: validExtensions = ["md", "gen", "smd", "bin"]
                    case .web: validExtensions = ["webrom"]
                    case .ios, .meloNX, .manicEmu: validExtensions = []
                    }
                    
                    if validExtensions.contains(ext) {
                        // PSX Logic: Skip .bin if .cue exists
                        if console == .playstation && (ext == "bin" || ext == "img") {
                            let base = url.deletingPathExtension().lastPathComponent
                            if ignoredBasenames.contains(base) {
                                // Skip this .bin because we have the .cue
                                continue
                            }
                        }
                        
                        // Check if already exists in library
                        if !roms.contains(where: { $0.fileName == fileName && $0.console == console }) {
                            // New File!
                            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                            
                            let newRom = ROMItem(
                                fileName: fileName,
                                console: console,
                                fileSize: fileSize
                            )
                            
                            roms.append(newRom)
                            newROMsAdded += 1
                            print("✨ Discovered new ROM: \(fileName) (\(console.systemName))")
                        }
                    }
                }
            } catch {
                print(" Error scanning directory for \(console): \(error.localizedDescription)")
            }
        }
        
        if newROMsAdded > 0 || missingROMsRemoved > 0 {
            saveROMs()
            // Sort by date added (newest first) or name
       
        }
        
        print("Scan Complete. Added: \(newROMsAdded), Removed: \(missingROMsRemoved)")
        
        // Refresh Random Widget
        self.updateRandomWidget()
    }
    
    //  Directory Management
    
    private func getROMsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let romsPath = documentsPath.appendingPathComponent("ROMs", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: romsPath, withIntermediateDirectories: true)
        
        return romsPath
    }
    
    private func getConsoleDirectory(for console: ROMItem.Console) -> URL {
        let romsDir = getROMsDirectory()
        let consoleDir = romsDir.appendingPathComponent(console.folderName, isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: consoleDir, withIntermediateDirectories: true)
        
        return consoleDir
    }
    
    func getROMFileURL(for rom: ROMItem) -> URL {
        let consoleDir = getConsoleDirectory(for: rom.console)
        return consoleDir.appendingPathComponent(rom.fileName)
    }
    
    //  ROM Management
    
    func addROM(from sourceURL: URL, console: ROMItem.Console) throws {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Create ROM item (Get size from file attributes to avoid reading data)
        let resources = try sourceURL.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = resources.fileSize ?? 0
        
        let rom = ROMItem(
            fileName: sourceURL.lastPathComponent,
            console: console,
            fileSize: fileSize
        )
        
        let destinationURL = getROMFileURL(for: rom)
        let fileManager = FileManager.default
        
        // Check if destination already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Determine Link Strategy: Move vs Copy
        // If file is in our App Sandbox (Inbox, tmp, or root Documents), we MOVE it to avoid duplication.
        // If file is external (iCloud, another app container), we COPY it to preserve original.
        
        let sandboxURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].deletingLastPathComponent() // Application Support/../
        let isSandboxed = sourceURL.path.contains(sandboxURL.path) || sourceURL.path.contains("/tmp/")
        
        do {
            if isSandboxed {
                print(" Moving file from Sandbox: \(sourceURL.path)")
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
            } else {
                print(" Copying external file: \(sourceURL.path)")
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
        } catch {
             // Fallback: If move fails (e.g. permissions), try copy
             if isSandboxed {
                 print(" Move failed, attempting copy: \(error)")
                 try fileManager.copyItem(at: sourceURL, to: destinationURL)
             } else {
                 throw error
             }
        }
        
        // Add to list
        roms.append(rom)
        saveROMs()
        
        print(" ROM saved: \(rom.displayName)")
    }
    
    func removeROM(_ rom: ROMItem) {
        // Remove file
        let fileURL = getROMFileURL(for: rom)
        try? FileManager.default.removeItem(at: fileURL)
        
        // Remove from list
        roms.removeAll { $0.id == rom.id }
        saveROMs()
        
        print(" ROM removed: \(rom.displayName)")
        NotificationCenter.default.post(name: NSNotification.Name("ROMDeleted"), object: rom)
    }
    
    // Manual Add for iOS Shortcuts
    func addIOSROM(_ rom: ROMItem) {
        roms.append(rom)
        saveROMs()
        print(" Added iOS Shortcut: \(rom.displayName)")
    }
    
    func loadROMData(_ rom: ROMItem) throws -> Data {
        let fileURL = getROMFileURL(for: rom)
        return try Data(contentsOf: fileURL)
    }
    
    //Box Art Management
    
    private func getBoxArtDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let boxArtPath = documentsPath.appendingPathComponent("BoxArt", isDirectory: true)
        try? FileManager.default.createDirectory(at: boxArtPath, withIntermediateDirectories: true)
        return boxArtPath
    }
    
    func saveBoxArt(image: UIImage, for rom: ROMItem) -> String? {
        let fileName = "\(rom.id.uuidString).jpg"
        let fileURL = getBoxArtDirectory().appendingPathComponent(fileName)
        
        // 1. Resize Image (Max 300x300 for better resolution)
        let targetSize = CGSize(width: 300, height: 300)
        let resizedImage = resizeImage(image: image, targetSize: targetSize)
        
        // 2. Compress (0.9 quality for high fidelity)
        if let data = resizedImage.jpegData(compressionQuality: 0.9) {
            try? data.write(to: fileURL)
            return fileName
        }
        return nil
    }
    
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        // ... (existing implementation)
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }

    // Box Art Downloader
    

    
    func downloadArtwork(for rom: ROMItem, completion: @escaping (Bool) -> Void) {
        print(" ROMStorageManager: downloadArtwork called for '\(rom.displayName)' (Console: \(rom.console))")
        var systemPath = ""
        switch rom.console {
        case .gameboyAdvance:
            systemPath = "Nintendo%20-%20Game%20Boy%20Advance"
        case .nintendoDS:
             systemPath = "Nintendo%20-%20Nintendo%20DS"
        case .playstation:
             systemPath = "Sony%20-%20PlayStation"
        case .snes:
             systemPath = "Nintendo%20-%20Super%20Nintendo%20Entertainment%20System"
        case .nes:
             systemPath = "Nintendo%20-%20Nintendo%20Entertainment%20System"
        case .gameboy:
             systemPath = "Nintendo%20-%20Game%20Boy"
        case .gameboyColor:
             systemPath = "Nintendo%20-%20Game%20Boy%20Color"
        case .segaGenesis:
             systemPath = "Sega%20-%20Mega%20Drive%20-%20Genesis"
        case .meloNX:
            // icons are provided by app sync
            print("MeloNX icons provided by sync")
            completion(false)
            return
        default:
            print(" ROMStorageManager: Console '\(rom.console)' is not supported for download.")
            completion(false)
            return
        }
        
        let baseUrl = "https://thumbnails.libretro.com/\(systemPath)/Named_Boxarts/"
        
        // Find best match from database
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Strip extension from ROM name if present, as user's ROMs might have extension in displayName
            // The DB matching logic expects just the name part mostly, but let's be safe.
            let searchName = rom.displayName.replacingOccurrences(of: ".gba", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".nds", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".cue", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".bin", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".pbp", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".iso", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".img", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".m3u", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".sfc", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".smc", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".nes", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".gb", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".gbc", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".gen", with: "", options: .caseInsensitive)
                                            .replacingOccurrences(of: ".smd", with: "", options: .caseInsensitive)
            
            print(" BoxArt Downloader: Requesting match for '\(searchName)' (Original: '\(rom.displayName)')")
            
            guard let bestMatchFilename = BoxArtDatabase.shared.findBestMatch(for: searchName, console: rom.console) else {
                print(" BoxArt Downloader: No matching artwork found in database for: \(searchName)")
                completion(false)
                return
            }
            
            print(" Database Match: '\(rom.displayName)' matches '\(bestMatchFilename)'")
            
            guard let encodedName = bestMatchFilename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: baseUrl + encodedName) else {
                print(" Invalid URL for artwork match: \(bestMatchFilename)")
                completion(false)
                return
            }
            
            print(" Downloading artwork from: \(url.absoluteString)")
            
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let data = data, let image = UIImage(data: data) {
                    
                    DispatchQueue.main.async {
                        // Success!
                        if let path = self.saveBoxArt(image: image, for: rom) {
                            self.updateROM(rom, newName: rom.displayName, newThumbnailPath: path)
                            print(" Artwork downloaded and saved: \(bestMatchFilename)")
                            completion(true)
                        } else {
                            completion(false)
                        }
                    }
                } else {
                    print(" Download failed for match: \(bestMatchFilename) (Status: \((response as? HTTPURLResponse)?.statusCode ?? 0))")
                    completion(false)
                }
            }
            task.resume()
        }
    }
    
    func updateROM(_ rom: ROMItem, newName: String, newThumbnailPath: String?, externalLaunchURL: String? = nil) {
        guard let index = roms.firstIndex(where: { $0.id == rom.id }) else { return }
        
        let newROM = ROMItem(
            id: rom.id,
            fileName: rom.fileName,
            displayName: newName,
            console: rom.console,
            dateAdded: rom.dateAdded,
            fileSize: rom.fileSize,
            customThumbnailPath: newThumbnailPath ?? rom.customThumbnailPath,
            refreshId: UUID(), // Force refresh
            externalLaunchURL: externalLaunchURL ?? rom.externalLaunchURL // Update if provided, else keep existing
        )
        
        // Invalidate cache for the old key
        if let key = rom.customThumbnailPath ?? rom.displayName as String? {
             ThumbnailCache.shared.removeObject(forKey: key as NSString)
        }
        // Also invalidate using the NEW key, just in case
        if let newKey = newROM.customThumbnailPath ?? newROM.displayName as String? {
            ThumbnailCache.shared.removeObject(forKey: newKey as NSString)
        }
        
        roms[index] = newROM
        saveROMs()
        print(" ROM updated: \(newName)")
    }
    
    func addPlayTime(_ duration: TimeInterval, to rom: ROMItem) {
        UserProfileManager.shared.addPlayTime(for: rom.id, duration: duration)
    }
    
    // Persistence
    
    private func saveROMs() {
        if let encoded = try? JSONEncoder().encode(roms) {
            UserDefaults.standard.set(encoded, forKey: romsKey)
        }
    }
    
    private func loadROMs() {
        if let data = UserDefaults.standard.data(forKey: romsKey),
           let decoded = try? JSONDecoder().decode([ROMItem].self, from: data) {
            roms = decoded
            print(" Loaded \(roms.count) ROMs")
        }
    }
    
    // Filtering
    
    func getROMs(for console: ROMItem.Console) -> [ROMItem] {
        return roms.filter { $0.console == console }
    }
    
    // Last Played Persistence
    
    func setLastPlayedROM(_ rom: ROMItem) {
        UserDefaults.standard.set(rom.id.uuidString, forKey: "lastPlayedROMId")
        
        // Save TEXT immediately (Main Thread) to ensure responsiveness
        print(" ROMItem: setLastPlayedROM called for \(rom.displayName)")
        WidgetDataManager.shared.saveLastPlayed(
            title: rom.displayName,
            console: rom.console.systemName,
            image: nil, // Will update with image in background
            romID: rom.id.uuidString
        )
        
        // Save IMAGE in background (Heavy operation)
        DispatchQueue.global(qos: .userInitiated).async {
            let image = rom.getThumbnail()
            DispatchQueue.main.async {
                print(" ROMItem: Updating Widget Image for \(rom.displayName)")
                WidgetDataManager.shared.saveLastPlayed(
                    title: rom.displayName,
                    console: rom.console.systemName,
                    image: image,
                    romID: rom.id.uuidString
                )
            }
        }
    }
    
    func getLastPlayedROM() -> ROMItem? {
        guard let idString = UserDefaults.standard.string(forKey: "lastPlayedROMId"),
              let id = UUID(uuidString: idString) else {
            return nil
        }
        return roms.first { $0.id == id }
    }
    
    func updateRandomWidget() {
        guard !roms.isEmpty else { return }
        
        let validRoms = roms.filter { $0.console != .ios } // Prefer actual games
        if let randomRom = validRoms.randomElement() ?? roms.randomElement() {
            print(" Selecting Random Widget Game: \(randomRom.displayName)")
            let image = randomRom.getThumbnail()
            WidgetDataManager.shared.saveRandomGame(
                title: randomRom.displayName,
                console: randomRom.console.systemName,
                image: image,
                romID: randomRom.id.uuidString
            )
        }
    }
    
    // iOS App Import Logic
    
    struct ITunesLookupResponse: Codable {
        let resultCount: Int
        let results: [ITunesResult]
    }
    
    struct ITunesResult: Codable {
        let trackName: String
        let artworkUrl512: String
        let bundleId: String?
        let trackViewUrl: String?
    }
    
    func importIOSGame(from url: URL) {
        print(" Importing iOS App from URL: \(url.absoluteString)")
        
        // 1. Extract ID from URL (e.g. apps.apple.com/us/app/name/id123456789)
        guard let idRange = url.absoluteString.range(of: "id\\d+", options: .regularExpression) else {
            print(" Could not find App ID in URL")
            return
        }
        
        let idString = String(url.absoluteString[idRange].dropFirst(2)) // Remove "id" prefix
        print(" Extracted App ID: \(idString)")
        
        // 2. Call iTunes Lookup API
        let lookupUrlString = "https://itunes.apple.com/lookup?id=\(idString)"
        guard let lookupUrl = URL(string: lookupUrlString) else { return }
        
        URLSession.shared.dataTask(with: lookupUrl) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
                if let result = response.results.first {
                    print(" Found App: \(result.trackName)")
                    
                    // 3. Download Artwork
                    if let artUrl = URL(string: result.artworkUrl512),
                       let artData = try? Data(contentsOf: artUrl),
                       let image = UIImage(data: artData) {
                        
                        DispatchQueue.main.async {
                            // 4. Create ROMItem
                            // Use bundleId as filename (if available) or trackName. 
                            let fileName = result.bundleId ?? result.trackName
                            
                            // Check if already exists
                            if self.roms.contains(where: { $0.externalLaunchURL == url.absoluteString }) {
                                print(" App already imported")
                                return
                            }
                            
                            let newRom = ROMItem(
                                id: UUID(),
                                fileName: fileName,
                                displayName: result.trackName,
                                console: .ios,
                                dateAdded: Date(),
                                fileSize: 0,
                                customThumbnailPath: nil,
                                refreshId: UUID(),
                                externalLaunchURL: url.absoluteString // Capture the App Store URL
                            )
                            
                            // Save Artwork
                            if let path = self.saveBoxArt(image: image, for: newRom) {
                                let validRom = ROMItem(
                                    id: newRom.id,
                                    fileName: newRom.fileName,
                                    displayName: newRom.displayName,
                                    console: newRom.console,
                                    dateAdded: newRom.dateAdded,
                                    fileSize: newRom.fileSize,
                                    customThumbnailPath: path,
                                    refreshId: newRom.refreshId,
                                    externalLaunchURL: newRom.externalLaunchURL
                                )
                                
                                self.addIOSROM(validRom)
                            }
                        }
                    }
                }
            } catch {
                print(" Error lookup: \(error)")
            }
        }.resume()
    }
    
    // Share Extension Checker
    func checkForPendingSharedLinks() {
        // Check App Group UserDefaults
        let suiteName = "group.com.sumee.shared"
        if let sharedDefaults = UserDefaults(suiteName: suiteName),
           let urlString = sharedDefaults.string(forKey: "sharedURL") {
            
            if let url = URL(string: urlString) {
                print(" Found pending shared URL: \(url)")
                importIOSGame(from: url)
                
                // Clear it
                sharedDefaults.removeObject(forKey: "sharedURL")
                sharedDefaults.synchronize()
            }
        }
    }
    
    // MeloNX Sync Logic (Thanks Stsossy)
    func addMeloNXGames(_ games: [GameScheme]) {
        print(" ROMStorageManager: Syncing \(games.count) MeloNX games...")
        var addedCount = 0
        
        for game in games {
             let expectedLaunchURL = "melonx://game?id=\(game.titleId)"
             
             // Check if already exists (by launch URL to avoid duplicates)
             if roms.contains(where: { $0.console == .meloNX && $0.externalLaunchURL == expectedLaunchURL }) {
                 continue 
             }
             
             // Generate ID
             let newId = UUID()
             
             // Create Base ROM Item
             let newRomLocal = ROMItem(
                id: newId,
                fileName: game.titleName, // Use Title Name as filename for display
                displayName: game.titleName,
                console: .meloNX,
                dateAdded: Date(),
                fileSize: 0, 
                customThumbnailPath: nil, // Will update below
                refreshId: UUID(),
                externalLaunchURL: expectedLaunchURL
             )
             
             // Save Icon if present
             var finalRom = newRomLocal
             if let iconData = game.iconData, let image = UIImage(data: iconData) {
                 if let path = self.saveBoxArt(image: image, for: newRomLocal) {
                     finalRom = ROMItem(
                        id: newRomLocal.id,
                        fileName: newRomLocal.fileName,
                        displayName: newRomLocal.displayName,
                        console: newRomLocal.console,
                        dateAdded: newRomLocal.dateAdded,
                        fileSize: newRomLocal.fileSize,
                        customThumbnailPath: path,
                        refreshId: newRomLocal.refreshId,
                        externalLaunchURL: newRomLocal.externalLaunchURL
                     )
                 }
             }
             
             self.roms.append(finalRom)
             addedCount += 1
             print(" Added MeloNX Game: \(game.titleName)")
        }
        
        if addedCount > 0 {
            saveROMs()
            print(" Saved \(addedCount) new MeloNX games to library.")
        } else {
            print(" No new MeloNX games to add.")
        }
    }
}

extension ROMItem {    
    // Token to represent "No Image Found" in cache
    private static let missingImageToken = UIImage()

    // Fast synchronous cache check
    func getCachedThumbnail() -> UIImage? {
        let cacheKey = (customThumbnailPath ?? displayName) as NSString
        if let cachedImage = ThumbnailCache.shared.object(forKey: cacheKey) {
            if cachedImage === ROMItem.missingImageToken {
                return nil
            }
            return cachedImage
        }
        return nil
    }

    func getThumbnail() -> UIImage? {
        // 0. Check Memory Cache
        if let cached = getCachedThumbnail() {
            return cached
        }
        
        let cacheKey = (customThumbnailPath ?? displayName) as NSString
        
        // Check if we already marked it as missing
        if let cachedImage = ThumbnailCache.shared.object(forKey: cacheKey), cachedImage === ROMItem.missingImageToken {
            return nil
        }
        
        // 1. Check Custom Thumbnail
        if let path = customThumbnailPath {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fullPath = documentsPath.appendingPathComponent("BoxArt").appendingPathComponent(path)
            
            // Try loading data first, then image
            if let data = try? Data(contentsOf: fullPath), let image = UIImage(data: data) {
                ThumbnailCache.shared.setObject(image, forKey: cacheKey)
                return image
            } else {
                // If custom path exists but load fails, print warning (debug only)
                print(" Failed to load custom thumbnail at: \(fullPath.path)")
            }
        }
        
        // 2. Default Logic
        // Eliminar extensiones si existen (para compatibilidad con ROMs ya importados)
        var nameToProcess = self.displayName.lowercased()
        let extensions = [".gb", ".gbc", ".gba", ".nes", ".snes", ".smc", ".sfc", ".md", ".gen", ".smd"]
        for ext in extensions {
            if nameToProcess.hasSuffix(ext) {
                nameToProcess = String(nameToProcess.dropLast(ext.count))
            }
        }
        
        // Normalizar el nombre del ROM para buscar la imagen
        let cleanName = nameToProcess
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
            .replacingOccurrences(of: "jue", with: "")
            .replacingOccurrences(of: "usa", with: "")
            .replacingOccurrences(of: "eur", with: "")
            .replacingOccurrences(of: "jpn", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // Determine prefix based on console
        let prefix: String
        switch self.console {
        case .gameboy: prefix = "gb_"
        case .gameboyColor: prefix = "gbc_"
        case .gameboyAdvance: prefix = "gba_"
        case .nes: prefix = "nes_"
        case .snes: prefix = "snes_"
        case .nintendoDS: prefix = "nds_"
        case .nintendo64: prefix = "n64_"
        case .playstation: prefix = "psx_"
        case .psp: prefix = "psp_"
        case .segaGenesis: prefix = "md_"
        case .ios: prefix = "ios_"
        case .meloNX: prefix = "melonx_"
        case .manicEmu: prefix = "manic_"
        case .web: prefix = "web_"
        }
        
 
        // Cache the miss
        ThumbnailCache.shared.setObject(ROMItem.missingImageToken, forKey: cacheKey)
        
        return nil
    }
}
