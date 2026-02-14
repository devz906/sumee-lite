import SwiftUI

struct GameOptionsMenuView: View {
    @Binding var isPresented: Bool
    @ObservedObject var gameController: GameControllerManager
    
    // Actions
    var onAddToHome: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onManageSaves: (() -> Void)? = nil
    var onManageSkins: (() -> Void)? = nil
    var onDelete: () -> Void
    var onCancel: () -> Void
    
    // Internal state to map index to action
    @State private var options: [MenuOption] = []
    @State private var selectedIndex: Int = 0
    @State private var isShowingSubmenu: Bool = false
    
    enum MenuOption: String, CaseIterable {
        case addToHome = "Add to Home"
        case edit = "Edit Details"
        case moreOptions = "More Options"
        case manageSaves = "Save Data"
        case manageSkins = "Skins"
        case delete = "Delete Game"
        case back = "Back"
        case cancel = "Cancel"
        
        var icon: String {
            switch self {
            case .addToHome: return "house"
            case .edit: return "pencil"
            case .moreOptions: return "ellipsis.circle"
            case .manageSaves: return "sdcard"
            case .manageSkins: return "paintpalette"
            case .delete: return "trash"
            case .back: return "arrow.left"
            case .cancel: return "xmark.circle"
            }
        }
    }

    var body: some View {
        ZStack {
            // Invisible dismiss layer
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Menu Card
            VStack(spacing: 0) {
                // Header
                Text(isShowingSubmenu ? "More Options" : "Game Options")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.35, green: 0.38, blue: 0.42))
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    if index > 0 {
                        Divider().padding(.horizontal, 16)
                    }
                    
                    Button(action: {
                        selectedIndex = index
                        handleAction(for: option)
                    }) {
                        HStack {
                            Text(option.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(option == .delete ? .red : Color(red: 0.2, green: 0.2, blue: 0.2))
                            Spacer()
                            Image(systemName: option.icon)
                                .font(.system(size: 16))
                                .foregroundColor(option == .delete ? .red : Color(red: 0.35, green: 0.38, blue: 0.42))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(selectedIndex == index ? Color.blue.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                    }
                }
            }
            .background(
                ZStack {
                    // 1. Bright White Blur Base
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Material.ultraThin)
                        .environment(\.colorScheme, .light)
                    
                    // 2. White Gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.white.opacity(0.1), location: 0),
                                    .init(color: Color.white.opacity(0.6), location: 0.5),
                                    .init(color: Color.white.opacity(1.0), location: 0.85),
                                    .init(color: Color.white.opacity(1.0), location: 1.0)
                                ]),
                                center: .center,
                                startRadius: 30,
                                endRadius: 300
                            )
                        )
                    
                    // 3. Dot Grid Texture
                    Canvas { context, size in
                        let spacing: CGFloat = 5.0
                        let dotSize: CGFloat = 1.5
                        for x in stride(from: 0, to: size.width, by: spacing) {
                            for y in stride(from: 0, to: size.height, by: spacing) {
                                let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.4)))
                            }
                        }
                    }
                    .blendMode(.overlay)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    // 4. Border Glow
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white, lineWidth: 6)
                        .blur(radius: 6)
                        .opacity(0.8)

                    // 5. Definition Rim
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white, lineWidth: 1)
                        .opacity(0.5)
                }
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 8)
            )
            .frame(width: 280)
            .id(isShowingSubmenu)
            .transition(.asymmetric(
                insertion: .move(edge: isShowingSubmenu ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: isShowingSubmenu ? .leading : .trailing).combined(with: .opacity)
            ))
        }
        .zIndex(1000)
        .onAppear {
            updateOptions()
        }
        // Controller Input Handling
        .onChange(of: gameController.dpadDown) { _, newValue in
            guard isPresented && newValue else { return }
            if selectedIndex < options.count - 1 {
                selectedIndex += 1
                AudioManager.shared.playMoveSound()
            }
        }
        .onChange(of: gameController.dpadUp) { _, newValue in
            guard isPresented && newValue else { return }
            if selectedIndex > 0 {
                selectedIndex -= 1
                AudioManager.shared.playMoveSound()
            }
        }
        .onChange(of: gameController.buttonAPressed) { _, newValue in
            guard isPresented && newValue else { return }
            handleSelection()
        }
        .onChange(of: gameController.buttonBPressed) { _, newValue in
            guard isPresented && newValue else { return }
            if isShowingSubmenu {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isShowingSubmenu = false
                    updateOptions()
                }
                AudioManager.shared.playSelectSound()
            } else {
                onCancel()
            }
        }
    }
    
    private func updateOptions() {
        options = []
        if !isShowingSubmenu {
            // Main Menu
            if onAddToHome != nil { options.append(.addToHome) }
            if onEdit != nil { options.append(.edit) }
            options.append(.moreOptions)
            options.append(.cancel)
        } else {
            // Submenu
            if onManageSaves != nil { options.append(.manageSaves) }
            if onManageSkins != nil { options.append(.manageSkins) }
            options.append(.delete)
            options.append(.back)
        }
        selectedIndex = 0
    }
    
    private func handleSelection() {
        guard selectedIndex < options.count else { return }
        let option = options[selectedIndex]
        handleAction(for: option)
    }
    
    private func handleAction(for option: MenuOption) {
        AudioManager.shared.playSelectSound()
        switch option {
        case .addToHome: onAddToHome?()
        case .edit: onEdit?()
        case .moreOptions:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isShowingSubmenu = true
                updateOptions()
            }
        case .manageSaves: onManageSaves?()
        case .manageSkins: onManageSkins?()
        case .delete: onDelete()
        case .back:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isShowingSubmenu = false
                updateOptions()
            }
        case .cancel: onCancel()
        }
    }
}
