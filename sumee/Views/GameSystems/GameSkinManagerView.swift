import SwiftUI
import UniformTypeIdentifiers

// Publicly visible SkinItem

struct SkinDirectoryItem: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var previewImage: UIImage? = nil
}

struct GameSkinManagerView: View {
    let rom: ROMItem
    var isEmbedded: Bool = false // New embedded mode flag
    var onDismiss: (() -> Void)? = nil
    var isInputActive: Bool = true // New input gating
    var isPortraitOverride: Bool? = nil // New override
    @Binding var triggerImport: Bool // New external trigger for import
    
    // Custom Init to allow optional binding (default to constant false)
    init(rom: ROMItem, isEmbedded: Bool = false, isInputActive: Bool = true, isPortraitOverride: Bool? = nil, onDismiss: (() -> Void)? = nil, triggerImport: Binding<Bool> = .constant(false)) {
        self.rom = rom
        self.isEmbedded = isEmbedded
        self.isInputActive = isInputActive
        self.isPortraitOverride = isPortraitOverride
        self.onDismiss = onDismiss
        self._triggerImport = triggerImport
    }
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var gameController = GameControllerManager.shared
    
    // Background State
    @State private var backgroundImage: UIImage?
    @State private var showBackground = false
    @State private var skins: [SkinDirectoryItem] = []
    @State private var selectedSkinIndex: Int = 0
    @State private var isProcessing = false
    @State private var activeSkinID: String? = nil // Track applied skin
    
    // Background Pattern
    private let dotSize: CGFloat = 2
    private let dotSpacing: CGFloat = 20
    

    
    // Grid Setup
    private func getColumns(isPortrait: Bool) -> [GridItem] {

        let count = isPortrait ? 3 : (isEmbedded ? 4 : 5) 
        return Array(repeating: GridItem(.flexible(), spacing: 15), count: count)
    }

    @State private var showFileImporter = false
    
    // Background Layer (Hidden when embedded)
    private var backgroundLayer: some View {
        Group {
            if !isEmbedded {
                GeometryReader { geo in
                    ZStack {
                        // Background Image
                        Group {
                            if let image = backgroundImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                                    .overlay(Color.black.opacity(0.6))
                            } else {
                                Color.black.opacity(0.85)
                            }
                        }
                        
                        // Dot Pattern
                        Path { path in
                            for x in stride(from: 0, to: geo.size.width, by: dotSpacing) {
                                for y in stride(from: 0, to: geo.size.height, by: dotSpacing) {
                                    path.addEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
                                }
                            }
                        }
                        .fill(Color.gray.opacity(0.3))
                    }
                }
                .ignoresSafeArea()
                .opacity(showBackground ? 1.0 : 0.0)
            }
        }
    }
    @State private var showDeleteAlert = false
    @State private var isImportFocused = false

    var body: some View {
        ZStack {
            // ... (Background Layer content)
            backgroundLayer
            
            // 2. Main Content
            GeometryReader { geo in
                let isPortrait = isPortraitOverride ?? (geo.size.height > geo.size.width)
                let columns = getColumns(isPortrait: isPortrait).count
                
                VStack(spacing: 0) {
                    
                    // Header (Hidden when embedded)
                    if !isEmbedded {
                        HStack(spacing: 20) {
                            ROMThumbnailView(rom: rom)
                                .frame(width: 60, height: 60)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rom.displayName)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                HStack {
                                    Text("Skins Manager")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            // Import Button (Copied from GameSaveManagerView)
                            Button(action: {
                                DispatchQueue.main.async {
                                    showFileImporter = true
                                }
                                AudioManager.shared.playSelectSound()
                            }) {
                                Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                                .scaleEffect(isImportFocused ? 1.2 : 1.0)
                                .shadow(color: isImportFocused ? .black.opacity(0.5) : .clear, radius: 10, x: 0, y: 5)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isImportFocused)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                        
                        // ... (Divider)
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal, 40)
                    }
                    
                    // ... (Content: Progress, Empty, Grid)
                    if rom.console == .nintendo64 {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            Text("Skins for this console coming soon")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else if isProcessing {
                        VStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(2.0)
                            Text("Processing Skin...")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 20)
                            Spacer()
                        }
                    } else if skins.isEmpty {
                        // CENTERED EMPTY STATE
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "paintpalette")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.2))
                            Text("No skins found")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                            Button(action: { 
                                DispatchQueue.main.async {
                                    showFileImporter = true 
                                }
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Import .deltaskin")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // ... (Existing Grid View)
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVGrid(columns: getColumns(isPortrait: isPortrait), spacing: 20) {
                                    ForEach(Array(skins.enumerated()), id: \.element.id) { index, skin in
                                        SkinCard(
                                            skin: skin,
                                            isSelected: !isImportFocused && index == selectedSkinIndex,
                                            isApplied: skin.name == activeSkinID,
                                            isCompact: isEmbedded
                                        )
                                        .id(index)
                                        .onTapGesture {
                                            isImportFocused = false
                                            selectedSkinIndex = index
                                            AudioManager.shared.playSelectSound()
                                            applySelectedSkin() // Apply on Tap
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                isImportFocused = false
                                                selectedSkinIndex = index
                                                AudioManager.shared.playSelectSound()
                                                showDeleteAlert = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            
                                            Button {
                                                isImportFocused = false
                                                selectedSkinIndex = index
                                                applySelectedSkin()
                                            } label: {
                                                Label("Apply Skin", systemImage: "checkmark.circle")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 40)
                                .padding(.top, isEmbedded ? 10 : 20)
                                .padding(.bottom, isEmbedded ? 20 : 100)
                                
                                if skins.count <= 1 {
                                    VStack(spacing: 8) {
                                        Text("Looking for skins?")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.6))
                                            .multilineTextAlignment(.center)
                                        
                                        Link("Download skins at: https://deltastyles.com/systems", destination: URL(string: "https://deltastyles.com/systems")!)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.blue)
                                            .multilineTextAlignment(.center)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 50)
                                }
                            }
                            .onChange(of: selectedSkinIndex) { _, newIndex in
                                withAnimation {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.02), // Start visible content almost immediately
                                    .init(color: .black, location: 0.85), // Keep visible longer
                                    .init(color: .clear, location: 1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    
                    // Footer Controls (Keep same)
                    VStack {
                        Spacer()
                        HStack {
                            if !isEmbedded {
                                ControlCard(actions: [
                                    ControlAction(icon: "b.circle", label: "Back", action: {
                                        AudioManager.shared.playMoveSound()
                                        if let onDismiss = onDismiss {
                                            onDismiss()
                                        } else {
                                            dismiss()
                                        }
                                    })
                                ], position: .left, scale: !isEmbedded && isPortrait ? 1.25 : 1.0)
                                .padding(.leading, 40)
                            }
                            
                            Spacer()
                            
                            // Right Controls (Context Actions)
                            // Right Controls (Context Actions)
                            ControlCard(actions: [
                                ControlAction(icon: "a.circle", label: "Select", action: {
                                    if !skins.isEmpty && !isImportFocused {
                                        applySelectedSkin()
                                    }
                                }),
                                ControlAction(icon: "x.circle", label: "Delete", action: {
                                    if !skins.isEmpty && !isImportFocused {
                                        showDeleteAlert = true
                                        AudioManager.shared.playSelectSound()
                                    }
                                })
                            ], position: .right, scale: !isEmbedded && isPortrait ? 1.25 : 1.0)
                            .padding(.trailing, 40)
                            .opacity((skins.isEmpty || isImportFocused) ? 0.5 : 1.0)
                            .disabled(skins.isEmpty || isImportFocused)
                        }
                        .padding(.bottom, 20)
                    }
                }
                .onChange(of: gameController.dpadUp) { _, pressed in
                     if pressed && isInputActive {
                         if !isImportFocused && selectedSkinIndex < columns {
                             // Move to Header
                             isImportFocused = true
                             AudioManager.shared.playMoveSound()
                         }
                     }
                }
                .onChange(of: gameController.dpadDown) { _, pressed in
                     if pressed && isInputActive {
                         if isImportFocused && !skins.isEmpty {
                             // Return to Grid
                             isImportFocused = false
                             selectedSkinIndex = 0
                             AudioManager.shared.playMoveSound()
                         } else if !isImportFocused {
                             // Navigate Grid Down
                             let nextRow = selectedSkinIndex + columns
                             if nextRow < skins.count {
                                 selectedSkinIndex = nextRow
                                 AudioManager.shared.playMoveSound()
                             }
                         }
                     }
                }
            }
        }
        .onAppear {
            loadBackground()
            loadSkins()
            gameController.disableHomeNavigation = true
            withAnimation(.easeIn(duration: 0.8).delay(0.2)) {
                showBackground = true
            }
        }
        .sheet(isPresented: $showFileImporter) {
            DocumentPicker(isPresented: $showFileImporter, types: [.item]) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        print("📂 File selected: \(url.path)")
                        importSkin(url: url)
                    }
                case .failure(let error):
                    print("Import failed: \(error.localizedDescription)")
                }
            }
        }
        .onChange(of: gameController.buttonBPressed) { _, pressed in
            if pressed && isInputActive {
                // If Alert is showing, B means Cancel
                if showDeleteAlert {
                    showDeleteAlert = false
                    AudioManager.shared.playMoveSound()
                    return
                }
                
                // Otherwise normal Back behavior
                AudioManager.shared.playMoveSound()
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }
        }
        .onChange(of: gameController.buttonAPressed) { _, pressed in
            if pressed && isInputActive {
                if isImportFocused {
                    DispatchQueue.main.async {
                         showFileImporter = true
                    }
                    AudioManager.shared.playSelectSound()
                } else if !skins.isEmpty {
                    // Apply Skin
                    applySelectedSkin()
                }
            }
        }
        .onChange(of: gameController.buttonXPressed) { _, pressed in
            if pressed && isInputActive && !skins.isEmpty && !isImportFocused {
                DispatchQueue.main.async {
                    showDeleteAlert = true
                    AudioManager.shared.playSelectSound()
                }
            }
        }
        .onChange(of: gameController.dpadRight) { _, pressed in
            if pressed && isInputActive && !isImportFocused && !skins.isEmpty && selectedSkinIndex < skins.count - 1 {
                selectedSkinIndex += 1
                AudioManager.shared.playMoveSound()
            }
        }
        .onChange(of: gameController.dpadLeft) { _, pressed in
            if pressed && isInputActive && !isImportFocused && !skins.isEmpty && selectedSkinIndex > 0 {
                selectedSkinIndex -= 1
                AudioManager.shared.playMoveSound()
            }
        }
        // Custom Delete Alert Overlay Removed
        .alert("Delete Skin", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedSkin()
            }
        } message: {
            Text("Are you sure you want to delete '\(skins.indices.contains(selectedSkinIndex) ? skins[selectedSkinIndex].name : "")'?")
        }
        .onChange(of: triggerImport) { _, newValue in
            if newValue {
                print(" External import trigger received")
                DispatchQueue.main.async {
                    self.showFileImporter = true
                    self.triggerImport = false // Reset trigger
                }
                AudioManager.shared.playSelectSound()
            }
        }
    }
    
    //  Skin Import Logic
    private func importSkin(url: URL) {
        isProcessing = true
        print(" Starting import for: \(url.path)")
        
        // Use a background task to avoid freezing UI
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 1. Access security scoped resource (even if copy, safe to call)
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                
                print(" File access granted: \(accessing)")
                
                // 2. Determine Destination
                guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                     print(" Failed to get documents dir")
                     return
                }
                
                let consoleFolder = self.consoleFolderName(for: self.rom.console)
                let skinsDir = documents.appendingPathComponent("skins").appendingPathComponent(consoleFolder)
                print(" Skins Directory: \(skinsDir.path)")
                
                // Create skins dir if needed
                if !FileManager.default.fileExists(atPath: skinsDir.path) {
                    try FileManager.default.createDirectory(at: skinsDir, withIntermediateDirectories: true, attributes: nil)
                    print(" Created skins directory")
                }
                
                // 3. Read Data
                let zipData = try Data(contentsOf: url)
                print("Read zip data: \(zipData.count) bytes")
                
                // 4. Determine Skin Name
                let skinName = url.deletingPathExtension().lastPathComponent
                let destinationFolder = skinsDir.appendingPathComponent(skinName)
                
                print(" Target Skin Folder: \(destinationFolder.path)")
                
                // 5. Unzip using MiniZip
                // Clean up destination if exists
                if FileManager.default.fileExists(atPath: destinationFolder.path) {
                    try FileManager.default.removeItem(at: destinationFolder)
                    print(" Removed existing skin folder")
                }
                try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
                
                print(" Starting unzipping...")
                try MiniZip.unzip(data: zipData, to: destinationFolder)
                print(" Unzip finished successfully")
                
                // 6. Refresh List
                self.loadSkins()
                
            } catch {
                print(" Skin Import Error: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                    // TODO: Show Error Alert
                }
            }
        }
    }
    
    private func deleteSelectedSkin() {
        guard skins.indices.contains(selectedSkinIndex) else { return }
        let skin = skins[selectedSkinIndex]
        
        // Start Processing Animation
        withAnimation { isProcessing = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            do {
                try FileManager.default.removeItem(at: skin.url)
                print(" Deleted skin: \(skin.name)")
                
                // Refresh full list safely
                self.loadSkins()
                
                AudioManager.shared.playSelectSound()
            } catch {
                print(" Failed to delete skin: \(error)")
                withAnimation { self.isProcessing = false }
            }
        }
    }
    
    private func loadSkins() {
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async { self.isProcessing = false }
                return
            }
            
            let consoleFolder = self.consoleFolderName(for: self.rom.console)
            let skinsDir = documents.appendingPathComponent("skins").appendingPathComponent(consoleFolder)
            
            var foundSkins: [SkinDirectoryItem] = []
            
            do {
                let items = try FileManager.default.contentsOfDirectory(at: skinsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                
                for item in items {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                        let preview = self.extractSkinPreview(from: item)
                        foundSkins.append(SkinDirectoryItem(name: item.lastPathComponent, url: item, previewImage: preview))
                    }
                }
            } catch {
                print("Error loading skins from \(skinsDir.path): \(error)")
            }
            
            foundSkins.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            
            // Add Default Option
            let defaultSkin = SkinDirectoryItem(name: "Default", url: URL(fileURLWithPath: ""))
            foundSkins.insert(defaultSkin, at: 0)
            
            DispatchQueue.main.async {
                self.skins = foundSkins
                self.isProcessing = false
                if self.selectedSkinIndex >= foundSkins.count {
                    self.selectedSkinIndex = 0
                }
                
                // Determine active skin from persistence
                let key = self.getPersistenceKey()
                if let saved = UserDefaults.standard.string(forKey: key) {
                    if saved == "NONE" {
                        self.activeSkinID = "Default"
                    } else {
                        self.activeSkinID = saved
                    }
                } else {
                    // First run assumption: Managers load first available skin
                    if foundSkins.count > 1 {
                        self.activeSkinID = foundSkins[1].name
                    } else {
                        self.activeSkinID = "Default"
                    }
                }
            }
        }
    }
    
    private func getPersistenceKey() -> String {
        switch rom.console {
        case .gameboyAdvance, .gameboy, .gameboyColor: return "GBA_LastUsedSkin"
        case .nintendoDS: return "DS_LastUsedSkin"
        case .snes: return "SNES_LastUsedSkin"
        case .nes: return "NES_LastUsedSkin"
        case .segaGenesis: return "MD_LastUsedSkin"
        case .playstation: return "PSX_LastUsedSkin"
        default: return ""
        }
    }

    private func applySelectedSkin() {
        guard skins.indices.contains(selectedSkinIndex) else { return }
        let skin = skins[selectedSkinIndex]
        
        print(" Applying skin: \(skin.name) for \(rom.console)")
        AudioManager.shared.playSelectSound()
        
        // Update UI State
        activeSkinID = skin.name
        
        let isDefault = skin.name == "Default"
        
        // Dispatch to appropriate manager
        switch rom.console {
        case .nintendoDS:
            if isDefault { DSSkinManager.shared.resetSkin() }
            else { DSSkinManager.shared.loadSkin(from: skin.url) }
        case .gameboyAdvance, .gameboy, .gameboyColor:
            if isDefault { GBASkinManager.shared.resetSkin() }
            else { GBASkinManager.shared.loadSkin(from: skin.url) }
        case .segaGenesis:
            if isDefault { MDSkinManager.shared.resetSkin() }
            else { MDSkinManager.shared.loadSkin(from: skin.url) }
        case .nes:
            if isDefault { NESSkinManager.shared.resetSkin() }
            else { NESSkinManager.shared.loadSkin(from: skin.url) }
        case .snes:
            if isDefault { SNESSkinManager.shared.resetSkin() }
            else { SNESSkinManager.shared.loadSkin(from: skin.url) }
        case .playstation:
            if isDefault { PSXSkinManager.shared.resetSkin() }
            else { PSXSkinManager.shared.loadSkin(from: skin.url) }
        // Add other consoles here
        default:
            print(" Skin application not implemented for \(rom.console)")
        }
        
        // Success Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Dismiss if embedded to return to game
        if isEmbedded {
             if let onDismiss = onDismiss {
                 onDismiss()
             } else {
           
                 dismiss()
             }
        } else {
             // If full screen manager, just dismiss
             dismiss()
        }
    }

    private func consoleFolderName(for console: ROMItem.Console) -> String {
        switch console {
        case .nintendoDS: return "ds"
        case .gameboyAdvance, .gameboy, .gameboyColor: return "gba"
        case .snes: return "snes"
        case .nes: return "nes"
        case .segaGenesis: return "genesis" // or md
        case .playstation: return "psx"
        case .psp: return "psp"
        case .nintendo64: return "n64"
        default: return "common"
        }
    }
    
    // ... (Keep existing loadBackground and blurImage)
    private func loadBackground() {
        DispatchQueue.global(qos: .userInteractive).async {
            guard let img = self.rom.getThumbnail() else { return }
            let blurred = self.blurImage(img, radius: 20)
            DispatchQueue.main.async {
                self.backgroundImage = blurred ?? img
            }
        }
    }
    
    private func blurImage(_ image: UIImage, radius: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let context = CIContext(options: nil)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage else { return nil }
        if let cgImage = context.createCGImage(output, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
    private func extractSkinPreview(from skinDir: URL) -> UIImage? {
        // 1. Try to read info.json to find specific portrait image
        let infoURL = skinDir.appendingPathComponent("info.json")
        if let data = try? Data(contentsOf: infoURL),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let reps = json["representations"] as? [String: Any],
           let iphone = reps["iphone"] as? [String: Any] {
            
            // Helper to dig for image name
            func findImageName(in dict: [String: Any]) -> String? {
                if let portrait = dict["portrait"] as? [String: Any] {
                    // Start looking for assets
                     if let assets = portrait["assets"] as? [String: Any] {
                         // Common keys: "resizable", "top", "bottom"
                         // Return first string value found
                         for value in assets.values {
                             if let filename = value as? String { return filename }
                         }
                     }
                }
                return nil
            }
            
            var targetImageName: String?
            
            // Priority 1: EdgeToEdge Portrait
            if let edge = iphone["edgeToEdge"] as? [String: Any] {
                targetImageName = findImageName(in: edge)
            }
            
            // Priority 2: Standard Portrait
            if targetImageName == nil, let std = iphone["standard"] as? [String: Any] {
                targetImageName = findImageName(in: std)
            }
            
            // Load if found
            if let imageName = targetImageName {
                let fileURL = skinDir.appendingPathComponent(imageName)
                
                // If PDF, render thumbnail
                if imageName.lowercased().hasSuffix(".pdf") {
                    if let thumb = renderPDFThumbnail(from: fileURL) {
                        return thumb
                    }
                }
                
                // Try standard image load
                if let img = UIImage(contentsOfFile: fileURL.path) {
                    return img
                }
            }
        }
        
        // 2. Heuristic Fallback: Find largest PNG/JPG/PDF in folder
        if let contents = try? FileManager.default.contentsOfDirectory(at: skinDir, includingPropertiesForKeys: [.fileSizeKey]) {
            let images = contents.filter {
                let ext = $0.pathExtension.lowercased()
                return ["png", "jpg", "jpeg", "pdf"].contains(ext)
            }
            
            // Sort by size (largest likely background)
            if let largest = images.sorted(by: {
                let size1 = (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let size2 = (try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return size1 > size2
            }).first {
                if largest.pathExtension.lowercased() == "pdf" {
                    return renderPDFThumbnail(from: largest)
                }
                return UIImage(contentsOfFile: largest.path)
            }
        }
        
        return nil
    }
    
    private func renderPDFThumbnail(from url: URL, targetWidth: CGFloat = 120) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else { return nil }
        
        let pageRect = page.getBoxRect(.mediaBox)
        let aspectRatio = pageRect.height / pageRect.width
        let targetSize = CGSize(width: targetWidth, height: targetWidth * aspectRatio)
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            UIColor.clear.set()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            
            // Flip Context
            ctx.cgContext.translateBy(x: 0.0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            // Scale to fit target width
            let scale = targetWidth / pageRect.width
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.drawPDFPage(page)
        }
    }
}

// MARK: - Subviews

struct SkinCard: View {
    let skin: SkinDirectoryItem
    let isSelected: Bool
    var isApplied: Bool = false
    var isCompact: Bool = false
    
    var body: some View {
        VStack(spacing: isCompact ? 3 : 6) {
            Spacer()
            
            // Preview Image or Icon
            if let preview = skin.previewImage {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: isCompact ? 70 : 90, maxHeight: isCompact ? 60 : 70)
                    .cornerRadius(4)
                    .shadow(radius: 2)
            } else {
                Image(systemName: skin.name == "Default" ? "slash.circle" : "iphone")
                    .font(.system(size: isCompact ? 24 : 32))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            
            // Name
            
            // Name
            Text(skin.name)
                .font(.system(size: isCompact ? 11 : 13, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 4)
            
            Spacer()
        }
        .frame(width: isCompact ? 80 : 100, height: isCompact ? 80 : 100)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            ZStack {
                // Applied Border (Green)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isApplied ? Color.green : .clear, lineWidth: 3)
                
                // Selection Border (Blue)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : .clear, lineWidth: isSelected ? 2 : 0)
                    .padding(isApplied ? 3 : 0) // Avoid overlap
                
                // Applied Checkmark Badge
                if isApplied {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .background(Circle().fill(Color.white))
                                .padding(4)
                        }
                        Spacer()
                    }
                }
            }
        )
        .shadow(color: isSelected ? .black.opacity(0.5) : .black.opacity(0.1), radius: isSelected ? 12 : 4, x: 0, y: isSelected ? 8 : 2)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
