import SwiftUI
import AVFoundation
import Combine
import MediaPlayer

class MusicPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = MusicPlayerManager()
    
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    // Categories
    @Published var systemSongs: [Song] = []
    @Published var librarySongs: [Song] = []
    @Published var albums: [MPMediaItemCollection] = []
    @Published var playlists: [MPMediaItemCollection] = []
    
    // Current Queue
    @Published var queue: [Song] = []
    
    @Published var isAuthorizedForAppleMusic: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private var systemPlayer = MPMusicPlayerController.applicationMusicPlayer
    private var timer: Timer?
    private var userInitiatedStop = false
    
    private override init() {
        super.init()
        Task {
            await checkAuthorization()
            await loadLibrary()
        }
        
        // Observe system player changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemPlayerStateChange),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: systemPlayer
        )
        systemPlayer.beginGeneratingPlaybackNotifications()
    }
    
    func checkAuthorization() async {
        let status = MPMediaLibrary.authorizationStatus()
        DispatchQueue.main.async {
            self.isAuthorizedForAppleMusic = (status == .authorized)
        }
    }
    
    func requestLibraryAccess() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.isAuthorizedForAppleMusic = (status == .authorized)
                if status == .authorized {
                    Task { await self.loadLibrary() }
                }
            }
        }
    }
    
    func loadLibrary() async {
        var localSongs: [Song] = []
        var foundURLs: [URL] = []
        
        // 1. Search in "Music" subdirectory (Local Files in Bundle)
        if let musicURLs = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: "Music") {
            foundURLs.append(contentsOf: musicURLs)
        }
        
        // 2. Search in Documents/Music (User Files)
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let musicDirectory = documentsPath.appendingPathComponent("Music", isDirectory: true)
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
        
        // Scan for audio files
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: musicDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let supportedExtensions = ["mp3", "m4a", "wav", "aac"]
            
            for url in fileURLs {
                if supportedExtensions.contains(url.pathExtension.lowercased()) {
                    foundURLs.append(url)
                }
            }
        } catch {
            print(" Error scanning Music directory: \(error.localizedDescription)")
        }
        
        // 3. Search in Root (for flattened resources - Legacy)
        if let rootURLs = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil) {
            foundURLs.append(contentsOf: rootURLs)
        }
        
        print("Found \(foundURLs.count) Audio Files (Bundle + Documents)")
        
        // Process Local Files
        for url in foundURLs {
            let fileName = url.deletingPathExtension().lastPathComponent
            
            // Deduplication
            if localSongs.contains(where: { $0.fileName == fileName }) { continue }
            
            let asset = AVAsset(url: url)
            let duration = (try? await asset.load(.duration).seconds) ?? 0
            
            // Filter: Only include songs longer than 10 seconds
            if duration < 10 { continue }
            
            // Extract metadata
            var title = fileName
            var artist = "Unknown Artist"
            var artwork: UIImage? = nil
            
            do {
                let metadata = try await asset.load(.commonMetadata)
                for item in metadata {
                    if item.commonKey == .commonKeyTitle, let value = try? await item.load(.stringValue) {
                        title = value
                    }
                    if item.commonKey == .commonKeyArtist, let value = try? await item.load(.stringValue) {
                        artist = value
                    }
                    if item.commonKey == .commonKeyArtist, let value = try? await item.load(.stringValue) {
                        artist = value
                    }
                    // optimize: Do NOT load artwork here to save RAM. AsyncArtworkImage adds it on demand.
                }
            } catch {
                print("Error loading metadata for \(fileName): \(error)")
            }
            
            if title == fileName {
                title = title.replacingOccurrences(of: "_", with: " ").capitalized
            }
            
            let song = Song(
                title: title,
                artist: artist,
                fileName: fileName,
                fileURL: url,
                duration: duration,
                artwork: nil // Lazy load via fileURL
            )
            localSongs.append(song)
        }
        
        // 3. Load Apple Music Library (if authorized)
        var appleSongs: [Song] = []
        var appleAlbums: [MPMediaItemCollection] = []
        var applePlaylists: [MPMediaItemCollection] = []
        
        if isAuthorizedForAppleMusic {
            // Songs
            let songsQuery = MPMediaQuery.songs()
            if let items = songsQuery.items {
                print("Found \(items.count) Apple Music songs")
                for item in items {
                    let song = Song(
                        title: item.title ?? "Unknown Title",
                        artist: item.artist ?? "Unknown Artist",
                        fileName: "", // Empty for Apple Music
                        duration: item.playbackDuration,
                        artwork: nil, // Lazy load via mediaItem
                        mediaItem: item
                    )
                    appleSongs.append(song)
                }
            }
            
            // Albums
            let albumsQuery = MPMediaQuery.albums()
            if let collections = albumsQuery.collections {
                appleAlbums = collections
            }
            
            // Playlists
            let playlistsQuery = MPMediaQuery.playlists()
            if let collections = playlistsQuery.collections {
                applePlaylists = collections
            }
        }
        
        DispatchQueue.main.async {
            self.systemSongs = localSongs
            self.librarySongs = appleSongs
            self.albums = appleAlbums
            self.playlists = applePlaylists
            
            // Default queue is system songs if nothing else
            if self.queue.isEmpty {
                self.queue = localSongs
            }
            
            print("Loaded Library: \(localSongs.count) System, \(appleSongs.count) Songs, \(appleAlbums.count) Albums, \(applePlaylists.count) Playlists")
        }
    }
    
    func play(song: Song, context: [Song]) {
        // Update queue context
        self.queue = context
        loadSong(song)
        play()
    }
    
    @Published var isLoading: Bool = false
    @Published var isMiniPlayerExpanded: Bool = true
    @Published var isSessionActive: Bool = false
    


    func loadSong(_ song: Song) {
        // Stop any current playback but keep session active for transition
        stop(clearSession: false)
        
        var songToPlay = song
        
        // Hydrate artwork if missing for Apple Music items (important for background display)
        if songToPlay.artwork == nil, let item = songToPlay.mediaItem {
            // Retrieve artwork large enough for background
            if let artworkImage = item.artwork?.image(at: CGSize(width: 600, height: 600)) {
                songToPlay = Song(
                    id: songToPlay.id,
                    title: songToPlay.title,
                    artist: songToPlay.artist,
                    fileName: songToPlay.fileName,
                    fileURL: songToPlay.fileURL,
                    duration: songToPlay.duration,
                    artwork: artworkImage,
                    mediaItem: item
                )
            }
        }
        
        currentSong = songToPlay
        isLoading = true
        isSessionActive = true // Activate session immediately on load
        
        // Run loading off the main thread to prevent UI freeze
        Task.detached(priority: .userInitiated) { [weak self, song, songToPlay] in
            guard let self = self else { return }
            
            if let mediaItem = songToPlay.mediaItem {
                // Apple Music Playback
                // Move preparation to background to prevent UI freeze (Spinner Animation)
                let collection = MPMediaItemCollection(items: [mediaItem])
                self.systemPlayer.setQueue(with: collection)
                try? await self.systemPlayer.prepareToPlay() // This can block, so we run it here
                
                await MainActor.run {
                    self.duration = songToPlay.duration
                    self.currentTime = 0
                    print(" Loaded Apple Music: \(songToPlay.title)")
                    self.isLoading = false
                    self.play() 
                }
            } else {
                // Local File Playback (Heavy I/O)
                var finalUrl: URL? = nil
                
                // 1. Try Bundle (Legacy MP3)
                if let url = Bundle.main.url(forResource: songToPlay.fileName, withExtension: "mp3", subdirectory: "Music") {
                    finalUrl = url
                } else if let url = Bundle.main.url(forResource: songToPlay.fileName, withExtension: "mp3") {
                     finalUrl = url
                }
                
                // 2. Try Documents/Music (Custom Files)
                if finalUrl == nil {
                    let fileManager = FileManager.default
                    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let musicDir = documentsPath.appendingPathComponent("Music")
                    let extensions = ["mp3", "m4a", "wav", "aac"]
                    
                    for ext in extensions {
                        let fileUrl = musicDir.appendingPathComponent("\(songToPlay.fileName).\(ext)")
                        if fileManager.fileExists(atPath: fileUrl.path) {
                            finalUrl = fileUrl
                            break
                        }
                    }
                }
                
                guard let url = finalUrl else {
                    print(" Could not find audio file for: \(songToPlay.fileName)")
                    await MainActor.run {
                        self.isLoading = false
                        self.isSessionActive = false
                    }
                    return
                }
                
                // Load Player in Background
                do {
                    let newPlayer = try AVAudioPlayer(contentsOf: url)
                    newPlayer.prepareToPlay() // Prepare without blocking Main
                    
                    // Extract Artwork for Local File
                    let asset = AVAsset(url: url)
                    var extractedArtwork: UIImage? = nil
                    let items = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: .common)
                    if let data = items.first?.dataValue, let image = UIImage(data: data) {
                        extractedArtwork = image
                    }
                    
                    await MainActor.run {
                        self.audioPlayer = newPlayer
                        self.audioPlayer?.delegate = self
                        self.duration = newPlayer.duration 
                        self.currentTime = 0
                        
                        // Update Current Song with Artwork so HomeView/Widget can see it
                        if var updatedSong = self.currentSong {
                            updatedSong.artwork = extractedArtwork
                            updatedSong.fileURL = url // Ensure URL is set
                            self.currentSong = updatedSong
                        }
                        
                        print(" Loaded Local: \(songToPlay.title) from \(url.path)")
                        self.isLoading = false
                        self.play()
                    }
                } catch {
                    print("Failed to load audio: \(error.localizedDescription)")
                    await MainActor.run {
                        self.isLoading = false
                        self.isSessionActive = false
                    }
                }
            }
        }
    }
    
    func resume() {
        if let _ = currentSong?.mediaItem {
            systemPlayer.play()
        } else {
            audioPlayer?.play()
        }
        isPlaying = true
        isSessionActive = true
        startTimer()
        print(" Resumed (Interruption Recovery)")
    }
    
    func play() {
        // Fade out background music before playing song
        AudioManager.shared.fadeOutBackgroundMusic(duration: 0.8) {
            if let _ = self.currentSong?.mediaItem {
                self.systemPlayer.play()
            } else {
                self.audioPlayer?.play()
            }
            
            self.isPlaying = true
            self.isSessionActive = true
            self.startTimer()
            print(" Playing: \(self.currentSong?.title ?? "Unknown")")
            
            self.userInitiatedStop = false
            
            // Trigger Notification
            if let song = self.currentSong {
                let info = AudioManager.TrackInfo(title: song.title, artist: song.artist, artwork: song.artwork)
                AudioManager.shared.showNotification(for: info)
            }
        }
    }
    
    func pause() {
        userInitiatedStop = true
        if let _ = currentSong?.mediaItem {
            systemPlayer.pause()
        } else {
            audioPlayer?.pause()
        }
        isPlaying = false
        stopTimer()
        print("⏸ Paused")
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func stop(clearSession: Bool = true) {
        userInitiatedStop = true
        if let _ = currentSong?.mediaItem {
            systemPlayer.stop()
        } else {
            audioPlayer?.stop()
            audioPlayer?.currentTime = 0
        }
        
        isPlaying = false
        currentTime = 0
        stopTimer()
        
        if clearSession {
            isSessionActive = false
            print("⏹ Stopped (Session Cleared)")
            // Resume background music
            AudioManager.shared.fadeInBackgroundMusic(duration: 1.0)
        } else {
            print("⏹ Stopped (Session Kept)")
        }
    }
    
    func seek(to time: TimeInterval) {
        if let _ = currentSong?.mediaItem {
            systemPlayer.currentPlaybackTime = time
        } else {
            audioPlayer?.currentTime = time
        }
        currentTime = time
    }
    
    func playNext() {
        guard let current = currentSong,
              let currentIndex = queue.firstIndex(where: { $0.id == current.id }) else {
            if !queue.isEmpty {
                play(song: queue[0], context: queue)
            }
            return
        }
    
        let nextIndex = (currentIndex + 1) % queue.count
        play(song: queue[nextIndex], context: queue)
        print("⏭ Next: \(queue[nextIndex].title)")
    }

    func playPrevious() {
        guard let current = currentSong,
              let currentIndex = queue.firstIndex(where: { $0.id == current.id }) else {
            if !queue.isEmpty {
                play(song: queue[0], context: queue)
            }
            return
        }
    
        let prevIndex = currentIndex == 0 ? queue.count - 1 : currentIndex - 1
        play(song: queue[prevIndex], context: queue)
        print("Previous: \(queue[prevIndex].title)")
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if let _ = self.currentSong?.mediaItem {
                self.currentTime = self.systemPlayer.currentPlaybackTime
            } else if let player = self.audioPlayer {
                self.currentTime = player.currentTime
                if !player.isPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func handleSystemPlayerStateChange() {
        DispatchQueue.main.async {
            let newState = self.systemPlayer.playbackState
            self.isPlaying = (newState == .playing)
            
            // Auto-advance logic for Apple Music
          
            if (newState == .stopped || newState == .paused) && !self.userInitiatedStop && !self.isLoading {
                // Delay slightly to ensure reliable state transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.systemPlayer.playbackState != .playing {
                         print(" Apple Music track finished, advancing...")
                         self.playNext()
                    }
                }
            }
        }
    }
    
    deinit {
        stopTimer()
        systemPlayer.endGeneratingPlaybackNotifications()
    }
    
    //  File Management
    
    func deleteSong(_ song: Song) {
        guard song.mediaItem == nil else {
            print(" Cannot delete Apple Music items")
            return
        }
        
        // 1. Check if it's playing
        if currentSong?.id == song.id {
            stop()
        }
        
        // 2. Locate file in Documents/Music
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let musicDir = documentsPath.appendingPathComponent("Music")
        
        let extensions = ["mp3", "m4a", "wav", "aac"]
        var fileFound = false
        
        for ext in extensions {
            let fileUrl = musicDir.appendingPathComponent("\(song.fileName).\(ext)")
            if fileManager.fileExists(atPath: fileUrl.path) {
                do {
                    try fileManager.removeItem(at: fileUrl)
                    print(" Deleted song file: \(song.fileName)")
                    fileFound = true
                    break
                } catch {
                    print(" Failed to delete file: \(error)")
                }
            }
        }
        
        if !fileFound {
            print(" File not found in Documents (might be Bundle file which cannot be deleted)")
        }
        
        // 3. Refresh Library
        Task {
            await loadLibrary()
        }
    }

    //  AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Local Song finished")
        
        // Auto-advance
        if !userInitiatedStop {
             playNext()
        } else {
            isPlaying = false
            stopTimer()
            isSessionActive = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AudioManager.shared.fadeInBackgroundMusic(duration: 1.0)
            }
        }
    }
}
