import SwiftUI
import Combine

//  Sidebar Item
struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isFocused: Bool
    var profileImage: UIImage? = nil
    
    @Environment(\.colorScheme) var colorScheme
    
    // Aesthetic Color lol
    var iconColor: Color {
        colorScheme == .dark ? Color(red: 0.8, green: 0.8, blue: 0.85) : Color(red: 0.35, green: 0.38, blue: 0.42)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isSelected ? Color.blue : iconColor, lineWidth: 1.5))
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isSelected ? .blue : iconColor)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
                }
            }
            .scaleEffect(isFocused ? 1.2 : 1.0)
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isFocused)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
            
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isSelected ? .blue : iconColor)
                .lineLimit(1)
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.clear)
    }
}

//   Store Card Background
struct StoreCardBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // 1. Solid Base (Wii U / 3DS Style
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.16) : Color.white)
            
            // 2. Subtle Border
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
            
            // 3. Very subtle bottom accent (3DS Folder Style)
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
                    .frame(height: 30)
                    .mask(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

//   Store Grid Item
struct StoreGridItem: View {
    let item: StoreItem
    let isFocused: Bool
    let isInstalled: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon / Thumbnail Area
            ZStack {
                Color.clear
                
                if let uiImage = UIImage(named: item.iconName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .padding(12)
                } else {
                    Image(systemName: item.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(Color(red: 0.4, green: 0.45, blue: 0.5))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
            .frame(height: 70) // Reduced from 80
            
            // Info Area
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
      
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : Color(red: 0.2, green: 0.2, blue: 0.2)) 
                    .lineLimit(1)
                
                HStack {
                    if isInstalled {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("INSTALLED")
                                .font(.system(size: 9, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.2))
                        )
                    } else {
                        Text("ADD")
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                            )
                    }
                    
                    Spacer()
                    
                    if let size = item.systemApp?.downloadSize {
                         Text(size)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
        }
        .background(StoreCardBackground())
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(isFocused ? 0.3 : 0.1), radius: isFocused ? 12 : 4, x: 0, y: isFocused ? 8 : 4)
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .offset(y: isFocused ? -8 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

// Store Status Header
struct StoreStatusHeader: View {
    @State private var currentDate = Date()
    @State private var batteryLevel: Float = 1.0
    @State private var batteryState: UIDevice.BatteryState = .unknown
    @ObservedObject private var profileManager = ProfileManager.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 16) {
                // Date
                Text(currentDate.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .gray : .gray)
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
                
                // Time
                Text(currentDate.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
                
                // Battery
                HStack(spacing: 4) {
                    Text("\(Int(batteryLevel * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(batteryColor)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
                    
                    Image(systemName: batteryIcon)
                        .font(.system(size: 18))
                        .foregroundColor(batteryColor)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
                }

                // Profile Image (Right Side)
                if let profileImage = profileManager.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 2, y: 2)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .overlay(
                        Capsule()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .onReceive(timer) { input in
            currentDate = input
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            batteryLevel = UIDevice.current.batteryLevel
            batteryState = UIDevice.current.batteryState
        }
    }
    
    var batteryColor: Color {
        if batteryState == .charging { return .green }
        else if batteryLevel < 0.2 { return .red }
        else { return colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8) }
    }
    
    var batteryIcon: String {
        if batteryState == .charging { return "battery.100.bolt" }
        if batteryLevel > 0.8 { return "battery.100" }
        if batteryLevel > 0.5 { return "battery.75" }
        if batteryLevel > 0.2 { return "battery.50" }
        return "battery.25"
    }
}

// Sidebar Background
struct StoreSidebarBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.16) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
        }
    }
}

//  Playstation Background
struct PlaystationThemedBackground: View {
    @State private var animate = false
    @State private var gradientRotation = 0.0
    @Environment(\.colorScheme) var colorScheme
    
    // Light Mode Colors
    let lightColors = [
        Color(red: 0.96, green: 0.97, blue: 1.0),
        Color(red: 0.92, green: 0.94, blue: 0.98),
        Color(red: 0.97, green: 0.96, blue: 0.98),
        Color(red: 0.96, green: 0.97, blue: 1.0)
    ]
    
    // Dark Mode Colors (Deep, Dark Blue/Purple/Black mix)
    let darkColors = [
        Color(red: 0.05, green: 0.07, blue: 0.12),
        Color(red: 0.08, green: 0.06, blue: 0.15),
        Color(red: 0.04, green: 0.04, blue: 0.10),
        Color(red: 0.05, green: 0.07, blue: 0.12)
    ]
    
    var body: some View {
        ZStack {
            AngularGradient(
                gradient: Gradient(colors: colorScheme == .dark ? darkColors : lightColors),
                center: .center
            )
            // .blur(radius: 20) // Removed for performance
            .scaleEffect(3)
            .rotationEffect(.degrees(gradientRotation))
            .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: gradientRotation)
            .ignoresSafeArea()
            .onAppear {
                gradientRotation = 360
            }
            
            GeometryReader { geo in
                ZStack {
                    FloatingShape(icon: "triangle.fill", color: .green, size: 80)
                        .position(x: geo.size.width * 0.15, y: geo.size.height * 0.2)
                        .offset(x: animate ? 40 : -40, y: animate ? -30 : 30)
                        .opacity(colorScheme == .dark ? 0.3 : 0.6)
                        .rotationEffect(.degrees(animate ? 10 : -25))
                        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animate)
                    
                    FloatingShape(icon: "circle.fill", color: .red, size: 120)
                        .position(x: geo.size.width * 0.8, y: geo.size.height * 0.8)
                        .offset(x: animate ? -50 : 30, y: animate ? -60 : 20)
                        .opacity(colorScheme == .dark ? 0.25 : 0.5)
                        .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
                        
                    FloatingShape(icon: "multiply", color: .blue, size: 60)
                        .position(x: geo.size.width * 0.85, y: geo.size.height * 0.25)
                        .offset(x: animate ? -30 : 30, y: animate ? 40 : -20)
                        // Removed expensive shadow
                        .rotationEffect(.degrees(animate ? 45 : 0))
                        .opacity(colorScheme == .dark ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animate)
                        
                    FloatingShape(icon: "square.fill", color: .pink, size: 70)
                        .position(x: geo.size.width * 0.2, y: geo.size.height * 0.75)
                        .offset(x: animate ? 60 : -20, y: animate ? 30 : -50)
                        // Removed expensive shadow
                        .rotationEffect(.degrees(animate ? -30 : 15))
                        .opacity(colorScheme == .dark ? 0.6 : 1.0)
                        .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: animate)
                        
                    FloatingShape(icon: "circle.fill", color: .purple, size: 40)
                        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                        .offset(x: animate ? -100 : 100, y: animate ? 100 : -100)
                        .opacity(colorScheme == .dark ? 0.2 : 0.3)
                        .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: animate)
                }
                .drawingGroup() // Offload compositing to GPU
            }
        }
        .allowsHitTesting(false) // Optimized: No interaction
        .onAppear {
            animate = true
        }
    }
}

struct FloatingShape: View {
    let icon: String
    let color: Color
    let size: CGFloat
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.8), color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .mask(
                        LinearGradient(colors: [.clear, .white], startPoint: .bottomTrailing, endPoint: .topLeading)
                    )
            )
    }
}
