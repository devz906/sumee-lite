import SwiftUI

enum MenuPage {
    case main
    case loadState
    case skinsManager
}

struct EmulatorMenuView: View {
    @Binding var isVisible: Bool
    @Binding var selectedIndex: Int
    @Binding var showLoadStateSheet: Bool // Deprecated, kept for compatibility if needed, but we'll use internal nav
    
    // New Props for Load State
    @Binding var activePage: MenuPage
    @Binding var selectedLoadStateIndex: Int
    let saveStates: [URL]
    let onLoadState: (URL) -> Void
    // New Props for Actions
    let onDelete: (URL) -> Void
    let onRename: (URL) -> Void
    @Binding var showDeleteConfirmation: Bool
    @Binding var stateToDelete: URL?
    @Binding var isSaving: Bool // New binding for animation
    @Binding var showSaveSuccess: Bool // Binding for save animation
    @State private var triggerSkinImport = false // Trigger for Skin Import
    
    let rom: ROMItem
    let onResume: () -> Void
    let onSave: () -> Void
    let onExit: () -> Void
    
    // Header props
    let isControllerConnected: Bool
    let controllerName: String
    
    @Binding var showControllerOptions: Bool
    
    // WebApp Mode
    var isWebApp: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width
            
            ZStack(alignment: .top) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    onResume()
                }
            
            // Header View
            HeaderView(
                isShowingPhotos: false,
                isShowingGameBoy: false,
                isShowingMusic: false,
                isShowingSettings: false,
                isEditing: false,
                currentPage: 0,
                isControllerConnected: isControllerConnected,
                controllerName: controllerName,
                customTitle: activePage == .main ? rom.displayName : "Load State",
                showContent: isVisible
            )
            .padding(.top, 20)
            .zIndex(101)
            
            // Content Container
            ZStack {
                // Main Menu
                landscapeMenuContent
                    .scaleEffect(activePage == .main ? 1.0 : 0.9)
                    .offset(y: activePage == .main ? (isPortrait ? -60 : 0) : 20)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: activePage)
                
                // Load State Submenu
                loadStateSubmenuContent(isPortrait: isPortrait)
                    .offset(x: 0) // Centered
                    .opacity(activePage == .loadState ? 1.0 : 0.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: activePage)
                
                // Skins Manager Submenu
                skinsManagerContent(isPortrait: isPortrait)
                    .offset(x: 0) // Centered
                    .opacity(activePage == .skinsManager ? 1.0 : 0.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: activePage)
            }
            .padding(.top, isPortrait ? 100 : -10)
            .zIndex(100)
            
   
            VStack {
                Spacer()
                if !isPortrait {
                    HStack {
                
                        if activePage == .loadState && !saveStates.isEmpty {
                            ControlCard(actions: [
                                ControlAction(icon: "y.circle", label: "Rename"),
                                ControlAction(icon: "x.circle", label: "Delete")
                            ])
                        }
                        
                        Spacer()
                        
                        // Right Side Controls
                        if activePage == .main {
                            ControlCard(actions: [
                                ControlAction(icon: "a.circle", label: "Select"),
                                ControlAction(icon: "b.circle", label: "Resume")
                            ])
                        
                        } else if activePage == .loadState {
                            ControlCard(actions: [
                                ControlAction(icon: "a.circle", label: "Load"),
                                ControlAction(icon: "b.circle", label: "Back")
                            ])
                        } else if activePage == .skinsManager {
                             ControlCard(actions: [
                                ControlAction(icon: "b.circle", label: "Back")
                            ])
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10) // Reduced padding to move lower
                }
            }
            .zIndex(102)
            .opacity(isVisible ? 1 : 0) // Fade out with menu
            .offset(y: isVisible ? 0 : 20) // Slide down with menu
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
            .transition(.opacity)
            
      
            if showDeleteConfirmation {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Text("Delete Save State?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(stateToDelete?.lastPathComponent ?? "")
                            .font(.body)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 40) {
                            VStack {
                                Image(systemName: "a.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                                Text("Delete")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            
                            VStack {
                                Image(systemName: "b.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                Text("Cancel")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                            .shadow(radius: 20)
                    )
                }
                .zIndex(200)
                .transition(.opacity)
            }
        }

        }
        .sheet(isPresented: $showControllerOptions) {
            GamepadSettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowControllerOptions"))) { _ in
            showControllerOptions = true
        }
    }
    
    
    func loadStateSubmenuContent(isPortrait: Bool) -> some View {
        VStack {
            Spacer()
                .frame(height: 80)
            
            HStack {
                Spacer()
                
                VStack(spacing: 0) {
                 
                    MenuButton(
                        title: "Back",
                        icon: "chevron.left",
                        isSelected: selectedLoadStateIndex == 0,
                        action: {
                            withAnimation { activePage = .main }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    if saveStates.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No Save States")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(Array(saveStates.enumerated()), id: \.element) { index, url in
                                        // Files start at Index 1
                                        SaveStateRow(
                                            url: url,
                                            isSelected: selectedLoadStateIndex == (index + 1),
                                            action: { onLoadState(url) }
                                        )
                                        .id(index + 1)
                                        
                                        if index < saveStates.count - 1 {
                                            Divider()
                                                .background(Color.black.opacity(0.1))
                                                .padding(.leading, 20)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 180) // Reduced from 220 to fit screen
                            .onChange(of: selectedLoadStateIndex) { _, newIndex in
                                withAnimation {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .frame(width: isPortrait ? 320 : 350)
                .background(BubbleBackground(position: .center, cornerRadius: 24))
              
                
                Spacer()
            }
            .offset(x: isVisible ? 0 : -350)
            .opacity(isVisible ? 1 : 0)
            
            Spacer()
        }
    }
    
    func skinsManagerContent(isPortrait: Bool) -> some View {
        VStack {
            Spacer()
                .frame(height: 80)
            
            HStack {
                Spacer()
                
                VStack(spacing: 0) {
                   
                    HStack(spacing: 10) {
                        // Back Button
                        MenuButton(
                            title: "Back",
                            icon: "chevron.left",
                            isSelected: true,
                            action: {
                                withAnimation { activePage = .main }
                            }
                        )
                        
                        // Import Button
                        Button(action: {
                            triggerSkinImport = true
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // Embedded Skin Manager
                    GameSkinManagerView(
                        rom: rom, 
                        isEmbedded: true, 
                        isInputActive: activePage == .skinsManager,
                        isPortraitOverride: isPortrait,
                        onDismiss: {
                             withAnimation { activePage = .main }
                        },
                        triggerImport: $triggerSkinImport
                    )
                        .frame(height: 240)
                        .clipped()
                }
                .frame(width: isPortrait ? 320 : 400)
                .frame(width: isPortrait ? 320 : 400)
                .background(BubbleBackground(position: .center, cornerRadius: 24))
                // Removed conditional padding
                
                Spacer()
            }
            .offset(x: isVisible ? 0 : -350)
            .opacity(isVisible ? 1 : 0)
            
            Spacer()
        }
    }
    
    var landscapeMenuContent: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                // Resume
                LandscapeMenuButton(icon: "play.fill", isSelected: selectedIndex == 0, action: onResume)

                if !isWebApp {
                    // Save State
                    LandscapeMenuButton(
                        icon: showSaveSuccess ? "checkmark.circle.fill" : "square.and.arrow.down.fill",
                        isSelected: selectedIndex == 1,
                        customColor: showSaveSuccess ? .green : nil,
                        action: {
                            selectedIndex = 1
                            onSave()
                            withAnimation {
                                showSaveSuccess = true
                            }
                            // Reset after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showSaveSuccess = false
                                }
                            }
                        }
                    )

                    // Load State
                    LandscapeMenuButton(icon: "folder.fill", isSelected: selectedIndex == 2, action: {
                        selectedIndex = 2
                        withAnimation {
                            activePage = .loadState
                            selectedLoadStateIndex = 0
                        }
                    })

                    // Skins
                    LandscapeMenuButton(icon: "paintpalette.fill", isSelected: selectedIndex == 3, action: {
                        selectedIndex = 3
                        withAnimation {
                            activePage = .skinsManager
                        }
                    })

                    // Controller Options
                    LandscapeMenuButton(icon: "gamecontroller.fill", isSelected: selectedIndex == 4, action: {
                        selectedIndex = 4
                        showControllerOptions = true
                    })
                }

                // Exit
                LandscapeMenuButton(icon: "xmark.circle.fill", isSelected: selectedIndex == (isWebApp ? 1 : 5), isDestructive: true, action: {
                    selectedIndex = (isWebApp ? 1 : 5)
                    onExit()
                })
            }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            BubbleBackground(position: .center, cornerRadius: 50)
        )
        .padding(.bottom, 30)
    }
    .offset(y: isVisible ? 0 : 200)
    .opacity(isVisible ? 1 : 0)
}
    
    // menuBackground property replaced by direct usage of BubbleBackground
}

struct LandscapeMenuButton: View {
    let icon: String
  
    let isSelected: Bool
    var isDestructive: Bool = false
    var customColor: Color? = nil
    let action: () -> Void
    
   
    let iconColor = Color(red: 0.35, green: 0.38, blue: 0.42)
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                
                    .foregroundColor(customColor ?? (isSelected ? (isDestructive ? .red : .blue) : iconColor))
          
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
            }
            .frame(width: 44, height: 44)
            .scaleEffect(isSelected ? 1.2 : 1.0)
            .offset(y: isSelected ? -10 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected) // Slightly bouncier spring
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SaveStateRow: View {
    let url: URL
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Text(url.creationDate?.formatted() ?? "Unknown Date")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(isSelected ? .white : Color(red: 0.2, green: 0.2, blue: 0.2))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .contentShape(Rectangle())
        }
    }
}
