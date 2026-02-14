import SwiftUI
import UIKit

struct StoreCommunityView: View {
    @ObservedObject var storeViewModel: StoreViewModel
    @ObservedObject var settings = SettingsManager.shared
    
    // Community Themes Data
    struct CommunityTheme: Identifiable {
        let id = UUID()
        let title: String
        let author: String
        let fileName: String
        let previewColor: Color
    }
    
    let themes = [
        CommunityTheme(title: "Playful Pastel", author: "SUMEE!", fileName: "SUMEE!_PlayfulPastel", previewColor: Color(hex: "#FFB3BA") ?? .pink),
        CommunityTheme(title: "Sloop's Theme", author: "Sloops", fileName: "Sloops_Theme", previewColor: Color(hex: "#6E93FF") ?? .blue),
        CommunityTheme(title: "Purple Wave V3", author: "Sloops", fileName: "Sloops_PurpleWaveV2", previewColor: Color(hex: "#9B51E0") ?? .purple),
        CommunityTheme(title: "Default Refresh", author: "System", fileName: "theme_default", previewColor: .gray)
    ]
    
    @State private var hoverIndex: Int = 0
    @State private var isImporting: Bool = false
    @State private var showRestartAlert: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            // Calculate columns for grid navigation
            
            let availableWidth = geo.size.width - 80
            let itemWidth: CGFloat = 160
            let spacing: CGFloat = 20
            let cols = max(1, Int((availableWidth + spacing) / (itemWidth + spacing)))
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Community Themes")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Themes created by the SUMEE community")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                // Grid
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 20)], spacing: 20) {
                            ForEach(0..<themes.count, id: \.self) { index in
                                let theme = themes[index]
                                CommunityThemeItem(
                                    theme: theme,
                                    isSelected: hoverIndex == index,
                                    onTap: {
                                        importAndApply(theme: theme)
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        // Bottom spacer
                        Color.clear.frame(height: 50)
                    }
                    .onChange(of: hoverIndex) { _, newIndex in
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
            .overlay(
                Group {
                    if isImporting {
                        ZStack {
                            Color.black.opacity(0.7).ignoresSafeArea()
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                Text("Importing Theme...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .padding(40)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.systemGray6)))
                        }
                    }
                }
            )
            // Controller Support
            .onReceive(GameControllerManager.shared.$dpadRight) { pressed in
                if pressed {
                    if hoverIndex < themes.count - 1 {
                        hoverIndex += 1
                        AudioManager.shared.playNavigationSound()
                    }
                }
            }
            .onReceive(GameControllerManager.shared.$dpadLeft) { pressed in
                if pressed {
                    if hoverIndex > 0 {
                        hoverIndex -= 1
                        AudioManager.shared.playNavigationSound()
                    }
                }
            }
            .onReceive(GameControllerManager.shared.$dpadDown) { pressed in
                if pressed {
                    let nextIndex = hoverIndex + cols
                    if nextIndex < themes.count {
                        hoverIndex = nextIndex
                        AudioManager.shared.playNavigationSound()
                    } else {
             
                    }
                }
            }
            .onReceive(GameControllerManager.shared.$dpadUp) { pressed in
                if pressed {
                    let nextIndex = hoverIndex - cols
                    if nextIndex >= 0 {
                        hoverIndex = nextIndex
                        AudioManager.shared.playNavigationSound()
                    }
                }
            }
            .onReceive(GameControllerManager.shared.$buttonAPressed) { pressed in
                if pressed && !isImporting {
                    if themes.indices.contains(hoverIndex) {
                        importAndApply(theme: themes[hoverIndex])
                    }
                }
            }
        }
    }
    
    // Logic to Read JSON from Bundle and Import
    private func importAndApply(theme: CommunityTheme) {
        guard !isImporting else { return }
        
        AudioManager.shared.playSelectSound()
        isImporting = true
        
        // Simulating network\/process delay for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Try explicit subdirectory first, then root
            var targetUrl = Bundle.main.url(forResource: theme.fileName, withExtension: "json", subdirectory: "Themes")
            
            if targetUrl == nil {
                targetUrl = Bundle.main.url(forResource: theme.fileName, withExtension: "json")
            }
            
            if let url = targetUrl {
                do {
                    let data = try Data(contentsOf: url)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        
                        // 1. Import (SettingsManager parses and updates State)
                        if settings.importTheme(jsonString: jsonString) {
                            print("Community Theme Imported: \(theme.title)")
                        
                            // 2. Commit & Restart Sequence
      
                            
                            SettingsManager.shared.activeThemeID = "custom_photo"
                            
                            // Trigger Restart UI similar to CustomThemeSettingsView
                            NotificationCenter.default.post(name: Notification.Name("ForceRestartApp"), object: nil)
                            
                        } else {
                            print(" Failed to parse theme JSON")
                            isImporting = false
                        }
                    }
                } catch {
                    print(" Error reading theme file: \(error)")
                    isImporting = false
                }
            } else {
                print(" Theme file not found in bundle: \(theme.fileName)")
                isImporting = false
            }
        }
    }
}

struct CommunityThemeItem: View {
    let theme: StoreCommunityView.CommunityTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var previewImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Preview Box
                ZStack {
                    if let uiImage = previewImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 100) // Ensure frame constraint
                             .clipped() // Clip to frame
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.previewColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(height: 100)
                .shadow(color: isSelected ? theme.previewColor.opacity(0.6) : .clear, radius: 10, x: 0, y: 5)
                
                // Text
                VStack(spacing: 4) {
                    Text(theme.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .blue : .primary)
                        .lineLimit(1)
                    
                    Text("by \(theme.author)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .opacity(isSelected ? 1.0 : 0.5)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(), value: isSelected)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadPreview()
        }
    }
    
    private func loadPreview() {
        guard previewImage == nil else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileName = theme.fileName
            var url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Themes")
            if url == nil {
                url = Bundle.main.url(forResource: fileName, withExtension: "json")
            }
            
            guard let validUrl = url,
                  let data = try? Data(contentsOf: validUrl),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let base64 = json["base64Image"] as? String,
                  let imageData = Data(base64Encoded: base64),
                  let image = UIImage(data: imageData) else {
                return
            }
            
            DispatchQueue.main.async {
                self.previewImage = image
            }
        }
    }
}
