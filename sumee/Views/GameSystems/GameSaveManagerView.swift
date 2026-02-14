import SwiftUI
import UniformTypeIdentifiers
import CoreImage // For optimized blur

struct GameSaveManagerView: View {
    let rom: ROMItem
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var gameController = GameControllerManager.shared
    
    @State private var saveFiles: [URL] = []
    @State private var selectedIndex: Int = 0
    
    @State private var isProcessing = false // New state for loading animation
    
    // Alert States
    @State private var showRenameAlert = false
    @State private var showDeleteAlert = false
    @State private var fileToRename: URL?
    @State private var newName: String = ""
    @State private var fileToDelete: URL?
    
    // Share & Import States
    @State private var showShareSheet = false
    @State private var fileToShare: URL?
    @State private var showFileImporter = false
    @State private var isImportFocused = false // Navigation state for Import button
    @State private var shareTimer: Timer? // For long-press detection
    
    // Background State

    @State private var backgroundImage: UIImage?
    @State private var showBackground = false // Control for delayed fade-in

    // Background Pattern
    private let dotSize: CGFloat = 2
    private let dotSpacing: CGFloat = 20
    
    // Grid Setup
    // Adaptive Grid: 5 columns for Landscape, 3 for Portrait
    private func getColumns(isPortrait: Bool) -> [GridItem] {
        let count = isPortrait ? 3 : 5
        return Array(repeating: GridItem(.flexible(), spacing: 15), count: count)
    }
    
    // Extracted Background Layer to fix clipping issues
    private var backgroundLayer: some View {
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
        .ignoresSafeArea() // Critical: Ensures background fills entire screen
        .opacity(showBackground ? 1.0 : 0.0)
    }

    var body: some View {
        ZStack {
            // 1. Background (Independent of Content Geometry)
            backgroundLayer
            
            // 2. Main Content
            GeometryReader { geo in
                let isPortrait = geo.size.height > geo.size.width
                
                ZStack {
                    VStack(spacing: 0) {

                    // ... Header ...
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
                            
                            Text(rom.console.systemName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Import Button
             
                        Button(action: {
                            // Use async to ensure UI loop is free to present modal
                            DispatchQueue.main.async {
                                showFileImporter = true
                            }
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                                .overlay(
                                    // Removed yellow stroke
                                    Circle()
                                        .stroke(Color.clear, lineWidth: 0)
                                )
                                .scaleEffect(isImportFocused ? 1.2 : 1.0) // Increased scale for elevation
                                .shadow(color: isImportFocused ? .black.opacity(0.5) : .clear, radius: 10, x: 0, y: 5) // Add deep shadow
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isImportFocused)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 40)
                    
                    // 3. Save Files Grid OR Loading
                    if isProcessing {
                        VStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(2.0)
                            Text("Updating...")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 20)
                            Spacer()
                        }
                    } else if saveFiles.isEmpty {
                        // CENTERED EMPTY STATE
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.2))
                            Text("No saved states found")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVGrid(columns: getColumns(isPortrait: isPortrait), spacing: 15) {
                                    ForEach(Array(saveFiles.enumerated()), id: \.element) { index, fileURL in
                                        SaveFileCard(
                                            fileURL: fileURL,
                                            isSelected: index == selectedIndex,
                                            onShare: {
                                                fileToShare = fileURL
                                                showShareSheet = true
                                            },
                                            onRename: {
                                                fileToRename = fileURL
                                                newName = fileURL.deletingPathExtension().lastPathComponent
                                                showRenameAlert = true
                                                AudioManager.shared.playSelectSound()
                                            },
                                            onDelete: {
                                                fileToDelete = fileURL
                                                showDeleteAlert = true
                                                AudioManager.shared.playSelectSound()
                                            }
                                        )
                                        .id(index)
                                        .onTapGesture {
                                            selectedIndex = index
                                        }
                                    }
                                }
                                .padding(.horizontal, 40)
                                .padding(.top, 20)
                                .padding(.bottom, 20) // Reduced bottom padding since mask handles visual fade
                            }
                            .onChange(of: selectedIndex) { _, newIndex in
                                withAnimation {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                            
                            .padding(.bottom, 100)
                        }
                    }

                }
            
                
                // Footer Controls (ControlCard Style)
                VStack {
                    Spacer()
                    HStack {
                        // Left Controls (Navigation)
                        ControlCard(actions: [
                            ControlAction(icon: "b.circle", label: "Back", action: {
                                AudioManager.shared.playMoveSound()
                                if let onDismiss = onDismiss {
                                    onDismiss()
                                } else {
                                    dismiss()
                                }
                            })
                        ], position: .left, scale: isPortrait ? 1.25 : 1.0)
                        .padding(.leading, 40)
                        
                        Spacer()
                        
                        // Right Controls (Context Actions)
                        ControlCard(actions: [
                            ControlAction(icon: "a.circle.fill", label: "Share (Hold)", action: nil), // Info-only label
                            ControlAction(icon: "y.circle", label: "Rename", action: {
                                 if !saveFiles.isEmpty {
                                     let file = saveFiles[selectedIndex]
                                     fileToRename = file
                                     newName = file.deletingPathExtension().lastPathComponent
                                     showRenameAlert = true
                                     AudioManager.shared.playSelectSound()
                                 }
                            }),
                            ControlAction(icon: "x.circle", label: "Delete", action: {
                                  if !saveFiles.isEmpty {
                                      let file = saveFiles[selectedIndex]
                                      fileToDelete = file
                                      showDeleteAlert = true
                                      AudioManager.shared.playSelectSound()
                                  }
                            })
                        ], position: .right, scale: isPortrait ? 1.25 : 1.0)
                        .padding(.trailing, 40)
                        .opacity(saveFiles.isEmpty ? 0.5 : 1.0)
                        .disabled(saveFiles.isEmpty)
                    }
                    .padding(.bottom, 20)
                }
                .zIndex(50)
                // Document Picker Sheet (Attached to Footer to avoid conflicts)
                .sheet(isPresented: $showFileImporter) {
                    DocumentPicker(isPresented: $showFileImporter, types: [.item]) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                importSaveFile(url: url)
                            }
                        case .failure(let error):
                            print("Import failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
        .onAppear {
            loadSaveFiles()
            loadBackground()
            gameController.disableHomeNavigation = true // Takes over input
            
            // Fade in background with delay to avoid "black box" effect during zoom
            withAnimation(.easeIn(duration: 0.8).delay(0.2)) {
                showBackground = true
            }
        }

        // ... Alerts ... (Keep existing alerts, just ensure they are connected)
        .alert("Rename File", isPresented: $showRenameAlert) {
            TextField("New Name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                if let url = fileToRename {
                    renameFile(url, to: newName)
                }
            }
        } message: {
            Text("Enter a new name.")
        }
        .alert("Delete File", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let url = fileToDelete {
                    deleteFile(url)
                }
            }
        } message: {
            Text("Are you sure you want to delete this file? This action cannot be undone.")
        }
        // Share Sheet
        .sheet(isPresented: $showShareSheet) {
            if let file = fileToShare {
                ShareSheet(activityItems: [file])
            }
        }
        // ... Input Handling ...
        .onChange(of: gameController.lastInputTimestamp) { _, _ in
            handleInput()
        }
        // Handle Button A Long Press for Share
        .onChange(of: gameController.buttonAPressed) { _, pressed in
            if pressed {
                // Start Timer
                shareTimer?.invalidate()
                shareTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
                    // Long Press Detected
                    // Long Press Detected
                    if !saveFiles.isEmpty && selectedIndex >= 0 && selectedIndex < saveFiles.count {
                         let file = saveFiles[selectedIndex]
                         fileToShare = file
                         showShareSheet = true
                         AudioManager.shared.playSelectSound()
                         let generator = UINotificationFeedbackGenerator()
                         generator.notificationOccurred(.success)
                    }
                }
            } else {
                // Cancel Timer
                shareTimer?.invalidate()
                shareTimer = nil
                
                // If Import button is focused, trigger action on press release (A)
                // If Import button is focused, trigger action on press release (A)
                if isImportFocused {
                    showFileImporter = true
                    AudioManager.shared.playSelectSound()
                }
            }
        }
    }
    
    // ... Input Logic (Keep existing) ...
    private func handleInput() {
        if isProcessing || showRenameAlert || showDeleteAlert || showShareSheet || showFileImporter { return } // Block input when modals active
        
 
        let isPortrait = UIScreen.main.bounds.height > UIScreen.main.bounds.width
        let cols = isPortrait ? 3 : 5
        
        // Navigation 2D
        if gameController.dpadDown {
            if isImportFocused {
                // Move from Import Button -> Grid
                isImportFocused = false
                selectedIndex = 0
                AudioManager.shared.playMoveSound()
            } else if selectedIndex + cols < saveFiles.count {
                selectedIndex += cols
                AudioManager.shared.playMoveSound()
            } else if selectedIndex < saveFiles.count - 1 {
                // If can't go down full row, go to last item
                selectedIndex = saveFiles.count - 1
                AudioManager.shared.playMoveSound()
            }
        } else if gameController.dpadUp {
            if isImportFocused {
                // Already at top
            } else if selectedIndex - cols >= 0 {
                selectedIndex -= cols
                AudioManager.shared.playMoveSound()
            } else if selectedIndex < cols {
                selectedIndex = -1
                isImportFocused = true
                AudioManager.shared.playMoveSound()
            }
        } else if gameController.dpadRight {
            if !isImportFocused && selectedIndex < saveFiles.count - 1 {
                selectedIndex += 1
                AudioManager.shared.playMoveSound()
            }
        } else if gameController.dpadLeft {
            if !isImportFocused && selectedIndex > 0 {
                selectedIndex -= 1
                AudioManager.shared.playMoveSound()
            }
        }
        
        // Actions
        if gameController.buttonBPressed {
            AudioManager.shared.playMoveSound()
            if let onDismiss = onDismiss {
                onDismiss()
            } else {
                dismiss()
            }
        } else if gameController.buttonYPressed { // Y -> Rename
            if !saveFiles.isEmpty {
                let file = saveFiles[selectedIndex]
                if file.pathExtension == "state" {
                    fileToRename = file
                    newName = file.deletingPathExtension().lastPathComponent
                    showRenameAlert = true
                    AudioManager.shared.playSelectSound()
                }
            }
        } else if gameController.buttonXPressed { // X -> Delete
             if !saveFiles.isEmpty {
                 let file = saveFiles[selectedIndex]
                 fileToDelete = file
                 showDeleteAlert = true
                 AudioManager.shared.playSelectSound()
             }
         }
    }

    //  File Operations with Animation

    
    private func renameFile(_ url: URL, to name: String) {
        // Prevent renaming Game Saves (only States)
        guard url.pathExtension == "state" else { return }
        
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        // Keep original extension
        let newURL = url.deletingLastPathComponent().appendingPathComponent(cleanName).appendingPathExtension("state")
        
        // Start Processing Animation
        withAnimation { isProcessing = true }
        
        // Simulate delay + Perform Action
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            do {
                try FileManager.default.moveItem(at: url, to: newURL)
                self.loadSaveFiles()
                AudioManager.shared.playSelectSound()
            } catch {
                print("Failed to rename file: \(error)")
            }
            
            // End Processing Animation
            withAnimation { isProcessing = false }
        }
    }
    
    private func deleteFile(_ url: URL) {
        // Start Processing Animation
        withAnimation { isProcessing = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            do {
                try FileManager.default.removeItem(at: url)
                self.loadSaveFiles()
                
                // Adjust index
                if self.selectedIndex >= self.saveFiles.count && self.selectedIndex > 0 {
                    self.selectedIndex -= 1
                }
                
                AudioManager.shared.playSelectSound()
            } catch {
                print("Failed to delete file: \(error)")
            }
             
            // End Processing Animation
            withAnimation { isProcessing = false }
        }
    }
    

    
    private func loadSaveFiles() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        var combinedFiles: [URL] = []
        
        // 1. Load Game Saves from Console-Specific Directory
        let savesDir = getSaveDirectory(for: rom.console)
        
        if let saves = try? FileManager.default.contentsOfDirectory(at: savesDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            let romBaseName = URL(fileURLWithPath: rom.fileName).deletingPathExtension().lastPathComponent
            
            let gameSaves = saves.filter { url in
                let name = url.lastPathComponent
                // Match exact filename OR basename match (e.g. "game.srm" matches "game.gba")
                return name.starts(with: rom.fileName) || name.starts(with: romBaseName)
            }
            combinedFiles.append(contentsOf: gameSaves)
        }
        
        // 2. Load Save States
        let statesDir = documents.appendingPathComponent("states").appendingPathComponent(rom.displayName)
        do {
            let files = try FileManager.default.contentsOfDirectory(at: statesDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            let states = files.filter { $0.pathExtension == "state" }.sorted {
                ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast)
            }
            combinedFiles.append(contentsOf: states)
        } catch {
            print("No states directory found (yet).") 
        }
        
        saveFiles = combinedFiles
        
        // Ensure index is valid
        if selectedIndex >= saveFiles.count && !saveFiles.isEmpty {
             selectedIndex = saveFiles.count - 1
        }
    }
    
    // Helper to match Core's save path logic
    private func getSaveDirectory(for console: ROMItem.Console) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let baseSaves = documents.appendingPathComponent("saves")
        
        let subDir: String
        switch console {
        case .nintendoDS: subDir = "ds"
        case .playstation: subDir = "psx"
        case .gameboyAdvance: subDir = "gba"
        case .gameboy, .gameboyColor: subDir = "gb" // Usually combined or specific, checking GBCore next if needed but 'gb' is safe guess
        case .snes: subDir = "snes"
        case .nes: subDir = "nes"
        case .nintendo64: subDir = "n64"
        case .psp: subDir = "psp" // PSP usually manages its own, but we might set it
        case .segaGenesis: subDir = "genesis"
        default: subDir = "common"
        }
        
        let dir = baseSaves.appendingPathComponent(subDir)
        // Ensure it exists to avoid read errors
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private func loadBackground() {
        print("DEBUG: Loading background for ROM: \(rom.displayName)")
        DispatchQueue.global(qos: .userInteractive).async {
            guard let img = self.rom.getThumbnail() else { return }
            
            // Pre-blur the image on background thread to prevent animation stutter
            let blurred = self.blurImage(img, radius: 20)
            
            DispatchQueue.main.async {
                // Set directly without animation since the container fades in via showBackground
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
    
    //Import Logic
    private func importSaveFile(url: URL) {
        print("DEBUG: Starting import for file: \(url.path)")
        
     
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        // Determine Destination based on extension
        let ext = url.pathExtension.lowercased()
        let isState = ext == "state"
        
        let destinationDir: URL
        if isState {
             destinationDir = documents.appendingPathComponent("states").appendingPathComponent(rom.displayName)
        } else {
             // It's a save file (.srm, .dsv, etc) - Use Helper
             destinationDir = getSaveDirectory(for: rom.console)
        }
        
        // Ensure destination dir exists
        do {
            try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
             print("ERROR: Failed to create directory: \(error)")
             return
        }
        
        // Construct filename
  
        var destinationFilename = url.lastPathComponent
        
        if !isState {
         
            destinationFilename = rom.fileName + "." + ext
            
        
            let baseName = URL(fileURLWithPath: rom.fileName).deletingPathExtension().lastPathComponent
            destinationFilename = baseName + "." + ext
        } else {
             // For States, ensure .state extension
             if !destinationFilename.hasSuffix(".state") {
                 destinationFilename += ".state"
             }
        }

        let destinationURL = destinationDir.appendingPathComponent(destinationFilename)
        print("DEBUG: Destination URL: \(destinationURL.path)")
        
        // 1. Perform File Copy IMMEDIATELY while we have access
        var copySuccess = false
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                print("DEBUG: Removing existing file at destination")
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: url, to: destinationURL)
            copySuccess = true
            print("DEBUG: Import copy successful")
        } catch {
            print("ERROR: Failed to import file: \(error)")
        }
        
        // 2. Start Animation and Delay UI Refresh
        withAnimation { isProcessing = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if copySuccess {
                self.loadSaveFiles()
                AudioManager.shared.playSelectSound()
            }
            // End Animation
            withAnimation { isProcessing = false }
        }
    }
}

//  Subviews

// New Square Compact Card Layout for Grid
// UTType Extension
extension UTType {
    static var gameSaveState: UTType {
        UTType(filenameExtension: "state") ?? .data
    }
}

//Subviews

// New Square Compact Card Layout for Grid
struct SaveFileCard: View {
    let fileURL: URL
    let isSelected: Bool
    var onShare: () -> Void // Callback for sharing
    var onRename: () -> Void // Callback for renaming
    var onDelete: () -> Void // Callback for deleting
    
    private var isStateFile: Bool {
        return fileURL.pathExtension == "state"
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            
            // Icon
            Image(systemName: isStateFile ? "doc.text" : "memorychip")
                .font(.system(size: 24))
                .foregroundColor(isStateFile ? .gray : .blue)
            
            // Information
            VStack(spacing: 8) {
                Text(isStateFile ? fileURL.deletingPathExtension().lastPathComponent : "Game Save")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
                
                if !isStateFile {
                    Text(fileURL.pathExtension.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                Text(formatDate(url: fileURL))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
        .frame(width: 100, height: 100)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isStateFile ? Color.clear : (isSelected ? Color.blue : Color.blue.opacity(0.3)), lineWidth: isStateFile ? 0 : 2)
        )
        .shadow(color: isSelected ? .black.opacity(0.5) : .black.opacity(0.2), radius: isSelected ? 12 : 4, x: 0, y: isSelected ? 8 : 4) // Deep shadow for lift
        .scaleEffect(isSelected ? 1.15 : 1.0) // Increased scale for distinct lift
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        // Context Menu for Sharing
        .contextMenu {
            Button(action: onShare) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            if isStateFile {
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func formatDate(url: URL) -> String {
        guard let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate else { return "--/--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// ... ControlHint and ShareSheet ...

struct ControlHint: View {
    let icon: String
    let label: String
    var color: Color = .white
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }
}

// Helper for Sharing
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
