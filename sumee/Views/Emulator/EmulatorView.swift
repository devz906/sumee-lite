import SwiftUI
import Combine

struct EmulatorView: View {
    @Environment(\.dismiss) var dismiss
    let rom: ROMItem
    var launchMode: GameLaunchMode = .normal
    var onDismiss: (() -> Void)?
    var shouldRestoreHomeNavigation: Bool = true // Default to true for HomeView
    @State private var romData: Data?
    @State private var isLoadingROM = true
    @ObservedObject private var gameController = GameControllerManager.shared
    
    init(rom: ROMItem, launchMode: GameLaunchMode = .normal, onDismiss: (() -> Void)? = nil, shouldRestoreHomeNavigation: Bool = true) {
        self.rom = rom
        self.launchMode = launchMode
        self.onDismiss = onDismiss
        self.shouldRestoreHomeNavigation = shouldRestoreHomeNavigation
        
        // For consoles that support native path loading (no data read required),

        let isNativePathConsole = (rom.console == .playstation || rom.console == .nintendoDS || 
                                   rom.console == .gameboy || rom.console == .gameboyColor || rom.console == .gameboyAdvance)
        
        _isLoadingROM = State(initialValue: !isNativePathConsole)
    }
    
    var body: some View {
        ZStack {
            if rom.console == .web, let urlString = rom.externalLaunchURL, let url = URL(string: urlString) {
                // Launch Web ROM Player
                WebROMPlayerView(url: url) {
                    if let onDismiss = onDismiss {
                         onDismiss()
                    } else {
                         dismiss()
                    }
                }
            } else if !isLoadingROM && (romData != nil || rom.console == .playstation || rom.console == .nintendoDS || rom.console == .gameboy || rom.console == .gameboyColor || rom.console == .gameboyAdvance) {
                WebEmulatorView(romData: romData, rom: rom, launchMode: launchMode, onDismiss: onDismiss)
                    .onAppear {
                        print(" WebEmulatorView appeared. Data size: \(romData?.count ?? 0) bytes")
                    }
            } else if isLoadingROM {
                // Loading state
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.green)
                        
                        Text("Loading ROM...")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(rom.displayName)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else {
                // Error state
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text("Failed to load ROM")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        
                        Button("Close") {
                            if let onDismiss = onDismiss {
                                onDismiss()
                            } else {
                                dismiss()
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .onAppear {
            // AppStatusManager.shared.show("Preparing ROM: \(rom.displayName)", icon: "gamecontroller")
            
            // Save as last played
            ROMStorageManager.shared.setLastPlayedROM(rom)
            
            // Configurar audio
            // Check if Music Player is active
            if MusicPlayerManager.shared.isPlaying {
                print("EmulatorView: Music Player active, NOT pausing background music (already paused by player)")
            } else {
                AudioManager.shared.pauseBackgroundMusic()
            }
            
            // Deshabilitar navegación del menú y sonidos (esto evita que los inputs del emulador afecten el menú)
            gameController.disableHomeNavigation = true
            gameController.disableMenuSounds = true
            
            loadROM()
        }
        .onDisappear {
            print(" EmulatorView disappeared for ROM: \(rom.displayName)")
            print("   - disableHomeNavigation: \(gameController.disableHomeNavigation) -> false")
            print("   - disableMenuSounds: \(gameController.disableMenuSounds) -> false")
            
            // Reanudar música de fondo ONLY if Music Player is NOT active
            if MusicPlayerManager.shared.isPlaying {
                print(" EmulatorView: Music Player active, NOT resuming background music")
            } else {
                AudioManager.shared.resumeBackgroundMusic()
            }
            
            // Re-habilitar navegación del menú y sonidos
            if shouldRestoreHomeNavigation {
                gameController.disableHomeNavigation = false
            }
            gameController.disableMenuSounds = false
            gameController.showMenu = false // Ensure menu state is cleared
            
            print(" EmulatorView: States restored")
        }
    }
    
    func loadROM() {
        let storage = ROMStorageManager.shared
        let fileURL = storage.getROMFileURL(for: rom)
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            AppStatusManager.shared.show("ROM not found", icon: "exclamationmark.triangle")
            isLoadingROM = false
            return
        }
        
        // For large games (PSX, DS) OR games with native path support (GBA, GB, GBC),
       
        if rom.console == .playstation || rom.console == .nintendoDS || 
           rom.console == .gameboy || rom.console == .gameboyColor || rom.console == .gameboyAdvance {
            print("💾 [EmulatorView] Skipping memory load for \(rom.console.rawValue) (Native Path Load)")
            DispatchQueue.main.async {
                self.romData = nil
                self.isLoadingROM = false
            }
            return
        }

        // Load ROM data
        do {
            let data = try Data(contentsOf: fileURL)
            // AppStatusManager.shared.show("ROM loaded", icon: "checkmark.circle")
            DispatchQueue.main.async {
                self.romData = data
                self.isLoadingROM = false
            }
        } catch {
            AppStatusManager.shared.show("Failed to load ROM", icon: "xmark.octagon")
            isLoadingROM = false
        }
    }
}

struct EmulatorView_Previews: PreviewProvider {
    static var previews: some View {
        EmulatorView(rom: ROMItem(fileName: "test.gb", console: .gameboy, fileSize: 32768))
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
