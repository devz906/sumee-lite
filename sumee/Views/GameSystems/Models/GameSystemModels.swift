import SwiftUI

enum ViewMode: String, CaseIterable {
    case vertical = "vertical"
    case grid = "grid"
    case bottomBar = "bottomBar"
    
    var icon: String {
        switch self {
        case .vertical: return "list.bullet"
        case .grid: return "square.grid.2x2.fill"
        case .bottomBar: return "dock.rectangle" // Theater Mode
        }
    }
}

struct ConsoleGroup: Identifiable {
    var id: String { console.rawValue }
    let console: ROMItem.Console
    let roms: [(index: Int, rom: ROMItem)]
}
