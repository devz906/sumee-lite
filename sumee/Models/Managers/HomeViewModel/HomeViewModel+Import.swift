import SwiftUI
import Combine
import PhotosUI

// HomeViewModel+Import.swift

extension HomeViewModel {
    
    // Fix Icons & Import Logic
    
    func fixIcons() {
        print("🔧 Running fixIcons (SystemApp Unified)...")
        var changed = false
        
        // Remove Deprecated "Animation" App
        removeAppByName("Animation")
        removeAppByName("Discord")
        
        // 1. Link Existing Apps to SystemApp Enum (Migration)
        for (pageIndex, page) in pages.enumerated() {
            for (appIndex, app) in page.enumerated() {
                var newApp = app
                var appChanged = false
                
                // If systemApp is nil, try to match by name
                if newApp.systemApp == nil {
                    // EXCLUDE Sketch from SystemApp linking to preserve Widget behavior
                    if let matchedSystemApp = SystemApp.allCases.first(where: { $0.defaultName == app.name }) {
                        newApp.systemApp = matchedSystemApp
                        appChanged = true
                        print("Linked \(app.name) to SystemApp.\(matchedSystemApp.rawValue)")
                    }
                }
                
                // 2. Fix Icons based on SystemApp source of truth
                if let systemApp = newApp.systemApp {
                    let correctIcon = systemApp.iconName
                    if newApp.iconName != correctIcon {
                        newApp.iconName = correctIcon
                        appChanged = true
                    }
                }
                
                if appChanged {
                    pages[pageIndex][appIndex] = newApp
                    changed = true
                }
            }
        }
        
        // 3. Ensure All Preinstalled System Apps Exist (Automated)
        for appType in SystemApp.allCases {
            // Skip Sketch (handled as Widget) & Discord (Hidden)
            if appType.isPreinstalled && appType != .discord {
                ensureSystemAppExists(appType)
            }
        }

        if changed {
            print(" Saving layout after fixIcons")
            saveLayout()
        }
        
        // 4. Ensure Widgets are in the Pages (Migration), again, i will no touch this
        ensureWidgetsInPages()
        
        // 5. Consolidate pages
        consolidatePages()
    }
    
    // Helpers
    
    func ensureSystemAppExists(_ systemApp: SystemApp) {
        // Check if exists anywhere
        let alreadyExists = pages.flatMap { $0 }.contains { $0.systemApp == systemApp || $0.name == systemApp.defaultName }
        
        if !alreadyExists {
            let newApp = AppItem(
                name: systemApp.defaultName,
                iconName: systemApp.iconName,
                color: systemApp.defaultColor,
                folderType: systemApp.folderType,
                systemApp: systemApp
            )
            addAppToFirstAvailableSlot(newApp)
            print("Injected \(systemApp.defaultName) App")
        }
    }
    
    func addRomToHome(_ rom: ROMItem, silent: Bool = false) {
        // Create AppItem from ROM
        var romApp = AppItem(
            name: rom.displayName,
            iconName: "gamecontroller", // Placeholder, will use ROMCardView, the verification loig will be here. REMEMBER
            color: .gray,
            isROM: true,
            romItem: rom
        )
        // Mark as new installation to show gift icon
        romApp.isNewInstallation = true
        
        // Find first page with space or append to end using helper
        addAppToFirstAvailableSlot(romApp)
        triggerSaveLayout()
        if !silent {
            AppStatusManager.shared.show("Added to Home", icon: "plus.circle")
        }
    }
    
    //File Import
    
    func handleFileImport(_ result: Result<[URL], Error>) {
        if isImportingMusic {
            handleMusicImport(result)
            isImportingMusic = false // Reset state
            return
        }
        
        switch result {
        case .success(let urls):
            print(" Processing \(urls.count) imported files...")
            var lastImported: ROMItem? = nil
            
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { 
                    print("Failed to access security scoped resource: \(url.lastPathComponent)")
                    continue 
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let ext = url.pathExtension.lowercased()
                let console: ROMItem.Console
                
                switch ext {
                case "gbc":          console = .gameboyColor
                case "gba":          console = .gameboyAdvance
                case "nes":          console = .nes
                case "snes", "smc", "sfc": console = .snes
                case "nds":          console = .nintendoDS
                case "n64", "z64", "v64": console = .nintendo64
                case "md", "gen", "smd": console = .segaGenesis
                case "bin":
                     // Heuristic: Check file size. Genesis games are typically cartridges (< 32MB). PSX .bin are CDs (> 100MB).
                     // Using 40MB as a safe upper limit for Genesis/Megadrive ROMs.
                     let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                     if fileSize > 0 && fileSize < 40 * 1024 * 1024 { // < 40 MB
                         console = .segaGenesis
                     } else {
                         console = .playstation
                     }
                case "pbp", "chd", "m3u", "cue", "iso", "img": 
                     console = .playstation
                default:             console = .gameboy
                }
                
                do {
                    try ROMStorageManager.shared.addROM(from: url, console: console)
                    print(" Successfully imported: \(url.lastPathComponent)")
                    // Capture the last one for animation
                    if let newRom = ROMStorageManager.shared.getROMs(for: console).last {
                        lastImported = newRom
                        
                        // Automatically add to Home Screen
                        DispatchQueue.main.async {
                            self.addRomToHome(newRom, silent: urls.count > 1) // Silent only if bulk import
                            
                            //  Trigger Artwork Download
                            ROMStorageManager.shared.downloadArtwork(for: newRom) { success in
                                if success {
                                    DispatchQueue.main.async {
                                        print(" Updating grid icon for: \(newRom.displayName)")
                                        // Fetch the UPDATED ROM from Manager (which has the new path)
                                        if let updatedRom = ROMStorageManager.shared.roms.first(where: { $0.id == newRom.id }) {
                                            // Update the AppItem in the Grid
                                            for (pIndex, page) in self.pages.enumerated() {
                                                if let aIndex = page.firstIndex(where: { $0.isROM && $0.romItem?.id == newRom.id }) {
                                                    print(" Refreshed ROM Item in Grid (Page \(pIndex))")
                                                    var mutableApp = self.pages[pIndex][aIndex]
                                                    mutableApp.romItem = updatedRom
                                                    // Force UI Refresh by updating the page
                                                    self.pages[pIndex][aIndex] = mutableApp
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    print(" Failed to import ROM \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            
            // Trigger animation for the last imported game
            if let newRom = lastImported {
                DispatchQueue.main.async {
                    self.newlyImportedGame = newRom
                    // Force refresh of GameSystemsView list AFTER animation finishes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        NotificationCenter.default.post(name: NSNotification.Name("ForceGameSystemsRefresh"), object: nil)
                    }
                }
            }
            
        case .failure(let error):
            print(" File picker error: \(error.localizedDescription)")
        }
    }
    
    func handleMusicImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            print(" Importing audio files: \(urls.map { $0.lastPathComponent })")
            let fileManager = FileManager.default
            guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let musicDir = documentsPath.appendingPathComponent("Music")
            try? fileManager.createDirectory(at: musicDir, withIntermediateDirectories: true)
            
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let destination = musicDir.appendingPathComponent(url.lastPathComponent)
                
                // Determine Link Strategy
                let sandboxURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].deletingLastPathComponent()
                let isSandboxed = url.path.contains(sandboxURL.path) || url.path.contains("/tmp/")
                
                do {
                    if fileManager.fileExists(atPath: destination.path) {
                        try fileManager.removeItem(at: destination)
                    }
                    
                    if isSandboxed {
                         print("Moving Music from Sandbox: \(url.lastPathComponent)")
                         try fileManager.moveItem(at: url, to: destination)
                    } else {
                         print(" Copying external Music: \(url.lastPathComponent)")
                         try fileManager.copyItem(at: url, to: destination)
                    }

                    print("Imported Music: \(url.lastPathComponent)")
                } catch {
                    // Fallback to copy if move fails
                    if isSandboxed {
                         try? fileManager.copyItem(at: url, to: destination)
                    }
                    print(" Music Import failed for \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            
            // Refresh Library
            Task {
                await MusicPlayerManager.shared.loadLibrary()
                // AudioManager.shared.playSelectSound()
            }
            
        case .failure(let error):
            print(" Music Import Error: \(error.localizedDescription)")
        }
    }
    
    func handlePhotoSelection() {
        guard let item = selectedPhotoItem else { return }
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success(let data):
                    guard let data = data else { return }
                    
                    // 1. Create UserImages directory if needed
                    guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
                    let imagesDir = documents.appendingPathComponent("UserImages")
                    try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
                    
                    // 2. Determine file extension
                    var ext = "png"
                    if self.isGIF(data: data) {
                        ext = "gif"
                    }
                    
                    let filename = UUID().uuidString + "." + ext
                    let destination = imagesDir.appendingPathComponent(filename)
                    
                    do {
                        try data.write(to: destination)
                        
                        // 3. Create AppItem
                        let newItem = AppItem(
                            name: "Custom Image",
                            iconName: "photo",
                            color: .clear,
                            isCustomImage: true,
                            customImagePath: "UserImages/" + filename
                        )
                        
                        // 4. Add to grid (Replacing selected Drop logic)
                        if self.selectedTabIndex < self.pages.count {
                            let page = self.pages[self.selectedTabIndex]
                            let selectedIndex = self.gameController.selectedAppIndex
                            
                            // Valid Index and Target is Empty? Replace it.
                            if selectedIndex < page.count {
                                let targetItem = page[selectedIndex]
                                if targetItem.name == "Empty" {
                                    self.pages[self.selectedTabIndex][selectedIndex] = newItem
                                } else {
                                    // Fallback: Append if somehow not empty (shouldn't happen with current logic)
                                    self.pages[self.selectedTabIndex].append(newItem)
                                }
                            } else {
                                // Index out of bounds (old logic for virtual slots) -> Append
                                self.pages[self.selectedTabIndex].append(newItem)
                            }
                            
                            self.triggerSaveLayout()
                            // Consolidation might be needed if we broke anything, but strictly replacing 1x1 with 1x1 is safe.
                            // We call it just in case.
                            self.consolidatePages()
                            
                            // Exit Edit Mode after adding
                            self.gameController.isEditingLayout = false
                        }
                        
                    } catch {
                        print("Failed to save image: \(error)")
                    }
                    
                case .failure(let error):
                    print("Photo picker error: \(error.localizedDescription)")
                }
                
                // Reset selection
                self.selectedPhotoItem = nil
            }
        }
    }
    
    func isGIF(data: Data) -> Bool {
        if data.count > 3 {
            let bytes = [UInt8](data.prefix(3))
            let gifHeader: [UInt8] = [0x47, 0x49, 0x46] // "GIF"
            return bytes == gifHeader
        }
        return false
    }
    
    //  - Preload ROMs (this will help on homebrew roms or games)
    
    func preloadROMs() {
        let hasPreloaded = UserDefaults.standard.bool(forKey: "hasPreloadedROMs_v1")
        guard !hasPreloaded else { return }
        
        print("Starting ROM Preload...")
        
        var romURLs: [URL] = []
        
        if let folderURL = Bundle.main.url(forResource: "rooms", withExtension: nil) {
            print(" Found 'rooms' folder in bundle: \(folderURL.path)")
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                romURLs = fileURLs
            } catch {
                print("Failed to list files in rooms folder: \(error)")
            }
        } else {
            // Fallback: Try searching for specific extensions in the main bundle if folder structure is lost
            print("'rooms' folder not found as bundle resource. Searching bundle root for common ROM extensions...")
            let extensions = ["gb", "gbc", "gba", "nes", "snes", "smc", "sfc"]
            for ext in extensions {
                if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                    romURLs.append(contentsOf: urls)
                }
            }
        }
        
        guard !romURLs.isEmpty else {
            print("No ROMs found to preload.")
            return
        }
        
        var count = 0
        for url in romURLs {
            let ext = url.pathExtension.lowercased()
            let console: ROMItem.Console?
            
            switch ext {
            case "gb": console = .gameboy
            case "gbc": console = .gameboyColor
            case "gba": console = .gameboyAdvance
            case "nes": console = .nes
            case "snes", "smc", "sfc": console = .snes
            default: console = nil
            }
            
            if let console = console {
                do {
                    // Check if already exists to avoid duplicates
                    try ROMStorageManager.shared.addROM(from: url, console: console)
                    // Also add to Home Screen automatically
                    if let newRom = ROMStorageManager.shared.roms.last(where: { $0.fileName == url.lastPathComponent }) {
                         addRomToHome(newRom, silent: true)
                    }
                    count += 1
                } catch {
                    print(" Failed to preload ROM \(url.lastPathComponent): \(error)")
                }
            }
        }
        
        if count > 0 {
            print("Preloaded \(count) ROMs successfully.")
            UserDefaults.standard.set(true, forKey: "hasPreloadedROMs_v1")
            AppStatusManager.shared.show("Preloaded \(count) Games", icon: "gamecontroller.fill")
        }
    }
    
    // Preload Default GIF
    
    func preloadDefaultGIF() {
        // Deprecated: "Animation" widget removed.
        // We set the flag to true to prevent future execution attempts regardless.
        UserDefaults.standard.set(true, forKey: "hasPreloadedGIF_v2")
    }
    
    // Helper to clean up old defaults
    func removeAppByName(_ name: String) {
        for (pageIndex, page) in pages.enumerated() {
            if let index = page.firstIndex(where: { $0.name == name }) {
                pages[pageIndex].remove(at: index)
                // If page becomes empty, remove it (unless it's the only one)
                if pages[pageIndex].isEmpty && pages.count > 1 {
                    pages.remove(at: pageIndex)
                }
                triggerSaveLayout()
                return 
            }
        }
    }
}
