import SwiftUI
import Combine

struct StoreCarouselView: View {
    let items: [StoreItem]
    var isFocused: Bool = false // Logic controlled externally
    
    @State private var currentIndex = 0
    private let timer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    
    // Theme Colors for Glow Effect
    struct CarouselTheme {
        let colors: [Color]
        var mainColor: Color { colors.first ?? .blue }
        var gradient: LinearGradient {
            LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // Define themes with hex colors
    let themes: [CarouselTheme] = [
        CarouselTheme(colors: [Color(hex: "#FF512F") ?? .red, Color(hex: "#DD2476") ?? .purple]),
        CarouselTheme(colors: [Color(hex: "#4568DC") ?? .blue, Color(hex: "#B06AB3") ?? .purple]),
        CarouselTheme(colors: [Color(hex: "#11998e") ?? .green, Color(hex: "#38ef7d") ?? .mint]),
        CarouselTheme(colors: [Color(hex: "#DA22FF") ?? .purple, Color(hex: "#9733EE") ?? .indigo]),
        CarouselTheme(colors: [Color(hex: "#FF9966") ?? .orange, Color(hex: "#FF5E62") ?? .red])
    ]
    
    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            let activeTheme = themes[currentIndex % themes.count]
            
            ZStack {
                ForEach(0..<min(items.count, 8), id: \.self) { index in
                    if index == currentIndex {
                        CarouselCard(item: items[index], gradient: themes[index % themes.count].gradient)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                            .zIndex(1) // Ensure current item is on top
                    }
                }
            }
            .frame(height: 160)
            .mask(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white, lineWidth: isFocused ? 4 : 0) // Focus Ring
                    .shadow(color: isFocused ? Color.white.opacity(0.5) : .clear, radius: 8)
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            // Dynamic Colored Glow
            .shadow(
                color: activeTheme.mainColor.opacity(isFocused ? 0.6 : 0.4), // Reduced opacity
                radius: isFocused ? 12 : 6, // Reduced radius to prevent clipping
                x: 0,
                y: isFocused ? 0 : 4 // Adjusted offset
            )
            .padding(.top, 5)
            .animation(.easeInOut(duration: 0.4), value: currentIndex)
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            .accessibilityHidden(true) 
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: 0.8)) {
                    currentIndex = (currentIndex + 1) % min(items.count, 8)
                }
            }
        }
    }
}

struct CarouselCard: View {
    let item: StoreItem
    let gradient: LinearGradient
    
    var body: some View {
        ZStack(alignment: .leading) { // Changed to center alignment mostly
            // Background
            gradient
            
            // Texture
            Group {
                if let uiImage = UIImage(named: item.iconName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: item.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: 250, height: 250)
            .rotationEffect(.degrees(-20))
            .offset(x: 100, y: 30)
            .blur(radius: 2)
            .opacity(0.30)
            .blendMode(.overlay)
            
            // Content
            HStack(alignment: .center, spacing: 16) {
                // Icon
                if let uiImage = UIImage(named: item.iconName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                } else {
                    Image(systemName: item.iconName)
                        .font(.system(size: 36)) // Slightly smaller icon
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("FEATURED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.3)))
                    
                    Text(item.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded)) // Adjusted size
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                        .lineLimit(1)
                    
                    Text("Discover something new today.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12) // Reduced vertical padding
        }
        .drawingGroup() // Optimize rendering pipeline
    }
}
