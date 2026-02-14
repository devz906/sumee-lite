import SwiftUI

struct PagedAppGrid: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var selectedTabIndex: Int // Direct binding to the selector's state source
    var showBubbles: Bool
    var showIcons: Bool
    
    @State private var dragOffset: CGFloat = 0
    private let pageSpacing: CGFloat = 40
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: pageSpacing) {
                // Unified Layout for iPhone & iPad
                ForEach(0..<viewModel.pages.count, id: \.self) { index in
                    AppGridPage(
                        apps: viewModel.pages[index],
                        pageIndex: index,
                        selectedTabIndex: selectedTabIndex,
                        showContent: viewModel.showContent,
                        showBubbles: showBubbles,
                        showIcons: showIcons,
                        isInitialLoad: viewModel.isInitialLoad,
                        gameController: viewModel.gameController,
                        pages: $viewModel.pages,
                        draggingItem: $viewModel.draggingItem,
                        currentRandomROM: viewModel.currentRandomROM,
                        onAppTap: { item, frame in
                            // Update selection context
                            viewModel.gameController.selectedAppIndex = viewModel.pages[index].firstIndex(where: { $0.id == item.id }) ?? 0
                            // Update page if needed (though tap usually implies we are on that page)
                            if selectedTabIndex != index {
                                selectedTabIndex = index
                            }
                            viewModel.handleAppTap(item, from: frame)
                        },
                        onWidgetTap: { item in viewModel.openApp(item) },
                        onDeleteApp: { item in viewModel.deleteApp(item) }
                    )
                    .frame(width: geometry.size.width)
                }
            }
            // Offset depends strictly on the binded selectedTabIndex + drag
            .offset(x: -CGFloat(selectedTabIndex) * (geometry.size.width + pageSpacing) + dragOffset)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedTabIndex)
            .animation(dragOffset == 0 ? .spring(response: 0.35, dampingFraction: 0.75) : .none, value: dragOffset)
            
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !viewModel.gameController.isEditingLayout else { return }
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        guard !viewModel.gameController.isEditingLayout else { return }
                        let threshold = geometry.size.width * 0.2
                        let velocityCheck = value.predictedEndTranslation.width
                        
                        var newIndex = selectedTabIndex
                        
                        if value.translation.width < -threshold || velocityCheck < -geometry.size.width / 2 {
                            newIndex = min(viewModel.pages.count - 1, newIndex + 1)
                        } else if value.translation.width > threshold || velocityCheck > geometry.size.width / 2 {
                            newIndex = max(0, newIndex - 1)
                        }
                        
                        dragOffset = 0
                        
                        // Update the binding (which updates ViewModel and Indicator)
                        if newIndex != selectedTabIndex {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedTabIndex = newIndex
                            }
                        }
                    }
            )
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
        .opacity(viewModel.isUIHidden ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: viewModel.isUIHidden)
        .onChange(of: selectedTabIndex) { oldValue, newValue in
            if oldValue != newValue {
                 dragOffset = 0 // Clean up drag logic if external change happens
                 viewModel.gameController.isSelectingWidget = false
                 viewModel.gameController.selectedWidgetIndex = 0
            }
        }
    }
}
