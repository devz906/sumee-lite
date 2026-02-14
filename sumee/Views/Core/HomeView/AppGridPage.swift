import SwiftUI
import UniformTypeIdentifiers

struct AppGridPage: View {
    let apps: [AppItem]
    let pageIndex: Int
    let selectedTabIndex: Int
    let showContent: Bool
    let showBubbles: Bool
    let showIcons: Bool
    let isInitialLoad: Bool
    @ObservedObject var gameController: GameControllerManager
    @Binding var pages: [[AppItem]]
    @Binding var draggingItem: AppItem?
    var currentRandomROM: ROMItem? 
    
    let onAppTap: (AppItem, CGRect) -> Void
    let onWidgetTap: (AppItem) -> Void
    let onDeleteApp: (AppItem) -> Void 
    var onMove: ((AppItem, AppItem) -> Void)? = nil
    var onReportSelectionFrame: ((CGRect) -> Void)? = nil
    
    // Grid Constants for Vita Layout

    let iconSize: CGFloat = 84
    let verticalSpacing: CGFloat = 10 // Positive spacing to separate rows vertically
    let horizontalSpacing: CGFloat = 18
    
    @State private var arrivalBounce: Double = 0
    // Track localized bounce for selection
    @State private var selectionBounce: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            
            // Layout & Centering Logic
            // In vertical mode (Phone Portrait), screen width (~390) is tight for 4 icons (~390).
          
            let isPortrait = geometry.size.width < geometry.size.height
            
            // Calculate scale to ensure 4 icons fit within the screen width
     
            let contentWidth: CGFloat = 400 
            let scaleFactor = isPortrait ? min(1.0, geometry.size.width / contentWidth) : 1.0
            
            // Center the grid vertically and horizontally
            VStack {
                Spacer()
                
                // Manual Staggered Grid Construction
 
                let rows = buildGridRows()
                
                VStack(spacing: verticalSpacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, rowItems in
                        HStack(spacing: horizontalSpacing) {
                            ForEach(rowItems) { item in
                                renderItem(item)
                            }
                        }
                    }
                }
                .scaleEffect(scaleFactor)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showIcons)
                .onChange(of: selectedTabIndex) { _, newIndex in
                    if newIndex == pageIndex {
                        triggerArrivalAnimation()
                    }
                }
                .onAppear {
                    if selectedTabIndex == pageIndex {
                        triggerArrivalAnimation()
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // Extracted animation logic for reuse
    private func triggerArrivalAnimation() {
   
        arrivalBounce = 0 
        
        withAnimation(.easeOut(duration: 0.15)) {
            arrivalBounce = 20.0
        }
        
        // 2. Spring back to 0 (Rest) with high bounciness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.3, blendDuration: 0)) {
                arrivalBounce = 0.0
            }
        }
    }


// Helper to chunk apps into [3, 2, 3, 2] pattern
    func buildGridRows() -> [[AppItem]] {
        var rows: [[AppItem]] = []
        var currentIndex = 0
        var currentRow = 0
        
        while currentIndex < apps.count {
            let capacity = VitaGridHelper.itemsPerRow(currentRow)
            let remaining = apps.count - currentIndex
            let take = min(capacity, remaining)
            
            let chunk = Array(apps[currentIndex..<currentIndex+take])
            rows.append(chunk)
            
            currentIndex += take
            currentRow += 1
        }
        
        return rows
    }
    
    @ViewBuilder
    func renderItem(_ item: AppItem) -> some View {
        let index = apps.firstIndex(where: { $0.id == item.id }) ?? 0
        // Hide selection if no controller is connected
        let isSelected = gameController.isControllerConnected && pageIndex == selectedTabIndex && index == gameController.selectedAppIndex
        
        let baseView = AppIconView(
            item: item,
            isSelected: isSelected,
            shouldAnimate: showIcons,
            isEditing: gameController.isEditingLayout,
            onDelete: {
                // Handle delete directly from the badge
                onDeleteApp(item)
                // "Any change exits edit mode" -> exit after delete action
    
                if gameController.isEditingLayout {
                    gameController.openEdit()
                }
            }
        )
        
        if gameController.isEditingLayout {
            DraggableGridItem(
                item: item,
                baseView: AnyView(baseView),
                iconSize: iconSize,
                showIcons: showIcons,
                arrivalBounce: arrivalBounce,
                onMove: onMove,
                gameController: gameController,
                findItem: { id in findItem(by: id) },
                onTap: { _ in }
            )
        } else {
            InteractableGridItem(
                item: item,
                index: index,
                baseView: AnyView(baseView),
                isSelected: isSelected,
                showIcons: showIcons,
                arrivalBounce: arrivalBounce,
                iconSize: iconSize,
                gameController: gameController,
                onAppTap: onAppTap,
                onReportSelectionFrame: onReportSelectionFrame
            )
        }
    }
    
    // Helper to find item across all pages
    func findItem(by id: UUID) -> AppItem? {
        for page in pages {
            if let item = page.first(where: { $0.id == id }) {
                return item
            }
        }
        return nil
    }
}

struct WaterDropPlaceholder: View {
    var isSelected: Bool = false
    
    var body: some View {
        ZStack {
            // Static dot
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 12, height: 12)
            
            // Selection Corners - Instant appearance
            CornerSelectionView()
            .frame(width: 90, height: 90)
            .opacity(isSelected ? 1 : 0)
            .animation(nil, value: isSelected)
        }
    }
}

struct CornerSelectionView: View {
    var body: some View {
        VStack {
            HStack {
                cornerIndicator
                Spacer()
                cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1))
            }
            Spacer()
            HStack {
                cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1))
                Spacer()
                cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1))
            }
        }
        .padding(4) // Adjust padding to fit nicely around the 90x90 area
    }
    
    private var cornerIndicator: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 12))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 12, y: 0))
        }
        .stroke(Color.cyan, lineWidth: 3)
        .frame(width: 12, height: 12)
    }
}

struct InteractableGridItem: View {
    let item: AppItem
    let index: Int
    let baseView: AnyView
    let isSelected: Bool
    let showIcons: Bool
    let arrivalBounce: Double
    let iconSize: CGFloat
    let gameController: GameControllerManager
    let onAppTap: (AppItem, CGRect) -> Void
    let onReportSelectionFrame: ((CGRect) -> Void)?
    
    @State private var isPressing = false
    
    var body: some View {
        BouncingItemWrapper(
            content: AnyView(
                baseView
                    .frame(width: iconSize, height: iconSize)
                    .scaleEffect(isPressing ? 0.9 : 1.0)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isPressing)
                    .zIndex(isSelected ? 100 : 0)
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    let frame = geo.frame(in: .global)
                                    if !gameController.isEditingLayout {
                                        gameController.selectedAppIndex = index
                                        onAppTap(item, frame)
                                    }
                                }
                                .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                                    // Immediate response
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                        isPressing = pressing
                                    }
                                }, perform: {
                                    if !gameController.isEditingLayout {
                                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                                        generator.impactOccurred()
                                        // Slight release animation before mode switch
                                        withAnimation(.spring()) {
                                            isPressing = false
                                        }
                                        gameController.openEdit()
                                    }
                                })
                                .onChange(of: isSelected) { _, isSel in
                                    if isSel {
                                        let frame = geo.frame(in: .global)
                                        onReportSelectionFrame?(frame)
                                    }
                                }
                                .onAppear {
                                    if isSelected {
                                        DispatchQueue.main.async { 
                                            let frame = geo.frame(in: .global)
                                            onReportSelectionFrame?(frame)
                                        }
                                    }
                                }
                        }
                    )
                    .opacity(showIcons ? 1 : 0)
                    .scaleEffect(showIcons ? 1 : 0.01)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.03), value: showIcons)
            ),
            isSelected: isSelected,
            arrivalBounce: arrivalBounce
        )
    }
}

struct DraggableGridItem: View {
    let item: AppItem
    let baseView: AnyView
    let iconSize: CGFloat
    let showIcons: Bool
    let arrivalBounce: Double
    let onMove: ((AppItem, AppItem) -> Void)?
    var gameController: GameControllerManager
    let findItem: (UUID) -> AppItem?
    let onTap: (CGRect) -> Void
    
    @State private var isPressing = false
    
    var body: some View {
        Button(action: {
             // Tap handled by drag/drop or other gestures usually
        }) {
            baseView
                .frame(width: iconSize, height: iconSize)
        }
        .buttonStyle(SqueezeButtonStyle())
        .contentShape(.dragPreview, Circle())
        .onDrag {
            return NSItemProvider(object: item.id.uuidString as NSString)
        } preview: {
            AppIconView(
                item: item,
                isSelected: false,
                shouldAnimate: false,
                isEditing: false
            )
            .frame(width: iconSize, height: iconSize)
        }
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
            providers.first?.loadObject(ofClass: NSString.self) { string, error in
                guard let idString = string as? String,
                      let sourceUUID = UUID(uuidString: idString) else { return }
                
                DispatchQueue.main.async {
                    if let sourceItem = findItem(sourceUUID) {
                        onMove?(sourceItem, item)
                        if gameController.isEditingLayout {
                            gameController.openEdit()
                        }
                    }
                }
            }
            return true
        }
        .rotation3DEffect(
            .degrees(arrivalBounce),
            axis: (x: 1.0, y: 0.0, z: 0.0)
        )
        .opacity(showIcons ? 1 : 0)
        .scaleEffect(showIcons ? 1 : 0.01)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showIcons)
    }
}

struct SqueezeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct BouncingItemWrapper: View {
    let content: AnyView
    let isSelected: Bool
    let arrivalBounce: Double // Passed from parent
    
    @State private var selectionBounce: Double = 0
    
    var body: some View {
        content
            .rotation3DEffect(
                // Combine global arrival bounce and local selection bounce
                .degrees(arrivalBounce + selectionBounce),
                axis: (x: 1.0, y: 0.0, z: 0.0)
            )
            .onChange(of: isSelected) { _, newValue in
                if newValue {
                     triggerSelectionBounce()
                }
            }
    }
    
    private func triggerSelectionBounce() {
        selectionBounce = 0
        
        withAnimation(.easeOut(duration: 0.12)) {
            selectionBounce = 10.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.4, blendDuration: 0)) {
                selectionBounce = 0.0
            }
        }
    }
}
