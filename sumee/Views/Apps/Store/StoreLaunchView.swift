import SwiftUI
import Combine

struct StoreLaunchView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: HomeViewModel
    
    @State private var animationState: LaunchState = .initial
    @State private var showContent = false
    
    enum LaunchState {
        case initial
        case expanding
        case splash
    }
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Conditional content based on what is being launched
            if showContent {
                StoreView(onDismiss: {
                    startExitSequence()
                }, viewModel: viewModel)
                .transition(.opacity)
            } else {
                // Splash Screen Content
                VStack {
                    Spacer()
                    VStack {
                        Image(systemName: "plus.square.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 0)
                        
                        Text("System Add ons")
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
        .onAppear {
            startLaunchSequence()
        }
        .onReceive(GameControllerManager.shared.$buttonBPressed) { pressed in

        
            if pressed && !showContent {
                startExitSequence()
            }
        }
    }
    
    private func startLaunchSequence() {
        if !MusicPlayerManager.shared.isPlaying {
            AudioManager.shared.fadeOutBackgroundMusic(duration: 0.5)
            AudioManager.shared.playStartGameSound()
            
            // Start Store Music
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.playStoreMusic()
            }
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animationState = .expanding
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                animationState = .splash
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.5)) {
                showContent = true
            }
        }
    }

    private func playStoreMusic() {
        AudioManager.shared.playStoreMusic()
    }
    
    private func startExitSequence() {
         AudioManager.shared.playStopGameSound()
         // Restore background music immediately (don't wait for SFX to finish)
         AudioManager.shared.fadeInBackgroundMusic(duration: 0.8)
         dismissAndAnimate()
    }
    
    private func dismissAndAnimate() {
        withAnimation(.easeOut(duration: 0.3)) {
            showContent = false
            animationState = .splash
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animationState = .initial
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isPresented = false
        }
    }
}

//Store View

struct StoreView: View {
    var onDismiss: () -> Void
    @ObservedObject var viewModel: HomeViewModel
    
    @StateObject private var storeViewModel = StoreViewModel()
    @ObservedObject private var gameController = GameControllerManager.shared
    @ObservedObject private var profileManager = ProfileManager.shared
    
    @State private var isRestarting = false

    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            
            ZStack { 
                if isPortrait {
                    StoreVerticalLayout(
                        storeViewModel: storeViewModel, 
                        profileManager: profileManager, 
                        onDismiss: onDismiss
                    )
                    .onAppear {
                        storeViewModel.homeViewModel = viewModel
                    }
                } else {
                    StoreHorizontalLayout(
                        storeViewModel: storeViewModel, 
                        profileManager: profileManager,
                        homeViewModel: viewModel,
                        onDismiss: onDismiss
                    )
                }

                
                // Global Detail Overlay
                if storeViewModel.isShowingDetail, let item = storeViewModel.selectedDetailItem {
                    StoreDetailView(
                        item: item,
                        isInstalled: storeViewModel.isItemInstalled(item),
                        onInstall: {
                            storeViewModel.installCurrentItem()
                        },
                        onBack: {
                            storeViewModel.closeDetail()
                        },
                        vm: storeViewModel
                    )
                    .zIndex(1000)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                //Restart Overlay
                if isRestarting {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Restarting to Apply...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .zIndex(2000)
                    .transition(.opacity)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ForceRestartApp"))) { _ in
            withAnimation { isRestarting = true }
             DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                 exit(0)
             }
        }
    }
}

// Extracted Store Content
struct StoreMainContent: View {
    @ObservedObject var storeViewModel: StoreViewModel
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var homeViewModel: HomeViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            VStack(spacing: 0) {
                // Header (Reduced since we have top tab bar)
                HStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("Add ons")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.7))
                }
                .padding(.vertical, 12)
                
                // Navigation Items
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(0..<storeViewModel.sidebarMenuItems.count, id: \.self) { index in
                                let item = storeViewModel.sidebarMenuItems[index]
                                SidebarItem(
                                    title: item.title,
                                    icon: item.icon,
                                    isSelected: storeViewModel.selectedSidebarIndex == index,
                                    isFocused: storeViewModel.isSidebarFocused && storeViewModel.selectedSidebarIndex == index,
                                    profileImage: item.title == "My Page" ? profileManager.profileImage : nil
                                )
                                .id(index)
                                .onTapGesture {
                                    storeViewModel.selectedSidebarIndex = index
                                    storeViewModel.isSidebarFocused = true
                                }
                            }
                        }
                    }
                    .onChange(of: storeViewModel.selectedSidebarIndex) { newIndex in
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
            .frame(width: 90)
            .background(StoreSidebarBackground())
            .padding(.vertical, 16)
            .padding(.leading, 16)
            .zIndex(1)
            // Overlay removed
            .blur(radius: storeViewModel.isShowingDetail ? 10 : 0)
            
             //Right Content Area
            ZStack {
                 VStack(spacing: 0) {
                     // Category Header
                     HStack(alignment: .center) {
                        HStack(spacing: 12) {
                            Text(storeViewModel.currentCategoryTitle)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .blue : .blue.opacity(0.8))
                                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
                            
                            if storeViewModel.currentCategoryTitle == "Themes" {
                                  Text("NEW")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.red))
                            }
                        }
                        .padding(.leading, 40)
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    
                    // Grid
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                                Section(header: Group {
                                    if storeViewModel.currentCategoryTitle == "Home" {
                                        StoreCarouselView(items: storeViewModel.carouselItems, isFocused: storeViewModel.isCarouselFocused)
                                            .padding(.bottom, 20)
                                            .padding(.top, 10)
                                            .id("ScrollTop")
                                    } else {
                                        Color.clear.frame(height: 1).id("ScrollTop")
                                    }
                                }) {
                                    ForEach(0..<storeViewModel.currentItems.count, id: \.self) { index in
                                        let item = storeViewModel.currentItems[index]
                                        StoreGridItem(
                                            item: item,
                                            isFocused: !storeViewModel.isSidebarFocused && !storeViewModel.isCarouselFocused && storeViewModel.selectedContentIndex == index,
                                            isInstalled: storeViewModel.isItemInstalled(item)
                                        )
                                        .id(index)
                                        .onTapGesture {
                                            storeViewModel.isSidebarFocused = false
                                            storeViewModel.selectedContentIndex = index
                                            storeViewModel.handleSelect()
                                        }
                                        .zIndex(!storeViewModel.isSidebarFocused && storeViewModel.selectedContentIndex == index ? 100 : 1)
                                    }
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 10)
                            .padding(.bottom, 60)
                        } // End ScrollView
                        // React to Content Selection (Grid Navigation)
                        .onChange(of: storeViewModel.selectedContentIndex) { newIndex in
                            if !storeViewModel.isSidebarFocused && !storeViewModel.isCarouselFocused && !storeViewModel.isShowingDetail {
                                withAnimation {
                                    // Always center the selected item in the grid to ensure visibility
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                        // React to Sidebar Focus
                        .onChange(of: storeViewModel.isSidebarFocused) { isFocused in
                            withAnimation {
                                if isFocused {
                                    proxy.scrollTo("ScrollTop", anchor: .top)
                                } else if !storeViewModel.isCarouselFocused {
                                    // Leaving sidebar to grid -> ensure content visible
                                    proxy.scrollTo(storeViewModel.selectedContentIndex, anchor: .center)
                                }
                            }
                        }
                        // React to Carousel Focus
                        .onChange(of: storeViewModel.isCarouselFocused) { isFocused in
                            withAnimation {
                                if isFocused {
                                    proxy.scrollTo("ScrollTop", anchor: .top)
                                } else if !storeViewModel.isSidebarFocused {
                                    // Leaving carousel to grid -> ensure content visible
                                    proxy.scrollTo(storeViewModel.selectedContentIndex, anchor: .center)
                                }
                            }
                        }
                    } // End ScrollViewReader
            }
         
            .blur(radius: storeViewModel.isShowingDetail ? 20 : 0)
            .scaleEffect(storeViewModel.isShowingDetail ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.3), value: storeViewModel.isShowingDetail)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// Vertical Layout (Mobile Style)
struct StoreVerticalLayout: View {
    @ObservedObject var storeViewModel: StoreViewModel
    @ObservedObject var profileManager: ProfileManager
    var onDismiss: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hello!")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray)
                    
                    Text("Let's Explore")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                        
                    HStack(spacing: 12) {
                        // Store/Category Pill
                        Text(storeViewModel.currentCategoryTitle.isEmpty ? "Home" : storeViewModel.currentCategoryTitle)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(
                                storeViewModel.selectedTab == .store 
                                ? (colorScheme == .dark ? .black : .white) 
                                : .gray.opacity(0.6)
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        storeViewModel.selectedTab == .store 
                                        ? (colorScheme == .dark ? Color.white : Color.black.opacity(0.8))
                                        : Color.gray.opacity(0.1)
                                    )
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    storeViewModel.selectedTab = .store
                                }
                            }
                        
                        // Community Pill
                        Text("Community")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(
                                storeViewModel.selectedTab == .community 
                                ? (colorScheme == .dark ? .black : .white) 
                                : .gray.opacity(0.6)
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        storeViewModel.selectedTab == .community 
                                        ? (colorScheme == .dark ? Color.white : Color.black.opacity(0.8))
                                        : Color.gray.opacity(0.1)
                                    )
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    storeViewModel.selectedTab = .community
                                }
                            }
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    if let image = profileManager.profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            // Horizontal Categories (Tabs)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 30) {
                    if !storeViewModel.sidebarMenuItems.isEmpty {
                        ForEach(storeViewModel.sidebarMenuItems.indices, id: \.self) { index in
                            let item = storeViewModel.sidebarMenuItems[index]
                            let isActive = storeViewModel.selectedTab == .store && storeViewModel.selectedSidebarIndex == index
                            
                            VStack(spacing: 8) {
                                Text(item.title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(isActive ? (colorScheme == .dark ? .white : .black) : .gray.opacity(0.6))
                                
                                if isActive {
                                    Capsule().fill(Color.blue).frame(width: 20, height: 3)
                                } else {
                                    Capsule().fill(Color.clear).frame(width: 20, height: 3)
                                }
                            }
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    storeViewModel.selectedTab = .store
                                    storeViewModel.selectedSidebarIndex = index
                                    storeViewModel.selectedContentIndex = 0
                                }
                            }
                        }
                    }
                    
                    // Credits Item (Manual Entry)
                    VStack(spacing: 8) {
                        Text("Credits")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(storeViewModel.selectedTab == .credits ? (colorScheme == .dark ? .white : .black) : .gray.opacity(0.6))
                        
                        if storeViewModel.selectedTab == .credits {
                            Capsule().fill(Color.blue).frame(width: 20, height: 3)
                        } else {
                            Capsule().fill(Color.clear).frame(width: 20, height: 3)
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            storeViewModel.selectedTab = .credits
                            storeViewModel.isSidebarFocused = false // Ensure focus logic relies on Tab
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 16)
            
            // Content
            Group {
                if storeViewModel.selectedTab == .community {
                    // Community Content
                    StoreCommunityView(storeViewModel: storeViewModel)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                } else {
                    // Store & Credits Content (Wrapped in ScrollView)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            if storeViewModel.selectedTab == .credits {
                                StoreCreditsView(storeViewModel: storeViewModel)
                                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                            } else {
                                // Carousel (Only on Home)
                                if storeViewModel.currentCategoryTitle == "Home" {
                                    StoreCarouselView(items: storeViewModel.carouselItems, isFocused: false)
                                        .frame(height: 180) 
                                        .padding(.horizontal, 24)
                                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                                }
                                
                                // Grid
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 20) {
                                    ForEach(0..<storeViewModel.currentItems.count, id: \.self) { index in
                                         StoreGridItem(
                                            item: storeViewModel.currentItems[index], 
                                            isFocused: false, 
                                            isInstalled: storeViewModel.isItemInstalled(storeViewModel.currentItems[index])
                                         )
                                         .onTapGesture {
                                             storeViewModel.isSidebarFocused = false
                                             storeViewModel.isCarouselFocused = false
                                             storeViewModel.selectedContentIndex = index
                                             storeViewModel.handleSelect()
                                         }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 100)
                                .id(storeViewModel.selectedSidebarIndex) // Force refresh ID
                                .transition(.opacity.animation(.easeInOut(duration: 0.2))) // Fade transition
                            }
                        }
                        .padding(.top, 10)
                    }
                }
            }
        }
        .background(
            PlaystationThemedBackground()
        )
        .onAppear {
             storeViewModel.gridColumns = 2
        }
        .overlay(
            VStack {
                Spacer()
                ControlCard(actions: [
                    ControlAction(icon: "b.circle", label: "Back", action: { onDismiss() })
                ], position: .center, isHorizontal: true, scale: 1.25)
                .padding(.bottom, 20)
            }
        )
    }
}

//  Horizontal Layout (Console Style)
struct StoreHorizontalLayout: View {
    @ObservedObject var storeViewModel: StoreViewModel
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var gameController = GameControllerManager.shared
    @ObservedObject var homeViewModel: HomeViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack { // Global Background
            PlaystationThemedBackground()
            
            VStack(spacing: 0) {
                //  - Top Tab Bar
                HStack(spacing: 12) {
                    Spacer()
                    
                    // Left Tab Trigger Hint
                    HStack(spacing: 4) {
                        Text("L1")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().stroke(Color.black.opacity(0.3), lineWidth: 1))
                            .foregroundColor(.black.opacity(0.6))
                    }
                    
                    // Tabs
                    ForEach(StoreViewModel.StoreTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue)
                            .font(.system(size: 20, weight: storeViewModel.selectedTab == tab ? .heavy : .medium, design: .rounded))
                            .foregroundColor(storeViewModel.selectedTab == tab ? .blue : .gray.opacity(0.7))
                            .scaleEffect(storeViewModel.selectedTab == tab ? 1.05 : 1.0)
                            .animation(.spring(), value: storeViewModel.selectedTab)
                            .onTapGesture {
                                withAnimation {
                                    storeViewModel.selectedTab = tab
                                    AudioManager.shared.playSelectSound()
                                }
                            }
                    }
                    
                    // Right Tab Trigger Hint
                    HStack(spacing: 4) {
                        Text("R1")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().stroke(Color.black.opacity(0.3), lineWidth: 1))
                            .foregroundColor(.black.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Status Header
                    StoreStatusHeader()
                        .padding(.trailing, 20)
                }
                .padding(.vertical, 8)
                .background(Color.clear) // Transparent header
                .zIndex(100)
                
                // Main Content Area
                ZStack {
                    if storeViewModel.selectedTab == .community {
                        // Community View
                        StoreCommunityView(storeViewModel: storeViewModel)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else if storeViewModel.selectedTab == .credits {
                         StoreCreditsView(storeViewModel: storeViewModel)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        // Store Content (Existing Layout)
                        StoreMainContent(storeViewModel: storeViewModel, profileManager: profileManager, homeViewModel: homeViewModel)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            storeViewModel.homeViewModel = homeViewModel // Inject dependency
            gameController.disableHomeNavigation = true
            storeViewModel.gridColumns = 4
        }
        .onDisappear {
            gameController.disableHomeNavigation = false
        }
        // Input Handling
        // Input Handling
        .onReceive(gameController.$dpadUp.dropFirst()) { pressed in 
            if pressed { storeViewModel.handleNavigation(.up) } 
        }
        .onReceive(gameController.$dpadDown.dropFirst()) { pressed in 
            if pressed { storeViewModel.handleNavigation(.down) } 
        }
        .onReceive(gameController.$dpadLeft.dropFirst()) { pressed in 
            if pressed { storeViewModel.handleNavigation(.left) } 
        }
        .onReceive(gameController.$dpadRight.dropFirst()) { pressed in 
            if pressed { storeViewModel.handleNavigation(.right) } 
        }
        .onReceive(gameController.$buttonAPressed.dropFirst()) { pressed in 
            if pressed { 
                print(" StoreView: 'A' Pressed. Invoking handleSelect.")
                storeViewModel.homeViewModel = homeViewModel
                storeViewModel.handleSelect() 
            } 
        }
        .onReceive(gameController.$buttonBPressed.dropFirst()) { pressed in 
            if pressed { 
                // Use ViewModel to decide (incorporates debounce & state check)
                if storeViewModel.handleBack() {
                    onDismiss()
                }
            } 
        }
        // Tab Switching Inputs
        .onReceive(gameController.$buttonL1Pressed.dropFirst()) { pressed in if pressed { storeViewModel.prevTab() } }
        .onReceive(gameController.$buttonR1Pressed.dropFirst()) { pressed in if pressed { storeViewModel.nextTab() } }
        
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ControlCard(actions: [
                        ControlAction(icon: "a.circle", label: "Select"),
                        ControlAction(icon: "b.circle", label: "Back", action: { onDismiss() })
                    ], position: .right)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
        )
    }
}
