import SwiftUI

struct ROMCardView: View {
    let rom: ROMItem
    let isSelected: Bool
    var isLoading: Bool = false // External loading state
    
    @State private var thumbnailImage: UIImage?
    @State private var hasLoadedImage = false
    
    // Colores del borde según la plataforma
    private var borderGradientColors: [Color] {
        switch rom.console {
        case .ios:
           
            return [
                Color(red: 90/255, green: 200/255, blue: 250/255),
                Color(red: 0/255, green: 122/255, blue: 255/255)
            ]
        case .web:
    
            return [
                Color(red: 100/255, green: 240/255, blue: 255/255),
                Color(red: 0/255, green: 150/255, blue: 200/255)
            ]
        case .gameboyColor:
            return [Color(red: 0.55, green: 0.2, blue: 0.7), Color(red: 0.45, green: 0.15, blue: 0.6)]
        case .gameboyAdvance:
            
            return [Color(red: 0.35, green: 0.25, blue: 0.55), Color(red: 0.3, green: 0.2, blue: 0.5)]
        case .nes:
          
           
            return [
                Color(red: 57/255, green: 146/255, blue: 230/255),
                Color(red: 251/255, green: 70/255, blue: 73/255)
            ]
        case .snes:
           
            return [Color(red: 0.9, green: 0.9, blue: 0.95), Color(red: 0.7, green: 0.7, blue: 0.75)]
        case .nintendoDS:
            
            return [
                Color(red: 179/255, green: 229/255, blue: 246/255),
                Color(red: 105/255, green: 134/255, blue: 144/255)
            ]
        case .nintendo64:
          
            return [
                Color(red: 141/255, green: 181/255, blue: 203/255),
                Color(red: 70/255, green: 90/255, blue: 101/255)
            ]
        case .playstation:
          
            return [
                Color(red: 53/255, green: 152/255, blue: 228/255),
                Color(red: 35/255, green: 130/255, blue: 200/255)
            ]
        case .psp:
          
            return [
                Color(red: 102/255, green: 102/255, blue: 102/255),
                Color(red: 0/255, green: 0/255, blue: 0/255)
            ]
        case .segaGenesis:
         
            return [
                Color.black,
                Color.white
            ]
        case .manicEmu:
            // ManicEmu: Red/Black Gradient
            return [
                Color(red: 255/255, green: 0/255, blue: 0/255),
                Color.black
            ]
        case .meloNX:
           
            return [
                Color(red: 255/255, green: 255/255, blue: 255/255),
                Color(red: 255/255, green: 0/255, blue: 0/255)
            ]
        default:
        
            return [
                Color(red: 238/255, green: 230/255, blue: 91/255),
                Color(red: 213/255, green: 128/255, blue: 142/255)
            ]
        }
    }
    
    private var depthColor: Color {
        switch rom.console {
        case .ios:
            return Color(red: 0/255, green: 122/255, blue: 255/255)
        case .web:
            return Color(red: 0/255, green: 100/255, blue: 180/255)
        case .nintendoDS:
            return Color(red: 105/255, green: 134/255, blue: 144/255)
        case .nintendo64:
            return Color(red: 70/255, green: 90/255, blue: 101/255)
        case .psp:
            return Color(red: 0/255, green: 0/255, blue: 0/255)
        case .segaGenesis:
            return Color.black
        case .nes:
            return Color(red: 251/255, green: 70/255, blue: 73/255)
        case .meloNX:
            return Color(red: 255/255, green: 0/255, blue: 0/255)
        case .manicEmu:
             return Color.black
        default:
            return borderGradientColors[0]
        }
    }
    
    // Color del badge según la plataforma
    private var badgeColor: Color {
        switch rom.console {
        case .ios: return Color(red: 0/255, green: 122/255, blue: 255/255)
        case .web: return Color(red: 0/255, green: 180/255, blue: 220/255) 
        case .gameboyColor: return Color(red: 0.55, green: 0.2, blue: 0.7)
        case .gameboyAdvance: return Color(red: 0.3, green: 0.2, blue: 0.5)
        case .nes: return Color(red: 251/255, green: 70/255, blue: 73/255)
        case .snes: return Color(red: 0.7, green: 0.7, blue: 0.75)
        case .nintendoDS: return Color(red: 105/255, green: 134/255, blue: 144/255)
        case .nintendo64: return Color(red: 70/255, green: 90/255, blue: 101/255)
        case .playstation: return Color(red: 0.1, green: 0.2, blue: 0.6)
        case .psp: return Color(red: 0/255, green: 0/255, blue: 0/255)
        case .segaGenesis: return Color.black
        case .meloNX: return Color(red: 255/255, green: 50/255, blue: 50/255)
        case .manicEmu: return Color.black
        default: return Color(red: 213/255, green: 128/255, blue: 142/255)
        }
    }
    
    private var badgeText: String {
        switch rom.console {
        case .ios: return "iOS"
        case .web: return "WEB"
        case .gameboyColor: return "GBC"
        case .gameboyAdvance: return "GBA"
        case .nes: return "NES"
        case .snes: return "SNES"
        case .nintendoDS: return "NDS"
        case .nintendo64: return "N64"
        case .playstation: return "PSX"
        case .psp: return "PSP"
        case .segaGenesis: return "GEN"
        case .meloNX: return "N"
        case .manicEmu: return "MA"
        default: return "GB"
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Sombra 3D reducida y definida
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(isSelected ? 0.5 : 0.3))
                    .offset(x: 0, y: isSelected ? 6 : 3)
                    .blur(radius: isSelected ? 4 : 2)
                
                // Cartucho - Capa de profundidad lateral derecha (solo cuando está seleccionado)
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    depthColor.opacity(0.8),
                                    depthColor.opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 85, height: 85)
                        .offset(x: 3, y: 0)
                }
                
                // Cartucho - Borde principal (color de plataforma)
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: borderGradientColors,
                            startPoint: .bottomTrailing,
                            endPoint: .topLeading
                        )
                    )
                    .frame(width: 85, height: 85)
             
                // Área del artwork (placeholder gris o thumbnail)
                RoundedRectangle(cornerRadius: 11)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.75),
                                Color(white: 0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 73, height: 73)
                    .overlay(
                        Group {
                            if let image = thumbnailImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 73, height: 73)
                                    .clipShape(RoundedRectangle(cornerRadius: 11))
                                    .opacity(isLoading ? 0.3 : 1)
                                    
                             
                                if isLoading {
                                    VStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    }
                                }
                            } else if isLoading {
                                // Loading and no image yet
                                VStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                    Text("loading...")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            } else if !hasLoadedImage {
                                // Initial load state, show nothing or minimal placeholder
                                Color.clear 
                            } else {
                                // Loaded, no image found -> "Artwork" placeholder
                                VStack(spacing: 4) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 26, weight: .light))
                                        .foregroundColor(.white.opacity(0.4))
                                    
                                    Text("ARTWORK")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                        }
                    )
                 
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            if !rom.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(rom.displayName)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.black.opacity(0.8))
                                    .lineLimit(1)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        Color(red: 210/210, green: 213/210, blue: 250/255).opacity(0.85)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 6)
                    }
                    .frame(width: 73, height: 73)
                
                // Badge de consola sin sombra (fusionado con el borde)
                VStack {
                    HStack {
                        Text(badgeText)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(badgeColor)
                            )
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: 73, height: 73)
                .padding(3)
                // Title Overlay Removed (Moved to external view)
            }
            .frame(width: 85, height: 85)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .rotation3DEffect(
                .degrees(isSelected ? -8 : 0),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.5
            )
            .offset(y: isSelected ? -5 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
            .padding(20)
            .drawingGroup()
            .padding(-15)
            .onAppear {
                if !hasLoadedImage {
                    loadThumbnail()
                }
            }
            // Reload if custom path changes
            .onChange(of: rom.customThumbnailPath) { oldValue, newValue in
                loadThumbnail()
            }
            // Reload if name changes (might match new asset)
            .onChange(of: rom.displayName) { oldValue, newValue in
                loadThumbnail()
            }
            .onChange(of: rom.refreshId) { oldValue, newValue in
                loadThumbnail()
            }
        }
 
    }
    
    // Static serial queue to prevent thread explosion during rapid scrolling
    private static let imageLoadingQueue = DispatchQueue(label: "com.sumee.romImageLoading", qos: .userInitiated)
    
    // Helper to force decompression on background thread
    private func forceDecompress(image: UIImage) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(at: .zero)
        let decompressedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return decompressedImage ?? image
    }
    
    private func loadThumbnail() {
     
        hasLoadedImage = false 
        thumbnailImage = nil
        
  
        ROMCardView.imageLoadingQueue.async {
      
            let rawImage = rom.getThumbnail()
            
         
            var finalImage: UIImage? = nil
            if let image = rawImage {
                finalImage = self.forceDecompress(image: image)
            }
            
            DispatchQueue.main.async {
                self.thumbnailImage = finalImage
                self.hasLoadedImage = true
                
                // If still no image, try download (which handles its own threading)
                if finalImage == nil {
                    ROMStorageManager.shared.downloadArtwork(for: self.rom) { success in
                     
                    }
                }
            }
        }
    }
    

}
