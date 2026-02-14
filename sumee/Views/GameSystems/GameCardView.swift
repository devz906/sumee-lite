import SwiftUI


struct GameCardView: View {
    let rom: ROMItem
    let offset: Int
    let playtime: String
    let selectedActionIndex: Int
    let baseConsoleColors: [Color]

    var dragOffset: CGFloat = 0
    var onShowSaveManager: (() -> Void)? = nil 
    var onShowSkinManager: (() -> Void)? = nil 
    
    @State private var dominantColor: Color?
    @State private var secondaryColor: Color?
    
    // Rotating Border State Removed
    
    private var isSelected: Bool { offset == 0 }
    
    var body: some View {
        // --- Fluid Animation Mathematics ---
        let baseX = isSelected ? 0 : -180
        let baseY = isSelected ? 0 : CGFloat(offset) * 110
        
     
        let finalX = baseX
        let finalY = baseY + dragOffset
        
        let visualOffset = finalY
        let threshold: CGFloat = 110
        let progress = min(1.0, max(0.0, abs(visualOffset) / threshold))
     
        let width = 350.0 - (240.0 * progress) 
        
  
        let height = 106.0 - (12.0 * progress)
        
    
        let scale = 1.0 - (0.1 * progress)
    
        let detailsOpacity = max(0, 1.0 - (progress * 1.5))
        
     
        let bgOpacity = max(0, 1.0 - (progress * 1.2))
        
       
        let itemOpacity = 1.0 - (0.4 * progress)
  
        let interpolatedX = 0.0 - (160.0 * progress)

        return HStack(spacing: 0) {
   
            ZStack(alignment: .topLeading) {
                ROMThumbnailView(rom: rom)
               
                    .frame(width: 98.0 - (8.0 * progress), height: 98.0 - (8.0 * progress))
                    .cornerRadius(8)
            
            }
            .padding(.horizontal, 12 * (1.0 - progress))
            .padding(.vertical, 4 * (1.0 - progress))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white, lineWidth: 2.0 * progress)
            )

         
            VStack(alignment: .leading, spacing: 4) {
                Text(rom.displayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Playtime Display
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text(playtime)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, -2)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 10) {
                    
                    if !rom.console.isAppOrWeb {
                         // "Skins"
                         Button(action: {
                             onShowSkinManager?()
                         }) {
                             Image(systemName: "paintpalette.fill")
                                 .font(.system(size: 14))
                                 .foregroundColor(.white)
                                 .frame(width: 36, height: 36)
                                 .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.2)))
                                 .overlay(
                                     RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: selectedActionIndex == 0 ? 2 : 0)
                                 )
                                 .scaleEffect(selectedActionIndex == 0 ? 1.1 : 1.0)
                         }
                         .buttonStyle(PlainButtonStyle())
                        
                        // "Book"
                        Button(action: {
                            onShowSaveManager?()
                        }) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.2)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: selectedActionIndex == 1 ? 2 : 0)
                                )
                                .scaleEffect(selectedActionIndex == 1 ? 1.1 : 1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 6)
                    }
                }
                .padding(.leading, 4)
            }
            .padding(.vertical, 8)
            .padding(.trailing, 16)
            .opacity(detailsOpacity)
            .blur(radius: progress * 10)
            .scaleEffect(1.0 - (0.2 * progress), anchor: .leading)
            .frame(width: max(0, width - 110), alignment: .leading)
            .clipped()
            
            Spacer()
        }
        .background(
            ZStack {
                LinearGradient(
                    colors: gradientColors(),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(bgOpacity)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(height: height)
        .frame(width: width)
        
        .scaleEffect(scale)
        .offset(x: interpolatedX)
        .offset(y: finalY)
        .opacity(itemOpacity)
        .zIndex(Double(1000 - abs(visualOffset)))
        .onAppear { 
            if isSelected { loadDominantColor() }
        }
        .onChange(of: isSelected) { newValue in
            if newValue { loadDominantColor() }
        }
        .onChange(of: rom.id) { _ in
            dominantColor = nil // Clear stale color
            if isSelected { loadDominantColor() }
        }
    }
    

    
    // Gradient Logic
    func gradientColors() -> [Color] {
        if let dom = dominantColor {
            return [dom, dom.opacity(0.6)]
        } else {
            return baseConsoleColors
        }
    }
    
    // Color Loading
    func loadDominantColor() {

        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = rom.getThumbnail() else { return }
            
            if let avg = image.averageColor {
                let color = Color(uiColor: avg)
                DispatchQueue.main.async {
                    withAnimation(.linear(duration: 0.3)) {
                        self.dominantColor = color
                    }
                }
            }
        }
    }
    
    // HELPEr
    func actionButton(index: Int, icon: String, color: Color) -> some View {
        let isSelected = (selectedActionIndex == index)
        
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(isSelected ? 0.2 : 0.15), radius: 1, x: isSelected ? 3 : 2, y: isSelected ? 3 : 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 2)
                )
            
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 1.0), value: isSelected)
    }
}
