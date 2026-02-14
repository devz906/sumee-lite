import WidgetKit
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Image Helper
extension Image {
    init?(data: Data) {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        self.init(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        self.init(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}

// MARK: - Data Models
struct WidgetROMEntry: TimelineEntry {
    let date: Date
    let romTitle: String
    let romConsole: String
    let romImageData: Data?
    let romID: String?
    let isRandom: Bool // Distinguish for UI
}

// MARK: - Last Played Provider
struct LastPlayedProvider: TimelineProvider {
    let suiteName = "group.com.sumee.shared"
    
    struct Keys {
        static let title = "widget.lastPlayed.title"
        static let console = "widget.lastPlayed.console"
        static let imageData = "widget.lastPlayed.imageData"
        static let romID = "widget.lastPlayed.romID"
    }
    
    func placeholder(in context: Context) -> WidgetROMEntry {
        WidgetROMEntry(date: Date(), romTitle: "Super Mario Bros", romConsole: "NES", romImageData: nil, romID: nil, isRandom: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetROMEntry) -> ()) {
        let entry = loadData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadData() -> WidgetROMEntry {
        let defaults = UserDefaults(suiteName: suiteName)
        
        let title = defaults?.string(forKey: Keys.title) ?? "No Saved Game"
        let console = defaults?.string(forKey: Keys.console) ?? "Open App"
        let data = defaults?.data(forKey: Keys.imageData)
        let romID = defaults?.string(forKey: Keys.romID)
        
        return WidgetROMEntry(
            date: Date(),
            romTitle: title,
            romConsole: console,
            romImageData: data,
            romID: romID,
            isRandom: false
        )
    }
}

// MARK: - Random Game Provider
struct RandomGameProvider: TimelineProvider {
    let suiteName = "group.com.sumee.shared"
    
    // Updated Keys for Random Game
    struct Keys {
        static let title = "widget.randomGame.title"
        static let console = "widget.randomGame.console"
        static let imageData = "widget.randomGame.imageData"
        static let romID = "widget.randomGame.romID"
    }
    
    func placeholder(in context: Context) -> WidgetROMEntry {
        WidgetROMEntry(date: Date(), romTitle: "Legend of Zelda", romConsole: "SNES", romImageData: nil, romID: nil, isRandom: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetROMEntry) -> ()) {
        let entry = loadData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = loadData()
        // Random game could update more frequently or stay static until app rotates it
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadData() -> WidgetROMEntry {
        let defaults = UserDefaults(suiteName: suiteName)
        
        let title = defaults?.string(forKey: Keys.title) ?? "Discover"
        let console = defaults?.string(forKey: Keys.console) ?? "Something New"
        let data = defaults?.data(forKey: Keys.imageData)
        let romID = defaults?.string(forKey: Keys.romID)
        
        return WidgetROMEntry(
            date: Date(),
            romTitle: title,
            romConsole: console,
            romImageData: data,
            romID: romID,
            isRandom: true
        )
    }
}

// MARK: - View
struct SumeeWidgetEntryView : View {
    var entry: WidgetROMEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if family == .systemSmall {
                // -- Small Layout: Only Sharp Image --
                if let data = entry.romImageData, let image = Image(data: data) {
                     image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                        .padding(6)
                } else {
                    // Fallback for Small
                    fallbackView
                }
            } else {
                // -- Medium/Large Layout --
                VStack {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 12) {
                        
                        // Small Cartridge / Album Art (Sharp)
                        if let data = entry.romImageData, let image = Image(data: data) {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            fallbackIcon
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(headerText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(entry.isRandom ? .yellow : .white.opacity(0.8))
                                .tracking(1)
                                .textCase(.uppercase)
                            
                            Text(entry.romTitle)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .shadow(color: .black, radius: 2, x: 0, y: 1)
                            
                            // Console Badge
                            if !entry.romConsole.isEmpty && entry.romConsole != "Sumee" {
                                Text(entry.romConsole)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.3))
                                    .cornerRadius(4)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                }
            }
        }
        .containerBackground(for: .widget) {
            // -- Unified Background Logic --
            if let data = entry.romImageData, let image = Image(data: data) {
                image
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 12)
                    .overlay(Color.black.opacity(0.1))
            } else {
                defaultGradient
            }
        }
        .widgetURL(createDeepLink(for: entry.romID))
    }
    
    // Helpers
    var headerText: String {
        if entry.isRandom { return "DISCOVER" }
        return entry.romTitle == "No Saved Game" ? "SUMEE" : "LAST PLAYED"
    }
    
    var fallbackView: some View {
        VStack {
            Image(systemName: "gamecontroller.fill")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    var fallbackIcon: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.2))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "gamecontroller.fill")
                    .foregroundColor(.white.opacity(0.8))
            )
    }
    
    var defaultGradient: some View {
         LinearGradient(
            gradient: Gradient(colors: entry.isRandom ?
                [Color(red: 0.2, green: 0.5, blue: 0.3), Color(red: 0.1, green: 0.3, blue: 0.2)] : // Green for Random
                [Color(red: 0.2, green: 0.2, blue: 0.3), Color(red: 0.1, green: 0.1, blue: 0.2)]   // Blue/Grey for Last Played
            ),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    func createDeepLink(for id: String?) -> URL? {
        guard let id = id else { return nil }
        return URL(string: "sumee://play?id=\(id)")
    }
}

// MARK: - Widgets Configuration

struct LastPlayedWidget: Widget {
    let kind: String = "SumeeWidget" // Keep ID for backward compatibility

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastPlayedProvider()) { entry in
            SumeeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Last Played")
        .description("Jump back into your recent games.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct RandomGameWidget: Widget {
    let kind: String = "RandomGameWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RandomGameProvider()) { entry in
            SumeeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Random Game")
        .description("Discover a random game from your collection.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
