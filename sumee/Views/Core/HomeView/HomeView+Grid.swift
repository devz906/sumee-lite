import SwiftUI

// HomeView+Grid.swift

extension HomeView {
    
    //  Main Grid Layout (Landscape)
    // Refactored into PagedAppGrid.swift for performance to isolate drag state.
    // var mainTabView: some View { ... }

    // Helper View for Portrait Grid Item to isolate Context Menu logic
    struct PortraitGridItem: View {
        let app: AppItem
        let showIcons: Bool
        let showBubbles: Bool
        @ObservedObject var viewModel: HomeViewModel
        @ObservedObject var gameController: GameControllerManager
        @ObservedObject var settings: SettingsManager // If needed for theme
        
        var body: some View {
            AppGridItemView(
                item: app,
                isSelected: false,
                showIcons: showIcons,
                isInitialLoad: false,
                gameController: gameController,
                currentRandomROM: viewModel.currentRandomROM,
                onTap: { frame in 
                    viewModel.handleAppTap(app, from: frame) 
                }
            )
            .contextMenu {
                if !app.isSpacer && app.name != "Empty" {
                    Button(role: .destructive) {
                        viewModel.appToDelete = app
                        viewModel.showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .frame(width: 90, height: 90)
            .opacity(showIcons ? 1 : 0)
            .scaleEffect(showIcons ? 1 : 0.3)
        }
    }

    
 
    //  Unified Layout (Vertical Paging for Both Orientations)
    
    var unifiedGridLayout: some View {
        GeometryReader { outerGeo in
            // LEVEL 1: HORIZONTAL MAIN NAVIGATION
            // Custom PageViewController to fix programmatic animation issues with SwiftUI TabView
            PageViewController(
                pages: [
                    AnyView(
                        // --- PAGE 0: VERTICAL APP GRID ---
                        // Replaced rotated TabView with Native Vertical PageViewController
                        PageViewController(
                            pages: viewModel.pages.indices.map { index in
                                AnyView(
                                    AppGridPage(
                                        apps: viewModel.pages[index],
                                        pageIndex: index,
                                        selectedTabIndex: viewModel.selectedTabIndex,
                                        showContent: viewModel.showContent,
                                        showBubbles: showBubbles,
                                        showIcons: showIcons,
                                        isInitialLoad: viewModel.isInitialLoad,
                                        gameController: viewModel.gameController,
                                        pages: $viewModel.pages,
                                        draggingItem: $viewModel.draggingItem,
                                        currentRandomROM: viewModel.currentRandomROM,
                                        onAppTap: { item, frame in 
                                            viewModel.handleAppTap(item, from: frame) 
                                        },
                                        onWidgetTap: { _ in },
                                        onDeleteApp: { app in
                                            viewModel.appToDelete = app
                                            viewModel.showDeleteConfirmation = true
                                        },
                                        onMove: { source, destination in
                                            viewModel.moveApp(source: source, destination: destination)
                                        },
                                        onReportSelectionFrame: { frame in
                                            viewModel.launchSourceRect = frame
                                        }
                                    )
                                )
                            },
                            currentPage: $viewModel.selectedTabIndex,
                            orientation: .vertical
                        )
                    )
                ] + viewModel.activeGameTasks.map { task in
                    AnyView(
                        GameLiveAreaView(
                            rom: task,
                            viewModel: viewModel
                        )
                        .id(task.id) // Helper for checking identity
                    )
                },
                currentPage: $viewModel.mainInterfaceIndex
            )
        }
        .coordinateSpace(name: "VitaContainer")
    }

    // Page Indicators
    
    var pageIndicators: some View {
        HStack(spacing: 20) {
            // Left Hint
            HStack(spacing: 4) {
                Text("L")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1.5)
                    )
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.gray.opacity(0.6))
            
            // Dots
            HStack(spacing: 8) {
                let pageCount = viewModel.pages.count
                ForEach(0..<pageCount, id: \.self) { index in
                    let activeColor = Color(red: 162/255, green: 248/255, blue: 104/255)
                    Circle()
                        .fill(viewModel.selectedTabIndex == index ? activeColor : Color.gray.opacity(0.3))
                        .frame(width: viewModel.selectedTabIndex == index ? 10 : 8, height: viewModel.selectedTabIndex == index ? 10 : 8)
                        .shadow(color: viewModel.selectedTabIndex == index ? activeColor.opacity(0.6) : Color.clear, radius: 4, x: 0, y: 0)
                }
            }
            
            // Right Hint
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                Text("R")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1.5)
                    )
            }
            .foregroundColor(.gray.opacity(0.6))
        }
        .compositingGroup() // Optimize opacity transitions for the whole group
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            BubbleBackground(position: .center, cornerRadius: 16, theme: settings.activeTheme, reduceTransparency: settings.reduceTransparency)
        )
        .padding(.vertical, 6)
        .opacity(viewModel.isUIHidden ? 0 : (viewModel.showContent ? 1 : 0))
        .scaleEffect(viewModel.showContent ? 1 : 0.5)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: viewModel.showContent)
        .animation(.easeOut(duration: 0.3), value: viewModel.isUIHidden)
    }
    //  Vertical Page Indicators (Portrait Left)
    
    var verticalPageIndicators: some View {
        VStack(spacing: 20) {
            // Top Hint (L / Up)
            /* Hidden to reduce clutter and overlap
            VStack(spacing: 4) {
                Text("L")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1.5)
                    )
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.gray.opacity(0.6))
            */
            
            // Dots (Slightly smaller and with background to ensure contrast over apps)
            VStack(spacing: 8) {
                let pageCount = viewModel.pages.count
                ForEach(0..<pageCount, id: \.self) { index in
                    let activeColor = Color(red: 162/255, green: 248/255, blue: 104/255)
                    Circle()
                        .fill(viewModel.selectedTabIndex == index ? activeColor : Color.white.opacity(0.2)) // Better contrast
                        .frame(width: viewModel.selectedTabIndex == index ? 8 : 6, height: viewModel.selectedTabIndex == index ? 8 : 6) // Smaller dots
                        .shadow(color: viewModel.selectedTabIndex == index ? activeColor.opacity(0.6) : Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            /*
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.2)) // Subtle pill background
                    .blur(radius: 5)
            )
            */
            
            // Bottom Hint (R / Down)
            /*
            VStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                Text("R")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1.5)
                    )
            }
            .foregroundColor(.gray.opacity(0.6))
            */
        }
    }
}
