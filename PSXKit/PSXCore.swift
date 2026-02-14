
import Foundation
import SwiftUI
import Combine
import AVFoundation
import GameController
import Darwin

// --- Libretro Type Definitions (Renamed to prevent collisions, it happen before) ---

typealias psx_retro_environment_t = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool
typealias psx_retro_video_refresh_t = @convention(c) (UnsafeRawPointer?, UInt32, UInt32, Int) -> Void
typealias psx_retro_audio_sample_t = @convention(c) (Int16, Int16) -> Void
typealias psx_retro_audio_sample_batch_t = @convention(c) (UnsafePointer<Int16>?, Int) -> Int
typealias psx_retro_input_poll_t = @convention(c) () -> Void
typealias psx_retro_input_state_t = @convention(c) (UInt32, UInt32, UInt32, UInt32) -> Int16

struct psx_retro_game_info {
    var path: UnsafePointer<CChar>? = nil
    var data: UnsafeRawPointer? = nil
    var size: Int = 0
    var meta: UnsafePointer<CChar>? = nil
}

struct psx_retro_system_av_info {
    struct Geometry {
        var base_width: UInt32 = 0
        var base_height: UInt32 = 0
        var max_width: UInt32 = 0
        var max_height: UInt32 = 0
        var aspect_ratio: Float = 0.0
    }
    struct Timing {
        var fps: Double = 60.0
        var sample_rate: Double = 44100.0
    }
    var geometry: Geometry = Geometry()
    var timing: Timing = Timing()
}

// ------------------------------------------------

// Variable global para renderizado
private let psxRendererInstance = PSXRenderer() // Se creará en PSXRenderView.swift

// Callbacks C globales

@_cdecl("psx_video_refresh")
func psx_video_refresh(data: UnsafeRawPointer?, width: UInt32, height: UInt32, pitch: Int) {
    guard let data = data else { return }
    // PCSX a veces reporta anchos que no coinciden exactamente con pitch/2 en 16bit, pero pitch es la fuente de verdad.
    psxRendererInstance.updateTexture(width: Int(width), height: Int(height), pitch: pitch, data: data)
}

private var psxTempAudioBuffer: [Int16] = [0, 0]

@_cdecl("psx_audio_sample")
func psx_audio_sample(left: Int16, right: Int16) {
    psxTempAudioBuffer[0] = left
    psxTempAudioBuffer[1] = right
    PSXAudio.shared.writeAudio(data: psxTempAudioBuffer, frames: 1)
}

@_cdecl("psx_audio_sample_batch")
func psx_audio_sample_batch(data: UnsafePointer<Int16>?, frames: Int) -> Int {
    guard let data = data else { return 0 }
    PSXAudio.shared.writeAudio(data: data, frames: frames)
    return frames
}

@_cdecl("psx_input_poll")
func psx_input_poll() {
    // Input gestionado por PSXInput
    PSXInput.shared.pollInput()
}

@_cdecl("psx_input_state")
func psx_input_state(port: UInt32, device: UInt32, index: UInt32, id: UInt32) -> Int16 {
    // Port 0 es Player 1
    if port == 0 {
        if device == 1 || device == 0 { // Joypad or Generic
            if id < 20 { // Check bounds
                let mask = UInt16(1 << id)
                return (PSXInput.shared.buttonMask & mask) != 0 ? 1 : 0
            }
        } else if device == 517 { // RETRO_DEVICE_ANALOG
             // TODO: Implementar sticks analógicos si el usuario los pide
             // Requiere leer thumbsticks de GCController
        }
    }
    return 0
}

struct psx_retro_variable {
    var key: UnsafePointer<CChar>?
    var value: UnsafePointer<CChar>?
}

@_cdecl("psx_environment")
func psx_environment(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
    switch cmd {
    case 3: // RETRO_ENVIRONMENT_GET_CAN_DUPE
        if let data = data {
            data.bindMemory(to: Bool.self, capacity: 1).pointee = true
        }
        return true
        
    case 9: // RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY
         if let data = data {
             // System Directory (para BIOS SCPH1001.BIN)
             if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                 let sysDir = docDir.appendingPathComponent("system") // Misma carpeta que otros cores
                 try? FileManager.default.createDirectory(at: sysDir, withIntermediateDirectories: true)
                 
                 let pathStr = sysDir.path
                 let cString = strdup(pathStr)
                 data.bindMemory(to: UnsafePointer<CChar>?.self, capacity: 1).pointee = UnsafePointer(cString)
                 print("📂 [PSXCore] System Directory set (for BIOS): \(pathStr)")
                 return true
             }
         }
         return false
         
     case 31: // RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY
        if let data = data {
            if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                // Defines standardized Save/Memory Card folder
                let saveDir = docDir.appendingPathComponent("saves/psx")
                try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
                
                let pathStr = saveDir.path
                let cString = strdup(pathStr)
                data.bindMemory(to: UnsafePointer<CChar>?.self, capacity: 1).pointee = UnsafePointer(cString)
                print("💾 [PSXCore] Save Directory set: \(pathStr)")
                return true
            }
        }
        return false

    case 10: // RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
        if let data = data {
            let format = data.bindMemory(to: UInt32.self, capacity: 1).pointee
            // 0 = 0RGB1555 (deprecated)
            // 1 = XRGB8888
            // 2 = RGB565
            if format == 2 {
                print("[PSXCore] Core requested RGB565. Allowed.")
                return true
            } else if format == 1 {
                 print(" [PSXCore] Core requested XRGB8888. Rendering logic might need update if this happens.")
                 // PSXRenderer usually expects 565, but we can allow 8888 if we update renderer.
                 // For now, let's prefer 565.
                 return false 
            }
            return false
        }
        return false
        
    case 16: // RETRO_ENVIRONMENT_GET_VARIABLE
        if let data = data {
            let variable = data.bindMemory(to: psx_retro_variable.self, capacity: 1).pointee
            if let key = variable.key {
                let keyString = String(cString: key)
                
                // --- PERFORMANCE TUNING ---
                if keyString == "pcsx_rearmed_spu_interpolation" {
                    // "simple" is fastest, "gaussian" is high quality but slower
                    // Spider-Man and heavy games benefit from "simple"
                    let value = strdup("simple")
                    data.bindMemory(to: psx_retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                    return true
                }

                if keyString == "pcsx_rearmed_dithering" {
                    // Disable dithering to save GPU/CPU
                    let value = strdup("disabled")
                    data.bindMemory(to: psx_retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                    // print("⚙️ [PSXCore] Dithering -> DISABLED (Performance)")
                    return true
                }
                
                if keyString == "pcsx_rearmed_show_bios_bootlogo" {
                    // BIOS Intro is cool, keep it.
                    let value = strdup("enabled")
                    data.bindMemory(to: psx_retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                    return true
                }
                
                if keyString == "pcsx_rearmed_frameskip" {
                    // "auto" helps heavy scenes drop frames instead of slowing down audio
                    let value = strdup("auto")
                    data.bindMemory(to: psx_retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                    return true
                }
                
                if keyString == "pcsx_rearmed_neon_interlace_enable" {
                    // Start disabled for performance
                    let value = strdup("disabled")
                    data.bindMemory(to: psx_retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                    return true
                }
                 
                if keyString == "pcsx_rearmed_vibration" {
                    // Input polling for vibration can be heavy
                    let value = strdup("disabled")
                    data.bindMemory(to: psx_retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                    return true
                }
            }
        }
        return false

    default:
        // print("[PSXCore] Environment CMD: \(cmd)")
        return false
    }
}

public class PSXCore: ObservableObject {
    @Published public var isRunning = false
    private var coreHandle: UnsafeMutableRawPointer?
    private var displayLink: CADisplayLink?
    
    // Renderer
    public var renderer: PSXRenderer {
        return psxRendererInstance
    }
    
    // Core Function Pointers
    private var retro_init: (@convention(c) () -> Void)?
    private var retro_deinit: (@convention(c) () -> Void)?
    private var retro_set_environment: (@convention(c) (psx_retro_environment_t) -> Void)?
    private var retro_set_video_refresh: (@convention(c) (psx_retro_video_refresh_t) -> Void)?
    private var retro_set_audio_sample: (@convention(c) (psx_retro_audio_sample_t) -> Void)?
    private var retro_set_audio_sample_batch: (@convention(c) (psx_retro_audio_sample_batch_t) -> Void)?
    private var retro_set_input_poll: (@convention(c) (psx_retro_input_poll_t) -> Void)?
    private var retro_set_input_state: (@convention(c) (psx_retro_input_state_t) -> Void)?
    
    private var retro_load_game: (@convention(c) (UnsafeRawPointer) -> Bool)?
    private var retro_get_system_av_info: (@convention(c) (UnsafeMutableRawPointer) -> Void)?
    private var retro_run: (@convention(c) () -> Void)?
    
    // Save States
    private var retro_serialize_size: (@convention(c) () -> Int)?
    private var retro_serialize: (@convention(c) (UnsafeMutableRawPointer, Int) -> Bool)?
    private var retro_unserialize: (@convention(c) (UnsafeRawPointer, Int) -> Bool)?
    
    // Memory / SRAM (For native saves)
    private var retro_get_memory_data: (@convention(c) (UInt32) -> UnsafeMutableRawPointer?)?
    private var retro_get_memory_size: (@convention(c) (UInt32) -> Int)?
    
    private var currentROMURL: URL?
    
    public init() {
        // Lazy initialization: Core will be loaded when loadGame() is called.
    }
    
    deinit {
        stopLoop()
        retro_deinit?()
        if let handle = coreHandle {
            dlclose(handle)
        }
    }
    
    private func loadCore() {
        var corePath: String?
        
        // Buildbot name: pcsx_rearmed_libretro_ios.dylib
        let possibleNames = ["pcsx_rearmed_libretro_ios", "pcsx_rearmed_libretro", "pcsx_rearmed"]
        
        // 1. Check Frameworks Directory (Production / Embed & Sign)
        if let frameworksURL = Bundle.main.privateFrameworksURL {
            let frameworkPath = frameworksURL.appendingPathComponent("pcsx_rearmed.framework/pcsx_rearmed").path
            print(" [PSXCore] Checking Frameworks Path: \(frameworkPath)")
            if FileManager.default.fileExists(atPath: frameworkPath) {
                print(" [PSXCore] Found in Frameworks!")
                corePath = frameworkPath
            }
        }
        
        // 2. Check Bundle Root (Development / Local)
        if corePath == nil {
             let rootFrameworkPath = Bundle.main.bundleURL.appendingPathComponent("pcsx_rearmed.framework/pcsx_rearmed").path
             print("🔍 [PSXCore] Checking Root Path: \(rootFrameworkPath)")
             if FileManager.default.fileExists(atPath: rootFrameworkPath) {
                 print("[PSXCore] Found in Root Bundle!")
                 corePath = rootFrameworkPath
             }
        }

        // 3. Fallback: Loose dylib (Legacy)
        if corePath == nil {
            for name in possibleNames {
                if let path = Bundle.main.path(forResource: name, ofType: "dylib") {
                    corePath = path
                    print("[PSXCore] Found in Resources: \(name)")
                    break
                }
            }
        }
        
        guard let validPath = corePath else {
            print(" [PSXCore] FATAL: Could not find pcsx_rearmed binary.")
            return
        }
        
        print(" [PSXCore] Loading Core from: \(validPath)")
        
        coreHandle = dlopen(validPath, RTLD_NOW)
        guard coreHandle != nil else {
            print(" [PSXCore] Falló dlopen: \(String(cString: dlerror()))")
            return
        }
        
        // Load Symbols
        retro_init = loadSymbol("retro_init")
        retro_deinit = loadSymbol("retro_deinit")
        retro_set_environment = loadSymbol("retro_set_environment")
        retro_set_video_refresh = loadSymbol("retro_set_video_refresh")
        retro_set_audio_sample = loadSymbol("retro_set_audio_sample")
        retro_set_audio_sample_batch = loadSymbol("retro_set_audio_sample_batch")
        retro_set_input_poll = loadSymbol("retro_set_input_poll")
        retro_set_input_state = loadSymbol("retro_set_input_state")
        retro_load_game = loadSymbol("retro_load_game")
        retro_run = loadSymbol("retro_run")
        retro_get_system_av_info = loadSymbol("retro_get_system_av_info")
        
        retro_serialize_size = loadSymbol("retro_serialize_size")
        retro_serialize = loadSymbol("retro_serialize")
        retro_unserialize = loadSymbol("retro_unserialize")
        
        retro_get_memory_data = loadSymbol("retro_get_memory_data")
        retro_get_memory_size = loadSymbol("retro_get_memory_size")
        
        // Init
        retro_set_environment?(psx_environment)
        retro_set_video_refresh?(psx_video_refresh)
        retro_set_audio_sample?(psx_audio_sample)
        retro_set_audio_sample_batch?(psx_audio_sample_batch)
        retro_set_input_poll?(psx_input_poll)
        retro_set_input_state?(psx_input_state)
        
        retro_init?()
        print(" [PSXCore] Core PCSX ReARMed initialized.")
    }
    
    private func loadSymbol<T>(_ name: String) -> T? {
        guard let handle = coreHandle else { return nil }
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }
    
    func loadGame(url: URL) -> Bool {
        // Ensure Core is loaded before proceeding
        if coreHandle == nil {
            loadCore()
        }
        
        stopLoop()
        
        // Save current ROM URL for save data handling
        currentROMURL = url
        
        // PSX Games are large (CD images). Libretro supports passing path instead of data.
        // We will TRY passing path first to avoid loading 700MB into RAM.
        
        var info = psx_retro_game_info()
        let path = url.path.cString(using: .utf8)!
        
        // For Sandbox safety: If file is in Documents, we can pass path.
        // We still need to ensure the core can read it.
        
        return path.withUnsafeBufferPointer { pathPtr in
            info.path = pathPtr.baseAddress
            info.data = nil
            info.size = 0
            info.meta = nil
            
            // Note: If core fails to open path due to sandbox, we might need a fallback to load Data,
            // but for PSX (ISO/BIN/CUE) loading Data is often not supported or too heavy.
            
            guard let success = withUnsafePointer(to: &info, { infoPtr in
                return retro_load_game?(infoPtr)
            }), success else {
                print(" [PSXCore] retro_load_game failed via Path.")
                return false
            }
            
            print(" [PSXCore] Game Loaded: \(url.lastPathComponent)")
            
            // Load Save RAM (Memory Card) if exists
            loadSaveRAM()
            
            var avInfo = psx_retro_system_av_info()
            withUnsafeMutablePointer(to: &avInfo) { avPtr in
                retro_get_system_av_info?(avPtr)
            }
            
            self.currentSampleRate = avInfo.timing.sample_rate // Store for resume
            PSXAudio.shared.start(rate: avInfo.timing.sample_rate)
            startLoop(fps: avInfo.timing.fps)
            
            return true
        }
    }
    
    private var lastFrameTime: CFTimeInterval = 0
    private var timeAccumulator: Double = 0
    private var targetInterval: Double = 1.0 / 60.0
    
    // MARK: - Pause/Resume Logic
    private var currentFPS: Double = 60.0
    private var currentSampleRate: Double = 44100.0
    
    public func pause() {
        if isRunning {
            isRunning = false
            displayLink?.isPaused = true
            PSXAudio.shared.stop()
            print("sh [PSXCore] Paused")
        }
    }
    
    public func resume() {
        if !isRunning && displayLink != nil {
            isRunning = true
            displayLink?.isPaused = false
            PSXAudio.shared.start(rate: currentSampleRate)
            print(" [PSXCore] Resumed at \(currentSampleRate)Hz")
        } else if !isRunning {
            startLoop(fps: currentFPS)
            PSXAudio.shared.start(rate: currentSampleRate)
        }
    }

    private func startLoop(fps: Double) {
        currentFPS = fps
        isRunning = true
        
        let safeFPS = fps > 0 ? fps : 60.0
        targetInterval = 1.0 / safeFPS
        
        lastFrameTime = CACurrentMediaTime()
        timeAccumulator = 0
        
        displayLink = CADisplayLink(target: self, selector: #selector(gameLoop))
        
        // Use preferredFrameRateRange to request high refresh rate for smoothness,
        // but our Accumulator logic will handle the exact pacing logic.
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        } else {
            displayLink?.preferredFramesPerSecond = 60
        }
        
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopLoop() {
        // Save RAM before stopping - ALWAYS try to save, even if paused
        saveSaveRAM()
        
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        PSXAudio.shared.stop()
    }
    
    // MARK: - Fast Forward
    private static var _fastForward = false
    public static var fastForward: Bool {
        get { return _fastForward }
        set {
            if _fastForward && !newValue {
                // Turning OFF Fast Forward -> Flush Audio to prevent lag
                PSXAudio.shared.flush()
            }
            _fastForward = newValue
        }
    }
    
    @objc private func gameLoop() {
        guard isRunning else { return }
        
        let currentTime = CACurrentMediaTime()
        var deltaTime = currentTime - lastFrameTime
        lastFrameTime = currentTime
        
        // Cap deltaTime to avoid spiral of death (e.g. if app was suspended)
        if deltaTime > 0.1 { deltaTime = 0.1 }
        
        if PSXCore.fastForward {
            // Turbo Mode: Bypass accumulator, just run multiple frames
            retro_run?()
            retro_run?()
            retro_run?()
            return
        }
        
        timeAccumulator += deltaTime
        
        // Run core frames until accumulator is drained
        // Limits catch-up to avoids freezing UI if we fall too far behind
        var framesRun = 0
        while timeAccumulator >= targetInterval && framesRun < 3 {
            retro_run?()
            timeAccumulator -= targetInterval
            framesRun += 1
        }
    }
    
    // MARK: - Save States
    func saveState() -> Data? {
        guard let getSize = retro_serialize_size, let serialize = retro_serialize else { return nil }
        let size = getSize()
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { ptr in
             return serialize(ptr.baseAddress!, size)
        }
        return result ? data : nil
    }
    
    func loadState(data: Data) -> Bool {
        guard let unserialize = retro_unserialize else { return false }
        let result = data.withUnsafeBytes { ptr in
            return unserialize(ptr.baseAddress!, data.count)
        }
        return result
    }
    
    // MARK: - Save RAM (Memory Card) Manual Handling
    private func getSaveRAMPath() -> URL? {
        guard let romURL = currentROMURL,
              let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let saveDir = docDir.appendingPathComponent("saves/psx")
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        
        let saveName = romURL.deletingPathExtension().lastPathComponent + ".srm"
        return saveDir.appendingPathComponent(saveName)
    }
    
    func loadSaveRAM() {
        guard let path = getSaveRAMPath(),
              FileManager.default.fileExists(atPath: path.path) else { return }
        
        guard let getData = retro_get_memory_data,
              let getSize = retro_get_memory_size else { return }
        
        let size = getSize(0) // RETRO_MEMORY_SAVE_RAM = 0
        guard size > 0 else { return }
        
        if let ptr = getData(0) {
            if let data = try? Data(contentsOf: path), data.count <= size {
                data.withUnsafeBytes { buffer in
                    ptr.copyMemory(from: buffer.baseAddress!, byteCount: data.count)
                }
                print(" [PSXCore] Save RAM loaded: \(path.lastPathComponent)")
            }
        }
    }
    
    func saveSaveRAM() {
        guard let path = getSaveRAMPath() else { return }
        
        guard let getData = retro_get_memory_data,
              let getSize = retro_get_memory_size else { return }
        
        let size = getSize(0) // RETRO_MEMORY_SAVE_RAM = 0
        guard size > 0 else { return }
        
        if let ptr = getData(0) {
            let data = Data(bytes: ptr, count: size)
            do {
                try data.write(to: path)
                // print("[PSXCore] Save RAM saved: \(path.lastPathComponent)") // Silenced for Autosave
            } catch {
                print(" [PSXCore] Failed to write Save RAM: \(error)")
            }
        }
    }
}
