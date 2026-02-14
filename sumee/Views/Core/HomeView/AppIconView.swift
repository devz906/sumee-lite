import SwiftUI

struct AppIconView: View, Equatable {
    let item: AppItem
    var isSelected: Bool = false
    var shouldAnimate: Bool = true
    var isEditing: Bool = false
    var onDelete: (() -> Void)? = nil // Callback for delete action
    @State private var isPressed = false
    @State private var hasAppeared = false
    @State private var animate3D = false
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // 0. ROM Cover Art Support
                if item.isROM, let rom = item.romItem, let cover = rom.getThumbnail() {
                     ZStack {
                        // Image full size
                        Image(uiImage: cover)
                            .resizable()
                            .aspectRatio(contentMode: .fill) 
                            .clipShape(Circle())
                        
                        // Subtle Inner Border for depth
                         Circle()
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(isSelected ? 0.3 : 0.15), radius: isSelected ? 8 : 4, x: 0, y: 4)
                    
                } else if let customImage = SettingsManager.shared.getCustomSystemIcon(named: item.iconName) {
                    // 1. Custom Icon Override
                     ZStack {
                        Image(uiImage: customImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(Circle()) // VITA STYLE: Circle
                        
                        // Overlay OnClick Variant if selected
                        if isSelected {
                            // Construct Name
                            let components = item.iconName.components(separatedBy: "_")
                            let onClickName: String = {
                                if components.count > 1 {
                                    var newComp = components
                                    newComp.insert("OnClick", at: 1)
                                    return newComp.joined(separator: "_")
                                } else {
                                    return item.iconName + "_OnClick"
                                }
                            }()
                            
                            // Try loading custom override for the OnClick variant first
                            if let customClickImage = SettingsManager.shared.getCustomSystemIcon(named: onClickName) {
                                Image(uiImage: customClickImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(Circle())
                                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                            } else if let variantImage = UIImage(named: onClickName) {
                                // Fallback to bundle OnClick
                                Image(uiImage: variantImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(Circle())
                                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                            }
                        }
                    }
                    .shadow(color: Color.black.opacity(isSelected ? 0.3 : 0.15), radius: isSelected ? 8 : 4, x: 0, y: 4)
                    
                } else if let uiImage = UIImage(named: item.iconName) {
                    // 2. Custom Icon - Full Replacement (Standard System)
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(Circle()) // VITA STYLE
                        
                        // Overlay OnClick Variant if selected
                        if isSelected {
                            // Construct Name
                            let components = item.iconName.components(separatedBy: "_")
                            let onClickName: String = {
                                if components.count > 1 {
                                    var newComp = components
                                    newComp.insert("OnClick", at: 1)
                                    return newComp.joined(separator: "_")
                                } else {
                                    return item.iconName + "_OnClick"
                                }
                            }()
                            
                            if let variantImage = UIImage(named: onClickName) {
                                Image(uiImage: variantImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(Circle())
                                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                            }
                        }
                    }
                    .shadow(color: Color.black.opacity(isSelected ? 0.3 : 0.15), radius: isSelected ? 8 : 4, x: 0, y: 4)
                } else {
                    // Standard Icon - Container Style
                    // VITA STYLE: Circular container
                    Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(isSelected ? 0.3 : 0.15), radius: isSelected ? 8 : 4, x: 0, y: 4)
                    
                    // Inner colored background
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    item.color.opacity(0.3),
                                    item.color.opacity(0.15)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(4)
                    
                    // Icon
                    Image(systemName: item.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(item.color)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(VitaBubbleOverlay()) // Apply 3D Glass Effect
            .opacity(shouldAnimate ? (hasAppeared ? 1 : 0) : 1)
            .scaleEffect(shouldAnimate ? (hasAppeared ? (isPressed ? 0.92 : (isSelected ? 1.1 : 1.0)) : 0.3) : (isPressed ? 0.92 : (isSelected ? 1.1 : 1.0)))
            // Edit Mode: Dance Animation (Repeating 3D Tilt)
            .rotation3DEffect(.degrees(isEditing ? (animate3D ? 6 : -6) : 0), axis: (x: 1.0, y: 0.0, z: 0.0))
            .onAppear {
                // Start the infinite animation loop immediately
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    animate3D = true
                }
            }
            // Pressed / Selected Animations
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .animation(shouldAnimate ? .interpolatingSpring(stiffness: 170, damping: 15) : .none, value: hasAppeared)
            // Overlay del contorno seleccionado POR ENCIMA del contenido y otras apps
         
            .zIndex(isSelected ? 10 : 0)
            .overlay(
                 Group {
                     // 1. New Installation Badge
                     if item.isNewInstallation {
                         ZStack {
                             Circle()
                                 .fill(Color.blue)
                                 .shadow(radius: 4)
                             Image(systemName: "gift.fill")
                                 .resizable()
                                 .aspectRatio(contentMode: .fit)
                                 .frame(width: 32, height: 32)
                                 .foregroundColor(.white)
                                 .shadow(color: .white.opacity(0.5), radius: 5)
                         }
                         .frame(width: 40, height: 40)
                         .offset(x: 30, y: -30) // Top Right
                         .allowsHitTesting(false)
                     }
                     
                     // 2. Edit Mode Delete Badge
                     if isEditing && !item.isSpacer && item.name != "Empty" {
                        Button(action: {
                            onDelete?()
                        }) {
                            ZStack {
                                // Glassy Blue-Grey Background (Gradient for depth)
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.4, green: 0.5, blue: 0.6),
                                                Color(red: 0.2, green: 0.3, blue: 0.4)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 30, height: 30)
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                
                                // Apply the same Glass Effect as icons
                                VitaBubbleOverlay()
                                    .frame(width: 30, height: 30)
                                    .opacity(0.9) 
                                
                                // X Symbol
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            }
                        }
                        .offset(x: 35, y: -35)
                        .transition(.scale.combined(with: .opacity))
                     }
                 }
            )
            .onTapGesture {
                if !isEditing {
                    isPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPressed = false
                    }
                }
            }
            .onAppear {
                hasAppeared = true
            }
        }
    }
    
    static func == (lhs: AppIconView, rhs: AppIconView) -> Bool {
        // Optimized check: unique ID + visual properties ONLY
        return lhs.item.id == rhs.item.id &&
               lhs.item.iconName == rhs.item.iconName &&
               lhs.item.color == rhs.item.color && 
               lhs.isSelected == rhs.isSelected &&
               lhs.shouldAnimate == rhs.shouldAnimate &&
               lhs.isEditing == rhs.isEditing &&
               lhs.item.isNewInstallation == rhs.item.isNewInstallation
    }
}

// MARK: - 3D Bubble Effect
struct VitaBubbleOverlay: View {
    var body: some View {
        ZStack {
            // 1. Inner Highlight (Top Left Reflection)
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white.opacity(0.7), location: 0.0),
                            .init(color: .white.opacity(0.1), location: 0.4),
                            .init(color: .clear, location: 0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(0.95) // Slightly smaller to keep edge distinct
            
            // 2. Rim Light (Bottom Right)
            Circle()
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .white.opacity(0.4)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            
            // 3. Subtle Inner Shadow to fake curvature
            Circle()
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                .blur(radius: 1)
        }
        .allowsHitTesting(false) // Pass touches through
    }
}
