import SwiftUI
import MediaPlayer

// MARK: - Equatable Grid Content
struct MusicGridContent: View, Equatable {
    let category: MusicPlayerInlineView.MusicCategory
    let navigationPath: [MusicPlayerInlineView.MusicNavigationItem]
    let currentSongs: [Song]
    let albums: [MPMediaItemCollection]
    let playlists: [MPMediaItemCollection]
    let selectedIndex: Int
    let playingSongID: UUID?
    let isPlaying: Bool
    
    // Actions
    let onSelectAlbum: (MPMediaItemCollection) -> Void
    let onSelectPlaylist: (MPMediaItemCollection) -> Void
    let onSelectSong: (Int) -> Void
    let onDeleteSong: (Song) -> Void
    
    static func == (lhs: MusicGridContent, rhs: MusicGridContent) -> Bool {
        // Only redraw if data relevant to display changes
        return lhs.category == rhs.category &&
               lhs.navigationPath == rhs.navigationPath &&
               lhs.selectedIndex == rhs.selectedIndex &&
               lhs.playingSongID == rhs.playingSongID &&
               lhs.isPlaying == rhs.isPlaying &&
               lhs.currentSongs.count == rhs.currentSongs.count &&
               lhs.albums.count == rhs.albums.count &&
               lhs.playlists.count == rhs.playlists.count
    }
    
    var body: some View {
        if category == .albums && navigationPath.isEmpty {
            albumsGrid
        } else if category == .playlists && navigationPath.isEmpty {
            playlistsGrid
        } else {
            songsGrid
        }
    }
    
    // SubViews (Copied & Optimized from InlineView)
    
    private var albumsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 16)], spacing: 16) {
            ForEach(albums.indices, id: \.self) { index in
                let album = albums[index]
                Button(action: {
                    onSelectAlbum(album)
                }) {
                    AlbumCard(album: album, isSelected: selectedIndex == index)
                }
                .buttonStyle(.plain) // Important for performance in Lists/Grids
            }
        }
        .padding(24)
        .padding(.bottom, 60)
    }
    
    private var playlistsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 16)], spacing: 16) {
            ForEach(playlists.indices, id: \.self) { index in
                let playlist = playlists[index]
                Button(action: {
                    onSelectPlaylist(playlist)
                }) {
                    PlaylistCard(playlist: playlist, isSelected: selectedIndex == index)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .padding(.bottom, 60)
    }
    
    private var songsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 16)
        ], spacing: 16) {
            // Include Random Button at Index 0 + Songs
            ForEach(0..<(currentSongs.count + 1), id: \.self) { index in
                Button(action: { onSelectSong(index) }) {
                    if index == 0 {
                        // Random Button
                        SongCardView(
                            song: Song(
                                title: "Random",
                                artist: "Shuffle Play",
                                fileName: "",
                                duration: 0,
                                artwork: UIImage(named: "icon_random")
                            ),
                            isSelected: selectedIndex == 0,
                            isPlaying: false
                        )
                    } else {
                        // Actual Songs
                        let songIndex = index - 1
                        if currentSongs.indices.contains(songIndex) {
                            let song = currentSongs[songIndex]
                            SongCardView(
                                song: song,
                                isSelected: selectedIndex == index,
                                isPlaying: playingSongID == song.id && isPlaying
                            )
                            .contextMenu {
                                if category == .system {
                                    Button(role: .destructive) {
                                        onDeleteSong(song)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .id(index)
            }
        }
        .padding(24)
        .padding(.bottom, 60)
    }
}

//  Helper Cards (Moved from InlineView)

struct AlbumCard: View {
    let album: MPMediaItemCollection
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            VStack {
                AsyncArtworkImage(
                    item: album.representativeItem,
                    size: CGSize(width: 140, height: 140),
                    cornerRadius: 20
                )
                
                Text(album.representativeItem?.albumTitle ?? "Unknown Album")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            
            if isSelected {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.blue, lineWidth: 4)
                    .frame(width: 150, height: 170)
            }
        }
    }
}

struct PlaylistCard: View {
    let playlist: MPMediaItemCollection
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            VStack {
                AsyncArtworkImage(
                     item: playlist.representativeItem,
                     size: CGSize(width: 140, height: 140),
                     cornerRadius: 20
                )
                
                Text(playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String ?? "Playlist")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            
            if isSelected {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.blue, lineWidth: 4)
                    .frame(width: 150, height: 170)
            }
        }
    }
}
