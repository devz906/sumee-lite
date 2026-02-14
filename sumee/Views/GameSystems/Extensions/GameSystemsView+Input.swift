import SwiftUI

extension GameSystemsView {
    
    func applyInputHandlers<Content: View>(to content: Content) -> some View {
        content
            .onReceive(gameController.inputPublisher) { event in
                handleGameInput(event)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                print("App foregrounded in GameSystemsView - Checking shared links")
                ROMStorageManager.shared.checkForPendingSharedLinks()
            }
    }

    func handleGameInput(_ event: GameControllerManager.GameInputEvent) {
        // Global Lock Check
        if isInputLocked || viewModel.showEmulator || showSettings { return }
        
        // Special Case: Options Sheet Active (Usually blocks input, or handles it internally)
        if showOptionsSheet || showReorderSheet { return }
        
        switch event {
        case .up(let repeated):
            if showViewModeSubmenu {
                if !repeated && selectedSubmenuIndex > 0 {
                    selectedSubmenuIndex -= 1
                    AudioManager.shared.playSelectSound()
                }
            } else if showViewModeMenu {
                if !repeated && selectedViewModeIndex > 0 {
                    selectedViewModeIndex -= 1
                    AudioManager.shared.playSelectSound()
                }
            } else {
                handleDpadUp(repeated: repeated)
            }
            
        case .down(let repeated):
            if showViewModeSubmenu {
                // Submenu: 0=Vertical, 1=Grid, 2=BottomBar, 3=Reorder, 4=StartAnim, 5=Transparency
                if !repeated && selectedSubmenuIndex < 5 {
                    selectedSubmenuIndex += 1
                    AudioManager.shared.playSelectSound()
                }
            } else if showViewModeMenu {
                // Main Menu: 0=ViewOptions, 1=Settings, 2=Exit Lite
                let limit = SettingsManager.shared.liteMode ? 2 : 0
                if !repeated && selectedViewModeIndex < limit {
                    selectedViewModeIndex += 1
                    AudioManager.shared.playSelectSound()
                }
            } else {
                handleDpadDown(repeated: repeated)
            }
            
        case .left(let repeated):
            if !showViewModeMenu && !showViewModeSubmenu {
                handleDpadLeft(repeated: repeated)
            }
            
        case .right(let repeated):
            if !showViewModeMenu && !showViewModeSubmenu {
                handleDpadRight(repeated: repeated)
            }
            
        case .l1:
            if !showViewModeMenu && viewMode == .bottomBar {
                // Previous Console
                if !viewModel.availableConsoles.isEmpty && viewModel.selectedConsoleIndex > 0 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.selectedConsoleIndex -= 1
                        let console = viewModel.availableConsoles[viewModel.selectedConsoleIndex]
                        viewModel.selectConsole(console, enter: false)
                    }
                    AudioManager.shared.playSelectSound()
                }
            }
            
        case .r1:
            if !showViewModeMenu && viewMode == .bottomBar {
                // Next Console
                if !viewModel.availableConsoles.isEmpty && viewModel.selectedConsoleIndex < viewModel.availableConsoles.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.selectedConsoleIndex += 1
                        let console = viewModel.availableConsoles[viewModel.selectedConsoleIndex]
                        viewModel.selectConsole(console, enter: false)
                    }
                    AudioManager.shared.playSelectSound()
                }
            }
            
        case .a:
            AudioManager.shared.playSelectSound()
            
            if showViewModeSubmenu {
                // Submenu Actions
                if selectedSubmenuIndex == 0 {
                    switchToMode(.vertical)
                    withAnimation { 
                        showViewModeSubmenu = false
                        showViewModeMenu = false 
                    }
                } else if selectedSubmenuIndex == 1 {
                    switchToMode(.grid)
                    withAnimation { 
                        showViewModeSubmenu = false
                        showViewModeMenu = false 
                    }
                } else if selectedSubmenuIndex == 2 {
                    switchToMode(.bottomBar)
                    withAnimation { 
                        showViewModeSubmenu = false
                        showViewModeMenu = false 
                    }
                } else if selectedSubmenuIndex == 3 {
                    // Reorder Consoles
                    withAnimation { 
                        showViewModeSubmenu = false
                        showViewModeMenu = false 
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showReorderSheet = true
                    }
                } else if selectedSubmenuIndex == 4 {
                    // Toggle Start Animation
                    disableStartAnimation.toggle()
                } else if selectedSubmenuIndex == 5 {
                    // Toggle Transparency Effect
                    enableCarouselTransparency.toggle()
                }
            } else if showViewModeMenu {
                if selectedViewModeIndex == 0 {
                    // Open View Options Submenu
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showViewModeSubmenu = true
                    }
                    // Initialize selection to current mode
                    let modes: [ViewMode] = [.vertical, .grid, .bottomBar]
                    if let idx = modes.firstIndex(of: viewMode) {
                        selectedSubmenuIndex = idx
                    } else {
                        selectedSubmenuIndex = 0
                    }
                } else if selectedViewModeIndex == 1 && SettingsManager.shared.liteMode {
                     // Settings
                    withAnimation {
                         showViewModeMenu = false
                         showSettings = true
                    }
                } else if selectedViewModeIndex == 2 && SettingsManager.shared.liteMode {
                    // Exit Lite Mode
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        SettingsManager.shared.setLiteMode(false)
                        isPresented = false
                    }
                }
            } else if viewModel.isSelectingConsole {
                if !viewModel.availableConsoles.isEmpty {
                    let console = viewModel.availableConsoles[viewModel.selectedConsoleIndex]
                    viewModel.selectConsole(console)
                }
            } else {
                 if selectedActionIndex != -1 {
                     if !viewModel.filteredROMs.isEmpty {
                         let rom = viewModel.filteredROMs[viewModel.selectedIndex]
                         if selectedActionIndex == 0 {
                             withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                 selectedROMForSkins = rom
                                 onEmulatorStarted?(true)
                             }
                             AudioManager.shared.playSelectSound()
                         } else if selectedActionIndex == 1 {
                             withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                 selectedROMForSaves = rom
                                 showSaveManager = true
                                 onEmulatorStarted?(true)
                             }
                             AudioManager.shared.playSelectSound()
                         }
                     }
                 } else {
                     if !viewModel.filteredROMs.isEmpty {
                        let rom = viewModel.filteredROMs[viewModel.selectedIndex]
                        if rom.console == .ios {
                            print(" Launching iOS App")
                            if let urlString = rom.externalLaunchURL {
                                 if urlString.contains("apple.com") && urlString.contains("/id") {
                                     AppLauncher.shared.presentStoreOverlay(from: urlString)
                                 } else {
                                     AppLauncher.shared.openURLScheme(urlString)
                                 }
                            }
                        } else {
                            viewModel.selectedROM = rom
                            withAnimation {
                                viewModel.showEmulator = true
                                onEmulatorStarted?(true)
                            }
                        }
                    }
                 }
            }
            
        case .b:
            if showViewModeSubmenu {
                withAnimation { showViewModeSubmenu = false }
                AudioManager.shared.playSelectSound()
            } else if showViewModeMenu {
                withAnimation { showViewModeMenu = false }
                AudioManager.shared.playSelectSound()
            } else {
                // BACK LOGIC
                if viewMode == .bottomBar {
                     if !viewModel.isSelectingConsole {
                         withAnimation { viewModel.isSelectingConsole = true }
                     } else {
                         if !SettingsManager.shared.liteMode {
                             withAnimation { isPresented = false }
                         }
                     }
                } else if viewMode == .vertical {
                     if !viewModel.isSelectingConsole {
                         viewModel.backToConsoles()
                     } else {
                         if !SettingsManager.shared.liteMode {
                             withAnimation { isPresented = false }
                         }
                     }
                } else {
                    if !SettingsManager.shared.liteMode {
                        withAnimation { isPresented = false }
                    }
                }
            }
            
        case .x:
            // Add Menu
            if selectedROMForSaves == nil && selectedROMForSkins == nil {
                print(" X button pressed in GameSystemsView - showing add menu")
                AudioManager.shared.playSelectSound()
                showAddSourceMenu = true
            }
            
        case .y:
            // Options
            if selectedROMForSaves == nil && selectedROMForSkins == nil && !showViewModeMenu {
                if !viewModel.filteredROMs.isEmpty {
                    let rom = viewModel.filteredROMs[viewModel.selectedIndex]
                    requestOptions(rom: rom)
                }
            }
            
        case .start:
            // View Mode Menu
             if selectedROMForSaves == nil && selectedROMForSkins == nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if SettingsManager.shared.liteMode {
                        // Lite Mode: Show Main Menu (Options, Settings, Exit)
                        showViewModeMenu.toggle()
                        if showViewModeMenu {
                            showViewModeSubmenu = false
                            selectedViewModeIndex = 0
                        }
                    } else {
                        // Regular Mode: Show View Options Submenu Directly
                        showViewModeSubmenu.toggle()
                        if showViewModeSubmenu {
                            showViewModeMenu = false
                            
                            // Initialize Submenu Selection
                            let modes: [ViewMode] = [.vertical, .grid, .bottomBar]
                            if let idx = modes.firstIndex(of: viewMode) {
                                selectedSubmenuIndex = idx
                            } else {
                                selectedSubmenuIndex = 0
                            }
                        }
                    }
                }
                AudioManager.shared.playSelectSound()
            }
            
        default: break
        }
    }
    
    // D-Pad Handlers
    
    func handleDpadDown(repeated: Bool = false) {
        if !viewModel.isSelectingConsole {
            if viewMode == .grid {
                moveGridSelection(direction: 1)
            } else if viewMode == .bottomBar {
                // Return focus to Bottom Bar
                 withAnimation { viewModel.isSelectingConsole = true }
                 AudioManager.shared.playSelectSound()
            } else {
                selectedActionIndex = -1
                // Faster spring for responsive list navigation
                withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
                     viewModel.moveSelection(delta: 1)
                 }
            }
        } else {
             // Console Nav
             if viewMode == .bottomBar {
                 // Down/Up Ignored in theater mode console nav
             } else {
                 // Vertical Console Nav
                 withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
                    viewModel.moveSelection(delta: 1)
                }
             }
        }
    }
    
    func handleDpadUp(repeated: Bool = false) {
        if !viewModel.isSelectingConsole {
            if viewMode == .grid {
                 moveGridSelection(direction: -1)
            } else if viewMode == .bottomBar {
                  if !repeated {
                      withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                         if selectedActionIndex > -1 { selectedActionIndex -= 1 }
                     }
                  }
            } else {
                 selectedActionIndex = -1
                 withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
                     viewModel.moveSelection(delta: -1)
                 }
            }
        } else {
             if viewMode == .bottomBar {
                 // Up from Bottom Bar -> Focus Games
                 withAnimation { viewModel.isSelectingConsole = false }
                 AudioManager.shared.playSelectSound()
             } else {
                 // Vertical Console Nav
                 withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
                    viewModel.moveSelection(delta: -1)
                }
            }
        }
    }
    
    func handleDpadRight(repeated: Bool = false) {
        if !viewModel.isSelectingConsole {
            if viewMode == .grid {
                withAnimation { viewModel.moveSelection(delta: 1) }
            } else if viewMode == .bottomBar {
                 // Right -> Next Card
                 selectedActionIndex = -1
                 withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
                     viewModel.moveSelection(delta: 1)
                 }
            } else {
                if !repeated {
                    // Check if current ROM supports actions (Not iOS/Web/Apps)
                    var supportsActions = true
                    if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < viewModel.filteredROMs.count {
                        if viewModel.filteredROMs[viewModel.selectedIndex].console.isAppOrWeb {
                            supportsActions = false
                        }
                    }
                    
                    if supportsActions {
                        withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                            if selectedActionIndex < 1 { selectedActionIndex += 1 }
                        }
                    }
                }
            }
        } else {
            // Console Nav
            if viewMode == .bottomBar {
                // Bottom Bar Nav: Change Console & Load Games
                withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
                    viewModel.moveSelection(delta: 1)
                }
                // Force load games while keeping focus
                let console = viewModel.availableConsoles[viewModel.selectedConsoleIndex]
                viewModel.selectConsole(console, enter: false)
            }
        }
    }
    
    func handleDpadLeft(repeated: Bool = false) {
       if !viewModel.isSelectingConsole {
            if viewMode == .grid {
                withAnimation { viewModel.moveSelection(delta: -1) }
            } else if viewMode == .bottomBar {
                 selectedActionIndex = -1
                 withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
                     viewModel.moveSelection(delta: -1)
                 }
            } else {
                if !repeated {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                        if selectedActionIndex > -1 { selectedActionIndex -= 1 }
                    }
                }
            }
        } else {
            // Console Nav
            if viewMode == .bottomBar {
                withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
                    viewModel.moveSelection(delta: -1)
                }
                let console = viewModel.availableConsoles[viewModel.selectedConsoleIndex]
                viewModel.selectConsole(console, enter: false)
            }
        }
    }
    
    func switchToMode(_ mode: ViewMode, save: Bool = true) {
        withAnimation {
            viewMode = mode
            if save {
                savedViewMode = mode.rawValue // Save intent
            }
            
            if mode == .vertical {
                viewModel.exitGlobalGrid()
                viewModel.backToConsoles()
            } else if mode == .bottomBar {
                viewModel.exitGlobalGrid()
                // Ensure a console is selected for display
                if viewModel.selectedConsole == nil && !viewModel.availableConsoles.isEmpty {
                    viewModel.selectConsole(viewModel.availableConsoles[0], enter: false)
                }
                viewModel.isSelectingConsole = true // Start focus on bar
                // Initialize Static Carousel Window
                bottomBarStartIndex = max(0, viewModel.selectedIndex - (bottomBarCapacity / 2))
            } else {
                viewModel.enterGlobalGrid()
            }
        }
    }
}
