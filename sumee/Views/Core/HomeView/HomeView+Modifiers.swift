import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import Combine

struct HomeEventModifiers: ViewModifier {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var gameController: GameControllerManager
    @ObservedObject var audioManager: AudioManager
    @Binding var appLoading: Bool
    
    // Closures for actions that need to be passed back or handled specifically
    var updateInterfaceOrientation: (UIInterfaceOrientationMask) -> Void
    var handleDeepLink: (URL) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showGamepadSettings) {
                GamepadSettingsView()
            }
            .fileImporter(
                isPresented: $viewModel.showingFilePicker,
                allowedContentTypes: viewModel.isImportingMusic ? [.audio] : [
                    UTType(filenameExtension: "gb")!,
                    UTType(filenameExtension: "gbc")!,
                    UTType(filenameExtension: "gba")!,
                    UTType(filenameExtension: "nes")!,
                    UTType(filenameExtension: "snes")!,
                    UTType(filenameExtension: "smc")!,
                    UTType(filenameExtension: "sfc")!,
                    UTType(filenameExtension: "nds")!,
                    UTType(filenameExtension: "n64")!,
                    UTType(filenameExtension: "z64")!,
                    UTType(filenameExtension: "v64")!,
                    UTType(filenameExtension: "iso")!,
                    UTType(filenameExtension: "bin")!,
                    UTType(filenameExtension: "cue")!,
                    UTType(filenameExtension: "pbp")!,
                    UTType(filenameExtension: "chd")!,
                    UTType(filenameExtension: "m3u")!,
                    UTType(filenameExtension: "md")!,
                    UTType(filenameExtension: "gen")!,
                    UTType(filenameExtension: "smd")!,
                    UTType(importedAs: "net.daringfireball.markdown")
                ],
                allowsMultipleSelection: true
            ) { result in
                viewModel.handleFileImport(result)
            }
            .photosPicker(
                isPresented: $viewModel.showingImagePicker,
                selection: $viewModel.selectedPhotoItem,
                matching: .images
            )
            .onChange(of: viewModel.selectedPhotoItem) { _, _ in
                viewModel.handlePhotoSelection()
            }
            .onChange(of: viewModel.selectedPhotoItem) { _, _ in
                viewModel.handlePhotoSelection()
            }
            .onChange(of: viewModel.showEmulator) { _, newValue in
                if newValue {
                    viewModel.gameController.disableHomeNavigation = true
                    viewModel.gameController.disableMenuSounds = true
                } else {
                    viewModel.gameController.disableHomeNavigation = false
                    viewModel.gameController.disableMenuSounds = false
                }
            }

            .onChange(of: viewModel.pages) { _, _ in viewModel.saveLayout() }
            .onChange(of: viewModel.gameController.isEditingLayout) { _, newValue in
                if newValue {
                    viewModel.backupPages = viewModel.pages
                } else {
                    viewModel.saveLayout()
                }
            }
            .confirmationDialog("Delete Game?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let app = viewModel.appToDelete {
                        viewModel.deleteApp(app)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let app = viewModel.appToDelete {
                    Text("Are you sure you want to remove '\(app.name)' from Home?")
                } else {
                    Text("Are you sure you want to remove this item?")
                }
            }
            .onChange(of: gameController.widgetInternalNavigationActive) { _, newValue in
                if newValue {
                    viewModel.handleWidgetAction()
                }
            }
            .onReceive(viewModel.gameController.inputPublisher.receive(on: RunLoop.main)) { event in
                viewModel.handleGameInput(event)
            }
            .onReceive(viewModel.gameController.moveAction, perform: viewModel.handleControllerMove)
             .onChange(of: gameController.isControllerConnected) { _, isConnected in
                  if isConnected {
                      AppDelegate.orientationLock = .landscape
                      updateInterfaceOrientation(.landscapeRight)
                  } else {
                      AppDelegate.orientationLock = .all
                      updateInterfaceOrientation(.portrait)
                  }
              }
            .onChange(of: viewModel.showContent) { _, newValue in

            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowFullMediaControls"))) { _ in
                withAnimation {
                    viewModel.showFullMediaControls = true
                }
            }
            .onReceive(viewModel.$isInitialLoad) { isInitial in
                if !isInitial {
                    withAnimation {
                        appLoading = false
                    }
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
    }
}
