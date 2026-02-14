import SwiftUI

struct StoreDetailView: View {
    let item: StoreItem
    let isInstalled: Bool
    var onInstall: () -> Void
    var onBack: () -> Void
    
    @ObservedObject var vm: StoreViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var animateIn = false
    
    // NOTE: Download logic moved to ViewModel for controller support
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
           
                Color.clear
                    .contentShape(Rectangle())
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        if vm.downloadState != .downloading {
                            onBack()
                        }
                    }
                
                // Content Card
                let isCompact = geo.size.width < 600 || geo.size.height > geo.size.width
                
                Group {
                    if vm.downloadState == .downloading {
                        // RETRO DOWNLOAD ANIMATION VIEW
                        RetroDownloadView(progress: vm.downloadProgress, color: item.color, iconName: item.iconName)
                            .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                    } else {
                        // NORMAL CONTENT
                        ScrollView(isCompact ? .vertical : []) {
                            ZStack { 
                                if isCompact {
                                     VStack(spacing: 24) {
                                          visualContent(isCompact: true)
                                          infoContent(isCompact: true)
                                     }
                                     .padding(.horizontal, 24)
                                     .padding(.vertical, 32)
                                } else {
                                     // Dynamic Horizontal Layout
                                     GeometryReader { innerGeo in
                                         HStack(spacing: 0) {
                                              visualContent(isCompact: false)
                                                  .frame(width: innerGeo.size.width * 0.4) // 40% Width
                                              infoContent(isCompact: false)
                                                  .padding(24) // Reduced padding
                                                  .frame(width: innerGeo.size.width * 0.6, alignment: .leading) // 60% Width
                                         }
                                     }
                                }
                            }
                        } // End ScrollView
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(colorScheme == .dark ? Color(hex: "#1a1a1a")! : Color.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                )
                .frame(
                    width: isCompact ? min(geo.size.width - 40, 400) : min(geo.size.width - 80, 700), // Slightly constrained max width
                    height: isCompact ? min(geo.size.height - 80, 700) : min(geo.size.height - 60, 400) // Tighter height constraint for landscape
                )
                .scaleEffect(animateIn ? 1.0 : 0.9)
                .opacity(animateIn ? 1.0 : 0.0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animateIn = true
            }
            // Logic handled in ViewModel now
        }
    }
    
    // Logic
    
    // startDownload() removed - logic in ViewModel
    
    //  Subviews
    
    @ViewBuilder
    func visualContent(isCompact: Bool) -> some View {
        ZStack {
            // Dynamic Background
            StartSplashBackground(color: item.color)
                .clipShape(RoundedRectangle(cornerRadius: isCompact ? 24 : 32, style: .continuous))
            
            VStack {
                Group {
                    if let uiImage = UIImage(named: item.iconName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: isCompact ? 100 : 140, maxHeight: isCompact ? 100 : 140)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 4) // Reduced shadow
                    } else {
                        Image(systemName: item.iconName)
                            .font(.system(size: isCompact ? 80 : 100))
                            .minimumScaleFactor(0.5)
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 4) // Reduced shadow
                    }
                }
                .scaleEffect(animateIn ? 1.0 : 0.8)
                .opacity(animateIn ? 1.0 : 0.0)
                
                Ellipse()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: isCompact ? 80 : 100, height: 10)
                    .blur(radius: 4)
                    .padding(.top, 20)
            }
        }
        .frame(height: isCompact ? 200 : nil)
    }
    
    @ViewBuilder
    func infoContent(isCompact: Bool) -> some View {
        VStack(alignment: isCompact ? .center : .leading, spacing: isCompact ? 16 : 24) {
            // Header
            VStack(alignment: isCompact ? .center : .leading, spacing: 8) {
                Text(item.systemApp?.developer ?? "Unknown Developer")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .minimumScaleFactor(0.8)
                
                Text(item.title)
                    .font(.system(size: isCompact ? 32 : 48, weight: .heavy, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.bottom, 4)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                HStack {
                    Text(item.systemApp?.category == .game ? "Game" : "App")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.blue.opacity(0.1)))
                        .foregroundColor(.blue)
                    
                    if let size = item.systemApp?.downloadSize, size != "N/A" {
                        Text(size)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.gray.opacity(0.1)))
                            .foregroundColor(.gray)
                    }
                }
            }
            .offset(y: animateIn ? 0 : 20)
            .opacity(animateIn ? 1.0 : 0.0)
            .layoutPriority(1)
            
            // Description
            // Use ScrollView for description independently to save space
            ScrollView(.vertical, showsIndicators: false) {
                Text(item.description)
                    .font(.system(size: isCompact ? 16 : 18, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                    .lineSpacing(4)
                    .multilineTextAlignment(isCompact ? .center : .leading)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxHeight: isCompact ? nil : 150) 
            .offset(y: animateIn ? 0 : 30)
            .opacity(animateIn ? 1.0 : 0.0)
            
            if !isCompact { Spacer(minLength: 0) }
            
            // Actions
            HStack(spacing: 20) {
                Group {
                    if vm.downloadState == .installed {
                        // Installed Status
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                            Text("INSTALLED")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.5)
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                        )
                        .scaleEffect(vm.detailFocus == .action ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: vm.detailFocus)
                    } else {
                        // Get Button
                        Button(action: { vm.startDownloadProcess() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                Text("ADD")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .minimumScaleFactor(0.5)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                            // Focus State
                            .overlay(
                                Capsule()
                                    .stroke(Color.white, lineWidth: vm.detailFocus == .action ? 3 : 0)
                                    .opacity(vm.detailFocus == .action ? 0.8 : 0)
                            )
                            .scaleEffect(vm.detailFocus == .action ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: vm.detailFocus)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .layoutPriority(2)
                Button(action: onBack) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        )
                        // Focus State
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: vm.detailFocus == .close ? 3 : 0)
                                .opacity(vm.detailFocus == .close ? 0.8 : 0)
                        )
                        .scaleEffect(vm.detailFocus == .close ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: vm.detailFocus)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .offset(y: animateIn ? 0 : 40)
            .opacity(animateIn ? 1.0 : 0.0)
        }
    }
}

// Reuse the nice background from StoreLaunchView logic but simplified
struct StartSplashBackground: View {
    let color: Color
    
    var body: some View {
        ZStack {
            // Clean gradient (Matte, no blur)
            LinearGradient(
                colors: [color.opacity(0.4), color.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Grid Removed as requested
        }
    }
}


// Retro Download View (Wii/3DS Style)
struct RetroDownloadView: View {
    var progress: CGFloat
    var color: Color
    var iconName: String
    
    @State private var floatingOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 40) {
             // Bouncing Icon
             ZStack {
                 Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                 
                 if let uiImage = UIImage(named: iconName) {
                     Image(uiImage: uiImage)
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .frame(width: 100, height: 100)
                         .shadow(radius: 10)
                 } else {
                     Image(systemName: iconName)
                         .font(.system(size: 60))
                         .foregroundColor(.white)
                 }
             }
             .offset(y: floatingOffset)
             .onAppear {
                 withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                     floatingOffset = -20
                 }
             }
             
             // Progress "Blocks"
             VStack(spacing: 12) {
                 Text("Adding...")
                     .font(.system(size: 18, weight: .bold, design: .monospaced))
                     .foregroundColor(.gray)
                 
                 HStack(spacing: 8) {
                     ForEach(0..<8) { index in
                         RoundedRectangle(cornerRadius: 4)
                             .fill(
                                 (CGFloat(index) / 8.0) < progress 
                                 ? color 
                                 : Color.gray.opacity(0.2)
                             )
                             // Flexible size: Aspect ratio 1, max 30, but can shrink
                             .aspectRatio(1.0, contentMode: .fit) 
                             .frame(maxWidth: 30) 
                             .overlay(
                                 RoundedRectangle(cornerRadius: 4)
                                     .stroke(Color.white.opacity(0.1), lineWidth: 1)
                             )
                             .scaleEffect((CGFloat(index) / 8.0) < progress ? 1.1 : 1.0)
                             .animation(.spring(response: 0.3, dampingFraction: 0.6), value: progress)
                     }
                 }
                 .padding(.horizontal, 40) 
                 
                 Text("\(Int(progress * 100))%")
                     .font(.system(size: 14, weight: .bold, design: .rounded))
                     .foregroundColor(.gray.opacity(0.8))
             }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
