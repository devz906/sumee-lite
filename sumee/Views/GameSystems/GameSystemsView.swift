import SwiftUI

struct GameSystemsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var homeViewModel: HomeViewModel // Replaces "friends"
    @StateObject var viewModel = GameSystemsViewModel()
    @ObservedObject var gameController = GameControllerManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var musicPlayer = MusicPlayerManager.shared
    var onRequestFilePicker: () -> Void
    var onRequestMusicPlayer: (() -> Void)? // Callback to open Music Player
    var onEmulatorStarted: ((Bool) -> Void)? // Callback to toggle header visibility
    
    @Namespace var animationNamespace // For Hero Animations
    
    @AppStorage("gameSystemViewMode") var savedViewMode: String = "grid"
    @AppStorage("disableStartAnimation") var disableStartAnimation: Bool = false
    @AppStorage("enableCarouselTransparency") var enableCarouselTransparency: Bool = false
    @State var viewMode: ViewMode = ViewMode(rawValue: UserDefaults.standard.string(forKey: "gameSystemViewMode") ?? "grid") ?? .grid
    @State var selectedActionIndex: Int = -1 // -1: Game Card, 0..2: Action Buttons
    
    // Save Manager State
    @State var showSaveManager = false
    @State var selectedROMForSaves: ROMItem?
    @State var selectedROMForSkins: ROMItem? // New State for Skins Manager
    @State var isInputLocked = false // Lock inputs during modal transitions
    
    // Options / Delete State
    @State var showOptionsSheet = false
    @State var romForOptions: ROMItem?
    @State var showDeleteConfirmation = false
    @State var romToDelete: ROMItem?
    @State var romToEdit: ROMItem?
    
    @State var showAddSourceMenu = false
    @State var showReorderSheet = false
    @State var showSettings = false // For Lite Mode Settings Access
    

    @State var showViewModeMenu = false // Custom View Mode Menu State
    @State var showViewModeSubmenu = false // Submenu for View Options
    @State var selectedViewModeIndex: Int = 0 // For Controller Navigation in Menu
    @State var selectedSubmenuIndex: Int = 0 // For Controller Navigation in Submenu
    
    @State var isPortrait: Bool = false // Track orientation state
    @State var currentCols: Int = 6 // Track columns for navigation
    
    // Gesture State for Smooth Dragging
    @State var dragOffset: CGFloat = 0 // Tracks realtime finger movement
    
    // Bottom Bar Static Carousel State
    @State var bottomBarStartIndex: Int = 0
    var bottomBarCapacity: Int { currentCols == 4 ? 5 : 9 }

    
    let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)
    
    var body: some View {
        ZStack {
            applyInputHandlers(to: internalContent)
            
            if showSettings {
                SettingsInlineView(isPresented: $showSettings, viewModel: homeViewModel)
                    .zIndex(500)
            }
        }
            .sheet(isPresented: $showAddSourceMenu) {
                GameAddSourceView(
                    onAddFile: {
                        showAddSourceMenu = false
                        // Slight delay to allow sheet to close before file picker (iOS limitation)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onRequestFilePicker()
                        }
                    },
                    onAddManicEmu: { name, url in
                        // Logic moved to GameAddSourceView handling, we just execute here
                        showAddSourceMenu = false
                        // Use helper directly
                        addManicEmuGame(name: name, url: url)
                    }
                )
            }

            .confirmationDialog("Delete Game?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    confirmDelete()
                }
                Button("Cancel", role: .cancel) {
                    romToDelete = nil
                }
            } message: {
                if let rom = romToDelete {
                    Text("Are you sure you want to delete '\(rom.displayName)'? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to delete this game?")
                }
            }
            // Edit Sheet
            .sheet(item: $romToEdit) { rom in
                GameDetailEditorView(rom: rom, onSave: { newName, newLaunchURL, newImage in
                    handleEditSave(rom: rom, newName: newName, newLaunchURL: newLaunchURL, newImage: newImage)
                    romToEdit = nil
                }, onCancel: {
                    romToEdit = nil
                })
            }
            .sheet(isPresented: $showReorderSheet) {
                ConsoleReorderView(isPresented: $showReorderSheet, viewModel: viewModel)
            }
    }
}
