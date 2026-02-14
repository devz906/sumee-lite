import SwiftUI
import Combine

struct HomeLockScreenView: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var settings = SettingsManager.shared
    
    // Timer for updating clock
    @State private var currentDate = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Peel Logic
    @State private var peelDragAmount: CGFloat = 80.0 // Start partially peeled
    
    // Dynamic Initial Peel based on geometries will be calculated in body
    // Threshold to trigger unlock
    private let unlockThreshold: CGFloat = 250.0 // Slight increase to account for start offset
    
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            
        
            let isVertical = h > w
            
            // Responsive Initial Peel calculation
      
            let responsivePeel: CGFloat = isVertical 
                ? max(60, min(w * 0.18, 150))
                : max(60, min(w * 0.10, 100))
            
            // Limit peel so it doesn't go too far backwards (negative) or breakingly far
            let limitedPeel = max(responsivePeel, min(peelDragAmount, w * 1.5))
            
            ZStack {
                // 1. UNDERLYING CONTENT (Transparent/Void)
                
                // 2. MAIN LOCK CONTENT (Masked)
                LockScreenContent(isVertical: isVertical, size: geometry.size)
                    .mask(
                        PeelMaskShape(peelOffset: limitedPeel)
                            .animation(.interactiveSpring(), value: limitedPeel)
                    )
                
                // 3. THE FLAP
                PeelFlapPath(peelOffset: limitedPeel)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(white: 0.95), // Brighter white paper
                                Color(white: 0.85),
                                Color(white: 0.7)
                            ]),
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: -4, y: 4)
                    .animation(.interactiveSpring(), value: limitedPeel)
                    
                // 4. INTERACTION AREA
                Color.clear
                    .contentShape(Rectangle()) 
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handlePeelDrag(value, initialPeel: responsivePeel)
                            }
                            .onEnded { value in
                                handlePeelEnd(value, initialPeel: responsivePeel)
                            }
                    )
            }
            .frame(width: w, height: h) // Explicit Frame on ZStack
            .onAppear {
                peelDragAmount = responsivePeel
            }
            .onChange(of: w) { newWidth in
                 // Recalculate based on new orientation
                 let newIsVertical = geometry.size.height > newWidth // Approximation during rotation change
                 // Actually better to re-run logic:
                 let newPeel: CGFloat
                 // If width is larger than height (usually landscape)
                 if newWidth > geometry.size.height {
                     newPeel = max(60, min(newWidth * 0.10, 100)) // Horizontal logic
                 } else {
                     newPeel = max(60, min(newWidth * 0.18, 150)) // Vertical logic
                 }
                 withAnimation { peelDragAmount = newPeel }
            }
        }
        .onReceive(timer) { input in
            currentDate = input
        }
        .ignoresSafeArea()
    }
    
    //  Components
    
    @ViewBuilder
    func LockScreenContent(isVertical: Bool, size: CGSize) -> some View {
        ZStack {
            // Theme-aware Background
            if settings.activeTheme.isDark {
                // Dark Mode: Deep Black Gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color(white: 0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                // Light Mode: Light Gray Gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(white: 0.9),
                        Color(white: 0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            
            // Pattern overlay
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 600, height: 600)
                .offset(x: -200, y: -200)
            
            VStack(spacing: 0) {
                Text(timeString)
                    .font(.system(size: isVertical ? 80 : 90, weight: .light, design: .rounded))
                    .foregroundColor(settings.activeTheme.isDark ? .white : .black.opacity(0.8))
                    .shadow(color: settings.activeTheme.isDark ? .black.opacity(0.5) : .white.opacity(0.5), radius: 4, x: 0, y: 2)
                
                Text(dateString)
                    .font(.system(size: isVertical ? 20 : 22, weight: .medium, design: .rounded))
                    .foregroundColor(settings.activeTheme.isDark ? .white.opacity(0.9) : .black.opacity(0.6))
                    .shadow(color: settings.activeTheme.isDark ? .black.opacity(0.5) : .white.opacity(0.5), radius: 2, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -40)
        }
        .frame(width: size.width, height: size.height)
    }
    
    //Logic
    
    // Formatters
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentDate)
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        formatter.locale = Locale(identifier: "es_MX") // Spanish as per context
        return formatter.string(from: currentDate).capitalized
    }
    
    @State private var lastHapticValue: CGFloat = 0
    
    // Haptic Generators
    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    let notificationFeedback = UINotificationFeedbackGenerator()
    
    private func handlePeelDrag(_ value: DragGesture.Value, initialPeel: CGFloat) {
        // We project the drag (both x and y) onto the diagonal "pull" vector.
        let tx = value.translation.width  // Negative when pulling left
        let ty = value.translation.height // Positive when pulling down
        
        // 45 degree projection: (ty - tx) * 0.7 approx
        let projection = (ty - tx) * 0.7 
        
        // Add projection to the initial resting state
        let newPeel = max(initialPeel, initialPeel + projection)
        self.peelDragAmount = newPeel
        
        // Haptic Feedback Logic
        if abs(newPeel - lastHapticValue) > 10 { 
            impactFeedback.impactOccurred(intensity: 0.6)
            lastHapticValue = newPeel
        }
    }
    
    private func handlePeelEnd(_ value: DragGesture.Value, initialPeel: CGFloat) {
        if peelDragAmount > unlockThreshold {
            // Unlock
            print("🔓 Unlocking via Peel")
            notificationFeedback.notificationOccurred(.success) // Success Haptic
            
            withAnimation(.easeOut(duration: 0.3)) {
                self.peelDragAmount = 1500 // Fully peel off screen
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                unlock()
            }
        } else {
            // Snap back to initial folded state
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.peelDragAmount = initialPeel
            }
            lastHapticValue = initialPeel // Reset haptic tracker
        }
    }

    private func unlock() {
        viewModel.unlockTapCount = 0
        viewModel.isIdleMode = false
        // Reset haptic tracker
        lastHapticValue = 0
    }
}


// Shapes for Peel Effect

// 1. The Mask: Covers everything EXCEPT the Top-Right corner triangle defined by offset
struct PeelMaskShape: Shape {
    var peelOffset: CGFloat
    
    var animatableData: CGFloat {
        get { peelOffset }
        set { peelOffset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
       
        let p = peelOffset * 1.5 // Multiplier to make it feel responsive
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY)) // TL
        path.addLine(to: CGPoint(x: rect.maxX - p, y: rect.minY)) // Top Cut Point
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + p)) // Right Cut Point
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) // BR
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // BL
        path.closeSubpath()
        return path
    }
}

// 2. The Flap: The Triangle representing the back of the paper
struct PeelFlapPath: Shape {
    var peelOffset: CGFloat
    
    var animatableData: CGFloat {
        get { peelOffset }
        set { peelOffset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let p = peelOffset * 1.5
        if p <= 1 { return path }
        

        
        path.move(to: CGPoint(x: rect.maxX - p, y: rect.minY)) // Top Hinge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + p)) // Right Hinge
        path.addLine(to: CGPoint(x: rect.maxX - p, y: rect.minY + p)) // The Tip
        path.closeSubpath()
        
        return path
    }
}



