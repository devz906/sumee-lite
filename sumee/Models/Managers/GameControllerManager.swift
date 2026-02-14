import SwiftUI
import GameController
import Combine

//Okey, so i need to redo all this code, it's working on pices.

class GameControllerManager: ObservableObject {
    static let shared = GameControllerManager()
    
    @Published var isControllerConnected = false
    @Published var controllerBatteryLevel: Float? = nil
    @Published var checkBatteryState: GCDeviceBattery.State = .unknown
    
    @Published var controllerName = ""
    @Published var isWiredConnection = false // New flag for connection type
    
    // Navigation state
    @Published var selectedAppIndex = 0
    @Published var currentPage = 0
    @Published var navigationFeedback = ""
    @Published var isSelectingWidget = false // Track if we're in widget area
    @Published var selectedWidgetIndex = 0 // Track widget selection
    
    // Menu state
    @Published var showMenu = false
    
    // Button states for external views
    @Published var buttonAPressed = false
    @Published var buttonBPressed = false
    @Published var buttonYPressed = false
    @Published var buttonXPressed = false
    @Published var buttonL1Pressed = false
    @Published var buttonR1Pressed = false
    @Published var buttonL2Pressed = false
    @Published var buttonR2Pressed = false
    @Published var dpadUp = false
    @Published var dpadDown = false
    @Published var dpadLeft = false
    @Published var dpadRight = false
    
    // Raw D-Pad states (Physical input only, for testing)
    @Published var rawDpadUp = false
    @Published var rawDpadDown = false
    @Published var rawDpadLeft = false
    @Published var rawDpadRight = false

    @Published var l3Pressed = false
    @Published var r3Pressed = false
    @Published var buttonStartPressed = false // Menu
    @Published var triggerL2Value: Float = 0
    @Published var triggerR2Value: Float = 0

    @Published var buttonSelectPressed = false // Options/Share
    
    // Calibration Settings
    @Published var leftStickInnerDeadzone: Float = 0.05 { didSet { saveConfiguration() } }
    @Published var leftStickOuterDeadzone: Float = 1.0 { didSet { saveConfiguration() } }
    @Published var rightStickInnerDeadzone: Float = 0.05 { didSet { saveConfiguration() } }
    @Published var rightStickOuterDeadzone: Float = 1.0 { didSet { saveConfiguration() } }
    
    @Published var triggerThreshold: Float = 0.1 { didSet { saveConfiguration() } }
    
    // Raw Stick Values (For Calibration View Visualization)
    @Published var rawLeftThumbstickX: Float = 0
    @Published var rawLeftThumbstickY: Float = 0
    @Published var rawRightThumbstickX: Float = 0
    @Published var rawRightThumbstickY: Float = 0
    
    // Internal state tracking for Input Merging (D-Pad vs Stick)
    // Prevents one source from cancelling the other
    private var _startPressed = false
    private var _selectPressed = false
    private var _buttonUpPressed = false
    private var _buttonDownPressed = false
    private var _buttonLeftPressed = false
    private var _buttonRightPressed = false
    
    private var _stickUpPressed = false
    private var _stickDownPressed = false
    private var _stickLeftPressed = false
    private var _stickRightPressed = false

    // Joystick Raw Values (Restored for compatibility, updated conditionally)
    // OPTIMIZATION: Removed @Published to prevent Main Thread UI thrashing on every micro-movement.
    // Views that need these values should poll them or use specific publishers, but HomeView does NOT need them.
    var leftThumbstickX: Float = 0
    var leftThumbstickY: Float = 0
    var rightThumbstickX: Float = 0
    var rightThumbstickY: Float = 0
    
    // Timestamp for any input change (optimization for observers)
    var lastInputTimestamp: TimeInterval = 0

    // Widget internal navigation coordination
    @Published var widgetInternalNavigationActive = false
    @Published var widgetInternalCanExitLeft = false
    @Published var widgetInternalCanExitRight = false

    @Published var widgetInternalCurrentIndex: Int = 1
    
    // Disable home menu navigation when modal is open
    var disableHomeNavigation = false
    
    // Disable menu sounds when emulator is active
    var disableMenuSounds = false
    
    // --- OPTIMIZATION: GAMEPLAY MODE ---
    // When true, stops publishing granular button events to avoid lagging the UI/Emulator
    var isGameplayMode = false
    
    // Tracks if any emulator view is currently active (regardless of menu state)
    var isEmulatorActive = false
    // -----------------------------------
    
    private var controller: GCController?
    var currentController: GCController? { return controller }
    private var navigationTimer: Timer?
    
    // Continuous Navigation Logic
    private func startContinuousNavigation() {
        navigationTimer?.invalidate()
        // Delay before repeating
        navigationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            self?.startRepeatTimer()
        }
    }
    
    private func startRepeatTimer() {
        navigationTimer?.invalidate()
        // Faster repeat rate (~0.15s)
        navigationTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.handleContinuousInput()
        }
    }
    
    private func handleContinuousInput() {
        // Prioritize D-pad, then Thumbstick
   
        
        if dpadUp || leftThumbstickY > 0.5 { navigateUp(repeated: true) }
        else if dpadDown || leftThumbstickY < -0.5 { navigateDown(repeated: true) }
        
        if dpadLeft || leftThumbstickX < -0.5 { navigateLeft(repeated: true) }
        else if dpadRight || leftThumbstickX > 0.5 { navigateRight(repeated: true) }
    }
    
    private func stopContinuousNavigation() {
        // Stop only if NO input is active
        let isThumbstickActive = abs(leftThumbstickX) > 0.5 || abs(leftThumbstickY) > 0.5
        if !dpadUp && !dpadDown && !dpadLeft && !dpadRight && !isThumbstickActive {
            navigationTimer?.invalidate()
            navigationTimer = nil
        }
    }
    
    private init() {
        setupControllerObservers()
        checkForConnectedControllers()
        loadConfiguration()
    }
    
    // MARK: - Persistence
    
    private func getConfigurationURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let systemDir = documentsDirectory.appendingPathComponent("system")
        
        if !FileManager.default.fileExists(atPath: systemDir.path) {
            try? FileManager.default.createDirectory(at: systemDir, withIntermediateDirectories: true)
        }
        
        return systemDir.appendingPathComponent("gamepad_config.json")
    }
    
    private func saveConfiguration() {
        let config = GamepadConfiguration(
            leftStickInnerDeadzone: leftStickInnerDeadzone,
            leftStickOuterDeadzone: leftStickOuterDeadzone,
            rightStickInnerDeadzone: rightStickInnerDeadzone,
            rightStickOuterDeadzone: rightStickOuterDeadzone,
            triggerThreshold: triggerThreshold
        )
        
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(config)
                try data.write(to: self.getConfigurationURL(), options: [.atomicWrite, .completeFileProtection])
            } catch {
                print("Failed to save gamepad config: \(error)")
            }
        }
    }
    
    private func loadConfiguration() {
        let url = getConfigurationURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(GamepadConfiguration.self, from: data)
            
            // Apply on Main Thread
            DispatchQueue.main.async {
                self.leftStickInnerDeadzone = config.leftStickInnerDeadzone
                self.leftStickOuterDeadzone = config.leftStickOuterDeadzone
                self.rightStickInnerDeadzone = config.rightStickInnerDeadzone
                self.rightStickOuterDeadzone = config.rightStickOuterDeadzone
                self.triggerThreshold = config.triggerThreshold
            }
        } catch {
            print("Failed to load gamepad config: \(error)")
        }
    }
    
    private func setupControllerObservers() {
        // Detect when a controller connects
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.handleControllerConnection(controller)
        }
        
        // Detect when a controller disconnects
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleControllerDisconnection()
        }
    }
    
    private func checkForConnectedControllers() {
        if let controller = GCController.controllers().first {
            handleControllerConnection(controller)
        }
    }
    
    private func handleControllerConnection(_ controller: GCController) {
        self.controller = controller
        self.isControllerConnected = true
        // Prefer vendorName (specific) over productCategory (generic)
        self.controllerName = controller.vendorName ?? controller.productCategory
        
        // Determine Connection Type Heuristic:

        if controller.battery == nil {
            self.isWiredConnection = true
        } else {
             self.isWiredConnection = false
        }
        
        print(" Controller connected: \(self.controllerName) (Wired: \(isWiredConnection))")
        
        // Initial Battery Read
        self.refreshControllerBatteryInfo()
        self.refreshControllerBatteryInfo()
        
        // SETUP OBSERVATION: Battery Level (it does not work!!)
        
        // Simple polling via Timer for battery updates (efficient enough for battery)
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isControllerConnected else {
                timer.invalidate()
                return
            }
            self.refreshControllerBatteryInfo()
        }
        
        setupControllerInputs(controller)
    }
    
    private func handleControllerDisconnection() {
        self.controller = nil
        self.isControllerConnected = false
        self.controllerName = ""
        self.controllerBatteryLevel = nil
        self.checkBatteryState = .unknown
        print(" Controller disconnected")
    }
    
    private func refreshControllerBatteryInfo() {
        guard let battery = self.controller?.battery else {
            self.controllerBatteryLevel = nil
            self.checkBatteryState = .unknown
            return
        }
        
        // Some controllers report -1 for unknown, but we still want to know it has a battery object
        self.controllerBatteryLevel = battery.batteryLevel
        self.checkBatteryState = battery.batteryState
    }
    
    // Helper functions to play sounds only when menu is active
    private func playMenuMoveSound() {
        
        
    }
    
    private func playMenuSelectSound() {
      
    }
    
    private func updateDirectionalState() {
        // Merge Inputs: D-Pad OR Stick
        let newUp = _buttonUpPressed || _stickUpPressed
        let newDown = _buttonDownPressed || _stickDownPressed
        let newLeft = _buttonLeftPressed || _stickLeftPressed
        let newRight = _buttonRightPressed || _stickRightPressed
        
        // Update Published Properties only on change
        if dpadUp != newUp { dpadUp = newUp }
        if dpadDown != newDown { dpadDown = newDown }
        if dpadLeft != newLeft { dpadLeft = newLeft }
        if dpadRight != newRight { dpadRight = newRight }
        
        // Handle Continuous Nav Trigger
        if newUp || newDown || newLeft || newRight {
            // If any direction is newly pressed (implicit via state check in handler usually, but here generally)
         
        } else {
            stopContinuousNavigation()
        }
    }
    
    private func applyStickCalibration(x: Float, y: Float, inner: Float, outer: Float) -> (Float, Float) {
        let magnitude = sqrt(x*x + y*y)
        if magnitude < inner { return (0, 0) }
        
        // Prevent Divide by Zero
        if inner >= outer { return (0,0) }
        
        let normalizedMag = min(1.0, (magnitude - inner) / (outer - inner))
        let scale = normalizedMag / magnitude
        
        return (x * scale, y * scale)
    }

    private func setupControllerInputs(_ controller: GCController) {
        // Extended Gamepad (Xbox, PlayStation, Razer Kishi)
        guard let gamepad = controller.extendedGamepad else {
            // Micro Gamepad (Apple TV Remote, etc.)
            if let microGamepad = controller.microGamepad {
                setupMicroGamepadInputs(microGamepad)
            }
            return
        }
        
        // --- Handlers ---
        
        // D-Pad Navigation
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            self._buttonUpPressed = pressed
            // Update raw state for testing UI
            DispatchQueue.main.async { self.rawDpadUp = pressed }
            self.updateDirectionalState()
            
            if pressed {
                // Always navigate (which sends inputPublisher event) and start repetition
                self.navigateUp()
                self.startContinuousNavigation()
                self.lastInputTimestamp = Date().timeIntervalSince1970
            }
        }
        
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            self._buttonDownPressed = pressed
            DispatchQueue.main.async { self.rawDpadDown = pressed }
            self.updateDirectionalState()
            
            if pressed {
                self.navigateDown()
                self.startContinuousNavigation()
                self.lastInputTimestamp = Date().timeIntervalSince1970
            }
        }
        
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            self._buttonLeftPressed = pressed
            DispatchQueue.main.async { self.rawDpadLeft = pressed }
            self.updateDirectionalState()
            
            if pressed {
                self.navigateLeft()
                self.startContinuousNavigation()
                self.lastInputTimestamp = Date().timeIntervalSince1970
            }
        }
        
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            self._buttonRightPressed = pressed
            DispatchQueue.main.async { self.rawDpadRight = pressed }
            self.updateDirectionalState()
            
            if pressed {
                self.navigateRight()
                self.startContinuousNavigation()
                self.lastInputTimestamp = Date().timeIntervalSince1970
            }
        }
        
        // A Button
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            DispatchQueue.main.async {
                self.buttonAPressed = pressed
                if pressed {
                    self.lastInputTimestamp = Date().timeIntervalSince1970
                    self.inputPublisher.send(.a)
                    if !self.disableHomeNavigation {
                        // Widget Interaction Logic
                        if self.isSelectingWidget {
                            self.widgetInternalNavigationActive = true
                            self.navigationFeedback = "Interact Widget (A)"
                            self.provideFeedback()
                            self.playMenuSelectSound()
                        } else {
                            self.selectCurrentApp()
                        }
                    }
                }
            }
        }
        
        // B Button
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            DispatchQueue.main.async {
                self.buttonBPressed = pressed
                if pressed {
                    self.lastInputTimestamp = Date().timeIntervalSince1970
                    self.inputPublisher.send(.b)
                    if !self.disableHomeNavigation {
                        self.goBack()
                    }
                }
            }
        }
        
        // X Button - Menu
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            DispatchQueue.main.async {
                self.buttonXPressed = pressed
                if pressed {
                    self.lastInputTimestamp = Date().timeIntervalSince1970
                    self.inputPublisher.send(.x)
                    if !self.disableHomeNavigation {
                        self.openMenu()
                    }
                }
            }
        }
        
        // Y Button - Edit
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            DispatchQueue.main.async {
                self.buttonYPressed = pressed
                if pressed {
                    self.lastInputTimestamp = Date().timeIntervalSince1970
                    self.inputPublisher.send(.y)
                     // Handled by View
                }
            }
        }
        
        // Left Shoulder (L1)
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            DispatchQueue.main.async {
                self.buttonL1Pressed = pressed
                if pressed {
                    self.lastInputTimestamp = Date().timeIntervalSince1970
                    self.inputPublisher.send(.l1)
                    if !self.disableHomeNavigation {
                        self.previousPage()
                    }
                }
            }
        }
        
        // Right Shoulder (R1)
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            DispatchQueue.main.async {
                self.buttonR1Pressed = pressed
                if pressed {
                    self.lastInputTimestamp = Date().timeIntervalSince1970
                    self.inputPublisher.send(.r1)
                    if !self.disableHomeNavigation {
                        self.nextPage()
                    }
                }
            }
        }
        
        // Triggers (L2/R2)
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            // Apply Custom Threshold
            let isPressed = value > self.triggerThreshold
            
            DispatchQueue.main.async {
                self.triggerL2Value = value
                self.buttonL2Pressed = isPressed
                if isPressed { self.lastInputTimestamp = Date().timeIntervalSince1970 }
            }
        }
        
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
             guard let self = self else { return }
             if self.isGameplayMode { return }
            
             // Apply Custom Threshold
             let isPressed = value > self.triggerThreshold
            
            DispatchQueue.main.async {
                self.triggerR2Value = value
                self.buttonR2Pressed = isPressed
                if isPressed { self.lastInputTimestamp = Date().timeIntervalSince1970 }
            }
        }
        
        // L3 Button
        gamepad.leftThumbstickButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            DispatchQueue.main.async {
                self.l3Pressed = pressed
                if pressed { self.lastInputTimestamp = Date().timeIntervalSince1970 }
            }
        }

        // R3 Button
        gamepad.rightThumbstickButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            if self.isGameplayMode { return }
            
            DispatchQueue.main.async {
                self.r3Pressed = pressed
                if pressed { self.lastInputTimestamp = Date().timeIntervalSince1970 }
            }
        }
        
        
        // Left Stick (Navigation)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self = self else { return }
            
            // OPTIMIZATION: Early exit for Gameplay Mode to avoid UI overhead
            if self.isGameplayMode { return }
            
            DispatchQueue.main.async {
                // Update Raw Values for Calibration View
                if abs(xValue - self.rawLeftThumbstickX) > 0.01 || abs(yValue - self.rawLeftThumbstickY) > 0.01 {
                    self.rawLeftThumbstickX = xValue
                    self.rawLeftThumbstickY = yValue
                }
                
                // Apply Calibration
                let (calX, calY) = self.applyStickCalibration(x: xValue, y: yValue, inner: self.leftStickInnerDeadzone, outer: self.leftStickOuterDeadzone)
                
                // Only update published properties if cal change is significant
                 let threshold: Float = 0.01 // Sensitivity for update
                 let xDiff = abs(calX - self.leftThumbstickX)
                 let yDiff = abs(calY - self.leftThumbstickY)
                
                if xDiff > threshold || yDiff > threshold {
                    self.leftThumbstickX = calX
                    self.leftThumbstickY = calY
                    
                    self.objectWillChange.send() // Ensure view updates for stick movement
                    
                    // Trigger navigation uses CALIBRATED values now
                    // Lower threshold (0.2) to prevent dropout when holding direction
                    self.handleThumbstickInput(x: calX, y: calY, threshold: 0.2)
                }
            }
        }
        
        // Right Stick (Navigation)
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self = self else { return }
            if self.isGameplayMode { return } // Optimization
            
            DispatchQueue.main.async {
                 // Update Raw Values for Calibration View
                if abs(xValue - self.rawRightThumbstickX) > 0.01 || abs(yValue - self.rawRightThumbstickY) > 0.01 {
                    self.rawRightThumbstickX = xValue
                    self.rawRightThumbstickY = yValue
                }
                
                 // Apply Calibration
                let (calX, calY) = self.applyStickCalibration(x: xValue, y: yValue, inner: self.rightStickInnerDeadzone, outer: self.rightStickOuterDeadzone)
                
                // Only update if change is significant
                 let threshold: Float = 0.01
                 let xDiff = abs(calX - self.rightThumbstickX)
                 let yDiff = abs(calY - self.rightThumbstickY)
            
                if xDiff > threshold || yDiff > threshold {
                    self.rightThumbstickX = calX
                    self.rightThumbstickY = calY
                    
                    // Higher threshold for right stick to prevent accidental sensitivity
                    self.handleThumbstickInput(x: calX, y: calY, threshold: 0.2)
                    
                    // Manually trigger change for non-published properties if significantly changed
                     if abs(calX) > 0.05 || abs(calY) > 0.05 {
                         self.objectWillChange.send()
                     }
                }
            }
        }
        
        // Start/Menu Button
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // COMBO CHECK: Always allow Menu Toggle even in Gameplay Mode
                if pressed && (self.controller?.extendedGamepad?.buttonOptions?.isPressed == true || self.buttonSelectPressed) {
                    self.toggleMenu()
                }
                
                // If in Gameplay Mode, STOP here to avoid publishing unnecessary state changes that cause stutter
                if self.isGameplayMode { return }
                
                self.buttonStartPressed = pressed
                if pressed {
                    self.lastInputTimestamp = Date().timeIntervalSince1970
                    self.inputPublisher.send(.start)
                }
            }
        }
        
        // Select/Options Button
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // COMBO CHECK: Always allow Menu Toggle even in Gameplay Mode
                if pressed && (self.controller?.extendedGamepad?.buttonMenu.isPressed == true || self.buttonStartPressed) {
                    self.toggleMenu()
                }
                
                // If in Gameplay Mode, STOP here to avoid publishing unnecessary state changes that cause stutter
                if self.isGameplayMode { return }
                
                self.buttonSelectPressed = pressed
                if pressed {
                    self.lastInputTimestamp = Date().timeIntervalSince1970
                    self.inputPublisher.send(.select)
                }
            }
        }
    }


    
    private func setupMicroGamepadInputs(_ gamepad: GCMicroGamepad) {
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.navigateUp()
            }
        }
        
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.navigateDown()
            }
        }
        
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.navigateLeft()
            }
        }
        
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.navigateRight()
            }
        }
    }
    
    // Edit Mode State
    @Published var isEditingLayout = false
    
    enum Direction {
        case up, down, left, right
    }
    
    let moveAction = PassthroughSubject<Direction, Never>()
    let selectAction = PassthroughSubject<Void, Never>()
    
    // Navigation Methods
    
 
    enum GameInputEvent {
        case up(Bool), down(Bool), left(Bool), right(Bool) // Bool indicates isRepeated
        case a, b, x, y, l1, r1, start, select
    }
    let inputPublisher = PassthroughSubject<GameInputEvent, Never>()
    
    func navigateUp(repeated: Bool = false) {
        DispatchQueue.main.async {
            self.inputPublisher.send(.up(repeated))
            guard !self.disableHomeNavigation else { return }
            self.moveAction.send(.up)
        }
    }
    
    @Published var currentWidgetCount: Int = 0 // Number of widgets on current page
    
    func navigateDown(repeated: Bool = false) {
        DispatchQueue.main.async {
            self.inputPublisher.send(.down(repeated))
            guard !self.disableHomeNavigation else { return }
            self.moveAction.send(.down)
        }
    }
    
    func navigateLeft(repeated: Bool = false) {
        DispatchQueue.main.async {
            self.inputPublisher.send(.left(repeated))
            guard !self.disableHomeNavigation else { return }
            self.moveAction.send(.left)
        }
    }
    
    func navigateRight(repeated: Bool = false) {
        DispatchQueue.main.async {
            self.inputPublisher.send(.right(repeated))
            guard !self.disableHomeNavigation else { return }
            self.moveAction.send(.right)
        }
    }
    
    // Delegate for resize action to avoid circular dependency
    var onWidgetResize: (() -> Void)?
    
    func selectCurrentApp() {
        // Don't select in home menu if disabled (e.g., folder is open)
        guard !disableHomeNavigation else { return }
        
        if isEditingLayout {
            // Delegate 'A' to HomeViewModel for resizing via closure
            onWidgetResize?()
            print(" 'A' Pressed in Edit Mode -> Resizing")
            return
        }
        
        playMenuSelectSound()
        

        
        if isSelectingWidget {
            navigationFeedback = "Select Widget \(selectedWidgetIndex)"
        } else {
            navigationFeedback = "Select App \(selectedAppIndex)"
        }
        
        provideFeedback()
        print("Selected: \(navigationFeedback)")
        
        // Notify listeners
        selectAction.send()
    }
    
    func goBack() {
        if isEditingLayout {
            // Discard changes when pressing B in edit mode
            isEditingLayout = false
            navigationFeedback = "Layout Discarded"
            provideFeedback()
            AudioManager.shared.playMoveSound()
            print(" Layout discarded")
            return
        }
        
        // If inside a widget, exit back to grid selecting rightmost app in same row
        if isSelectingWidget {
            isSelectingWidget = false
            widgetInternalNavigationActive = false
            selectedAppIndex = max(0, selectedWidgetIndex * 3 + 2)
            navigationFeedback = "Exit Widget (B)"
            provideFeedback()
            playMenuMoveSound()
            print(" Exited widget via B")
            return
        }
        
        navigationFeedback = "Back (B)"
        provideFeedback()
        print(" Back button pressed")
    }
    
    func openMenu() {
        showMenu = true
        navigationFeedback = "Menu (X)"
        provideFeedback()
        print(" Menu button pressed")
    }
    
    func toggleMenu() {
        showMenu.toggle()
        navigationFeedback = showMenu ? "Menu Opened (L3+R3)" : "Menu Closed"
        provideFeedback()
        if showMenu {
            AudioManager.shared.playSelectSound()
        } else {
            AudioManager.shared.playMoveSound()
        }
        print(" Menu toggled: \(showMenu)")
    }
    
    func openEdit() {
        // If already in edit mode, pressing Y saves layout; otherwise enter edit mode
        if isEditingLayout {
            isEditingLayout = false
            navigationFeedback = "Layout Saved"
            provideFeedback()
            AudioManager.shared.playSelectSound()
            print(" Layout saved")
        } else {
            isEditingLayout = true
            navigationFeedback = "Edit Mode ON"
            provideFeedback()
            AudioManager.shared.playSelectSound()
            print(" Entered edit mode")
        }
    }
    
    func previousPage() {
        // Handled by HomeViewModel directly via buttonL1Pressed observation
 
    }
    
    // @Published var totalPages = 4 // Removed to avoid confusion
    
    func nextPage() {
        // Handled by HomeViewModel directly via buttonR1Pressed observation.

    }

    
    private var lastThumbstickTime: Date = Date()
    
    private func handleThumbstickInput(x: Float, y: Float, threshold: Float) {
        // Defines
        // Use a slightly larger threshold (0.5) to activate, but a smaller one (0.3) to deactivate.
        // This "Schmitt Trigger" / Hysteresis creates a "Sticky" input that resists noise.
        let activateThreshold: Float = 0.55
        let deactivateThreshold: Float = 0.35
        
        // --- UP ---
        if _stickUpPressed {
            // RELEASE Check: Must drop below lower threshold to release
            if y < deactivateThreshold { _stickUpPressed = false }
        } else {
            // PRESS Check: Must exceed higher threshold to press
            if y > activateThreshold { _stickUpPressed = true }
        }
        
        // --- DOWN ---
        if _stickDownPressed { // y is negative
            // RELEASE Check: Must rise above (less negative than) lower threshold
            if y > -deactivateThreshold { _stickDownPressed = false }
        } else {
            // PRESS Check: Must drop below (more negative than) higher threshold
            if y < -activateThreshold { _stickDownPressed = true }
        }
        
        // --- RIGHT ---
        if _stickRightPressed {
            if x < deactivateThreshold { _stickRightPressed = false }
        } else {
            if x > activateThreshold { _stickRightPressed = true }
        }
        
        // --- LEFT ---
        if _stickLeftPressed { // x is negative
            if x > -deactivateThreshold { _stickLeftPressed = false }
        } else {
            if x < -activateThreshold { _stickLeftPressed = true }
        }
        
        // Save old states to detect edges for Navigation triggers
        let wasUp = dpadUp
        let wasDown = dpadDown
        let wasLeft = dpadLeft
        let wasRight = dpadRight
        
        updateDirectionalState()
        
        // Trigger Navigation Events based on rising edge of FINAL state (merged Stick + Dpad)
        // If Stick caused the state to flip true, fire event.
        
        if !wasUp && dpadUp {
            self.lastInputTimestamp = Date().timeIntervalSince1970
            navigateUp(); startContinuousNavigation()
        }
        
        if !wasDown && dpadDown {
             self.lastInputTimestamp = Date().timeIntervalSince1970
             navigateDown(); startContinuousNavigation()
        }
        
        if !wasLeft && dpadLeft {
            self.lastInputTimestamp = Date().timeIntervalSince1970
            navigateLeft(); startContinuousNavigation()
        }
        
        if !wasRight && dpadRight {
            self.lastInputTimestamp = Date().timeIntervalSince1970
            navigateRight(); startContinuousNavigation()
        }
    }
    
    private func provideFeedback() {
        // Haptic feedback always enabled
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Clear feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.navigationFeedback = ""
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct GamepadConfiguration: Codable {
    var leftStickInnerDeadzone: Float
    var leftStickOuterDeadzone: Float
    var rightStickInnerDeadzone: Float
    var rightStickOuterDeadzone: Float
    var triggerThreshold: Float
}
