import SwiftUI

struct PhotosGalleryInlineView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var gameController = GameControllerManager.shared
    @ObservedObject private var screenshotManager = ScreenshotManager.shared
    
    private var screenshots: [Screenshot] { screenshotManager.screenshots }
    
    @State private var selectedScreenshot: Screenshot?
    @State private var showingDeleteAlert = false
    @State private var screenshotToDelete: Screenshot?
    @State private var selectedIndex: Int = 0
    @State private var showContent = false
    
    var body: some View {
        GeometryReader { mainGeo in
            let isPortrait = mainGeo.size.height > mainGeo.size.width
            let topPadding: CGFloat = isPortrait ? 110 : 70
            
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: topPadding)
                    
                    // Content
                    if screenshots.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No Screenshots Yet")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Take a screenshot to see it here")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: showContent)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                Color.clear.frame(height: 0)
                                    .id("top")
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 16)],
                                    spacing: 16
                                ) {
                                    ForEach(screenshots.indices, id: \.self) { index in
                                        Button(action: {
                                            AudioManager.shared.playSelectSound()
                                            selectedIndex = index
                                            selectedScreenshot = screenshots[index]
                                        }) {
                                            ZStack {
                                                // White card background
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white)
                                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                                
                                                if let image = screenshots[index].image {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 140, height: 140)
                                                        .clipped()
                                                        .cornerRadius(12)
                                                }
                                                
                                                // Selection indicator
                                                if selectedIndex == index {
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .strokeBorder(Color.blue, lineWidth: 4)
                                                }
                                            }
                                            .frame(width: 150, height: 150)
                                            .id(index)
                                            .drawingGroup() // OPTIMIZACIÓN CRÍTICA
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                screenshotToDelete = screenshots[index]
                                                showingDeleteAlert = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 24)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 40)
                                .animation(.easeOut(duration: 0.4), value: showContent)
                            }
                            .scrollIndicators(.hidden)
                            .onChange(of: selectedIndex) { oldValue, newValue in
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                        // Mask for smooth fade at top and bottom edges
                        .mask(
                            VStack(spacing: 0) {
                                LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom)
                                    .frame(height: 30) // Top fade area
                                Rectangle().fill(Color.black) // Middle stable area
                                LinearGradient(gradient: Gradient(colors: [.black, .clear]), startPoint: .top, endPoint: .bottom)
                                    .frame(height: 30) // Bottom fade area
                            }
                        )
                    }
                }
                
                // --- SCREENSHOT DETAIL OVERLAY ---
                if let screenshot = selectedScreenshot, let image = screenshot.image {
                    ZStack {
                        Color.black.ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    selectedScreenshot = nil
                                }
                            }
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(.vertical, 40)
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    selectedScreenshot = nil
                                }
                            }
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.3))) // Animación explícita en transición
                    .zIndex(5)
                }
                
  
                // Bottom Controls
                bottomControlsLayer(isPortrait: isPortrait)
                    .zIndex(10)
                
              
                VStack {
                    Color.clear
                        .frame(height: 70)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
            } // End ZStack
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // FullScreenCover removed to allow controls overlay
            .alert("Delete Screenshot?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let screenshot = screenshotToDelete {
                        deleteScreenshot(screenshot)
                    }
                }
            }
            .onAppear {
                // Enable joystick input by disabling home navigation
                gameController.disableHomeNavigation = true
                print(" Photos: disableHomeNavigation = \(gameController.disableHomeNavigation)")
                withAnimation {
                    showContent = true
                }
            }
            .onDisappear {
                // Re-enable home navigation when leaving photos
                gameController.disableHomeNavigation = false
            }
            .onChange(of: gameController.buttonAPressed) { oldValue, newValue in
                if newValue && !screenshots.isEmpty {
                    AudioManager.shared.playSelectSound()
                    selectedScreenshot = screenshots[selectedIndex]
                }
            }
            .onChange(of: gameController.buttonBPressed) { oldValue, newValue in
                if newValue {
                    AudioManager.shared.playSwipeSound()
                    if selectedScreenshot != nil {
                        // Cerrar foto
                        withAnimation { selectedScreenshot = nil }
                    } else {
                        // Cerrar galería
                        AudioManager.shared.playBackMusic()
                        withAnimation(.easeOut(duration: 0.4)) {
                            isPresented = false
                        }
                    }
                }
            }
            .onChange(of: gameController.buttonYPressed) { oldValue, newValue in
                if newValue && !screenshots.isEmpty {
                    screenshotToDelete = screenshots[selectedIndex]
                    showingDeleteAlert = true
                }
            }
            .onChange(of: gameController.dpadRight) { oldValue, newValue in
                if newValue && !screenshots.isEmpty {
                    let newIndex = min(selectedIndex + 1, screenshots.count - 1)
                    if newIndex != selectedIndex {
                        AudioManager.shared.playMoveSound()
                        selectedIndex = newIndex
                    } else {
                        AudioManager.shared.playMoveSound() // Sonido de pared
                    }
                }
            }
            .onChange(of: gameController.dpadLeft) { oldValue, newValue in
                if newValue && !screenshots.isEmpty {
                    let newIndex = max(selectedIndex - 1, 0)
                    if newIndex != selectedIndex {
                        AudioManager.shared.playMoveSound()
                        selectedIndex = newIndex
                    } else {
                        AudioManager.shared.playMoveSound() // Sonido de pared
                    }
                }
            }
            .onChange(of: gameController.dpadDown) { oldValue, newValue in
                if newValue && !screenshots.isEmpty {
                    let columns = 4
                    let newIndex = min(selectedIndex + columns, screenshots.count - 1)
                    if newIndex != selectedIndex {
                        AudioManager.shared.playMoveSound()
                        selectedIndex = newIndex
                    } else {
                        AudioManager.shared.playMoveSound() // Sonido de pared
                    }
                }
            }
            .onChange(of: gameController.dpadUp) { oldValue, newValue in
                if newValue && !screenshots.isEmpty {
                    let columns = 4
                    let newIndex = max(selectedIndex - columns, 0)
                    if newIndex != selectedIndex {
                        AudioManager.shared.playMoveSound()
                        selectedIndex = newIndex
                    } else {
                        AudioManager.shared.playMoveSound() // Sonido de pared
                    }
                }
            }
        }
    }    
    private func deleteScreenshot(_ screenshot: Screenshot) {
        screenshotManager.deleteScreenshot(screenshot)
        
        // Adjust selected index if needed
        if selectedIndex >= screenshots.count {
            selectedIndex = max(0, screenshots.count - 1)
        }
    }

    
    @ViewBuilder
    private func bottomControlsLayer(isPortrait: Bool) -> some View {
        if isPortrait {
            // Portrait: Unified, Scaled Back Button only
            VStack(spacing: 12) {
                // Indicators
                HStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 10))
                    Text("\(screenshots.count) photos")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.gray.opacity(0.6))
                .opacity(showContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: showContent)
                
                ControlCard(actions: [
                    ControlAction(icon: "b.circle", label: "Back", action: {
                        AudioManager.shared.playSwipeSound()
                        if selectedScreenshot != nil {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedScreenshot = nil
                            }
                        } else {
                            AudioManager.shared.playBackMusic()
                            withAnimation(.easeOut(duration: 0.4)) {
                                isPresented = false
                            }
                        }
                    })
                ], position: .center, isHorizontal: true, scale: 1.25)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 50)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: showContent)
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom) // Anchor to bottom
        } else {
            // Landscape: Split Controls (Original Layout)
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // Left button - Delete
                    ControlCard(actions: [
                        ControlAction(icon: "y.circle", label: "Delete")
                    ])
                    .opacity(showContent ? 1 : 0)
                    .offset(x: showContent ? 0 : -50)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: showContent)
                    
                    Spacer()
                    
                    // Page Indicators
                    HStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 10))
                        Text("\(screenshots.count) photos")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.gray.opacity(0.6))
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: showContent)
                    
                    Spacer()
                    
                    // Right buttons - Back / Open
                    ControlCard(actions: [
                        ControlAction(icon: "b.circle", label: "Back", action: {
                            AudioManager.shared.playSwipeSound()
                            if selectedScreenshot != nil {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedScreenshot = nil
                                }
                            } else {
                                withAnimation(.easeOut(duration: 0.4)) {
                                    isPresented = false
                                }
                            }
                        }),
                        ControlAction(icon: "a.circle", label: selectedScreenshot == nil ? "Open" : "")
                    ])
                    .opacity(showContent ? 1 : 0)
                    .offset(x: showContent ? 0 : 50)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: showContent)
                    .onTapGesture {
                        AudioManager.shared.playSwipeSound()
                        if selectedScreenshot != nil {
                            withAnimation { selectedScreenshot = nil }
                        } else {
                            withAnimation { isPresented = false }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            }
        }
    }
}

struct ScreenshotDetailView: View {
    let screenshot: Screenshot
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var gameController = GameControllerManager.shared
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            if let image = screenshot.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .alert("Delete Screenshot?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .onChange(of: gameController.buttonBPressed) { oldValue, newValue in
            if newValue {
                AudioManager.shared.playSwipeSound()
                dismiss()
            }
        }
        .onChange(of: gameController.buttonYPressed) { oldValue, newValue in
            if newValue {
                showingDeleteAlert = true
            }
        }
    }
}
