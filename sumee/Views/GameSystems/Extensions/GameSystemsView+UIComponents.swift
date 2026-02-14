import SwiftUI

extension GameSystemsView {
    
    //  Main Content Layers
    
    @ViewBuilder
    var internalContent: some View {
        ZStack {
            // 1. Dynamic Background
            if let song = musicPlayer.currentSong,
               let artwork = song.artwork,
               musicPlayer.isSessionActive {
                // Music Background (Mirrored from HomeView)
                GeometryReader { geo in
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 20)
                        .overlay(Color.black.opacity(0.3))
                        .clipped()
                }
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeInOut(duration: 0.8)))
            } else if !viewModel.isSelectingConsole && viewMode != .grid {
                BackgroundImageView(viewModel: viewModel)
            } else {
                if viewMode == .bottomBar {
                    Color(red: 0.18, green: 0.18, blue: 0.20) // Lighter dark background for Theater Mode
                        .ignoresSafeArea()
                } else {
                    // Optimized: Reuse HomeView background by staying transparent
                    Color.clear
                }
            }
            
            // 2. Main Content ZStack (Consoles vs Games)
            mainContentLayer
                .id(viewModel.refreshID)
                .opacity(viewModel.isReloading ? 0 : 1)
 
            // 3. Footer Controls (Hide when Save Manager is active)
            footerControlsLayer
            
            // View Toggle (Moved to Top Right)
            viewToggleLayer
            
            // Custom View Mode Menu Overlay
            customViewModeMenuLayer
            
            // Bottom Bar Controls Legend
            bottomBarControlsLegendLayer
            
            // 4. Emulator Overlay
            emulatorOverlayLayer
            
            // 5. Game Save Manager Overlay
            saveManagerOverlayLayer
            
            // 6. Skins Manager Overlay
            skinManagerOverlayLayer
            
            // 8. Lite Mode Exit Overlay
            liteModeExitLayer
            
            // 7. Options Menu Overlay
            if showOptionsSheet {
                GameOptionsMenuView(
                    isPresented: $showOptionsSheet,
                    gameController: gameController,
                    onAddToHome: {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showOptionsSheet = false
                            }
                        }
                        if let rom = romForOptions {
                            // Delay slightly to allow menu close
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if !SettingsManager.shared.liteMode {
                                    isPresented = false // Close GameSystemsView
                                }
                                NotificationCenter.default.post(name: NSNotification.Name("AddRomToHome"), object: rom)
                            }
                        }
                    },
                    onEdit: {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showOptionsSheet = false
                            }
                        }
                        if let rom = romForOptions {
                            romToEdit = rom
                        }
                    },
                    onManageSaves: {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showOptionsSheet = false
                            }
                        }
                        if let rom = romForOptions {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedROMForSaves = rom
                                    onEmulatorStarted?(true) // Hide Header
                                }
                            }
                        }
                    },
                    onManageSkins: {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showOptionsSheet = false
                            }
                        }
                        if let rom = romForOptions {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedROMForSkins = rom
                                    onEmulatorStarted?(true) // Hide Header
                                }
                            }
                        }
                    },
                    onDelete: {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showOptionsSheet = false
                            }
                        }
                        if let rom = romForOptions {
                            requestDelete(rom: rom)
                        }
                    },
                    onCancel: {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showOptionsSheet = false
                            }
                        }
                    }
                )
                .zIndex(2100)
            }
        }
    }
    
    @ViewBuilder
    var mainContentLayer: some View {
        GeometryReader { geo in
            let isPortraitLocal = geo.size.height > geo.size.width
            
            Color.clear
                .onAppear { 
                    self.isPortrait = isPortraitLocal
                    currentCols = isPortraitLocal ? 4 : 6 
                    
                    // Initialize ViewModel based on Saved Mode
                    if viewMode == .grid {
                        viewModel.enterGlobalGrid()
                    } else {
                        // Vertical mode starts at console selection
                        viewModel.isSelectingConsole = true
                    }
                }
                .onChange(of: isPortraitLocal) { newValue in 
                    self.isPortrait = newValue
                    currentCols = newValue ? 4 : 6 
                    // Removed forced mode switching on rotation
                }
                .onChange(of: viewModel.selectedIndex) { _, newIndex in
                    if viewMode == .bottomBar {
                        let capacity = bottomBarCapacity
                        let buffer = 1 // Start scrolling at penultimate item
                        
                        // Calculate boundaries to keep selection within [start + buffer, start + capacity - 1 - buffer]
                        let rightThreshold = newIndex - capacity + 1 + buffer
                        let leftThreshold = newIndex - buffer
                        
                        var newStart = bottomBarStartIndex
                        
                        if bottomBarStartIndex < rightThreshold {
                            newStart = rightThreshold
                        } else if bottomBarStartIndex > leftThreshold {
                            newStart = leftThreshold
                        }
                        
                        // Clamp to valid range
                        let maxStart = max(0, viewModel.filteredROMs.count - capacity)
                        newStart = max(0, min(newStart, maxStart))
                        
                        if newStart != bottomBarStartIndex {
                            withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) {
                                bottomBarStartIndex = newStart
                            }
                        }
                    }
                }
            
            ZStack {
                // --- CONSOLES LAYER ---
                ZStack {
                    if viewMode == .bottomBar {
                        // In Bottom Bar Mode, we use a separate view at the bottom
                        Color.clear 
                    } else if viewModel.availableConsoles.isEmpty {
                        Text("No Consoles Found")
                            .font(.headline)
                            .foregroundColor(.gray)
                    } else {
                        
                        let isGlobal = viewModel.isGlobalMode
                        let shouldShow = !isGlobal && viewModel.isSelectingConsole
                        
                        ZStack {
                            // LINE 1: FULL CONSOLE LIST (Visible when selecting console)
                            fullConsoleListLayer(geo: geo, shouldShow: shouldShow)

                            // LINE 2: COLLAPSED CARD (Removed)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.5, dampingFraction: 1.0), value: viewModel.isSelectingConsole)
                
                // --- GAMES LAYER ---
                ZStack {
                    if viewModel.filteredROMs.isEmpty {
                        if viewMode == .grid {
                             VStack(spacing: 20) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("No Games Found")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Tap to add games\nor press X on gamepad")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showAddSourceMenu = true
                            }
                        } else if !viewModel.isSelectingConsole && !viewModel.isGlobalMode && viewMode != .vertical && viewMode != .bottomBar {
                             // Should show empty state only if we expected games
                        }
                    } else {
                        if viewMode == .grid {
                            gamesGridView(isPortrait: isPortrait)
                                .mask(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: .clear, location: 0),
                                            .init(color: .black, location: 0.05), // Fade top 5%
                                            .init(color: .black, location: 1.0)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .padding(.top, 20) // Reduced padding to start higher
                                .transition(.opacity)
                        } else {
                            // Use Horizontal Carousel for Global Horizontal, and Bottom Bar
                            gamesCarouselView(mode: viewMode)
                                .transition(.opacity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Adaptive Offset for Games Layer
                .offset(x: gamesLayerXOffset)
                .offset(y: viewMode == .bottomBar ? 50 : 0) // Moved UP per request
                // In BottomBar mode, games are visible even when selecting console (just dimmed)
                .opacity(viewModel.isSelectingConsole ? (viewMode == .bottomBar ? 0.6 : 0) : 1)
                // Removed .id(viewModel.selectedConsole) to prevent heavy reconstruction of the Game List during rapid scrolling
                .animation(.spring(response: 0.35, dampingFraction: 1.0).delay(0.05), value: viewModel.isSelectingConsole)
                .animation(.easeInOut(duration: 0.3), value: viewMode)
                
                // --- BOTTOM BAR LAYER ---
                if viewMode == .bottomBar {
                    consoleBottomBarView
                }
            }
        }
        .contentShape(Rectangle()) // Ensure tap areas work
        .gesture(

             viewModel.isSelectingConsole && !viewModel.isGlobalMode ? nil : 
             DragGesture()
                .onChanged { value in
                    // Only apply drag if we are in a carousel mode (not grid)
                     if viewMode != .grid {
                  
                         let isVerticalMode = (viewMode == .vertical)
                         
                         
                         withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.86)) {
                             self.dragOffset = isVerticalMode ? value.translation.height : value.translation.width
                         }
                     }
                }
                .onEnded { value in
                    // NATURAL INERTIA LOGIC
                    
                    var isVertical = false
                    var itemSize: CGFloat = 160
                    
                    if viewModel.isSelectingConsole {
                        if viewMode == .vertical {
                            isVertical = true; itemSize = 160
                        } else {
                            isVertical = false; itemSize = 140
                        }
                    } else if viewMode != .grid {
                         isVertical = true; itemSize = 72
                    }

                    let translation = isVertical ? value.predictedEndTranslation.height : value.predictedEndTranslation.width
                    var delta = Int(round(translation / itemSize))
                    
                    delta = max(-5, min(5, delta))
                    
                    // Minimum Movement Check:
                    if delta == 0 && abs(translation) > (itemSize / 2) {
                         delta = translation > 0 ? -1 : 1
                    }
                    
                    // Bounds Checking
                    if viewModel.isSelectingConsole {
                        let current = viewModel.selectedConsoleIndex
                        let count = viewModel.availableConsoles.count
                        let target = current + delta
                        let clamped = max(0, min(count - 1, target))
                        delta = clamped - current
                    } else {
                        let current = viewModel.selectedIndex
                        let count = viewModel.filteredROMs.count
                        let target = current + delta
                        let clamped = max(0, min(count - 1, target))
                        delta = clamped - current
                    }
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if delta != 0 {
                            viewModel.moveSelection(delta: delta)
                        }
                        self.dragOffset = 0
                    }
                }
        )
        .blur(radius: viewModel.showEmulator ? 10 : (selectedROMForSaves != nil || selectedROMForSkins != nil ? 10 : 0)) // Blur if emulator OR save/skin manager
        .scaleEffect((selectedROMForSaves != nil || selectedROMForSkins != nil) ? 0.9 : 1.0) // Scale down if manager active
        .opacity((selectedROMForSaves != nil || selectedROMForSkins != nil) ? 0.6 : 1.0) // Fade if manager active
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedROMForSaves) // Smooth transition
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedROMForSkins)
    }
    
    //Console Views
    
    @ViewBuilder
    func fullConsoleListLayer(geo: GeometryProxy, shouldShow: Bool) -> some View {
        if !viewModel.isGlobalMode {
            Group {
                // Vertical Carousel (Default)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(viewModel.availableConsoles.enumerated()), id: \.offset) { index, console in
                            consoleItemView(console: console, index: index, shouldShow: shouldShow)
                        }
                    }
                    .padding(.leading, 20)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: Binding(
                    get: { viewModel.selectedConsoleIndex },
                    set: { 
                         // Guard against scroll view fighting the controller
                         if viewModel.isControllerScrolling { return }
                         if let v = $0, v != viewModel.selectedConsoleIndex { 
                             viewModel.selectedConsoleIndex = v 
                         } 
                    }
                ))
                .onChange(of: viewModel.selectedConsoleIndex) { _, newIndex in
                    if newIndex >= 0 && newIndex < viewModel.availableConsoles.count {
                         let console = viewModel.availableConsoles[newIndex]
                         if console != viewModel.selectedConsole {
                             viewModel.selectConsole(console, enter: false)
                         }
                    }
                }
                .safeAreaPadding(.vertical, (geo.size.height - 140) / 2)
                .frame(width: 400) 
                .offset(x: isPortrait ? 20 : 0)
            }

            // Persistent Sidebar Logic for Horizontal Mode

            .opacity((shouldShow || !isPortrait) ? 1 : 0)
            .offset(x: shouldShow ? 0 : (isPortrait ? -80 : -140))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: shouldShow)
            .allowsHitTesting(shouldShow)
        }
    }
    
    @ViewBuilder

    func consoleItemView(console: ROMItem.Console, index: Int, shouldShow: Bool) -> some View {
        let isSelected = (console == viewModel.selectedConsole)
        let persistSidebar = !isPortrait // Keep visible in Horizontal
        let opacity = (shouldShow || persistSidebar) ? 1.0 : (isSelected ? 0.0 : 0.0)
        
        let baseView = ConsoleCardView(
            console: console,
            offset: 0,

            dragOffset: 0,
            isSelectingConsole: shouldShow,
            gameCount: viewModel.getGameCount(for: console),
            imageName: consoleImageName(for: console)
        )
        
        // Reverting to standard unconditional matchedGeometryEffect for smooth "perfect" animation.
        // The duplicate code removal should be sufficient for performance.
        baseView.matchedGeometryEffect(id: "console_\(console.rawValue)", in: animationNamespace, isSource: true)
        .frame(height: 140) // Fixed height for Vertical List
        .scrollTransition(axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.8)
                .opacity(phase.isIdentity ? 1.0 : (enableCarouselTransparency ? 0.5 : 1.0))
                .blur(radius: phase.isIdentity ? 0 : (enableCarouselTransparency ? 2 : 0))
                .offset(x: (!phase.isIdentity) ? -20 : 0)
        }
        .opacity(opacity)
        .id(index)
        .onTapGesture {
            AudioManager.shared.playSelectSound()
            
            if viewModel.getGameCount(for: console) == 0 {
                showAddSourceMenu = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewModel.selectConsole(console)
                }
            }
        }
        // Selection Indicator Arrow (Sidebar Mode Only)
        .overlay(alignment: .trailing) {
            if isSelected && !shouldShow && !isPortrait {
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 20)) // Slightly smaller base font
                    .scaleEffect(x: 0.8, y: 1.5) // Stretched vertically ("anchita"), compressed slightly horiz
                    .foregroundColor(.gray)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: 80) // Much further right
            }
        }
    }
    
    // Game Views
    
    @ViewBuilder
    func gamesCarouselView(mode: ViewMode) -> some View {

        
        // --- THEATER MODE (BottomBar) Logic remains separate ---
        if mode == .bottomBar {
             if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < viewModel.filteredROMs.count {
                 let rom = viewModel.filteredROMs[viewModel.selectedIndex]
                 let centerIndex = bottomBarCapacity / 2
                 let step: CGFloat = 85
                 let startX = CGFloat(-centerIndex) * step
                 
                 Text(rom.displayName)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                    .lineLimit(1)
                    .frame(width: 400, alignment: .leading)
                    .offset(x: startX + 155, y: -55)
                    .zIndex(200)
             }
            
            // Return Theater Mode implementation (Unchanged)
            AnyView(
                ForEach(visibleIndices(), id: \.self) { index in
                    if index >= 0 && index < viewModel.filteredROMs.count {
                        let rom = viewModel.filteredROMs[index]
                        let offset = index - viewModel.selectedIndex
                         // ... (Keep existing Logic for Bottom Bar, it's specific)
                        let isSelected = (offset == 0)
                        let visualIndex = index - bottomBarStartIndex
                        
                        VStack {
                            ROMThumbnailView(rom: rom)
                                .frame(width: isSelected ? 90 : 70, height: isSelected ? 90 : 70)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(isSelected ? 0.5 : 0.3), radius: isSelected ? 12 : 6, x: 0, y: 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                                )
                                .scaleEffect(isSelected ? 1.0 : 0.85)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
                        }
                        .offset(x: calculateStaticTheaterXOffset(visualIndex: visualIndex))
                        .offset(y: 0) 
                        .zIndex(isSelected ? 100 : Double(-abs(offset)))
                        .onTapGesture {
                            if index == viewModel.selectedIndex {
                                AudioManager.shared.playSelectSound()
                                if !viewModel.showEmulator {
                                    if rom.console == .ios {
                                        // Prioritize StoreKit launch if URL exists
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
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                                    viewModel.selectedIndex = index
                                }
                            }
                        }
                    }
                }
            )
        } else {
             // --- NEW UNIFIED CAROUSEL (Vertical Only) ---
             // Uses ScrollView with .scrollTargetBehavior(.viewAligned) for native fluidity
             
             AnyView(
                 GeometryReader { geometry in
                     ScrollView(.vertical, showsIndicators: false) {
                         // Always Vertical Stack
                         LazyVStack(alignment: .center, spacing: 0) { 
                             contentGenerator() 
                         }
                         .frame(maxWidth: .infinity) // Ensure stack fills width to allow centering
                         .scrollTargetLayout()
                         .id(enableCarouselTransparency) // Force updates when setting changes
                     }
                     .scrollTargetBehavior(.viewAligned)
                     .scrollPosition(id: Binding(
                         get: { 
                             if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < viewModel.filteredROMs.count {
                                 return viewModel.filteredROMs[viewModel.selectedIndex].id
                             }
                             return nil
                         },
                         set: { newID in
                             // Prevent ScrollView from overwriting selection during controller navigation
                             if viewModel.isControllerScrolling { return }
                             
                             if let id = newID, 
                                let index = viewModel.filteredROMs.firstIndex(where: { $0.id == id }) {
                                 viewModel.selectedIndex = index
                             }
                         }
                     ))
                     // Padding to center the active item using ACTUAL geometry size
                     .safeAreaPadding(.vertical, (geometry.size.height - 110)/2)
                 }
                 .frame(maxWidth: .infinity)
             )
        }
    }
    
    func contentGenerator() -> some View {
        ForEach(Array(viewModel.filteredROMs.enumerated()), id: \.element.id) { index, rom in
            // We trick GameCardView to think it's focused (offset: 0) so it renders fully details.
            // We then use .scrollTransition to morph it into the 'Left Collapsed' look.
            GameCardView(
                rom: rom,
                offset: 0, // Always render as "Selected" visually internally
                playtime: viewModel.getPlaytime(for: rom),
                selectedActionIndex: viewModel.isSelectingConsole ? -1 : (index == viewModel.selectedIndex ? selectedActionIndex : -1),
                baseConsoleColors: consoleColor(for: rom.console),
                dragOffset: 0, // Native scroll handles pos
                onShowSaveManager: {
                    withAnimation(.easeOut(duration: 0.2)) { onEmulatorStarted?(true) }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        selectedROMForSaves = rom
                        showSaveManager = true
                    }
                },
                onShowSkinManager: {
                    withAnimation(.easeOut(duration: 0.2)) { onEmulatorStarted?(true) }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        selectedROMForSkins = rom
                    }
                }
            )
            .id(rom.id) // Use UUID instead of Index for robust scrolling
            .frame(width: 350, height: 110) // Fixed frame for scrolling consistency (Matches GameCardView internal logic)
            .scrollTransition(axis: .vertical) { content, phase in
                content
                    // Scale down neighbors (smoother interpolation)
                    .scaleEffect(phase.isIdentity ? 1.0 : 0.9)
                    // Fade neighbors slightly
                    .opacity(phase.isIdentity ? 1.0 : (enableCarouselTransparency ? 0.6 : 1.0))
                    // VERTICAL MODE: Centered (0) to match Horizontal behavior.
                    .offset(x: 0)
                    .blur(radius: phase.isIdentity ? 0 : (enableCarouselTransparency ? 2 : 0))
            }
            .contextMenu {
                 Button { NotificationCenter.default.post(name: NSNotification.Name("AddRomToHome"), object: rom) } label: { Label("Add to Home", systemImage: "plus.square.on.square") }
                 Button {
                     withAnimation(.easeOut(duration: 0.2)) { onEmulatorStarted?(true) }
                     withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { selectedROMForSaves = rom; showSaveManager = true }
                 } label: { Label("Save Data", systemImage: "sdcard") }
                 Button {
                     withAnimation(.easeOut(duration: 0.2)) { onEmulatorStarted?(true) }
                     withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { selectedROMForSkins = rom }
                 } label: { Label("Manage Skins", systemImage: "paintbrush") }
                 Button { romToEdit = rom } label: { Label("Edit", systemImage: "pencil") }
                 Button(role: .destructive) { requestDelete(rom: rom) } label: { Label("Delete", systemImage: "trash") }
            }
            .onTapGesture {
                if index == viewModel.selectedIndex {
                    // Launch
                    AudioManager.shared.playSelectSound()
                    if !viewModel.showEmulator {
                        if rom.console == .ios {
                            // Prioritize StoreKit launch if URL exists
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
                } else {
                    // Scroll to
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                        viewModel.selectedIndex = index
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func gamesGridView(isPortrait: Bool) -> some View {
        let groups = getConsoleGroups()
        
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                 LazyVGrid(columns: isPortrait ? Array(repeating: GridItem(.flexible(), spacing: 10), count: 3) : gridColumns, spacing: 10, pinnedViews: [.sectionHeaders]) {
                    ForEach(groups) { group in
                        Section(header: ConsoleHeaderView(title: group.console.systemName)) {
                            ForEach(group.roms, id: \.rom.id) { item in
                                gridItemView(item: item)
                            }
                        }
                    }
                }
                .padding(.top, 100)
                .padding(.bottom, 100)
                .padding(.horizontal, 40)
            }
             .onChange(of: viewModel.selectedIndex) { newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
    
    @ViewBuilder
    func gridItemView(item: (index: Int, rom: ROMItem)) -> some View {
        let index = item.index
        let rom = item.rom
        let isSelected = (index == viewModel.selectedIndex)
        
        ROMCardView(rom: rom, isSelected: isSelected)
            .contextMenu {
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("AddRomToHome"), object: rom)
                } label: {
                    Label("Add to Home", systemImage: "plus.square.on.square")
                }
                Button {
                    // Open Save Manager
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        selectedROMForSaves = rom
                        showSaveManager = true
                        onEmulatorStarted?(true) // Hide Header
                    }
                } label: {
                    Label("Save Data", systemImage: "sdcard")
                }
                Button {
                    // Open Skin Manager
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        selectedROMForSkins = rom
                        onEmulatorStarted?(true) // Hide Header
                    }
                } label: {
                    Label("Skins Manager", systemImage: "paintpalette")
                }
                Button {
                    romToEdit = rom
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    requestDelete(rom: rom)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .padding(4)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .id(index) // Important for scrolling
            .onTapGesture {
                 if isSelected {
                     // Second Tap -> Play
                     AudioManager.shared.playSelectSound()
                     if !viewModel.showEmulator {
                          // Check if iOS Shortcut
                          if rom.console == .ios {
                              // Prioritize StoreKit launch if URL exists
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
                 } else {
                     // Tap Unselected -> Select
                     viewModel.selectedIndex = index
                 }
            }
    }
    
    //  Overlays
    
    @ViewBuilder
    var emulatorOverlayLayer: some View {
        if viewModel.showEmulator, let rom = viewModel.selectedROM {
            // GameLaunchView logic ...
            GameLaunchView(
                rom: rom,
                onDismiss: {
                    withAnimation {
                        viewModel.showEmulator = false
                        gameController.disableHomeNavigation = true
                        onEmulatorStarted?(false)
                    }
                },
                shouldRestoreHomeNavigation: false
            )
            .zIndex(1000)
            .transition(.asymmetric(insertion: .opacity, removal: .opacity)) // Keep existing
        }
    }
    
    @ViewBuilder
    var saveManagerOverlayLayer: some View {
        if let rom = selectedROMForSaves {
            GameSaveManagerView(rom: rom, onDismiss: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedROMForSaves = nil
                    gameController.disableHomeNavigation = true // Re-enable for SystemsView logic (handled by onChange below)
                    onEmulatorStarted?(false) // Show Header
                }
            })
            .zIndex(2000) // Topmost
            .transition(.opacity.combined(with: .scale(scale: 0.92))) // Zoom in transition
        }
    }
    
    @ViewBuilder
    var skinManagerOverlayLayer: some View {
        if let rom = selectedROMForSkins {
            GameSkinManagerView(rom: rom, onDismiss: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedROMForSkins = nil
                    gameController.disableHomeNavigation = true
                    onEmulatorStarted?(false)
                }
            })
            .zIndex(2000)
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }
    
    @ViewBuilder
    var footerControlsLayer: some View {
        if selectedROMForSaves == nil && selectedROMForSkins == nil && viewMode != .bottomBar {
            bottomControlsLayer(isPortrait: isPortrait)
                .zIndex(50)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func bottomControlsLayer(isPortrait: Bool) -> some View {
        if isPortrait {
            // Portrait: Unified Control (Back + Add), Scaled 1.25x
            VStack {
                Spacer()
                
                let actions: [ControlAction] = {
                    var items: [ControlAction] = []
                    
                    // Back Button (Only if NOT Lite Mode OR if navigating hierarchy)
                    // Hierarchy = Not Selecting Console AND Not Global Mode
                    let canGoUp = !viewModel.isSelectingConsole && !viewModel.isGlobalMode
                    let showBack = !SettingsManager.shared.liteMode || canGoUp
                    
                    if showBack {
                        items.append(ControlAction(icon: "b.circle", label: "Back", action: {
                            // Back Logic
                            if !viewModel.showEmulator {
                                if viewMode == .vertical {
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
                        }))
                    }
                    
                    items.append(ControlAction(icon: "x.circle", label: "Add", action: {
                        print("🎮 Add button pressed via Touch")
                        AudioManager.shared.playSelectSound()
                        showAddSourceMenu = true
                    }))
                    
                    // Lite Mode: Music Player Button
                    if SettingsManager.shared.liteMode {
                        items.append(ControlAction(icon: "music.note", label: "Music", action: {
                            AudioManager.shared.playSelectSound()
                            onRequestMusicPlayer?()
                        }))
                    }
                    
                    return items
                }()
                
                ControlCard(actions: actions, position: .center, isHorizontal: true, scale: 1.25)
                // Center horizontally
                // Padding bottom 20
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .bottom) // Ensure full width for centering
        } else {
            // Landscape: Split Controls (Original)
            VStack {
                Spacer()
                HStack {
                    // Left Controls (Options/Add/Music)
                    let leftActions: [ControlAction] = {
                        var items: [ControlAction] = []
                        
                        items.append(ControlAction(icon: "y.circle", label: "Options", action: {
                            if !viewModel.filteredROMs.isEmpty {
                                let rom = viewModel.filteredROMs[viewModel.selectedIndex]
                                requestOptions(rom: rom)
                            }
                        }))
                        
                        items.append(ControlAction(icon: "x.circle", label: "Add", action: {
                            print("🎮 Add button pressed via Touch")
                            AudioManager.shared.playSelectSound()
                            showAddSourceMenu = true
                        }))
                        
                        // Lite Mode: Music Player Button
                        if SettingsManager.shared.liteMode {
                            items.append(ControlAction(icon: "music.note", label: "Music", action: {
                                AudioManager.shared.playSelectSound()
                                onRequestMusicPlayer?()
                            }))
                        }
                        
                        return items
                    }()
                    
                    ControlCard(actions: leftActions, position: .left)
                    .padding(.leading, 40)
                    
                    Spacer()
                    
                    // Right Controls (Select/Back)
                    let rightActions: [ControlAction] = {
                        var items: [ControlAction] = []
                        
                        // Select/Play Action
                        items.append(ControlAction(icon: "a.circle", label: viewModel.isSelectingConsole ? "Select" : (selectedActionIndex == 0 ? "Skins" : (selectedActionIndex == 1 ? "Manage" : "Play"))))
                        
                        // Back Action
                        let canGoUp = !viewModel.isSelectingConsole && !viewModel.isGlobalMode
                        let showBack = !SettingsManager.shared.liteMode || canGoUp
                        
                        if showBack {
                             items.append(ControlAction(icon: "b.circle", label: "Back", action: {
                                 if !viewModel.showEmulator {
                                     if viewMode == .vertical {
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
                             }))
                        }
                        
                        return items
                    }()

                    ControlCard(actions: rightActions, position: .right)
                    .padding(.trailing, 40)
                }
                .padding(.bottom, 20)
            }
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    var liteModeExitLayer: some View {
        EmptyView()
    }
    
    @ViewBuilder
    var viewToggleLayer: some View {
        // Settings Menu for View Mode Selection
        if settingsShouldBeVisible {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showViewModeMenu.toggle()
                }
                AudioManager.shared.playSelectSound()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                    Image(systemName: "square.grid.2x2.fill")
                    Image(systemName: "dock.rectangle")
                    
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16, weight: .medium))
                }
                .font(.system(size: 14))
                .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.8) : Color(red: 0.35, green: 0.38, blue: 0.42))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    BubbleBackground(position: .center, cornerRadius: 50)
                )
            }
            .padding(.top, isPortrait ? 90 : 80) // Increased top space in portrait
            .padding(.trailing, isPortrait ? 24 : 40) // Closer to edge in portrait
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .zIndex(60)
        }
    }
    
    @ViewBuilder
    var customViewModeMenuLayer: some View {
        Group {
            if showViewModeMenu {
                // Invisible dismiss layer
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showViewModeMenu = false }
                    }
                    .zIndex(61)
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    // 0. View Options (Submenu Trigger)
                    Button(action: {
                        AudioManager.shared.playSelectSound()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showViewModeSubmenu = true
                        }
                    }) {
                        HStack {
                            Text("View Options")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : Color(red: 0.2, green: 0.2, blue: 0.2))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.6) : Color(red: 0.35, green: 0.38, blue: 0.42))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(selectedViewModeIndex == 0 ? Color.blue.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    
                    if SettingsManager.shared.liteMode {
                        Divider().padding(.horizontal, 16)
                        
                        // 1. Settings
                        Button(action: {
                            AudioManager.shared.playSelectSound()
                            withAnimation {
                                showViewModeMenu = false
                                showSettings = true
                            }
                        }) {
                            HStack {
                                Text("Settings")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : Color(red: 0.2, green: 0.2, blue: 0.2))
                                Spacer()
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.6) : Color(red: 0.35, green: 0.38, blue: 0.42))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(selectedViewModeIndex == 1 ? Color.blue.opacity(0.1) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        
                        // 2. Exit Lite Mode
                        Button(action: {
                            AudioManager.shared.playSelectSound()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                 SettingsManager.shared.setLiteMode(false)
                                 isPresented = false
                            }
                        }) {
                            HStack {
                                Text("Exit Lite Mode")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : Color(red: 0.2, green: 0.2, blue: 0.2))
                                Spacer()
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.6) : Color(red: 0.35, green: 0.38, blue: 0.42))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(selectedViewModeIndex == 2 ? Color.blue.opacity(0.1) : Color.clear)
                            .contentShape(Rectangle())
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .background(
                    BubbleBackground(position: .center, cornerRadius: 20)
                )
                .frame(width: 260)
                .padding(.top, isPortrait ? 140 : 130)
                .padding(.trailing, isPortrait ? 24 : 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(62)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
            // SUBMENU OVERLAY
            if showViewModeSubmenu {
                // Dimmed background to focus on submenu (optional, or just stacked)
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showViewModeSubmenu = false }
                    }
                    .zIndex(63)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Submenu Items
                    viewModeOption(title: "By Consoles", icon: "list.bullet", mode: .vertical, index: 0, isSubmenu: true)
                    Divider().padding(.horizontal, 16)
                    viewModeOption(title: "All Games (Grid)", icon: "square.grid.2x2.fill", mode: .grid, index: 1, isSubmenu: true)
                    viewModeOption(title: "Theater Mode", icon: "dock.rectangle", mode: .bottomBar, index: 2, isSubmenu: true)
                    
                    Divider().padding(.horizontal, 16)
                    
                    Button(action: {
                        AudioManager.shared.playSelectSound()
                        withAnimation { 
                            showViewModeSubmenu = false
                            showViewModeMenu = false 
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showReorderSheet = true
                        }
                    }) {
                        HStack {
                            Text("Reorder Consoles")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : Color(red: 0.2, green: 0.2, blue: 0.2))
                            Spacer()
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 16))
                                .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.6) : Color(red: 0.35, green: 0.38, blue: 0.42))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(selectedSubmenuIndex == 3 ? Color.blue.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    
                    Divider().padding(.horizontal, 16)
                    
                    Button(action: {
                        disableStartAnimation.toggle()
                        AudioManager.shared.playSelectSound()
                    }) {
                        HStack {
                            Text("Start Animation")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : Color(red: 0.2, green: 0.2, blue: 0.2))
                            Spacer()
                            Text(disableStartAnimation ? "OFF" : "ON")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(disableStartAnimation ? Color.gray : Color.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(selectedSubmenuIndex == 4 ? Color.blue.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    
                    Divider().padding(.horizontal, 16)
                    
                    Button(action: {
                        enableCarouselTransparency.toggle()
                        AudioManager.shared.playSelectSound()
                    }) {
                        HStack {
                            Text("Transparency Effect")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : Color(red: 0.2, green: 0.2, blue: 0.2))
                            Spacer()
                            Text(enableCarouselTransparency ? "ON" : "OFF")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(enableCarouselTransparency ? Color.blue : Color.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(selectedSubmenuIndex == 5 ? Color.blue.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .background(
                    BubbleBackground(position: .center, cornerRadius: 20)
                )
                .frame(width: 280)
                // Positioned slightly offset to create "superimposed" hierarchy effect, or center it
                .padding(.top, isPortrait ? 140 : 130)
                .padding(.trailing, isPortrait ? 24 : 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(64)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
    
    func viewModeOption(title: String, icon: String, mode: ViewMode, index: Int, isSubmenu: Bool = false) -> some View {
        let isSelected = isSubmenu ? (selectedSubmenuIndex == index) : (selectedViewModeIndex == index)
        
        return Button(action: {
            AudioManager.shared.playSelectSound()
            switchToMode(mode)
            withAnimation { 
                showViewModeSubmenu = false
                showViewModeMenu = false 
            }
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : Color(red: 0.2, green: 0.2, blue: 0.2))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(viewMode == mode ? .blue : (settings.activeTheme.isDark ? .white.opacity(0.6) : Color(red: 0.35, green: 0.38, blue: 0.42)))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12) // Slightly reduced height in submenu
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
    }
    
    @ViewBuilder
    var bottomBarControlsLegendLayer: some View {
        if viewMode == .bottomBar && !viewModel.showEmulator && selectedROMForSaves == nil && selectedROMForSkins == nil {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    controlLegendRow(icon: "y.circle.fill", text: "Options")
                    controlLegendRow(icon: "b.circle.fill", text: "Back")
                }
                VStack(alignment: .leading, spacing: 8) {
                    controlLegendRow(icon: "x.circle.fill", text: "Add Game")
                    controlLegendRow(icon: "a.circle.fill", text: "Accept")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                BubbleBackground(position: .center, cornerRadius: 20)
            )
            .padding(.top, 80)
            .padding(.trailing, 195)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .zIndex(55)
        }
    }
    
    func controlLegendRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.6) : Color(red: 0.35, green: 0.38, blue: 0.42)) // Gunmetal Blue-Grey
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : Color(red: 0.2, green: 0.2, blue: 0.2)) // Dark Grey Text
        }
    }
    
    @ViewBuilder
    var consoleBottomBarView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(0..<viewModel.availableConsoles.count, id: \.self) { index in
                        let console = viewModel.availableConsoles[index]
                        let isSelected = (index == viewModel.selectedConsoleIndex)
                        
                        VStack(spacing: 4) {
                            // Text Only as per request "elimina las imagenes y solo muetra el nombre"
                            Text(console.systemName)
                                .font(.system(size: isSelected ? 16 : 14, weight: isSelected ? .bold : .medium, design: .rounded))
                                .fontWeight(isSelected ? .bold : .regular)
                        }
                         .foregroundColor(isSelected ? .white : .gray)
                         .scaleEffect(isSelected ? 1.2 : 1.0)
                         .opacity(isSelected ? 1.0 : (viewModel.isSelectingConsole || viewMode == .bottomBar ? 0.7 : 0.4))
                         .onTapGesture {
                             withAnimation { 
                                 viewModel.selectedConsoleIndex = index
                                 viewModel.selectConsole(console, enter: viewMode != .bottomBar)
                             }
                         }
                         .id(index)
                    }
                }
                .padding(.horizontal, 40)
            }
            .onChange(of: viewModel.selectedConsoleIndex) { newIndex in
                withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
            }
        }
        .frame(height: 100)
        .background(
             LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.9), Color.clear]), startPoint: .bottom, endPoint: .top)
        )
        // Position at bottom
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 0)
    }
}
