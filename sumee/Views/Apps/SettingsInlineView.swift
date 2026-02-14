import SwiftUI
import UIKit

struct SettingsInlineView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject private var gameController = GameControllerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var audioManager = AudioManager.shared
    @State private var showContent = false
    @State private var selectedIndex: Int = 0


    


    public enum Row: Int, CaseIterable {
        case lightMode // Performance Mode
        case liteMode // NEW: Lite Mode
        case enableAutoSave // NEW: Optional Auto-Save
        case enableBackgroundMusic
        case enableUISounds

        case backgroundVolume
        case sfxVolume

        case idleTimer // New Option
        case showBatteryPercentage

        // christmasTheme was here
        case reduceTransparency

        case showFloatingCartridges // New Option
        // case showFloatingChat // [NEW] Floating Chat Bubbles
  
        // case floatingCartridgesQuality removed
        case floatingCartridgesBlur // New Option
        // case dsConfig // New Option
        case resetWelcome // New Option
        case resetDefaults
        case deleteBios
        // case exportLogs // New Option


        case discord
    }


    @State private var showDeleteBiosConfirmation = false
    @State private var exportLogsItem: LogExportItem?

    
    @ViewBuilder
    var mainContent: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width
            
            VStack {
                HStack(alignment: .center, spacing: 20) {
                     Spacer()
                     
                     // Floating Icon
                    if !isPortrait {
                         Image("icon_settings")
                             .resizable()
                             .aspectRatio(contentMode: .fill)
                             .frame(width: 130, height: 130)
                             .clipShape(RoundedRectangle(cornerRadius: 28))
                             .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.3), lineWidth: 1))
                             .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 8)
                             .rotationEffect(.degrees(-6))
                             .scaleEffect(showContent ? 1 : 0.8)
                             .offset(x: showContent ? 0 : -200) // Slide Left
                             .opacity(showContent ? 1 : 0)
                             .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showContent)
                         
                         Spacer()
                    }
                     
                    settingsPanel
                    
                    if isPortrait {
                        Spacer()
                    }
                }
                .padding(.top, isPortrait ? 130 : 80) // Increased top padding for portrait
                .padding(.trailing, isPortrait ? 0 : 20) // Removed extra trailing in portrait for centering
                .padding(.bottom, 20)
                Spacer() // Push to top
            }
            .frame(maxWidth: .infinity, alignment: .topTrailing)
        }

    }
    
    @ViewBuilder
    var settingsPanel: some View {
        VStack(spacing: 0) {
            // Settings list
            ScrollViewReader { proxy in
                ScrollView {
                    settingsList
                }
                .scrollIndicators(.hidden)
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("row-\(newValue)", anchor: .center)
                    }
                }
            }
            .frame(maxHeight: 520) // Constrain height to force scrolling
            .background(
                BubbleBackground(
                    position: .center,
                    cornerRadius: 35,
                    theme: settings.activeTheme,
                    reduceTransparency: settings.reduceTransparency
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 35))
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .onAppear {
                // gameController.disableHomeNavigation = true // Removed to allow continuous signals
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showContent = true }
                // Removed local state initialization since we are binding directly or applying instantly
                // s_lightMode init removed

            }
            .onDisappear { 
                // gameController.disableHomeNavigation = false 
            }
            // Controller Input Handlers attached to the bubble view
            .onChange(of: gameController.buttonAPressed) { _, newValue in if newValue { activateCurrentRow() } }
            .onChange(of: gameController.buttonBPressed) { _, newValue in if newValue { close() } }
            .onChange(of: gameController.buttonYPressed) { _, newValue in if newValue { activateCurrentRow() } }
            
            // CONTINUOUS CONTROL VIA MOVE ACTION
            .onReceive(gameController.moveAction) { direction in
                switch direction {
                case .up:
                    moveSelection(delta: -1)
                case .down:
                    moveSelection(delta: 1)
                case .left:
                    if let row = Row(rawValue: selectedIndex) {
                        if row == .backgroundVolume || row == .sfxVolume || row == .idleTimer { adjustCurrentSlider(by: -1) } // -1 indicates decrement
                        else { moveSelection(delta: -1) }
                    }
                case .right:
                    if let row = Row(rawValue: selectedIndex) {
                        if row == .backgroundVolume || row == .sfxVolume || row == .idleTimer { adjustCurrentSlider(by: 1) } // 1 indicates increment
                        else { moveSelection(delta: 1) }
                    }
                }
            }
        }
        .frame(width: 320)
        .offset(x: showContent ? 0 : 400) // Slide Right
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showContent)
    }
    
    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width
            
            ZStack(alignment: .bottom) {
                // Tap to close background - Unifies exit animation
                Color.white.opacity(0.001) // Invisible but hit-testable
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                
                // Main content (Bubble)
                mainContent
                    .allowsHitTesting(true)
                
                if !isPortrait {
                    bottomControls
                }
            }
            .contentShape(Rectangle()) // Ensure the ZStack takes hit testing correctly
            .alert(isPresented: $showDeleteBiosConfirmation) {
                Alert(
                    title: Text("Delete DS BIOS"),
                    message: Text("Are you sure you want to delete the imported DS BIOS files? You will need to import them again to play DS games."),
                    primaryButton: .destructive(Text("Delete")) {
                        DSBiosManager.shared.deleteAllBios()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .sheet(item: $exportLogsItem) { item in
            LogExportShareSheet(activityItems: [item.url])
        }
        // Side Effects for Settings Changes (Matches Touch & Controller)
        .onChange(of: settings.enableBackgroundMusic) { _, isEnabled in
            if isEnabled {
                audioManager.fadeInBackgroundMusic(targetVolume: settings.backgroundVolume)
            } else {
                audioManager.fadeOutBackgroundMusic(duration: 0.4)
            }
        }
        .onChange(of: settings.backgroundVolume) { _, newVolume in
            if settings.enableBackgroundMusic {
                audioManager.setVolume(newVolume)
            }
        }


        // Legacy updateLightModeState removed


        // Removed onChange of floatingCartridgesQuality
    }
    
    private var settingsList: some View {
        VStack(spacing: 16) {
            // Performance Mode
            settingToggleRow(title: "Performance Mode", isOn: performanceModeBinding, index: Row.lightMode.rawValue, icon: "speedometer")
            
       
            // Lite Mode
            VStack(alignment: .leading, spacing: 4) {
                SettingRowHelper(title: "Lite Mode", isOn: $settings.liteMode, index: Row.liteMode.rawValue, icon: "iphone.homebutton", selectedIndex: selectedIndex)
                
                if settings.liteMode {
                    Text("Restart required to activate")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.leading, 44) // Align with text
                }
                }
            
            // Auto-Save Toggle
             SettingRowHelper(title: "Auto-Save on Exit", isOn: $settings.enableAutoSave, index: Row.enableAutoSave.rawValue, icon: "arrow.triangle.2.circlepath", selectedIndex: selectedIndex)
            
            SettingsAudioView(settings: settings, selectedIndex: selectedIndex)
            SettingsVisualsView(settings: settings, selectedIndex: selectedIndex)
            SettingsDataView(selectedIndex: selectedIndex, showDeleteBiosConfirmation: $showDeleteBiosConfirmation, exportLogsItem: $exportLogsItem, settings: settings) // Pass necessary bindings
        }
        .padding(16) // Add inner padding to the content
        .padding(.bottom, 60) // Extra padding for scrolling past buttons
    }




struct SettingsAudioView: View {
    @ObservedObject var settings: SettingsManager
    var selectedIndex: Int

    var body: some View {
        Group {
            SettingRowHelper(title: "Background Music", isOn: $settings.enableBackgroundMusic, index: SettingsInlineView.Row.enableBackgroundMusic.rawValue, icon: "music.note", selectedIndex: selectedIndex)
            SettingRowHelper(title: "UI Sounds", isOn: $settings.enableUISounds, index: SettingsInlineView.Row.enableUISounds.rawValue, icon: "speaker.wave.2", selectedIndex: selectedIndex)

            
            SettingSliderRowHelper(title: "Music Volume", value: $settings.backgroundVolume, range: 0.0...1.0, index: SettingsInlineView.Row.backgroundVolume.rawValue, icon: "music.note.list", selectedIndex: selectedIndex)
            SettingSliderRowHelper(title: "SFX Volume", value: $settings.sfxVolume, range: 0.0...1.0, index: SettingsInlineView.Row.sfxVolume.rawValue, icon: "speaker.3", selectedIndex: selectedIndex)
        }
    }
}

struct SettingsVisualsView: View {
    @ObservedObject var settings: SettingsManager
    var selectedIndex: Int

    var body: some View {
        Group {


            SettingIdleSliderRow(value: $settings.idleTimerDuration, index: SettingsInlineView.Row.idleTimer.rawValue, selectedIndex: selectedIndex)
            
            SettingRowHelper(title: "Show Battery %", isOn: $settings.showBatteryPercentage, index: SettingsInlineView.Row.showBatteryPercentage.rawValue, icon: "battery.100", selectedIndex: selectedIndex)

            

            
            SettingRowHelper(title: "Reduce Transparency", isOn: $settings.reduceTransparency, index: SettingsInlineView.Row.reduceTransparency.rawValue, icon: "square.on.square.dashed", selectedIndex: selectedIndex)
            
            SettingRowHelper(title: "Floating Cartridges", isOn: $settings.showFloatingCartridges, index: SettingsInlineView.Row.showFloatingCartridges.rawValue, icon: "square.stack.3d.up.fill", selectedIndex: selectedIndex)
            
            // SettingRowHelper(title: "Floating Chat", isOn: $settings.showFloatingChat, index: SettingsInlineView.Row.showFloatingChat.rawValue, icon: "bubble.left.and.bubble.right.fill", selectedIndex: selectedIndex)

            SettingRowHelper(title: "Cartridge Blur Effect", isOn: $settings.floatingCartridgesBlur, index: SettingsInlineView.Row.floatingCartridgesBlur.rawValue, icon: "drop.triangle", selectedIndex: selectedIndex)
        }
    }
}

struct SettingsDataView: View {
    var selectedIndex: Int
    @Binding var showDeleteBiosConfirmation: Bool
    @Binding var exportLogsItem: LogExportItem?
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Group {
            /*
            SettingButtonRowHelper(title: "Reset DS Setup", icon: "arrow.counterclockwise.circle", color: .purple, index: SettingsInlineView.Row.dsConfig.rawValue, selectedIndex: selectedIndex, action: {
                UserDefaults.standard.set(false, forKey: "ds_firmware_configured")
                AppStatusManager.shared.show("DS Setup Reset", icon: "checkmark.circle")
                AudioManager.shared.playSelectSound()
            })
            */
            
            SettingButtonRowHelper(title: "Show Welcome Screen", icon: "hand.wave.fill", color: .cyan, index: SettingsInlineView.Row.resetWelcome.rawValue, selectedIndex: selectedIndex, action: {
                UserDefaults.standard.set(false, forKey: "ds_firmware_configured") // Keeping consistent action structure if needed, but original was just welcome reset
                UserDefaults.standard.set(false, forKey: "hasShownWelcome")
                AppStatusManager.shared.show("Welcome Reset", icon: "checkmark.circle")
                AudioManager.shared.playSelectSound()
            })
            
            ResetButtonRowHelper(index: SettingsInlineView.Row.resetDefaults.rawValue, selectedIndex: selectedIndex, settings: settings)
            SettingButtonRowHelper(title: "Delete DS BIOS", icon: "trash.circle", color: .orange, index: SettingsInlineView.Row.deleteBios.rawValue, selectedIndex: selectedIndex, action: {
                showDeleteBiosConfirmation = true
                AudioManager.shared.playSelectSound()
            })
            
            /*
            SettingButtonRowHelper(title: "Export Logs", icon: "folder.badge.gear", color: .blue, index: SettingsInlineView.Row.exportLogs.rawValue, selectedIndex: selectedIndex, action: {
                AudioManager.shared.playSelectSound()
                AppStatusManager.shared.show("Compressing Logs...", icon: "archivebox")
                
                settings.exportLogs { url in
                    DispatchQueue.main.async {
                        if let url = url {
                            exportLogsItem = LogExportItem(url: url)
                        } else {
                            AppStatusManager.shared.show("Export Failed", icon: "exclamationmark.triangle")
                        }
                    }
                }
            })
            */

            DiscordButtonRowHelper(index: SettingsInlineView.Row.discord.rawValue, selectedIndex: selectedIndex)
        }
    }
}

    private var performanceModeBinding: Binding<Bool> {
        Binding<Bool>(get: { settings.performanceMode }, set: { val in
            settings.performanceMode = val
            // s_lightMode is deprecated, using direct setting
            if !val {
               
  
            }
        })
    }

    private var bottomControls: some View {
        // Bottom controls
        HStack(alignment: .bottom) {
            Spacer()
            
            Spacer()
                .frame(width: 280)
                
            ControlCard(actions: [
                ControlAction(icon: "b.circle", label: "Back", action: { close() }),
                ControlAction(icon: "a.circle", label: "Select")
            ])
            .opacity(showContent ? 1 : 0)
        }
        .frame(height: 32)
        .padding(.horizontal, 20)
        .padding(.bottom, 2)
        .offset(y: -10)
        .animation(.easeOut(duration: 0.5).delay(0.6), value: showContent)
    }

    private func moveSelection(delta: Int) {
        let maxIndex = Row.allCases.count - 1
        var newIndex = selectedIndex + delta
        newIndex = max(0, min(newIndex, maxIndex))
        if newIndex != selectedIndex {
            AudioManager.shared.playMoveSound()
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        selectedIndex = newIndex
    }

    private func activateCurrentRow() {
        guard let row = Row(rawValue: selectedIndex) else { return }
        switch row {
        case .lightMode:
            settings.performanceMode.toggle()
            // Side effects handled in SettingsManager

        case .liteMode:
            settings.setLiteMode(!settings.liteMode)
            // No immediate launch, user must restart
            AudioManager.shared.playSelectSound()
        case .enableAutoSave:
            settings.enableAutoSave.toggle()
        case .enableBackgroundMusic:
            settings.enableBackgroundMusic.toggle()
        case .enableUISounds: settings.enableUISounds.toggle()

        case .backgroundVolume:
            settings.backgroundVolume = min(1.0, settings.backgroundVolume + 0.1)
        case .sfxVolume:
            settings.sfxVolume = min(1.0, settings.sfxVolume + 0.1)
        case .idleTimer:
            // Cycle: +30s, wrap to 0 (Disabled) if > 300
            let next = settings.idleTimerDuration + 30
            settings.idleTimerDuration = (next > 300) ? 0 : next


        case .showBatteryPercentage: settings.showBatteryPercentage.toggle()


        case .reduceTransparency:
            settings.reduceTransparency.toggle()
        case .showFloatingCartridges:
            settings.showFloatingCartridges.toggle()
        // case .showFloatingChat:
        //    settings.showFloatingChat.toggle()
        
        case .floatingCartridgesBlur:
            settings.floatingCartridgesBlur.toggle()

        /*
        case .dsConfig:
            UserDefaults.standard.set(false, forKey: "ds_firmware_configured")
            AppStatusManager.shared.show("DS Setup Reset", icon: "checkmark.circle")
            AudioManager.shared.playSelectSound()
        */
        
        case .resetWelcome:
            UserDefaults.standard.set(false, forKey: "hasShownWelcome")
            AppStatusManager.shared.show("Welcome Reset", icon: "checkmark.circle")
            AudioManager.shared.playSelectSound()
        case .resetDefaults:
            settings.resetToDefaults()
            // Sync light mode
            // Sync light mode not needed

            AudioManager.shared.playSelectSound()


        case .deleteBios:
            showDeleteBiosConfirmation = true
            AudioManager.shared.playSelectSound()
        /*
        case .exportLogs:
            AudioManager.shared.playSelectSound()
            AppStatusManager.shared.show("Compressing Logs...", icon: "archivebox")
            
            settings.exportLogs { url in
                DispatchQueue.main.async {
                    if let url = url {
                        exportLogsItem = LogExportItem(url: url)
                    } else {
                        AppStatusManager.shared.show("Export Failed", icon: "exclamationmark.triangle")
                    }
                }
            }
        */
        case .discord:
            if let url = URL(string: "https://discord.gg/Y9nmfurM") {
                UIApplication.shared.open(url)
            }
        }
        AudioManager.shared.playSelectSound()
    }

    private func adjustCurrentSlider(by delta: Float) {
        guard let row = Row(rawValue: selectedIndex) else { return }
        switch row {
        case .backgroundVolume:
            settings.backgroundVolume = max(0.0, min(1.0, settings.backgroundVolume + (delta > 0 ? 0.05 : -0.05)))
        case .sfxVolume:
            settings.sfxVolume = max(0.0, min(1.0, settings.sfxVolume + (delta > 0 ? 0.05 : -0.05)))
        case .idleTimer:
            // Delta is +1 or -1 from controller
            let step: Double = 10.0
            let change = (delta > 0 ? step : -step)
            let newValue = settings.idleTimerDuration + change
            // Clamp 0 to 300 (5 min)
            settings.idleTimerDuration = max(0.0, min(300.0, newValue))
        default:
            return
        }
        AudioManager.shared.playMoveSound()
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

    }

    // adjustQuality function removed



    
    private func applyDirectly() {
    }

    private func close() {
        AudioManager.shared.playSwipeSound()
        AudioManager.shared.playBackMusic()
        
        withAnimation(.easeIn(duration: 0.3)) {
            showContent = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }

    //  Rows

    private func settingToggleRow(title: String, isOn: Binding<Bool>, index: Int, icon: String, iconColor: Color? = nil) -> some View {
        let isDark = settings.activeTheme.isDark
        
        return ZStack {
            // Card background - Wii U style with soft shadows
            RoundedRectangle(cornerRadius: 20)
                .fill(settings.reduceTransparency ? (isDark ? Color(UIColor.secondarySystemBackground) : Color.white) : (isDark ? Color(UIColor.secondarySystemBackground).opacity(0.85) : Color.white.opacity(0.85)))
                .shadow(color: Color.black.opacity(selectedIndex == index ? 0.15 : 0.08), radius: selectedIndex == index ? 8 : 4, x: 0, y: selectedIndex == index ? 4 : 2)
            
            HStack(spacing: 10) {
                // Icon container with colored background
                ZStack {
                    if let color = iconColor {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: isDark ? [Color(white: 0.3), Color(white: 0.25)] : [
                                        Color(red: 0.95, green: 0.95, blue: 0.97),
                                        Color(red: 0.88, green: 0.88, blue: 0.92)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDark ? .white : Color(red: 0.45, green: 0.45, blue: 0.5))
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isDark ? .white : Color(red: 0.2, green: 0.2, blue: 0.25))
                }
                
                Spacer()
                
                // Toggle switch
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(Color(red: 0.3, green: 0.6, blue: 0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 2)

            // Selection indicator - cyan corners
            if selectedIndex == index {
                // Cyan corner indicators (Wii U style)
                VStack {
                    HStack {
                        cornerIndicator
                            .scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedIndex == index)
                        Spacer()
                        cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1))
                            .scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.05), value: selectedIndex == index)
                    }
                    Spacer()
                    HStack {
                        cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1))
                            .scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1), value: selectedIndex == index)
                        Spacer()
                        cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1))
                            .scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.15), value: selectedIndex == index)
                    }
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .id("row-\(index)")
    }

    private func settingSliderRow(title: String, value: Binding<Float>, range: ClosedRange<Float>, index: Int, icon: String) -> some View {
        let isDark = settings.activeTheme.isDark
        
        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(settings.reduceTransparency ? (isDark ? Color(UIColor.secondarySystemBackground) : Color.white) : (isDark ? Color(UIColor.secondarySystemBackground).opacity(0.85) : Color.white.opacity(0.85)))
                .shadow(color: Color.black.opacity(selectedIndex == index ? 0.15 : 0.08), radius: selectedIndex == index ? 8 : 4, x: 0, y: selectedIndex == index ? 4 : 2)
            
            HStack(spacing: 10) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: isDark ? [Color(white: 0.3), Color(white: 0.25)] : [
                                    Color(red: 0.95, green: 0.95, blue: 0.97),
                                    Color(red: 0.88, green: 0.88, blue: 0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDark ? .white : Color(red: 0.45, green: 0.45, blue: 0.5))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isDark ? .white : Color(red: 0.2, green: 0.2, blue: 0.25))
                        Spacer()
                        Text(String(format: "%.0f%%", value.wrappedValue * 100))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDark ? Color(white: 0.8) : Color(red: 0.5, green: 0.5, blue: 0.55))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isDark ? Color(white: 0.3) : Color(red: 0.92, green: 0.92, blue: 0.94))
                            )
                    }
                    
                    Slider(value: value, in: range)
                        .tint(Color(red: 0.3, green: 0.6, blue: 0.9))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 2)

            if selectedIndex == index {
                VStack {
                    HStack {
                        cornerIndicator
                            .scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedIndex == index)
                        Spacer()
                        cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1))
                            .scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.05), value: selectedIndex == index)
                    }
                    Spacer()
                    HStack {
                        cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1))
                            .scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1), value: selectedIndex == index)
                        Spacer()
                        cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1))
                            .scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.15), value: selectedIndex == index)
                    }
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .id("row-\(index)")
    }

    // resetButtonRow removed - replaced by ResetButtonRowHelper
    

    
    private func settingButtonRow(title: String, icon: String, color: Color, index: Int, action: @escaping () -> Void) -> some View {
        let isDark = settings.activeTheme.isDark

        return Button(action: {
            action()
            AudioManager.shared.playSelectSound()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(settings.reduceTransparency ? (isDark ? Color(UIColor.secondarySystemBackground) : Color.white) : (isDark ? Color(UIColor.secondarySystemBackground).opacity(0.85) : Color.white.opacity(0.85)))
                    .shadow(color: Color.black.opacity(selectedIndex == index ? 0.15 : 0.08), radius: selectedIndex == index ? 8 : 4, x: 0, y: selectedIndex == index ? 4 : 2)
                
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [color.opacity(0.15), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(color)
                    }
                    
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(color)
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 2)

                if selectedIndex == index {
                    VStack {
                        HStack {
                            cornerIndicator.scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            Spacer()
                            cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        }
                        Spacer()
                        HStack {
                            cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            Spacer()
                            cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.plain)
        .id("row-\(index)")
    }

    private func discordButtonRow(index: Int) -> some View {
        let isDark = settings.activeTheme.isDark
        
        return Button(action: {
            if let url = URL(string: "https://discord.gg/VVRFE6Aa4R") {
                UIApplication.shared.open(url)
            }
            AudioManager.shared.playSelectSound()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(settings.reduceTransparency ? (isDark ? Color(UIColor.secondarySystemBackground) : Color.white) : (isDark ? Color(UIColor.secondarySystemBackground).opacity(0.85) : Color.white.opacity(0.85)))
                    .shadow(color: Color.black.opacity(selectedIndex == index ? 0.15 : 0.08), radius: selectedIndex == index ? 8 : 4, x: 0, y: selectedIndex == index ? 4 : 2)
                
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 88/255, green: 101/255, blue: 242/255))
                            .frame(width: 32, height: 32)
                        
                        Image("discord_icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.white)
                    }
                    
                    Text("Join Discord")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 88/255, green: 101/255, blue: 242/255))
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 2)

                if selectedIndex == index {
                    VStack {
                        HStack {
                            cornerIndicator.scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            Spacer()
                            cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        }
                        Spacer()
                        HStack {
                            cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            Spacer()
                            cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.plain)
        .id("row-\(index)")
    }
    
    // Corner indicator for selected item (Wii U style)
    static var cornerIndicator: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 12))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 12, y: 0))
        }
        .stroke(Color.cyan, lineWidth: 3)
        .frame(width: 12, height: 12)
    }

    private var cornerIndicator: some View {
        Self.cornerIndicator
    }
}

//Helper Views for extracted Structs

struct SettingIdleSliderRow: View {
    @Binding var value: Double
    var index: Int
    var selectedIndex: Int
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        let isDark = settings.activeTheme.isDark
        
        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(settings.reduceTransparency ? (isDark ? Color(UIColor.secondarySystemBackground) : Color.white) : (isDark ? Color(UIColor.secondarySystemBackground).opacity(0.85) : Color.white.opacity(0.85)))
                .shadow(color: Color.black.opacity(selectedIndex == index ? 0.15 : 0.08), radius: selectedIndex == index ? 8 : 4, x: 0, y: selectedIndex == index ? 4 : 2)
            
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: isDark ? [Color(white: 0.3), Color(white: 0.25)] : [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.88, green: 0.88, blue: 0.92)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDark ? .white : Color(red: 0.45, green: 0.45, blue: 0.5))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Idle Auto-Hide")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isDark ? .white : Color(red: 0.2, green: 0.2, blue: 0.25))
                        Spacer()
                        Text(formatDuration(value))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(value == 0 ? .red : (isDark ? Color(white: 0.8) : Color(red: 0.5, green: 0.5, blue: 0.55)))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(isDark ? Color(white: 0.3) : Color(red: 0.92, green: 0.92, blue: 0.94)))
                    }
                    
                    Slider(value: $value, in: 0...300, step: 10)
                        .tint(Color(red: 0.3, green: 0.6, blue: 0.9))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 2)

            if selectedIndex == index {
                VStack {
                    HStack {
                        SettingsInlineView.cornerIndicator.scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        Spacer()
                        SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                    }
                    Spacer()
                    HStack {
                        SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        Spacer()
                        SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                    }
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .id("row-\(index)")
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        if seconds == 0 { return "Disabled" }
        if seconds < 60 { return String(format: "%.0fs", seconds) }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if secs == 0 { return "\(minutes)m" }
        return "\(minutes)m \(secs)s"
    }
}

struct SettingRowHelper: View {
    let title: String
    @Binding var isOn: Bool
    let index: Int
    let icon: String
    var iconColor: Color? = nil
    var selectedIndex: Int
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let isDark = settings.activeTheme.isDark
        
        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(settings.reduceTransparency ? (isDark ? Color(UIColor.secondarySystemBackground) : Color.white) : (isDark ? Color(UIColor.secondarySystemBackground).opacity(0.85) : Color.white.opacity(0.85)))
                .shadow(color: Color.black.opacity(selectedIndex == index ? 0.15 : 0.08), radius: selectedIndex == index ? 8 : 4, x: 0, y: selectedIndex == index ? 4 : 2)
            
            HStack(spacing: 10) {
                ZStack {
                    if let color = iconColor {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: isDark ? [Color(white: 0.3), Color(white: 0.25)] : [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.88, green: 0.88, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundColor(isDark ? .white : Color(red: 0.45, green: 0.45, blue: 0.5))
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(isDark ? .white : Color(red: 0.2, green: 0.2, blue: 0.25))
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn).labelsHidden().tint(Color(red: 0.3, green: 0.6, blue: 0.9))
            }
            .padding(.horizontal, 14).padding(.vertical, 2)

            if selectedIndex == index {
                VStack {
                    HStack {
                        SettingsInlineView.cornerIndicator.scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        Spacer()
                        SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                    }
                    Spacer()
                    HStack {
                        SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        Spacer()
                        SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                    }
                }.padding(8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .id("row-\(index)")
    }
}

struct SettingSliderRowHelper: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let index: Int
    let icon: String
    var selectedIndex: Int
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let isDark = settings.activeTheme.isDark
        
        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(settings.reduceTransparency ? (isDark ? Color(UIColor.secondarySystemBackground) : Color.white) : (isDark ? Color(UIColor.secondarySystemBackground).opacity(0.85) : Color.white.opacity(0.85)))
                .shadow(color: Color.black.opacity(selectedIndex == index ? 0.15 : 0.08), radius: selectedIndex == index ? 8 : 4, x: 0, y: selectedIndex == index ? 4 : 2)
            
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: isDark ? [Color(white: 0.3), Color(white: 0.25)] : [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.88, green: 0.88, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundColor(isDark ? .white : Color(red: 0.45, green: 0.45, blue: 0.5))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(isDark ? .white : Color(red: 0.2, green: 0.2, blue: 0.25))
                        Spacer()
                        Text(String(format: "%.0f%%", value * 100))
                            .font(.system(size: 13, weight: .bold)).foregroundColor(isDark ? Color(white: 0.8) : Color(red: 0.5, green: 0.5, blue: 0.55)).padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(isDark ? Color(white: 0.3) : Color(red: 0.92, green: 0.92, blue: 0.94)))
                    }
                    Slider(value: $value, in: range).tint(Color(red: 0.3, green: 0.6, blue: 0.9))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 2)

            if selectedIndex == index {
                VStack {
                    HStack {
                        SettingsInlineView.cornerIndicator.scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        Spacer()
                        SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                    }
                    Spacer()
                    HStack {
                        SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        Spacer()
                        SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                    }
                }.padding(8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .id("row-\(index)")
    }
}



struct SettingButtonRowHelper: View {
    let title: String
    let icon: String
    let color: Color
    let index: Int
    var selectedIndex: Int
    let action: () -> Void
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let isDark = settings.activeTheme.isDark
        
        return Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(settings.reduceTransparency ? (isDark ? Color(UIColor.secondarySystemBackground) : Color.white) : (isDark ? Color(UIColor.secondarySystemBackground).opacity(0.85) : Color.white.opacity(0.85)))
                    .shadow(color: Color.black.opacity(selectedIndex == index ? 0.15 : 0.08), radius: selectedIndex == index ? 8 : 4, x: 0, y: selectedIndex == index ? 4 : 2)
                
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [color.opacity(0.15), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundColor(color)
                    }
                    
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(color)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 2)
                
                if selectedIndex == index {
                    VStack {
                        HStack {
                            SettingsInlineView.cornerIndicator.scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            Spacer()
                            SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        }
                        Spacer()
                        HStack {
                            SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            Spacer()
                            SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        }
                    }.padding(8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.plain)
        .id("row-\(index)")
    }
}

struct ResetButtonRowHelper: View {
    let index: Int
    var selectedIndex: Int
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        let isDark = settings.activeTheme.isDark
        
        return Button(action: {
            settings.resetToDefaults()
            AppStatusManager.shared.show("Settings Reset", icon: "arrow.counterclockwise")
            AudioManager.shared.playSelectSound()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(settings.reduceTransparency ? (isDark ? Color(UIColor.secondarySystemBackground) : Color.white) : (isDark ? Color(UIColor.secondarySystemBackground).opacity(0.85) : Color.white.opacity(0.85)))
                    .shadow(color: Color.black.opacity(selectedIndex == index ? 0.15 : 0.08), radius: selectedIndex == index ? 8 : 4, x: 0, y: selectedIndex == index ? 4 : 2)
                
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 16, weight: .medium)).foregroundColor(.orange)
                    }
                    Text("Reset to Defaults").font(.system(size: 13, weight: .semibold)).foregroundColor(Color.orange)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 2)
                
                if selectedIndex == index {
                    VStack {
                        HStack {
                            SettingsInlineView.cornerIndicator.scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            Spacer()
                            SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        }
                        Spacer()
                        HStack {
                            SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            Spacer()
                            SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        }
                    }.padding(8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.plain)
        .id("row-\(index)")
    }
}

struct DiscordButtonRowHelper: View {
    let index: Int
    var selectedIndex: Int
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        let isDark = settings.activeTheme.isDark

        return Button(action: {
            if let url = URL(string: "https://discord.gg/VVRFE6Aa4R") {
                UIApplication.shared.open(url)
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(settings.reduceTransparency ? (isDark ? Color(UIColor.secondarySystemBackground) : Color.white) : (isDark ? Color(UIColor.secondarySystemBackground).opacity(0.85) : Color.white.opacity(0.85)))
                    .shadow(color: Color.black.opacity(selectedIndex == index ? 0.15 : 0.08), radius: selectedIndex == index ? 8 : 4, x: 0, y: selectedIndex == index ? 4 : 2)
                
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color(red: 0.35, green: 0.4, blue: 0.85), Color(red: 0.25, green: 0.3, blue: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    }
                    Text("Join Discord").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(red: 0.35, green: 0.4, blue: 0.85))
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 2)
                
                if selectedIndex == index {
                    VStack {
                        HStack {
                            SettingsInlineView.cornerIndicator.scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            Spacer()
                            SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        }
                        Spacer()
                        HStack {
                            SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                            Spacer()
                            SettingsInlineView.cornerIndicator.rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1)).scaleEffect(selectedIndex == index ? 1.0 : 0.5)
                        }
                    }.padding(8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.plain)
        .id("row-\(index)")
    }
    }


struct LogExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct LogExportShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
