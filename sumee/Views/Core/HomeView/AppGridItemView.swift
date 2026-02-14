import SwiftUI
import UniformTypeIdentifiers

struct AppGridItemView: View {
    let item: AppItem
    let isSelected: Bool
    let showIcons: Bool
    let isInitialLoad: Bool
    let gameController: GameControllerManager
    let currentRandomROM: ROMItem?
    
    // Actions
    let onTap: (CGRect) -> Void
    
    // Layout context (optional, for sizing)
    var isWidgetExpanded: Bool = false
    
    var body: some View {
        Group {
            if item.isSpacer {
                Color.clear
                    .frame(width: 90, height: 90)
                    .allowsHitTesting(false)
            } else if item.isROM {
                if let rom = item.romItem {
                    ZStack {
                        ROMCardView(rom: rom, isSelected: isSelected)
                            .frame(width: 90, height: 90)
                    }
                    .padding(12)
                    // .drawingGroup() // Removed
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    let frame = geo.frame(in: .global)
                                    onTap(frame)
                                }
                        }
                    )
                } else {
                    Rectangle().fill(Color.red)
                }
            } else if item.isCustomImage {
                CustomAppIconView(item: item, isSelected: isSelected)
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    let frame = geo.frame(in: .global)
                                    onTap(frame)
                                }
                        }
                    )
            } else {
                ZStack {
                    AppIconView(
                        item: item,
                        isSelected: isSelected,
                        shouldAnimate: isInitialLoad,
                        isEditing: gameController.isEditingLayout
                    )
                    .frame(width: 90, height: 90)
                }
                .padding(12)
                // .drawingGroup() // Removed
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let frame = geo.frame(in: .global)
                                onTap(frame)
                            }
                    }
                )
            }
        }
    }
}
