import Foundation
import SwiftUI
import Combine
import AVFoundation
import GameController
import Darwin

// --- Libretro Type Definitions (Swift Mirror) ---

typealias retro_environment_t = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool
typealias retro_video_refresh_t = @convention(c) (UnsafeRawPointer?, UInt32, UInt32, Int) -> Void
typealias retro_audio_sample_t = @convention(c) (Int16, Int16) -> Void
typealias retro_audio_sample_batch_t = @convention(c) (UnsafePointer<Int16>?, Int) -> Int
typealias retro_input_poll_t = @convention(c) () -> Void
typealias retro_input_state_t = @convention(c) (UInt32, UInt32, UInt32, UInt32) -> Int16

struct retro_game_info {
    var path: UnsafePointer<CChar>? = nil
    var data: UnsafeRawPointer? = nil
    var size: Int = 0
    var meta: UnsafePointer<CChar>? = nil
}

struct retro_system_av_info {
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


private let gbaRendererInstance = GBARenderer()

// Callbacks C globales
@_cdecl("gba_video_refresh")
func gba_video_refresh(data: UnsafeRawPointer?, width: UInt32, height: UInt32, pitch: Int) {
    guard let data = data else { return }
    gbaRendererInstance.updateTexture(width: Int(width), height: Int(height), pitch: pitch, data: data)
}

private var gbaTempAudioBuffer: [Int16] = [0, 0]

@_cdecl("gba_audio_sample")
func gba_audio_sample(left: Int16, right: Int16) {
    gbaTempAudioBuffer[0] = left
    gbaTempAudioBuffer[1] = right
    GBAAudio.shared.writeAudio(data: gbaTempAudioBuffer, frames: 1)
}

@_cdecl("gba_audio_sample_batch")
func gba_audio_sample_batch(data: UnsafePointer<Int16>?, frames: Int) -> Int {
    guard let data = data else { return 0 }
    GBAAudio.shared.writeAudio(data: data, frames: frames)
    return frames
}

@_cdecl("gba_input_poll")
func gba_input_poll() {
    // Input gestionado por Polling en lugar de Eventos (Fix Latency/Performance)
    GBAInput.shared.pollInput()
}

@_cdecl("gba_input_state")
func gba_input_state(port: UInt32, device: UInt32, index: UInt32, id: UInt32) -> Int16 {
    // Port 0 es Player 1
    if port == 0 {
        if device == 1 || device == 0 { // Joypad or Generic
            if id < 16 {
                let mask = UInt16(1 << id)
                return (GBAInput.shared.buttonMask & mask) != 0 ? 1 : 0
            }
        }
    }
    return 0
}

@_cdecl("gba_environment")
func gba_environment(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
    switch cmd {
    case 3: // RETRO_ENVIRONMENT_GET_CAN_DUPE
        if let data = data {
            data.bindMemory(to: Bool.self, capacity: 1).pointee = true
        }
        return true
    case 31: // RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY
        if let data = data {
            if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let saveDir = docDir.appendingPathComponent("saves/gba")
                try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
                
                let pathStr = saveDir.path
                let cString = strdup(pathStr)
                data.bindMemory(to: UnsafePointer<CChar>?.self, capacity: 1).pointee = UnsafePointer(cString)
                print("📂 [GBACore] Save Directory set to: \(pathStr)")
                return true
            }
        }
        return false
    case 10: // RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
        if let data = data {
            let format = data.bindMemory(to: UInt32.self, capacity: 1).pointee
            // We support RGB565 (2) and potentially XRGB8888 (1)
            // But GBARenderView is hardcoded to .b5g6r5Unorm (RGB565)
            // So we strictly prefer 2.
            if format == 2 {
                print("[GBACore] Core requested RGB565. Allowed.")
                return true
            } else {
                 print("[GBACore] Core requested format \(format). Denied (Only RGB565 supported).")
                 return false // Force it to try 565 if it can, otherwise fail
            }
        }
        return false
        
    default:

        return false
    }
}

// Global static storage for paths to ensure pointer validity
private var gbaSystemDir: String = ""
private var gbaSystemDirPtr: UnsafePointer<CChar>?

// Clase Principal del Core
public class GBACore: ObservableObject {
    @Published public var isRunning = false
    private var coreHandle: UnsafeMutableRawPointer?
    private var displayLink: CADisplayLink?
    private var hasPrintedLoop = false

    public var renderer: GBARenderer {
        return gbaRendererInstance
    }
    

    private var retro_init: (@convention(c) () -> Void)?
    private var retro_deinit: (@convention(c) () -> Void)?
    private var retro_set_environment: (@convention(c) (retro_environment_t) -> Void)?
    private var retro_set_video_refresh: (@convention(c) (retro_video_refresh_t) -> Void)?
    private var retro_set_audio_sample: (@convention(c) (retro_audio_sample_t) -> Void)?
    private var retro_set_audio_sample_batch: (@convention(c) (retro_audio_sample_batch_t) -> Void)?
    private var retro_set_input_poll: (@convention(c) (retro_input_poll_t) -> Void)?
    private var retro_set_input_state: (@convention(c) (retro_input_state_t) -> Void)?
    
    // Updated signatures to use UnsafeRawPointer to avoid 'not representable' errors
    private var retro_load_game: (@convention(c) (UnsafeRawPointer) -> Bool)?
    private var retro_get_system_av_info: (@convention(c) (UnsafeMutableRawPointer) -> Void)?
    
    private var retro_run: (@convention(c) () -> Void)?
    
    // Save State Functions
    private var retro_serialize_size: (@convention(c) () -> Int)?
    private var retro_serialize: (@convention(c) (UnsafeMutableRawPointer, Int) -> Bool)?
    private var retro_unserialize: (@convention(c) (UnsafeRawPointer, Int) -> Bool)?
    
    // Memory / SRAM (For native saves)
    private var retro_get_memory_data: (@convention(c) (UInt32) -> UnsafeMutableRawPointer?)?
    private var retro_get_memory_size: (@convention(c) (UInt32) -> Int)?
    
    private var currentROMURL: URL?
    
    public init() {
        
    }
    
 
    func saveState() -> Data? {
        guard let getSize = retro_serialize_size,
              let serialize = retro_serialize else {
            print(" [GBACore] Save State functions not found in core.")
            return nil
        }
        
        let size = getSize()
        print(" [GBACore] State Size Needed: \(size) bytes")
        
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { ptr in
            return serialize(ptr.baseAddress!, size)
        }
        
        if result {
             print(" [GBACore] State captured successfully.")
             return data
        } else {
             print(" [GBACore] Failed to capture state.")
             return nil
        }
    }
    
    func loadState(data: Data) -> Bool {
        guard let unserialize = retro_unserialize else {
             print(" [GBACore] Load State function not found in core.")
             return false
        }
        
        // Safety check on size if possible, though libretro just takes the buffer
        let result = data.withUnsafeBytes { ptr in
            return unserialize(ptr.baseAddress!, data.count)
        }
        
        if result {
            print(" [GBACore] State loaded successfully.")
            return true
        } else {
            print(" [GBACore] Failed to load state.")
            return false
        }
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
        
        // 1. Check Frameworks Directory
        if let frameworksURL = Bundle.main.privateFrameworksURL {
            let frameworkPath = frameworksURL.appendingPathComponent("mgba.framework/mgba").path
            print(" [GBACore] Checking Frameworks Path: \(frameworkPath)")
            if FileManager.default.fileExists(atPath: frameworkPath) {
                print(" [GBACore] Found in Frameworks!")
                corePath = frameworkPath
            } else {
                 // Debug: List content of Frameworks
                 if let contents = try? FileManager.default.contentsOfDirectory(atPath: frameworksURL.path) {
                     print(" [DEBUG] Frameworks Dir Contents: \(contents)")
                 }
            }
        }
        
        // 2. Updated Fallback: Check Bundle Root directly for "mgba.framework"
        if corePath == nil {
             // Check if it's at root/mgba.framework/mgba
             let rootFrameworkPath = Bundle.main.bundleURL.appendingPathComponent("mgba.framework/mgba").path
             print(" [GBACore] Checking Root Path: \(rootFrameworkPath)")
             if FileManager.default.fileExists(atPath: rootFrameworkPath) {
                 print(" [GBACore] Found in Root Bundle!")
                 corePath = rootFrameworkPath
             }
        }
        
        // 3. Last Resort: Loose dylib
        if corePath == nil {
             if let path = Bundle.main.path(forResource: "mgba_libretro_ios", ofType: "dylib") {
                 print(" [GBACore] Found as Resource dylib!")
                 corePath = path
             }
        }

        guard let validPath = corePath else {
            print(" [GBACore] FATAL: Could not find mgba binary anywhere.")
            print(" [DEBUG] Bundle Root Contents: \(try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath))")
            return
        }
        
        print(" [GBACore] Loading Core from: \(validPath)")
        
        coreHandle = dlopen(validPath, RTLD_NOW)
        guard coreHandle != nil else {
            print(" [GBACore] Falló dlopen: \(String(cString: dlerror()))")
            return
        }
        
 
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
        
        // Save State Symbols
        retro_serialize_size = loadSymbol("retro_serialize_size")
        retro_serialize = loadSymbol("retro_serialize")
        retro_unserialize = loadSymbol("retro_unserialize")
        
        retro_get_memory_data = loadSymbol("retro_get_memory_data")
        retro_get_memory_size = loadSymbol("retro_get_memory_size")
        
        // Inicializ
        retro_set_environment?(gba_environment)
        retro_set_video_refresh?(gba_video_refresh)
        retro_set_audio_sample?(gba_audio_sample)
        retro_set_audio_sample_batch?(gba_audio_sample_batch)
        retro_set_input_poll?(gba_input_poll)
        retro_set_input_state?(gba_input_state)
        

        
        retro_init?()
        print("[GBACore] Core mGBA inicializado correctamente.")
    }
    
    private func loadSymbol<T>(_ name: String) -> T? {
        guard let handle = coreHandle else { return nil }
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }
    

    func loadGame(url: URL) -> Bool {
        // Ensure Core is initialized
        if coreHandle == nil {
            loadCore()
        }
        
        // Stop previous loop if running
        stopLoop()
        
        // Save current ROM URL for save data handling
        currentROMURL = url

        
        guard let data = try? Data(contentsOf: url) else {
            print(" [GBACore] Error leyendo ROM: \(url)")
            return false
        }
        
        let path = url.path.cString(using: .utf8)!
        
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let baseAddress = ptr.baseAddress else { return false }
            
            var info = retro_game_info()
            info.path = path.withUnsafeBufferPointer { $0.baseAddress } 
            info.data = baseAddress
            info.size = data.count
            info.meta = nil
            

            guard let success = withUnsafePointer(to: &info, { infoPtr in
                return retro_load_game?(infoPtr)
            }), success else {
                print("[GBACore] retro_load_game falló.")
                return false
            }
        
            
            print(" [GBACore] Juego cargado exitosamente.")
            
            // Load Save RAM (Memory Card) if exists
            loadSaveRAM()
            

            var avInfo = retro_system_av_info()
            withUnsafeMutablePointer(to: &avInfo) { avPtr in
                retro_get_system_av_info?(avPtr)
            }
            
            let sampleRate = avInfo.timing.sample_rate
            self.currentSampleRate = sampleRate // Store for resume
            
            GBAAudio.shared.start(rate: sampleRate)
            
            startLoop(fps: avInfo.timing.fps)
            return true
        }
    }
    
    // MARK: - Pause/Resume Logic
    private var currentFPS: Double = 60.0
    private var currentSampleRate: Double = 44100.0
    
    public func pause() {
        if isRunning {
            isRunning = false
            displayLink?.isPaused = true
            GBAAudio.shared.stop()
            print("sh [GBACore] Paused")
        }
    }
    
    public func resume() {
        if !isRunning && displayLink != nil {
            isRunning = true
            displayLink?.isPaused = false
            GBAAudio.shared.start(rate: currentSampleRate) // Use valid rate
             print(" [GBACore] Resumed at \(currentSampleRate)Hz")
        } else if !isRunning {
             // Re-start if invalidated
             startLoop(fps: currentFPS)
             GBAAudio.shared.start(rate: currentSampleRate)
        }
    }

    private func startLoop(fps: Double) {
        currentFPS = fps
        isRunning = true
        displayLink = CADisplayLink(target: self, selector: #selector(gameLoop))
        
        // Fix for ProMotion (120Hz) - Cap at 60 FPS
        let targetFPS = Float(fps > 0 ? fps : 60.0)
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: targetFPS, maximum: targetFPS, preferred: targetFPS)
        } else {
            displayLink?.preferredFramesPerSecond = Int(targetFPS)
        }
        
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopLoop() {
        // Save RAM before stopping - ALWAYS try to save
        saveSaveRAM()
        
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        GBAAudio.shared.stop()
    }
    
    
    // Fast Forward
    public var isFastForwarding = false
    
    @objc private func gameLoop() {
        if !hasPrintedLoop {
            print(" [GBACore] Game Loop Running...")
            hasPrintedLoop = true
        }
        
        if isFastForwarding {
            // Speed up 3x
            retro_run?()
            retro_run?()
            retro_run?()
        } else {
            retro_run?()
        }
    }
    
    // MARK: - Save RAM (Memory Card) Manual Handling

    private func getSaveRAMPath(extension: String = "sav") -> URL? {
        guard let romURL = currentROMURL,
              let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let saveDir = docDir.appendingPathComponent("saves/gba")
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        
        let saveName = romURL.deletingPathExtension().lastPathComponent + ".\(`extension`)"
        return saveDir.appendingPathComponent(saveName)
    }
    
    func loadSaveRAM() {
        // Try loading .sav first (GBA Standard), then .srm (Libretro Standard)
        var path = getSaveRAMPath(extension: "sav")
        if path == nil || !FileManager.default.fileExists(atPath: path!.path) {
            path = getSaveRAMPath(extension: "srm")
        }
        
        guard let finalPath = path,
              FileManager.default.fileExists(atPath: finalPath.path) else { return }
        
        guard let getData = retro_get_memory_data,
              let getSize = retro_get_memory_size else { return }
        
        let size = getSize(0) // RETRO_MEMORY_SAVE_RAM = 0
        guard size > 0 else { return }
        
        if let ptr = getData(0) {
            if let data = try? Data(contentsOf: finalPath), data.count <= size {
                data.withUnsafeBytes { buffer in
                    ptr.copyMemory(from: buffer.baseAddress!, byteCount: data.count)
                }
                print(" [GBACore] Save RAM loaded: \(finalPath.lastPathComponent)")
            }
        }
    }
    
    func saveSaveRAM() {
       
        guard let path = getSaveRAMPath(extension: "sav") else { return }
        
        guard let getData = retro_get_memory_data,
              let getSize = retro_get_memory_size else { return }
        
        let targetSize = getSize(0) // RETRO_MEMORY_SAVE_RAM = 0
        guard targetSize > 0 else { return }
        
        if let ptr = getData(0) {
            let data = Data(bytes: ptr, count: targetSize)
            do {
                try data.write(to: path)
                print(" [GBACore] Save RAM saved: \(path.lastPathComponent)")
            } catch {
                print(" [GBACore] Failed to write Save RAM: \(error)")
            }
        }
    }
}
