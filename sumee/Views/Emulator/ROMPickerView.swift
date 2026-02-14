import SwiftUI
import UniformTypeIdentifiers

struct ROMPickerView: View {
    @State private var showFilePicker = false
    @State private var selectedROMs: [ROMFile] = []
    var onROMSelected: (URL) -> Void
    var onDismiss: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.15, green: 0.15, blue: 0.2)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: { onDismiss?() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Select ROM")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 30)
                }
                .padding()
                
                // ROM List or Empty State
                if selectedROMs.isEmpty {
                    VStack(spacing: 30) {
                        Spacer()
                        
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))
                        
                        VStack(spacing: 10) {
                            Text("No ROMs Added")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Tap the button below to add\nROM files (.gb, .gba, .nes, .snes, .sfc)")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                        
                        // Add ROM Button
                        Button(action: { showFilePicker = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                Text("Add ROM Files")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: 300)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.4, green: 0.7, blue: 0.3),
                                        Color(red: 0.3, green: 0.6, blue: 0.2)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                        }
                        .padding(.bottom, 40)
                    }
                } else {
                    // ROM List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(selectedROMs) { rom in
                                ROMRowView(rom: rom) {
                                    onROMSelected(rom.url)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Add More Button
                    Button(action: { showFilePicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                            Text("Add More ROMs")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    if ["gb", "gbc", "gba", "nes", "snes", "smc", "sfc", "md", "gen", "smd", "bin"].contains(url.pathExtension.lowercased()) {
                        let rom = ROMFile(url: url)
                        if !selectedROMs.contains(where: { $0.id == rom.id }) {
                            selectedROMs.append(rom)
                        }
                    }
                }
            case .failure(let error):
                print("Error selecting ROM: \(error.localizedDescription)")
            }
        }
        .onAppear {
            loadSavedROMs()
        }
    }
    
    func loadSavedROMs() {
        // Load previously selected ROMs from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "savedROMs"),
           let urls = try? JSONDecoder().decode([String].self, from: data) {
            selectedROMs = urls.compactMap { urlString in
                guard let url = URL(string: urlString) else { return nil }
                return ROMFile(url: url)
            }
        }
    }
    
    func saveROMs() {
        let urlStrings = selectedROMs.map { $0.url.absoluteString }
        if let data = try? JSONEncoder().encode(urlStrings) {
            UserDefaults.standard.set(data, forKey: "savedROMs")
        }
    }
}

struct ROMRowView: View {
    let rom: ROMFile
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // ROM Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.6, green: 0.73, blue: 0.06),
                                    Color(red: 0.5, green: 0.65, blue: 0.06)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // ROM Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(rom.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(rom.type.uppercased())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct ROMFile: Identifiable, Codable {
    let id: String
    let url: URL
    let name: String
    let type: String
    
    init(url: URL) {
        self.id = url.lastPathComponent
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.type = url.pathExtension
    }
}

struct ROMPickerView_Previews: PreviewProvider {
    static var previews: some View {
        ROMPickerView { _ in }
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
