import AVFoundation
import SwiftUI
import Combine

// Settings-aware Audio Manager

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    private let settings = SettingsManager.shared
    private let audioQueue = DispatchQueue(label: "com.sumee.audio", qos: .userInitiated)
    
    private var audioPlayer: AVAudioPlayer?
    private var soundEffectPlayer: AVAudioPlayer?
    private var swipeEffectPlayer: AVAudioPlayer?
    private var selectEffectPlayer: AVAudioPlayer?
    private var startGamePlayer: AVAudioPlayer? // Retain the player
    @Published var isPlaying = false
    
    // Notification State
    struct TrackInfo {
        let title: String
        let artist: String
        let artwork: UIImage?
    }
    
    @Published var currentTrackInfo: TrackInfo?
    @Published var showTrackNotification = false
    private var notificationTimer: Timer?
    
    private init() {
        setupAudioSession()
        preloadNavigationSound()
    }
    
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    // Helper to get dynamic background music URL
    private func getBackgroundMusicURL() -> URL? {
        var filename = settings.activeTheme.musicTrack ?? "music_background"
        
        // Custom Theme Override
        if settings.activeTheme.id == "custom_photo", let customTrack = settings.customThemeMusic {
             filename = customTrack
        }
        
        // Check Bundle first
        if let url = Bundle.main.url(forResource: filename, withExtension: "mp3") { return url }
        if let url = Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Music") { return url }
        if let url = Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Resources/Music") { return url }
        if let url = Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Resources/Audio/Music") { return url }
        if let url = Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Audio/Music") { return url }
        
        // Check Documents/Music (For User Added Songs)
        let fileManager = FileManager.default
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
             let musicDir = documentsPath.appendingPathComponent("Music")
             let extensions = ["mp3", "m4a", "wav", "aac"]
             
             for ext in extensions {
                 let fileUrl = musicDir.appendingPathComponent("\(filename).\(ext)")
                 if fileManager.fileExists(atPath: fileUrl.path) {
                     return fileUrl
                 }
             }
        }
        
        return nil
    }
    
    // Música de fondo general
    func playBackgroundMusic() {
        // Check if Music Player is active
        if MusicPlayerManager.shared.isPlaying {
            print("🎵 Music Player active, skipping background music")
            return
        }
        
        guard settings.enableBackgroundMusic, let url = getBackgroundMusicURL() else {
            print("Background music file not found or disabled")
            return
        }
        
        // Check if already playing this file
        if isPlaying, let currentUrl = audioPlayer?.url {
            print("🎵 Checking current URL: \(currentUrl.lastPathComponent) vs \(url.lastPathComponent)")
            if currentUrl == url && audioPlayer?.isPlaying == true {
                print("🎵 Background music already playing, skipping restart")
                return
            }
        } else {
            print("🎵 Not playing or URL mismatch. isPlaying: \(isPlaying), currentUrl: \(String(describing: audioPlayer?.url))")
        }
        
        // Fade out música actual
        fadeOutCurrentMusic(duration: 0.5) {
            // Fade in música de fondo
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.volume = 0.0
                self.audioPlayer?.numberOfLoops = -1
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                
                // Fade in gradual
                self.fadeInMusic(to: self.settings.backgroundVolume, duration: 0.8)
                self.isPlaying = true
                print("🎵 Background music started with fade in")
                
                // Show notification with metadata
                Task {
                    let info = await self.extractMetadata(from: url, defaultArtist: "Sumee OST")
                    self.showNotification(for: info)
                }
            } catch {
                print("Failed to play background music: \(error.localizedDescription)")
            }
        }
    }
    
    // Legacy support for fadeInBackgroundMusic used by GameSystemsLaunchView
    func fadeInBackgroundMusic(duration: TimeInterval = 1.0, targetVolume: Float = 0.3) {
        restoreBackgroundMusic()
    }
    
    // Legacy support for stopBackgroundMusic
    func stopBackgroundMusic() {
        fadeOutCurrentMusic(duration: 0.5) {
            self.isPlaying = false
        }
    }
    
    // Pause/Resume for Video Playback
    func pauseCurrentMusic() {
        if let player = audioPlayer, player.isPlaying {
             player.pause()
             isPlaying = false
        }
    }
    
    func resumeCurrentMusic() {
        if let player = audioPlayer, !player.isPlaying {
            player.play()
            isPlaying = true
        }
    }
    
    // Música para canvas (cuando abre sketch)
    func playDrawMusic() {
        // Check if Music Player is active
        if MusicPlayerManager.shared.isPlaying {
            print("🎵 Music Player active, skipping draw music")
            return
        }
        
        guard settings.enableBackgroundMusic, let url = Bundle.main.url(forResource: "music_draw", withExtension: "mp3") else {
            print("Draw music file not found")
            return
        }
        
        // Fade out música de fondo actual
        fadeOutCurrentMusic(duration: 0.5) {
            // Fade in música de canvas
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.volume = 0.0
                self.audioPlayer?.numberOfLoops = -1
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                
                // Fade in gradual
                self.fadeInMusic(to: self.settings.backgroundVolume, duration: 0.8)
                self.isPlaying = true
                print("🎵 Draw music started with fade in")
            } catch {
                print("Failed to play draw music: \(error.localizedDescription)")
            }
        }
    }

    // Música para MiBrowser
    func playBrowserMusic() {
        if MusicPlayerManager.shared.isPlaying { return }
        
        guard settings.enableBackgroundMusic else { return }

        // Try to find mibrowser.mp3
        // Searching in multiple likely locations including the user provided specific path
        var musicUrl: URL?
        if let url = Bundle.main.url(forResource: "mibrowser", withExtension: "mp3") { musicUrl = url }
        else if let url = Bundle.main.url(forResource: "mibrowser", withExtension: "mp3", subdirectory: "sumee/Resources/Audio/Music") { musicUrl = url }
        else if let url = Bundle.main.url(forResource: "mibrowser", withExtension: "mp3", subdirectory: "Resources/Audio/Music") { musicUrl = url }
        
        guard let url = musicUrl else {
            print("Browser music file 'mibrowser.mp3' not found")
            return
        }
        
        fadeOutCurrentMusic(duration: 0.5) {
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.volume = 0.0
                self.audioPlayer?.numberOfLoops = -1
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                
                self.fadeInMusic(to: self.settings.backgroundVolume, duration: 0.8)
                self.isPlaying = true
            } catch {
                print("Failed to play browser music: \(error.localizedDescription)")
            }
        }
    }
    
    // Restaurar música de fondo (después de salir del canvas)
    func restoreBackgroundMusic() {
        // Check if Music Player is active
        if MusicPlayerManager.shared.isPlaying {
            print("🎵 Music Player active, skipping restore background music")
            return
        }
        
        // Check if Emulator/Game is active (Gameplay Mode)
        // Check if Emulator/Game is active (Gameplay Mode OR In-Emulator Menu)
        if GameControllerManager.shared.isGameplayMode || GameControllerManager.shared.isEmulatorActive {
            print("🎮 Emulator Active, suppressing background music restoration")
            return
        }
        
        guard settings.enableBackgroundMusic, let url = getBackgroundMusicURL() else {
            print("Background music file not found or disabled")
            return
        }
        
        // Check if already playing this file
        if isPlaying, let currentUrl = audioPlayer?.url {
            if currentUrl == url && audioPlayer?.isPlaying == true {
                print("🎵 Background music already playing, skipping restore")
                return
            }
        }
        
        // Fade out música actual
        fadeOutCurrentMusic(duration: 0.5) {
            // Fade in música de fondo
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.volume = 0.0
                self.audioPlayer?.numberOfLoops = -1
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                
                // Fade in gradual
                self.fadeInMusic(to: self.settings.backgroundVolume, duration: 0.8)
                self.isPlaying = true
                print("🎵 Background music restored with fade in")
            } catch {
                print("Failed to restore background music: \(error.localizedDescription)")
            }
        }
    }
    
    // Fade out de la música actual
    private func fadeOutCurrentMusic(duration: TimeInterval, completion: @escaping () -> Void) {
        guard let player = audioPlayer, player.isPlaying else {
            completion()
            return
        }
        
        let startVolume = player.volume
        let fadeSteps = 20
        let stepDuration = duration / TimeInterval(fadeSteps)
        
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            let newVolume = startVolume * (1.0 - Float(currentStep) / Float(fadeSteps))
            player.volume = max(newVolume, 0.0)
            
            if currentStep >= fadeSteps {
                timer.invalidate()
                player.stop()
                completion()
            }
        }
    }
    
    // Fade in de nueva música
    private func fadeInMusic(to targetVolume: Float, duration: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        let fadeSteps = 20
        let stepDuration = duration / TimeInterval(fadeSteps)
        let volumeIncrement = targetVolume / Float(fadeSteps)
        
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            let newVolume = volumeIncrement * Float(currentStep)
            player.volume = min(newVolume, targetVolume)
            
            if currentStep >= fadeSteps {
                timer.invalidate()
            }
        }
    }
    // Música para Game Systems
    func playGameSystemsMusic() {
        guard settings.enableBackgroundMusic else { return }
        
        // Check if Music Player is active
        if MusicPlayerManager.shared.isPlaying {
            print("🎵 Music Player active, skipping Game Systems music")
            return
        }
        
        // Intentar encontrar el archivo con el nombre original (ya que Xcode lo busca ahí)
        let filename = "Nintendo 3DS - Internet Settings Theme (Pan!c Pop Remix) - Pan!c Pop - SoundLoadMate.com"
        let ext = "mp3"
        
        // Primero buscar en la raíz (donde Xcode espera que esté)
        var url = Bundle.main.url(forResource: filename, withExtension: ext)
        
        // Si no, buscar en Music (por si el usuario ya actualizó el proyecto)
        if url == nil {
            url = Bundle.main.url(forResource: "game_systems_bgm", withExtension: "mp3", subdirectory: "Music") ??
                  Bundle.main.url(forResource: "game_systems_bgm", withExtension: "mp3", subdirectory: "Resources/Audio/Music")
        }
        
        guard let musicURL = url else {
            print("Game Systems music file not found")
            return
        }
        
        // Fade out música actual
        fadeOutCurrentMusic(duration: 0.5) {
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: musicURL)
                self.audioPlayer?.volume = 0.0
                self.audioPlayer?.numberOfLoops = -1
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                
                // Fade in gradual
                self.fadeInMusic(to: self.settings.backgroundVolume, duration: 0.8)
                self.isPlaying = true
                print("🎵 Game Systems music started with fade in")
                
                // Show notification with metadata
                Task {
                    let info = await self.extractMetadata(from: musicURL, defaultArtist: "Unknown Artist")
                    self.showNotification(for: info)
                }
            } catch {
                print("Failed to play Game Systems music: \(error.localizedDescription)")
            }
        }
        }
    
    // Música para ProfileView
    func playProfileMusic() {
        guard settings.enableBackgroundMusic else { return }
        
        // Intentar encontrar el archivo music_profile.mp3
        guard let url = Bundle.main.url(forResource: "music_profile", withExtension: "mp3") ?? 
                        Bundle.main.url(forResource: "music_profile", withExtension: "mp3", subdirectory: "Resources/Music") ??
                        Bundle.main.url(forResource: "music_profile", withExtension: "mp3", subdirectory: "Resources/Audio/Music") ??
                        Bundle.main.url(forResource: "music_profile", withExtension: "mp3", subdirectory: "Music") else {
            print("Profile music file (music_profile.mp3) not found")
            return
        }
        
        // Fade out música de fondo actual
        fadeOutCurrentMusic(duration: 0.5) {
            // Fade in música de perfil
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.volume = 0.0
                self.audioPlayer?.numberOfLoops = -1
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                
                // Fade in gradual
                self.fadeInMusic(to: self.settings.backgroundVolume, duration: 0.8)
                self.isPlaying = true
                print("🎵 Profile music started with fade in")
            } catch {
                print("Failed to play Profile music: \(error.localizedDescription)")
            }
        }
    }
    
    // Música para DS Config
    func playDSConfigMusic() {
        guard settings.enableBackgroundMusic else { return }
        
        let filename = "Lobby-Music-01-by-Mafty"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3") ??
                        Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Resources/Music") ??
                        Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Resources/Audio/Music") ??
                        Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Music") else {
            print("DS Config music file not found: \(filename)")
            return
        }
        
        fadeOutCurrentMusic(duration: 0.5) {
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.volume = 0.0
                self.audioPlayer?.numberOfLoops = -1
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                
                self.fadeInMusic(to: self.settings.backgroundVolume, duration: 0.8)
                self.isPlaying = true
                print("🎵 DS Config music started")
            } catch {
                print("Failed to play DS Config music: \(error)")
            }
        }
    }
    
    func stopDSConfigMusic() {
        fadeOutCurrentMusic(duration: 1.0) {
            self.isPlaying = false
            print("🎵 DS Config music stopped")
        }
    }
    
    // Música para EENews - REMOVED
    // func playEENewsMusic() { }
    
    // MARK: - SFX Methods
    
    // Música para MeloNX
    func playMeloNXMusic() {
        guard settings.enableBackgroundMusic else { return }
        
        let filename = "melonx"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3") ??
                        Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Resources/Music") ??
                        Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Resources/Audio/Music") ??
                        Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Music") else {
            print("MeloNX music file not found: \(filename)")
            return
        }
        
        // Prevent restarting if already playing (common in rapid navigation)
        if isPlaying, let currentUrl = audioPlayer?.url, currentUrl == url, audioPlayer?.isPlaying == true {
             return
        }
        
        fadeOutCurrentMusic(duration: 0.5) {
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.volume = 0.0
                self.audioPlayer?.numberOfLoops = -1
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                
                self.fadeInMusic(to: self.settings.backgroundVolume, duration: 0.8)
                self.isPlaying = true
                print("🎵 MeloNX music started")
                
                // Show notification
                 Task {
                     let info = await self.extractMetadata(from: url, defaultArtist: "Nintendo 3DS OST")
                     self.showNotification(for: info)
                 }
            } catch {
                print("Failed to play MeloNX music: \(error)")
            }
        }
    }

    // Música para Store
    func playStoreMusic() {
        guard settings.enableBackgroundMusic else { return }
        
        let filename = "Lobby Music 02 by Mafty"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3") ??
                        Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Resources/Music") ??
                        Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Resources/Audio/Music") ??
                        Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Music") else {
            print("Store music file not found: \(filename)")
            return
        }
        
        // Check if Music Player is active (User Music)
        if MusicPlayerManager.shared.isPlaying {
             print("🎵 Music Player active, skipping Store music")
             return
        }
        
        // Prevent restarting if already playing
        if isPlaying, let currentUrl = audioPlayer?.url, currentUrl == url, audioPlayer?.isPlaying == true {
             return
        }

        fadeOutCurrentMusic(duration: 0.5) {
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.volume = 0.0
                self.audioPlayer?.numberOfLoops = -1
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                
                self.fadeInMusic(to: self.settings.backgroundVolume, duration: 0.8)
                self.isPlaying = true
                print("🎵 Store music started")
                
                // Show notification
                 Task {
                     let info = await self.extractMetadata(from: url, defaultArtist: "Store OST")
                     self.showNotification(for: info)
                 }
            } catch {
                print("Failed to play Store music: \(error)")
            }
        }
    }
    
    
    func showNotification(for track: TrackInfo) {
        // Update info
        DispatchQueue.main.async {
            self.currentTrackInfo = track
            
            // Show notification
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                self.showTrackNotification = true
            }
            
            // Cancel previous timer
            self.notificationTimer?.invalidate()
            
            // Auto hide after 4 seconds
            self.notificationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.showTrackNotification = false
                }
            }
        }
    }
    
    private func extractMetadata(from url: URL, defaultArtist: String) async -> TrackInfo {
        let asset = AVAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist = defaultArtist
        var artwork: UIImage? = nil
        
        do {
            let metadata = try await asset.load(.commonMetadata)
            
            for item in metadata {
                if let commonKey = item.commonKey {
                    switch commonKey {
                    case .commonKeyTitle:
                        if let titleValue = try? await item.load(.stringValue) {
                            title = titleValue
                        }
                    case .commonKeyArtist:
                        if let artistValue = try? await item.load(.stringValue) {
                            artist = artistValue
                        }
                    case .commonKeyArtwork:
                        if let data = try? await item.load(.dataValue), let image = UIImage(data: data) {
                            artwork = image
                        }
                    default:
                        break
                    }
                }
            }
        } catch {
            print("Failed to load metadata: \(error)")
        }
        
        return TrackInfo(title: title, artist: artist, artwork: artwork)
    }
    
    func stopGameSystemsMusic() {
        // Fade out y luego restaurar música de fondo si es necesario, o simplemente detener
        fadeOutCurrentMusic(duration: 0.5) {
            self.isPlaying = false
            print("🎵 Game Systems music stopped")
            // Opcional: Restaurar música de fondo automáticamente si se desea
            // self.restoreBackgroundMusic() 
            // Pero GameSystemsLaunchView maneja la restauración explícitamente en startExitSequence llamando a fadeInBackgroundMusic
        }
    }
    
    // MARK: - Restored Methods
    
    // Música de fin de juego
    func playStopGameSound(completion: (() -> Void)? = nil) {
        guard settings.enableUISounds else {
            completion?()
            return
        }
        guard let url = Bundle.main.url(forResource: "music_stopgame_2", withExtension: "mp3") else {
            print("Stop game sound file not found")
            completion?()
            return
        }
        
        do {
            startGamePlayer = try AVAudioPlayer(contentsOf: url)
            startGamePlayer?.volume = settings.sfxVolume
            startGamePlayer?.prepareToPlay()
            startGamePlayer?.play()
            print("🎵 Stop game sound played")
            
            if let duration = startGamePlayer?.duration {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    completion?()
                }
            } else {
                completion?()
            }
        } catch {
            print("Failed to play stop game sound: \(error.localizedDescription)")
            completion?()
        }
    }
    
    // Música de inicio de juego
    func playStartGameSound(completion: (() -> Void)? = nil) {
        guard settings.enableUISounds else {
            completion?()
            return
        }
        
        // Try "music_startgame" first, then fallback to "music_startgame_2"
        var url = Bundle.main.url(forResource: "music_startgame", withExtension: "mp3")
        if url == nil {
            url = Bundle.main.url(forResource: "music_startgame_2", withExtension: "mp3")
        }
        
        guard let soundURL = url else {
            print("Start game sound file not found (music_startgame or music_startgame_2)")
            completion?()
            return
        }
        
        do {
            startGamePlayer = try AVAudioPlayer(contentsOf: soundURL)
            startGamePlayer?.volume = settings.sfxVolume
            startGamePlayer?.prepareToPlay()
            startGamePlayer?.play()
            print("🎵 Start game sound played: \(soundURL.lastPathComponent)")
            
            if let duration = startGamePlayer?.duration {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    completion?()
                }
            } else {
                completion?()
            }
        } catch {
            print("Failed to play start game sound: \(error.localizedDescription)")
            completion?()
        }
    }

    

    // MARK: - Sound Effects & Controls
    
    func playMoveSound() {
        guard settings.enableUISounds else { return }
        playNavigationSound()
    }
    
    // playSelectSound is now optimized below in the Optimized section, so we remove the legacy implementation here
    // func playSelectSound() { ... } 
    
    func playSpecialSelectSound() {
        guard settings.enableUISounds else { return }
        playSoundEffect(name: "music_select_special")
    }
    
    func playOpenSound() {
        guard settings.enableUISounds else { return }
        playSoundEffect(name: "open")
    }
    
    func playStartGridSound() {
        guard settings.enableUISounds else { return }
        playSoundEffect(name: "start_homenu")
    }
    
    func playSuccessSound() {
        guard settings.enableUISounds else { return }
        playSoundEffect(name: "music_savegame")
    }
    
    func playSwipeSound() {
        guard settings.enableUISounds else { return }
        playSoundEffect(name: "sfx_swipe")
    }
    
    func playCartridgeSound() {
        guard settings.enableUISounds else { return }
        playSoundEffect(name: "sound_cartridge")
    }
    
    // Alias for restoring background music (used in MusicPlayerInlineView)
    func playBackMusic() {
        restoreBackgroundMusic()
    }
    
    private func playSoundEffect(name: String) {
        // Try various paths and extensions
        let extensions = ["mp3", "wav"]
        let subdirectories = [nil, "Resources/Audio/Sounds", "Audio/Sounds"]
        
        var soundUrl: URL?
        
        for subdir in subdirectories {
            for ext in extensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdir) {
                    soundUrl = url
                    break
                }
            }
            if soundUrl != nil { break }
        }
        
        guard let url = soundUrl else { return }
        
        do {
            soundEffectPlayer = try AVAudioPlayer(contentsOf: url)
            soundEffectPlayer?.volume = settings.sfxVolume
            soundEffectPlayer?.prepareToPlay()
            soundEffectPlayer?.play()
        } catch {
            print("Failed to play sound effect: \(error)")
        }
    }
    
    // MARK: - Optimized Navigation & Selection Sound
    
    private var navigationSoundPlayers: [AVAudioPlayer] = []
    private var selectSoundPlayers: [AVAudioPlayer] = [] // Pool for keyboard/select sounds
    private var currentPoolIndex = 0
    private var currentSelectPoolIndex = 0
    
    func preloadNavigationSound() {
        // 1. Preload Cursor (Navigation)
        if let url = Bundle.main.url(forResource: "cursor", withExtension: "mp3") ??
                     Bundle.main.url(forResource: "cursor", withExtension: "mp3", subdirectory: "Resources/Audio/Sounds") {
            
            for _ in 0..<5 {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.volume = settings.sfxVolume
                    player.prepareToPlay()
                    navigationSoundPlayers.append(player)
                } catch {
                    print("Failed to preload navigation sound instance: \(error)")
                }
            }
        }
        
        // 2. Preload Select (Typing/Keyboard)
        // Try to find the file using the same logic as playSoundEffect
        let selectNames = ["music_select", "sound_select"]
        var selectUrl: URL?
        
        for name in selectNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp3") ??
                         Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "Resources/Audio/Sounds") ??
                         Bundle.main.url(forResource: name, withExtension: "wav") {
                selectUrl = url
                break
            }
        }
        
        if let url = selectUrl {
            for _ in 0..<5 {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.volume = settings.sfxVolume
                    player.prepareToPlay()
                    selectSoundPlayers.append(player)
                } catch {
                    print("Failed to preload select sound instance: \(error)")
                }
            }
        } else {
            print("Warning: music_select file not found for preloading")
        }
    }
    
    func playNavigationSound() {
        guard settings.enableUISounds else { return }
        
        // Capture volume on Main Thread to avoid accessing SettingsManager from background
        let volume = settings.sfxVolume
        
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // If pool empty, try to load it
            if self.navigationSoundPlayers.isEmpty {
                self.preloadNavigationSound()
            }
            
            guard !self.navigationSoundPlayers.isEmpty else { return }
            
            // Round-robin selection for polyphony
            let player = self.navigationSoundPlayers[self.currentPoolIndex]
            
            // Allow this specific player to restart if it was the one playing (though unlikely with pool of 5)
            if player.isPlaying {
                player.stop()
                player.currentTime = 0
            }
            
            player.volume = volume
            player.play()
            
            // Advance index
            self.currentPoolIndex = (self.currentPoolIndex + 1) % self.navigationSoundPlayers.count
        }
    }
    
    func playSelectSound() {
        guard settings.enableUISounds else { return }
        let volume = settings.sfxVolume
        
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Fallback if pool is empty (e.g. init failed), utilize legacy method on main thread or try generic load
            if self.selectSoundPlayers.isEmpty {
                DispatchQueue.main.async {
                    self.playSoundEffect(name: "music_select")
                }
                return
            }
            
            let player = self.selectSoundPlayers[self.currentSelectPoolIndex]
            
            if player.isPlaying {
                player.stop()
                player.currentTime = 0
            }
            
            player.volume = volume
            player.play()
            
            self.currentSelectPoolIndex = (self.currentSelectPoolIndex + 1) % self.selectSoundPlayers.count
        }
    }
    
    // MARK: - Audio Control Helpers
    
    func pauseAllAudioForAppEntry() {
        audioPlayer?.pause()
        // Pause other players if needed
    }
    
    func pauseBackgroundMusic() {
        audioPlayer?.pause()
    }
    
    func resumeBackgroundMusic() {
        if GameControllerManager.shared.isGameplayMode || GameControllerManager.shared.isEmulatorActive { return }
        
        if settings.enableBackgroundMusic && !MusicPlayerManager.shared.isPlaying {
            audioPlayer?.play()
        }
    }
    
    func fadeOutBackgroundMusic(duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeOutCurrentMusic(duration: duration) {
            self.audioPlayer?.pause()
            self.isPlaying = false
            completion?()
        }
    }
    
    func setVolume(_ volume: Float) {
        audioPlayer?.volume = volume
    }

}
