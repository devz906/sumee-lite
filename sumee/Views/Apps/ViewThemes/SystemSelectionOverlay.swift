import SwiftUI
import PhotosUI

struct SystemSelectionOverlay: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: SettingsManager
    
    // Controlled by Parent
    @Binding var selectionIndex: Int
    @Binding var slotSelectionIndex: Int
    @Binding var selectedApp: SystemApp?
    @Binding var targetSlot: IconSlot?
    @Binding var showIconPicker: Bool
    
    // Which of the 4 slots are we editing?
    enum IconSlot {
        case set1
        case set1Click
        case set2
        case set2Click
        
        var title: String {
            switch self {
            case .set1: return "Regular (Set 1)"
            case .set1Click: return "Clicked (Set 1)"
            case .set2: return "Regular (Set 2)"
            case .set2Click: return "Clicked (Set 2)"
            }
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    // Theme Colors
    var themeBlue: Color {
        Color(red: 0/255, green: 158/255, blue: 224/255)
    }
    
    var themeBg: Color {
        colorScheme == .dark 
            ? Color(red: 28/255, green: 28/255, blue: 30/255)
            : Color(red: 235/255, green: 235/255, blue: 240/255)
    }

    var cardBg: Color {
        colorScheme == .dark ? Color(red: 44/255, green: 44/255, blue: 46/255) : Color.white
    }
    
    var textMain: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.8)
    }

    // Filtered list of apps that allow icon customization
    private var themableApps: [SystemApp] {
        SystemApp.allCases.filter { app in
            switch app {
            case .meloNX, .tetris, .slither: return false
            default: return true
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                themeBg.ignoresSafeArea()
                PromptGridBackground(isDark: colorScheme == .dark)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        if selectedApp != nil {
                            Button(action: goBack) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(themeBlue)
                            }
                        }
                        
                        Text(selectedApp == nil ? "Select System App" : selectedApp!.rawValue)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(textMain)
                        
                        if selectedApp != nil {
                            Spacer()
                        }
                    }
                    .padding()
                    
                    if let app = selectedApp {
                        // Detail View (4 Slots)
                        slotSelectionView(for: app)
                    } else {
                        // Main List
                        appListView
                    }
                }
                .background(cardBg)
                .overlay(alignment: .topTrailing) {
                    Button(action: { withAnimation { isPresented = false } }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.gray.opacity(0.6))
                            .background(Circle().fill(cardBg))
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
                .cornerRadius(24)
                .shadow(radius: 20)
                .padding(20)
                .frame(maxWidth: 500, maxHeight: 600)
            }
        }
    }
    
    private func goBack() {
        withAnimation {
            selectedApp = nil
            targetSlot = nil
        }
        AudioManager.shared.playSelectSound()
    }
    
    private var appListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(themableApps.enumerated()), id: \.element) { index, app in
                        let isFocused = (index == selectionIndex)
                        
                        Button(action: {
                            withAnimation { selectedApp = app }
                            AudioManager.shared.playSelectSound()
                        }) {
                            HStack {
                                // Current Icon Preview (Normal Set 1)
                                let currentKey = getKey(for: app, slot: .set1)
                                if let custom = settings.getCustomSystemIcon(named: currentKey, ignoreActiveTheme: true) {
                                    Image(uiImage: custom)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(8)
                                } else if let stock = UIImage(named: currentKey) {
                                    Image(uiImage: stock)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(8)
                                } else {
                                    // Fallback for SF Symbols if missing bundle image
                                    Image(systemName: "square.dashed")
                                        .frame(width: 40, height: 40)
                                }
                                
                                Text(app.rawValue)
                                    .font(.headline)
                                    .foregroundColor(textMain)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(isFocused ? themeBlue : .gray)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
                            )
                            // Focus Border
                            .rotatingBorder(isSelected: isFocused, lineWidth: 3)
                            .scaleEffect(isFocused ? 1.02 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal)
                .onChange(of: selectionIndex) { newIndex in
                    withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
                }
            }
        }
    }
    
    private func slotSelectionView(for app: SystemApp) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    Text("Customize the 4 icon states for this app.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        // Mapped to indices 0, 1, 2, 3
                        slotButton(for: app, slot: .set1, index: 0)
                            .id(0)
                        slotButton(for: app, slot: .set1Click, index: 1)
                            .id(1)
                        slotButton(for: app, slot: .set2, index: 2)
                            .id(2)
                        slotButton(for: app, slot: .set2Click, index: 3)
                            .id(3)
                    }
                    .padding()
                    
                    // Reset Button (Index 4)
                    Button(action: {
                         resetAll(for: app)
                    }) {
                        Text("Reset to Default")
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                            .rotatingBorder(isSelected: slotSelectionIndex == 4, lineWidth: 3)
                            .scaleEffect(slotSelectionIndex == 4 ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: slotSelectionIndex == 4)
                    }
                    .id(4)
                    
                    // Bottom Padding for scrolling
                    Color.clear.frame(height: 50)
                }
            }
            .onChange(of: slotSelectionIndex) { _, newIndex in
                 withAnimation {
                     proxy.scrollTo(newIndex, anchor: .center)
                 }
            }
        }
    }
    
    private func slotButton(for app: SystemApp, slot: IconSlot, index: Int) -> some View {
        let key = getKey(for: app, slot: slot)
        let hasCustom = settings.customSystemIcons[key] != nil
        let isFocused = (slotSelectionIndex == index)
        
        return Button(action: {
            targetSlot = slot
            showIconPicker = true
        }) {
            VStack {
                // Preview
                if let custom = settings.getCustomSystemIcon(named: key, ignoreActiveTheme: true) {
                    Image(uiImage: custom)
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .frame(width: 80, height: 80)
                         .cornerRadius(16)
                         .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeBlue, lineWidth: 2))
                } else if let stock = UIImage(named: key) {
                     Image(uiImage: stock)
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .frame(width: 80, height: 80)
                         .cornerRadius(16)
                } else {
                     Image(systemName: "questionmark.square.dashed")
                         .resizable()
                         .frame(width: 80, height: 80)
                         .foregroundColor(.gray)
                }
                
                Text(slot.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(textMain)
                
                if hasCustom {
                    Text("Edited")
                        .font(.caption2)
                        .foregroundColor(themeBlue)
                }
            }
            .padding()
            .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
            .cornerRadius(16)
            .shadow(radius: 2)
            // Focus
            .rotatingBorder(isSelected: isFocused, lineWidth: 4)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        }
    }
    
    // Logic to reconstruct the exact keys used by AppIconView
    private func getKey(for app: SystemApp, slot: IconSlot) -> String {
        // Base name depends on Set 1 or Set 2
        let baseName: String
        switch slot {
        case .set1, .set1Click:
            baseName = app.iconName(for: 1)
        case .set2, .set2Click:
            baseName = app.iconName(for: 2)
        }
        
        // Add OnClick if needed
        switch slot {
        case .set1Click, .set2Click:
            let components = baseName.components(separatedBy: "_")
            if components.count > 1 {
                var newComp = components
                newComp.insert("OnClick", at: 1)
                return newComp.joined(separator: "_")
            } else {
                return baseName + "_OnClick"
            }
        default:
            return baseName
        }
    }
    
    private func resetAll(for app: SystemApp) {
        settings.resetCustomSystemIcon(for: getKey(for: app, slot: .set1))
        settings.resetCustomSystemIcon(for: getKey(for: app, slot: .set1Click))
        settings.resetCustomSystemIcon(for: getKey(for: app, slot: .set2))
        settings.resetCustomSystemIcon(for: getKey(for: app, slot: .set2Click))
        AudioManager.shared.playSelectSound()
    }
}

// Background Component (Local Copy)
private struct PromptGridBackground: View {
    var isDark: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let spacing: CGFloat = 30
                for x in stride(from: 0, through: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: height))
                }
                for y in stride(from: 0, through: height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(
                isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), 
                lineWidth: 1
            )
        }
    }
}
