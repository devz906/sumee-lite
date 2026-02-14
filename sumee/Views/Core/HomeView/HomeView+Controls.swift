import SwiftUI

// HomeView+Controls.swift

extension HomeView {
    
    // Header
    
    func headerView(isPortrait: Bool) -> some View {
        HeaderView(
            isShowingPhotos: viewModel.showPhotosGallery,
            isShowingGameBoy: false, // Deprecated
            isShowingMusic: viewModel.showMusicPlayer,
            isShowingSettings: viewModel.showSettings,
            isEditing: viewModel.gameController.isEditingLayout,
            currentPage: viewModel.selectedTabIndex,
            mainInterfaceIndex: viewModel.mainInterfaceIndex,
            isControllerConnected: viewModel.gameController.isControllerConnected,
            controllerName: viewModel.gameController.controllerName,
            activeGameTasks: viewModel.activeGameTasks,
            onTaskTap: { index in
                withAnimation {
                    viewModel.mainInterfaceIndex = index
                }
            },
            customTitle: viewModel.selectedAppTitle,

            onControlsTap: { withAnimation { viewModel.showFullMediaControls = true } },
            onControllerIconTap: { viewModel.showGamepadSettings = true },
            useGlassEffect: false
        )
            .padding(.top, isPortrait ? 55 : 35)
            .opacity(viewModel.shouldHideHeader ? 0 : (viewModel.showContent ? 1 : 0))
            .offset(y: viewModel.showContent ? 0 : -30)
            .animation(.easeOut(duration: 0.6).delay(0.1), value: viewModel.showContent)
            .animation(.easeOut(duration: 0.3), value: viewModel.showGameSystems)
            .animation(.easeOut(duration: 0.3), value: viewModel.showGameSystemsHeader)
            // .animation(.easeOut(duration: 0.3), value: viewModel.showEENews)
            .animation(.easeOut(duration: 0.3), value: viewModel.showMeloNX)
    }
    
    //  Bottom Controls
    
    func bottomControls(isPortrait: Bool) -> some View {
        ZStack(alignment: .center) {
            // Widget focused mode
            HStack {
                ControlCard(actions: [
                    ControlAction(icon: "a.circle", label: "Interact"),
                    ControlAction(icon: "b.circle", label: "Exit Widget")
                ], position: .left)
                Spacer()
            }
            .opacity((viewModel.gameController.isSelectingWidget && !viewModel.gameController.isEditingLayout) ? 1 : 0)
            .offset(y: (viewModel.gameController.isSelectingWidget && !viewModel.gameController.isEditingLayout) ? 0 : 60)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.gameController.isSelectingWidget)
            
            // Normal mode
            Group {
                if isPortrait {
                    VStack(spacing: 0) {
                        ControlCard(actions: [
                            ControlAction(icon: "a.circle", label: "Select", action: {
                                viewModel.handleButtonAPress()
                            }),
                            ControlAction(icon: "y.circle", label: "Edit", action: {
                                viewModel.handleButtonYPress()
                            })
                        ], position: .center)
                    }
                } else {
                    HStack {
                        ControlCard(actions: [
                            ControlAction(icon: "y.circle", label: "Edit", action: {
                                viewModel.handleButtonYPress()
                            })
                        ], position: .left)
                        Spacer()
                        Spacer()
                        ControlCard(actions: [
                            ControlAction(icon: "a.circle", label: "Select", action: {
                                viewModel.handleButtonAPress()
                            })
                        ], position: .right)
                    }
                }
            }
            .opacity((viewModel.gameController.isEditingLayout || viewModel.gameController.isSelectingWidget) ? 0 : (viewModel.showContent ? 1 : 0))
            .offset(y: (viewModel.gameController.isEditingLayout || viewModel.gameController.isSelectingWidget) ? 60 : 0)
            
            // Shared Page Indicators (Removed as per user request - Vertical Only)
            // Group {
            //    if !isPortrait {
            //        pageIndicators
            //    }
            // }
            .opacity((viewModel.showContent && !viewModel.gameController.isSelectingWidget) ? 1 : 0)
            .animation(.default, value: viewModel.gameController.isEditingLayout)

            // Edit mode
            HStack {
                ControlCard(actions: [
                    ControlAction(icon: "y.circle", label: "Save", action: {
                        viewModel.gameController.openEdit()
                    }),
                    ControlAction(icon: "a.circle", label: "Resize", action: {
                        viewModel.handleControllerSelect()
                    }),
                    ControlAction(icon: "b.circle", label: "Undo", action: {
                        viewModel.gameController.goBack()
                    })
                ], position: .left)
                
                ControlCard(actions: [
                    ControlAction(icon: "x.circle", label: "Remove")
                ], position: .left)
                Spacer()
                ControlCard(actions: [
                    ControlAction(icon: "arrow.up.and.down.and.arrow.left.and.right", label: "Move")
                ], position: .right)
            }
            .opacity(viewModel.gameController.isEditingLayout ? 1 : 0)
            .offset(y: viewModel.gameController.isEditingLayout ? 0 : 60)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.gameController.isEditingLayout)
            .allowsHitTesting(viewModel.gameController.isEditingLayout)
        }
        .frame(height: isPortrait ? nil : 32) // Allow auto-height for Portrait stack
        .padding(.horizontal, 20)
        .padding(.bottom, isPortrait ? 20 : 2) // Extra bottom padding for stacked feel
        .offset(y: -10)
        .opacity(viewModel.isUIHidden ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: viewModel.isUIHidden)
    }
}
