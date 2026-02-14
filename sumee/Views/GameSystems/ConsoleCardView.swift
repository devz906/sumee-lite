import SwiftUI

struct ConsoleCardView: View {
    let console: ROMItem.Console
    let offset: Int

    let dragOffset: CGFloat
    let isSelectingConsole: Bool
    let gameCount: Int
    let imageName: String?
    
    
    var body: some View {
        // --- Dynamic Position & Animation Logic ---


        let baseX: CGFloat = 0
        let baseY = CGFloat(offset) * 160
        
     
        let dragX: CGFloat = 0
        let dragY = isSelectingConsole ? dragOffset : 0
        
        let xOffset = baseX + dragX
        let yOffset = baseY + dragY
  
        let distanceFromCenter = abs(yOffset)
        

        let selectionThreshold: CGFloat = 160
        
  
        let rawProgress = distanceFromCenter / selectionThreshold
        let progress = max(0, min(1, rawProgress))
        
        let scale = 1.3 - (0.3 * progress)
        

        let textOpacity = max(0, 1.0 - (rawProgress * 1.5)) 

        let cardOpacity = 1.0 - (0.4 * progress)


        ZStack {
            if let imageName = imageName {
                if imageName.hasPrefix("/") {
                
                    if let cached = SettingsManager.shared.getCustomConsoleIcon(for: console) {
                         Image(uiImage: cached)
                            .resizable()
                            .scaledToFill()
                    } else if let image = UIImage(contentsOfFile: imageName) {
                         // Fallback for non-cached paths
                         Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                         Color.gray // Fail safe
                    }
                } else {
                    // It's an Asset Name
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                }
            } else {
                // Fallback for missing images
                ZStack {
                    Color.gray
                    Text(console.systemName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 120, height: 120)
        .background(Color.white)
        .cornerRadius(10)
        //.shadow(color: .black.opacity(0.15), radius: 1, x: 4, y: 4)
        // Overlay the text details so they don't affect the frame/layout of the card
        .overlay(alignment: .leading) {
            HStack {
                if isSelectingConsole {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(console.systemName)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                            //.shadow(color: .black.opacity(0.15), radius: 1, x: 4, y: 4)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 10))
                            Text("\(gameCount) Games")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.8))
                        .foregroundColor(.gray)
                        .clipShape(Capsule())
                        //.shadow(color: .black.opacity(0.15), radius: 1, x: 4, y: 4)
                    }
                    .padding(.leading, 12)
                } else {
                    // Sidebar Mode: Clean look (No text, no chevron)
                }
                Spacer()
            }
            .frame(width: 250, alignment: .leading)
            .offset(x: 125)
            .opacity(textOpacity)
        }
        // Apply transformations to the fixed 120x120 frame
        .scaleEffect(scale)
      
        .offset(x: xOffset, y: yOffset)
        .opacity(cardOpacity)
        .zIndex(Double(1000.0 - Double(distanceFromCenter)))
    }
    
}
