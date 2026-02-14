import SwiftUI

extension GameSystemsView {
    
    // MARK: - Console Helpers
    
    func consoleImageName(for console: ROMItem.Console) -> String? {
        // Check for Custom Theme Override
        if SettingsManager.shared.activeThemeID == "custom_photo",
           let customPath = SettingsManager.shared.getCustomConsoleIconPath(for: console) {
            return customPath
        }
        
        switch console {
        case .gameboy: return "cart_gb"
        case .gameboyColor: return "cart_gbc"
        case .gameboyAdvance: return "cart_gba"
        case .nintendo64: return "cart_n64"
        case .nintendoDS: return "cart_nds"
        case .nes: return "cart_nes"
        case .snes: return "cart_snes"
        case .playstation: return "cart_psx"
        case .psp: return "cart_psp"
        case .ios: return "cart_ios" // Use the asset image for iOS console
        case .web: return "cart_mibrowser" // Updated to specific asset
        case .segaGenesis: return "cart_segaGenesis"
        case .meloNX: return "cart_melonx"
        case .manicEmu: return "cart_manic"
        }
    }

    func consoleColor(for console: ROMItem.Console) -> [Color] {
         switch console {
         case .gameboy, .gameboyColor, .gameboyAdvance:
             return [.purple, .blue]
         case .nes, .snes, .nintendo64, .nintendoDS:
             return [.red, .orange]
         case .playstation, .psp:
             return [.blue, .cyan]
         case .ios, .web:
             return [.blue, .white]
         case .segaGenesis:
             return [.black, .red]
         case .meloNX:
             return [.red, .cyan]
         case .manicEmu:
             return [.red, .black]
         }
     }
    
    // MARK: - Indices Helpers
    
    func visibleConsoleIndices() -> [Int] {
        // ALWAYS return all indices to prevent "pop-in/pop-out" during high-speed inertia scrolling
        // The performance cost is negligible for < 50 items, but the animation smoothness is critical.
        return Array(0..<viewModel.availableConsoles.count)
    }

    func visibleIndices() -> [Int] {
        if viewMode == .bottomBar {
             // Static Window Logic
             let start = bottomBarStartIndex
             let end = min(start + bottomBarCapacity - 1, viewModel.filteredROMs.count - 1)
             if start > end { return [] }
             return (start...end).map { $0 }
        } else {
             // Return ALL items for smooth inertia animation
             if viewModel.filteredROMs.count < 50 {
                 return Array(0..<viewModel.filteredROMs.count)
             } else {
                 let current = viewModel.selectedIndex
                 // Large window for inertia
                 let minIndex = max(0, current - 15)
                 let maxIndex = min(viewModel.filteredROMs.count - 1, current + 15)
                 return Array(minIndex...maxIndex)
             }
        }
    }
    
    // Offset & Layout
    
    var gamesLayerXOffset: CGFloat {
        if isPortrait {
         
            return (viewModel.isSelectingConsole && viewMode != .bottomBar) ? 400 : 0
        } else {
            // Landscape
            if viewModel.isSelectingConsole && viewMode != .bottomBar {
                return 200
            } else if viewMode == .grid {
                return 0
            } else if viewMode == .bottomBar {
                return 25
            } else {
                return 130
            }
        }
    }
    
    func calculateStaticTheaterXOffset(visualIndex: Int) -> CGFloat {
        let centerIndex = bottomBarCapacity / 2
        let step: CGFloat = 85
        return CGFloat(visualIndex - centerIndex) * step
    }
    
    // Grid Logic
    
    func getConsoleGroups() -> [ConsoleGroup] {
        let indexed = viewModel.filteredROMs.enumerated().map { (index: $0.offset, rom: $0.element) }
        let grouped = Dictionary(grouping: indexed, by: { $0.rom.console })
        
     
        return viewModel.availableConsoles.compactMap { console in
            guard let items = grouped[console] else { return nil }
       
            return ConsoleGroup(console: console, roms: items.sorted { $0.index < $1.index })
        }
    }
    
    func moveGridSelection(direction: Int) {
        let cols = currentCols
        let groups = getConsoleGroups()
        let currentIndex = viewModel.selectedIndex
        
        // Find current position
        guard let groupIndex = groups.firstIndex(where: { group in group.roms.contains(where: { $0.index == currentIndex }) }),
              let itemIndexInGroup = groups[groupIndex].roms.firstIndex(where: { $0.index == currentIndex })
        else { return }
        
        let currentGroup = groups[groupIndex]
        let currentRow = itemIndexInGroup / cols
        let currentCol = itemIndexInGroup % cols
        
        var nextIndex: Int?
        
        if direction > 0 { 
            let targetRow = currentRow + 1
            let targetIndexInGroup = targetRow * cols + currentCol
            
            if targetIndexInGroup < currentGroup.roms.count {
                // Stay in same group
                nextIndex = currentGroup.roms[targetIndexInGroup].index
            } else {
                // Move to next group
                if groupIndex + 1 < groups.count {
                    let nextGroup = groups[groupIndex + 1]
                    // Try to land on same column in first row
                    let targetIndexInNextGroup = min(currentCol, nextGroup.roms.count - 1)
                    nextIndex = nextGroup.roms[targetIndexInNextGroup].index
                }
            }
        } else {
            let targetRow = currentRow - 1
            
            if targetRow >= 0 {
                // Stay in same group
                let targetIndexInGroup = targetRow * cols + currentCol
                nextIndex = currentGroup.roms[targetIndexInGroup].index
            } else {
                // Move to previous group
                if groupIndex - 1 >= 0 {
                    let prevGroup = groups[groupIndex - 1]
                    let lastRowInPrev = (prevGroup.roms.count - 1) / cols
                    // Try to land on same column in last row
                    var targetIndexInPrevGroup = lastRowInPrev * cols + currentCol
                    // If that slot is empty (last row incomplete), clamp to last item
                    if targetIndexInPrevGroup >= prevGroup.roms.count {
                        targetIndexInPrevGroup = prevGroup.roms.count - 1
                    }
                    nextIndex = prevGroup.roms[targetIndexInPrevGroup].index
                }
            }
        }
        
        if let idx = nextIndex {
            AudioManager.shared.playMoveSound()
            
            // Lock ViewModel sound trigger to avoid duplicate
            viewModel.isControllerScrolling = true
            
            withAnimation {
                viewModel.selectedIndex = idx
            }
            
            DispatchQueue.main.async {
                self.viewModel.isControllerScrolling = false
            }
        }
    }
    
    //  Data Management (Add/Delete/Edit)
    
    func addManicEmuGame(name: String, url: String) {
        guard !name.isEmpty, !url.isEmpty else { return }
        
        // Create ROMItem
        let newRom = ROMItem(
            id: UUID(),
            fileName: name,
            displayName: name,
            console: .manicEmu,
            dateAdded: Date(),
            fileSize: 0,
            customThumbnailPath: nil,
            refreshId: UUID(),
            externalLaunchURL: url
        )
        
        // Use generic addIOSROM to persist it
        ROMStorageManager.shared.addIOSROM(newRom)
        viewModel.updateROMs()
        
        // Add to Home Screen automatically
        homeViewModel.addRomToHome(newRom)
    }
    
    func requestOptions(rom: ROMItem) {
        romForOptions = rom
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showOptionsSheet = true
        }
        AudioManager.shared.playSelectSound()
    }

    func requestDelete(rom: ROMItem) {
         romToDelete = rom
         showDeleteConfirmation = true
     }
     
     func confirmDelete() {
         if let rom = romToDelete {
             deleteROM(rom)
         }
         romToDelete = nil
         showDeleteConfirmation = false
     }

    func deleteROM(_ rom: ROMItem) {
        ROMStorageManager.shared.removeROM(rom)
        AudioManager.shared.playSelectSound()
        viewModel.updateROMs() // Refresh list
    }
    
    func handleEditSave(rom: ROMItem, newName: String, newLaunchURL: String?, newImage: UIImage?) {
        DispatchQueue.global(qos: .userInitiated).async {
            var logoPath: String? = nil
            if let image = newImage {
                logoPath = ROMStorageManager.shared.saveBoxArt(image: image, for: rom)
            }
            DispatchQueue.main.async {
                ROMStorageManager.shared.updateROM(rom, newName: newName, newThumbnailPath: logoPath, externalLaunchURL: newLaunchURL)
                viewModel.updateROMs()
            }
        }
    }
    
    //UI Helpers
    
    func controlHint(button: String, label: String) -> some View {
        HStack(spacing: 4) {
             Text(button)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.gray, lineWidth: 1.5))
            
            Text(label)
                .font(.system(size: 16, weight: .bold)) // Bolder font like image
                .foregroundColor(.gray)
        }
    }
    
    var settingsShouldBeVisible: Bool {
        return !viewModel.showEmulator
    }
}
