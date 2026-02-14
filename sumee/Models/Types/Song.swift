import MediaPlayer

struct Song: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    let title: String
    let artist: String
    let fileName: String // MP3 filename without extension (empty for Apple Music)
    var fileURL: URL? // Local file URL for lazy loading
    let duration: TimeInterval
    var artwork: UIImage? = nil // Not codable, kept for caching/current song
    var mediaItem: MPMediaItem? = nil // Not codable
    
    enum CodingKeys: String, CodingKey {
        case id, title, artist, fileName, duration, fileURL
    }
    
    init(id: UUID = UUID(), title: String, artist: String, fileName: String, fileURL: URL? = nil, duration: TimeInterval, artwork: UIImage? = nil, mediaItem: MPMediaItem? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.fileName = fileName
        self.fileURL = fileURL
        self.duration = duration
        self.artwork = artwork
        self.mediaItem = mediaItem
    }
    
    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable
    static func == (lhs: Song, rhs: Song) -> Bool {
        return lhs.id == rhs.id
    }
}
