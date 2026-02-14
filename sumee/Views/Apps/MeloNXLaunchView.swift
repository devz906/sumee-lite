import SwiftUI
import Combine
import Foundation

struct MeloNXLaunchView: View {
    @Binding var isPresented: Bool
    
    @State private var animationState: LaunchState = .initial
    @State private var showContent = false
    @State private var launchingGame: GameScheme? = nil // Track which game is launching
    
    enum LaunchState {
        case initial
        case expanding
        case splash
        case gameLaunch // New state for game launching
    }
    
    var body: some View {
        ZStack {

            LinearGradient(gradient: Gradient(colors: [Color(hex: "2c3e50") ?? .black, Color(hex: "4ca1af") ?? .blue]), startPoint: .top, endPoint: .bottom)
                .clipShape(Circle())
       
                .scaleEffect(animationState == .initial ? 0.01 : 2.5) 
                .opacity(animationState == .initial ? 0 : 1)
                .ignoresSafeArea()
            
            // Conditional content
            if showContent {
                MeloNXView(
                    onDismiss: {
                        startExitSequence()
                    }, onLaunch: { game in
                        startGameLaunchSequence(game)
                    })
                .transition(.opacity)
                .opacity(launchingGame != nil ? 0 : 1)
            } else {
                // Splash Screen Content
				if launchingGame == nil {
					VStack {
						Spacer()
						VStack {
							// Placeholder Icon
							Image("icon_melonx")
								.resizable()
								.scaledToFit()
								.frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(radius: 10)
							Text("MeloNX")
								.font(.system(size: 24, weight: .bold, design: .rounded))
								.foregroundColor(.white)
								.padding(.top, 16)
						}
						.scaleEffect(animationState == .initial ? 0.1 : (animationState == .expanding ? 1.2 : 1.0))
						.opacity(animationState == .initial ? 0 : 1)
						.rotationEffect(.degrees(animationState == .initial ? -180 : 0))
						
						Spacer()
					}
					.transition(.opacity)
				}
            }
            
            // Game Launch Overlay
            if let game = launchingGame {
                ZStack {
                     // 1. Background Expander
                     Circle()
                         .fill(Color.black)
                         .frame(width: 100, height: 100)
                         .scaleEffect(animationState == .gameLaunch ? 30.0 : 1.0)
                         .opacity(animationState == .gameLaunch ? 1.0 : 0.0)
                    
                     // 2. Game Icon (Centered, sharp, Rounded Rectangle)
                     if let icon = game.iconData, let uiImage = UIImage(data: icon) {
                         Image(uiImage: uiImage)
                             .resizable()
                             .aspectRatio(contentMode: .fill)
                             .frame(width: 120, height: 120)
                             .clipShape(RoundedRectangle(cornerRadius: 24))
                             .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white, lineWidth: 4))
                             .shadow(radius: 10)
                             .scaleEffect(animationState == .gameLaunch ? 1.2 : 1.0)
                             .opacity(1.0) 
                     }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            startLaunchSequence()
        }
        // Reset state when app becomes active again?
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if launchingGame != nil {
                resetToContent()
            }
        }
    }
    
    private func resetToContent() {
        withAnimation {
            self.animationState = .splash
            self.launchingGame = nil
            self.showContent = true
        }
    }
    
    private func startLaunchSequence() {

        if MusicPlayerManager.shared.isPlaying {
            print(" Music Player active, skipping MeloNX Launch audio")
        } else {
         
            AudioManager.shared.playStartGameSound()
            
            // Start MeloNX Music
            AudioManager.shared.playMeloNXMusic()
        }
        
        // Step 1: Expand from center
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animationState = .expanding
        }
        
        // Step 2: Settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                animationState = .splash
            }
        }
        
        // Step 3: Show Content
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.5)) {
                showContent = true
            }
        }
    }
    
    private func startGameLaunchSequence(_ game: GameScheme) {
        // 1. Set State to trigger overlay
        withAnimation(.easeInOut(duration: 0.3)) {
            self.launchingGame = game
            self.showContent = false // Hide UI
        }
        
        AudioManager.shared.playStartGameSound()
        
        // 2. Animate Expansion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.8)) {
                self.animationState = .gameLaunch
            }
        }
        
        // 3. Launch URL after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            if let url = URL(string: "melonx://game?id=\(game.titleId)") {
                UIApplication.shared.open(url)
            }
          
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                 self.resetToContent()
            }
        }
    }
    
    private func startExitSequence() {
         // Play SFX
         AudioManager.shared.playStopGameSound()
         
         // Immediately restore background music (don't wait for SFX to finish)
         if !MusicPlayerManager.shared.isPlaying {
             AudioManager.shared.fadeInBackgroundMusic(duration: 0.8)
         }
         
         dismissAndAnimate()
    }
    
    private func dismissAndAnimate() {
        withAnimation(.easeOut(duration: 0.3)) {
            showContent = false
            animationState = .splash
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animationState = .initial // Shrink back to initial state
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isPresented = false // Finally dismiss the launch view
        }
    }
}

struct MeloNXView: View {
    var onDismiss: () -> Void
    var onLaunch: (GameScheme) -> Void // Closure for launching game
    
    @State private var animateText = false
    @ObservedObject private var gameController = GameControllerManager.shared
    
    @State var games: [GameScheme] = []
    
    // Computed properties for layout
    var recentGames: [GameScheme] {
        Array(games.prefix(10))
    }
    
    // Focus State
    enum FocusArea {
        case header // Sync / Trash buttons
        case recent // Top horizontal scroll
        case folder // Bottom grid
        case expandedFolder // New area for open folder
    }
    
    @State private var focusedArea: FocusArea = .recent
    @State private var recentIndex = 0
    @State private var folderIndex = 0
    @State private var expandedGameIndex = 0
    @State private var headerIndex = 0
    
    @State private var isFolderExpanded = false
    
    // Controller Listeners
    @State private var subscribers: [AnyCancellable] = []
    
    // Track IDs of new games to animate them
    @State private var animatingGameIds: [String: Double] = [:]
    
    // Alert State
    @State private var showMeloNXMissingAlert = false

    var body: some View {
        ZStack {
         
            
            // Modern Background
            LinearGradient(gradient: Gradient(colors: [Color(hex: "2c3e50") ?? .black, Color(hex: "4ca1af") ?? .blue]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                HeaderView(
                 
                   isControllerConnected: GameControllerManager.shared.isControllerConnected,
                   customTitle: "MeloNX"
                )
                .padding(.top, 0)
                .padding(.bottom, 10)
                
                // Content ScrollView
                if games.isEmpty {
                    EmptyLibraryView(onSync: syncGames)
                        .opacity(animateText ? 1 : 0)
                        .scaleEffect(animateText ? 1 : 0.95)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        ScrollViewReader { scrollProxy in
                            VStack(alignment: .leading, spacing: 30) {
                                
                                // 1. Featured / Recent Row (Large Icons)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    ScrollViewReader { horizontalProxy in
                                        HStack(spacing: 20) {
                                            ForEach(Array(recentGames.enumerated()), id: \.element.id) { index, game in
                                                MeloNXGameCardView(
                                                    game: game,
                                                    size: 100,
                                                    isFocused: (focusedArea == .recent && recentIndex == index),
                                                    delay: animatingGameIds[game.id] ?? 0 // Pass delay
                                                ) {
                                                    launchGame(game)
                                                }
                                                .id("recent_\(index)")
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 30)
                                        .onChange(of: recentIndex) { newIndex in
                                            if focusedArea == .recent {
                                                withAnimation {
                                                    horizontalProxy.scrollTo("recent_\(newIndex)", anchor: .center)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.top, -20)
                                .id("recent_section") // ID for the whole section to ensure safe scrolling
                                
                                // 2. All Software Folder
                                VStack(spacing: 20) {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 15)], spacing: 15) {
                                        FolderCardView(
                                            title: "All Software",
                                            games: games,
                                            isFocused: (focusedArea == .folder && folderIndex == 0),
                                            delay: animatingGameIds["__ALL_SOFTWARE__"] ?? 0
                                        ) {
                                            toggleFolder()
                                        }
                                        .id("folder_card")
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    // Expanded Content
                                    if isFolderExpanded {
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 20)], spacing: 20) {
                                            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                                                MeloNXGameCardView(
                                                    game: game,
                                                    size: 110, // Slightly larger for grid view
                                                    isFocused: (focusedArea == .expandedFolder && expandedGameIndex == index)
                                                ) {
                                                    launchGame(game)
                                                }
                                                .id("expanded_\(index)")
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.top, 10)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                }
                                .padding(.bottom, 30) // Reduce padding here, space handled by buttons below
                                
                                .onChange(of: isFolderExpanded) { expanded in
                                    if expanded {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            withAnimation {
                                                scrollProxy.scrollTo("expanded_0", anchor: .top)
                                            }
                                        }
                                    }
                                }
                                .onChange(of: expandedGameIndex) { newIndex in
                                    if focusedArea == .expandedFolder {
                                        withAnimation {
                                            scrollProxy.scrollTo("expanded_\(newIndex)", anchor: .center)
                                        }
                                    }
                                }
                                .onChange(of: focusedArea) { newArea in
                                    withAnimation {
                                        if newArea == .recent {
                                            scrollProxy.scrollTo("recent_section", anchor: .center) // Scroll to section center to avoid cut-off
                                        } else if newArea == .folder {
                                            scrollProxy.scrollTo("folder_card", anchor: .center)
                                        } else if newArea == .expandedFolder {
                                             // Handles own scroll
                                        }
                                    }
                                }
                                
                                // Sync / Trash Action Buttons (Integrated into ScrollContent)
                                if !games.isEmpty {
                                    HStack(spacing: 20) {
                                        Spacer()
                                        
                                        Button(action: syncGames) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                Text("Sync")
                                            }
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.2))
                                            .clipShape(Capsule())
                                        }
                                        
                                        Button(action: clearGames) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "trash")
                                                Text("Clear")
                                            }
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.2))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.bottom, 20) // Bottom spacing for scroll content
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                }
            }
            .padding(.top, 20) // Safe Area
            
            // Bottom Controls (GameController Style)
            VStack(spacing: 12) {
                Spacer()
                
                ZStack(alignment: .center) {
                    HStack {
                        // Left Controls
                        ControlCard(actions: [
                            ControlAction(icon: "b.circle", label: "Back", action: {
                                AudioManager.shared.playNavigationSound()
                                onDismiss()
                            })
                        ], position: .left)
                        
                        Spacer()
                        
                        // Right Controls
                        ControlCard(actions: [
                            ControlAction(icon: "a.circle", label: "Start", action: {
                                handleAction()
                            }),
                            ControlAction(icon: "dpad", label: "Navigate")
                        ], position: .right)
                    }
                }
                .frame(height: 32)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
                .allowsHitTesting(true)
            }
        }
        .onAppear {
            loadGames()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animateText = true
            }
            setupController()
        }
        .onDisappear {
            restoreController()
        }
        .onOpenURL { url in
            let incomingGames = GameScheme.pullFromURL(url, otherURL: {
                print("MeloNX: Failed to parse URL or Scheme mismatch")
            })
            
            if !incomingGames.isEmpty {
                // Single-batch update for fluid animation
                
                var preservedGames: [GameScheme] = []
                var newGames: [GameScheme] = []
                var incomingMap = Dictionary(uniqueKeysWithValues: incomingGames.map { ($0.titleId, $0) })
                
                // Process existing
                for existing in self.games {
                    if let fresh = incomingMap[existing.titleId] {
                        var updated = fresh
                        updated.id = existing.id
                        preservedGames.append(updated)
                        incomingMap.removeValue(forKey: existing.titleId)
                    }
                }
                
                // Process new
                for incoming in incomingGames {
                    if incomingMap[incoming.titleId] != nil {
                         newGames.append(incoming)
                    }
                }
                
                // Calculate delays for new games
                // We restart delay map
                var newDelays: [String: Double] = [:]
                let baseDelay = 0.35 // Slower speed per item
                
                for (index, game) in newGames.enumerated() {
                    // Stagger: 0.35s * index using the count of new games
                    newDelays[game.id] = Double(index) * baseDelay
                }
                
                // Also assign a delay to the folder so it appears after the games
           
                newDelays["__ALL_SOFTWARE__"] = Double(newGames.count) * baseDelay + 0.2
                
                self.animatingGameIds = newDelays
                
                withAnimation {
                    // Insert new games at the front
           
                    self.games = newGames + preservedGames
                }
                
                saveGames()
                
                // Sync with ROM Library
                ROMStorageManager.shared.addMeloNXGames(self.games)
                
                // Clean up delays after animation finishes
                let maxDelay = Double(newGames.count) * baseDelay + 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + maxDelay) {
                    self.animatingGameIds.removeAll()
                }
            }
        }
        .alert(isPresented: $showMeloNXMissingAlert) {
            Alert(
                title: Text("MeloNX Not Installed"),
                message: Text("Please install MeloNX to sync your games."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Controller Logic
    
    private func setupController() {
        // Disable main menu navigation
        GameControllerManager.shared.disableHomeNavigation = true
        
        // Subscribe to inputs
 
        GameControllerManager.shared.$dpadRight
            .sink { pressed in if pressed { self.navigate(.right) } }
            .store(in: &subscribers)
        
        GameControllerManager.shared.$dpadLeft
            .sink { pressed in if pressed { self.navigate(.left) } }
            .store(in: &subscribers)
        
        GameControllerManager.shared.$dpadDown
            .sink { pressed in if pressed { self.navigate(.down) } }
            .store(in: &subscribers)
            
        GameControllerManager.shared.$dpadUp
            .sink { pressed in if pressed { self.navigate(.up) } }
            .store(in: &subscribers)
            
        // Buttons
        GameControllerManager.shared.$buttonAPressed
            .sink { pressed in if pressed { self.handleAction() } }
            .store(in: &subscribers)
            
        GameControllerManager.shared.$buttonBPressed
            .sink { pressed in
                if pressed {
                    self.onDismiss()
                }
            }
            .store(in: &subscribers)
    }
    
    private func restoreController() {
        GameControllerManager.shared.disableHomeNavigation = false
        subscribers.removeAll()
    }
    
    enum NavDirection { case up, down, left, right }
    
    // Joystick Debounce State
    @State private var lastNavTime = Date()
    
    private func navigate(_ direction: NavDirection) {
        // Debounce Check: Ignore inputs faster than 150ms (allows ~6 moves/sec)
        // This prevents "machine gun" scrolling from noisy analog sticks
        let now = Date()
        if now.timeIntervalSince(lastNavTime) < 0.15 { return }
        lastNavTime = now
        
        AudioManager.shared.playMoveSound()
        
        switch direction {
        case .up:
            if focusedArea == .recent {
                 // Already at top (Header is disabled for controller)
                 // Do nothing or bounce
            } else if focusedArea == .folder {
                focusedArea = .recent
                recentIndex = 0 
            } else if focusedArea == .expandedFolder {
                let columns = 3
                if expandedGameIndex < columns {
                    focusedArea = .folder
                    folderIndex = 0
                } else {
                    expandedGameIndex = max(0, expandedGameIndex - columns)
                }
            }
            
        case .down:
            if focusedArea == .header { // Should not happen if unreachable, but kept safe
                focusedArea = .recent
                recentIndex = 0
            } else if focusedArea == .recent {
                focusedArea = .folder
                folderIndex = 0
            } else if focusedArea == .folder {
                if isFolderExpanded {
                    focusedArea = .expandedFolder
                    expandedGameIndex = 0
                }
            } else if focusedArea == .expandedFolder {
                let columns = 3
                if expandedGameIndex + columns < games.count {
                    expandedGameIndex += columns
                }
            }
            
        case .left:
            if focusedArea == .header {
                 // headerIndex = max(0, headerIndex - 1)
            } else if focusedArea == .recent {
                 recentIndex = max(0, recentIndex - 1)
            } else if focusedArea == .expandedFolder {
                expandedGameIndex = max(0, expandedGameIndex - 1)
            }
            
        case .right:
             if focusedArea == .header {
                  // headerIndex = min(1, headerIndex + 1)
             } else if focusedArea == .recent {
                  recentIndex = min(games.count - 1, recentIndex + 1)
             } else if focusedArea == .expandedFolder {
                 expandedGameIndex = min(games.count - 1, expandedGameIndex + 1)
             }
        }
    }
    
    private func handleAction() {
        AudioManager.shared.playSelectSound()
        
        switch focusedArea {
        case .header:
            if headerIndex == 0 { syncGames() }
            else { clearGames() }
        case .recent:
            if recentIndex < games.count {
                launchGame(games[recentIndex])
            }
        case .folder:
            toggleFolder()
        case .expandedFolder:
            if expandedGameIndex < games.count {
                launchGame(games[expandedGameIndex])
            }
        }
    }
    
    private func handleBack() {
        if isFolderExpanded {
            // Collapse folder
            withAnimation {
                isFolderExpanded = false
            }
            focusedArea = .folder // Return focus to folder
            AudioManager.shared.playMoveSound() 

        } else {
            onDismiss()
        }
    }
    
    private func toggleFolder() {
        withAnimation {
            isFolderExpanded.toggle()
        }
        if isFolderExpanded {
            focusedArea = .expandedFolder
            expandedGameIndex = 0 
        } else {

        }
    }
    
    private func syncGames() {
        if let url = URL(string: "melonx://gameInfo?scheme=sumeemelonx") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                showMeloNXMissingAlert = true
            }
        }
    }
    
    private func clearGames() {
        withAnimation {
            self.games = []
            saveGames()
        }
    }
    
    private func launchGame(_ game: GameScheme) {
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            // Move to front
            var updatedGames = games
            let selectedGame = updatedGames.remove(at: index)
            updatedGames.insert(selectedGame, at: 0)
            self.games = updatedGames
            saveGames()
        }
        
        // Trigger Launch Animation in Parent
        onLaunch(game)
    }
    
    // Persistence Helpers
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getGamesFileURL() -> URL {
        getDocumentsDirectory().appendingPathComponent("melonx_games.json")
    }
    
    private func saveGames() {
        do {
            let data = try JSONEncoder().encode(games)
            try data.write(to: getGamesFileURL())
            print("MeloNX: Saved \(games.count) games to disk.")
        } catch {
            print("MeloNX: Failed to save games: \(error.localizedDescription)")
        }
    }
    
    private func loadGames() {
        let url = getGamesFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let loadedGames = try JSONDecoder().decode([GameScheme].self, from: data)
            self.games = loadedGames
            print("MeloNX: Loaded \(loadedGames.count) games from disk.")
            
            // Sync with ROM Library on load to ensure consistency
            ROMStorageManager.shared.addMeloNXGames(loadedGames)
        } catch {
            print("MeloNX: Failed to load games: \(error.localizedDescription)")
        }
    }
}

struct EmptyLibraryView: View {
    var onSync: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.5))
            
            Text("Your Library is Empty")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Sync with MeloNX to import your games.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button(action: onSync) {
                Text("Sync Library")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Components

struct MeloNXGameCardView: View {
    let game: GameScheme
    let size: CGFloat
    var isFocused: Bool = false
    var delay: Double = 0 // Staggered animation delay
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isVisible = false // Controls the pop-in animation
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Game Cover
                if let icon = game.iconData, let uiImage = UIImage(data: icon) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                } else {
                    ZStack {
                        Color.gray.opacity(0.3)
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: size, height: size)
                }
                
                // Gradient Overlay
                LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                    .frame(height: size * 0.4)
                
                // Title
                Text(game.titleName)
                    .font(.system(size: size * 0.12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(8)
                    .frame(width: size, alignment: .bottomLeading)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: (isHovered || isFocused) ? 4 : 0)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect((isHovered || isFocused) ? 1.1 : 1.0)
            .scaleEffect(isVisible ? 1.0 : 0.001) // Pop-in scale
            .opacity(isVisible ? 1.0 : 0.0) // Pop-in opacity
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFocused)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if delay > 0 {
                // If there's a delay, start invisible and animate in
                isVisible = false
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                    isVisible = true
                }
                // Optional: Play tick sound when it physically appears
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    AudioManager.shared.playSelectSound()
                }
            } else {
                isVisible = true
            }
        }
    }
}

struct FolderCardView: View {
    let title: String
    let games: [GameScheme]
    var isFocused: Bool = false
    var delay: Double = 0
    let action: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Folder Shape with Grid
                ZStack {
                    // Custom Shape Background
                    FolderShape()
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            FolderShape()
                                .stroke(Color.white, lineWidth: isFocused ? 3 : 2)
                                .opacity(isFocused ? 1.0 : 0.5)
                        )
                    
                    // Games Grid (pushed down slightly to avoid tab)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(games.prefix(4)) { game in
                            if let icon = game.iconData, let uiImage = UIImage(data: icon) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 30) // Adjusted mini height
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Color.gray.opacity(0.5)
                                    .frame(height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(.top, 18) // Push content away from top tab
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .aspectRatio(1.0, contentMode: .fit)
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .scaleEffect(isVisible ? 1.0 : 0.001) // Pop-in scale
                .opacity(isVisible ? 1.0 : 0.0) // Pop-in opacity
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFocused)
                
                // Title below folder
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isFocused ? .yellow : .white)
                    .padding(.leading, 4)
                    .padding(.top, 4)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if delay > 0 {
                isVisible = false
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
    }
}

// Shapes
struct FolderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Dynamic Parameters
        let width = rect.width
        let height = rect.height
        let cornerRadius: CGFloat = 10
        let tabHeight: CGFloat = height * 0.15
        let tabWidth: CGFloat = width * 0.4
        
        // Start top-left of Tab
        path.move(to: CGPoint(x: 0, y: tabHeight))
        


        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        
        path.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0), control: CGPoint(x: 0, y: 0))
        

        path.addLine(to: CGPoint(x: tabWidth - cornerRadius, y: 0))
        
  
        path.addQuadCurve(to: CGPoint(x: tabWidth + cornerRadius, y: tabHeight), control: CGPoint(x: tabWidth + cornerRadius, y: 0))
        
     
        path.addLine(to: CGPoint(x: width - cornerRadius, y: tabHeight))
        
    
        path.addQuadCurve(to: CGPoint(x: width, y: tabHeight + cornerRadius), control: CGPoint(x: width, y: tabHeight))
        

        path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
        

        path.addQuadCurve(to: CGPoint(x: width - cornerRadius, y: height), control: CGPoint(x: width, y: height))
        
  
        path.addLine(to: CGPoint(x: cornerRadius, y: height))
        

        path.addQuadCurve(to: CGPoint(x: 0, y: height - cornerRadius), control: CGPoint(x: 0, y: height))
   
        path.closeSubpath()
        
        return path
    }
}

// Data Models

struct GameScheme: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID().uuidString
    
    var titleName: String
    var titleId: String
    var developer: String
    var version: String
    var iconData: Data?
    
    static func pullFromURL(_ url: URL, otherURL: @escaping () -> Void) -> [GameScheme] {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            
            // Based on user snippet: components.host == "melonx"
            if components.host == "melonx" {
                if let text = components.queryItems?.first(where: { $0.name == "games" })?.value, let data = GameScheme.base64URLDecode(text) {
                    
                    if let decoded = try? JSONDecoder().decode([GameScheme].self, from: data) {
                        return decoded
                    }
                }
            }
        }
        
        otherURL()
        return []
    }
    
    private static func base64URLDecode(_ text: String) -> Data? {
        var base64 = text
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 = base64.appending("=")
        }
        return Data(base64Encoded: base64)
    }
}


