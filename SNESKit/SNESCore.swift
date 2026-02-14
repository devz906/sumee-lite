import Foundation
import SwiftUI
import Combine
import AVFoundation
import GameController
import Darwin

// --- Libretro Types for SNES ---
typealias snes_retro_environment_t = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool
typealias snes_retro_video_refresh_t = @convention(c) (UnsafeRawPointer?, UInt32, UInt32, Int) -> Void
typealias snes_retro_audio_sample_t = @convention(c) (Int16, Int16) -> Void
typealias snes_retro_audio_sample_batch_t = @convention(c) (UnsafePointer<Int16>?, Int) -> Int
typealias snes_retro_input_poll_t = @convention(c) () -> Void
typealias snes_retro_input_state_t = @convention(c) (UInt32, UInt32, UInt32, UInt32) -> Int16

struct snes_retro_game_info {
    var path: UnsafePointer<CChar>? = nil
    var data: UnsafeRawPointer? = nil
    var size: Int = 0
    var meta: UnsafePointer<CChar>? = nil
}

struct snes_retro_system_av_info {
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

// Global instance for C callbacks to access
private let snesRendererInstance = SNESRenderer()

// --- C Callbacks ---

@_cdecl("snes_video_refresh")
func snes_video_refresh(data: UnsafeRawPointer?, width: UInt32, height: UInt32, pitch: Int) {
    guard let data = data else { return }
    // SNES9x outputs RGB565 usually. Pitch is bytes per row.
    if pitch > 0 && width > 0 && height > 0 {
        snesRendererInstance.updateTexture(width: Int(width), height: Int(height), pitch: pitch, data: data)
    }
}

private var snesTempAudioBuffer: [Int16] = [0, 0]

@_cdecl("snes_audio_sample")
func snes_audio_sample(left: Int16, right: Int16) {
    snesTempAudioBuffer[0] = left
    snesTempAudioBuffer[1] = right
    SNESAudio.shared.writeAudio(data: snesTempAudioBuffer, frames: 1)
}

@_cdecl("snes_audio_sample_batch")
func snes_audio_sample_batch(data: UnsafePointer<Int16>?, frames: Int) -> Int {
    guard let data = data else { return 0 }
    SNESAudio.shared.writeAudio(data: data, frames: frames)
    return frames
}

@_cdecl("snes_input_poll")
func snes_input_poll() {
    SNESInput.shared.pollInput()
}

@_cdecl("snes_input_state")
func snes_input_state(port: UInt32, device: UInt32, index: UInt32, id: UInt32) -> Int16 {
    // Port 0 = Player 1
    if port == 0 {
        if device == 1 || device == 0 { // Joypad
            let mask = UInt16(1 << id)
            return (SNESInput.shared.buttonMask & mask) != 0 ? 1 : 0
        }
    }
    return 0
}

@_cdecl("snes_environment")
func snes_environment(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
    switch cmd {
    case 10: // RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
        if let data = data {
            let format = data.bindMemory(to: UInt32.self, capacity: 1).pointee
            // 2 = RGB565 (Standard for SNES9x)
            if format == 2 {
                print(" [SNES] Core set RGB565")
                return true
            }
        }
        return false
    case 31: // RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY
        if let data = data {
            if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let saveDir = docDir.appendingPathComponent("saves/snes")
                try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
                let pathStr = saveDir.path
                let cString = strdup(pathStr)
                data.bindMemory(to: UnsafePointer<CChar>?.self, capacity: 1).pointee = UnsafePointer(cString)
                print("📂 [SNESCore] Save Directory set to: \(pathStr)")
                return true
            }
        }
        return false
    default:
        return false
    }
}

// --- Wrapper ---

public class SNESCore: ObservableObject {
    @Published public var isRunning = false
    private var coreHandle: UnsafeMutableRawPointer?
    private var displayLink: CADisplayLink?
    
    public var renderer: SNESRenderer {
        return snesRendererInstance
    }
    
    // Core Functions
    private var retro_init: (@convention(c) () -> Void)?
    private var retro_deinit: (@convention(c) () -> Void)?
    private var retro_set_environment: (@convention(c) (snes_retro_environment_t) -> Void)?
    private var retro_set_video_refresh: (@convention(c) (snes_retro_video_refresh_t) -> Void)?
    private var retro_set_audio_sample: (@convention(c) (snes_retro_audio_sample_t) -> Void)?
    private var retro_set_audio_sample_batch: (@convention(c) (snes_retro_audio_sample_batch_t) -> Void)?
    private var retro_set_input_poll: (@convention(c) (snes_retro_input_poll_t) -> Void)?
    private var retro_set_input_state: (@convention(c) (snes_retro_input_state_t) -> Void)?
    
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
        let libName = "snes9x_libretro_ios"
        
        // 1. Check Frameworks Directory (Preferred for Embedded Dylibs)
        if let frameworksURL = Bundle.main.privateFrameworksURL {
            // Case A: Inside a .framework wrapper (Standard)
            let frameworkPath = frameworksURL.appendingPathComponent("Snes9x.framework/Snes9x").path
            if FileManager.default.fileExists(atPath: frameworkPath) {
                print(" [SNESCore] Found in Frameworks: \(frameworkPath)")
                corePath = frameworkPath
            }
            // Case B: Fallback
            else {
                let flatPath = frameworksURL.appendingPathComponent("snes9x_libretro_ios.dylib").path
                if FileManager.default.fileExists(atPath: flatPath) {
                    corePath = flatPath
                }
            }
        }
        
        // 2. Fallback: Check Bundle Root / Resources
        if corePath == nil {
            if let path = Bundle.main.path(forResource: libName, ofType: "dylib") {
                corePath = path
            }
        }
        
        guard let validPath = corePath else {
            print(" [SNESCore] Could not find snes9x library.")
            return
        }
        
        print(" [SNESCore] Loading core from: \(validPath)")
        
        coreHandle = dlopen(validPath, RTLD_NOW)
        guard coreHandle != nil else {
            let error = String(cString: dlerror())
            print(" [SNESCore] dlopen failed: \(error)")
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
        
        // Setup Callbacks
        retro_set_environment?(snes_environment)
        retro_set_video_refresh?(snes_video_refresh)
        retro_set_audio_sample?(snes_audio_sample)
        retro_set_audio_sample_batch?(snes_audio_sample_batch)
        retro_set_input_poll?(snes_input_poll)
        retro_set_input_state?(snes_input_state)
        
        retro_init?()
        print("[SNESCore] Initialized")
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
        
        stopLoop()
        
        currentROMURL = url
        
        var info = snes_retro_game_info()
        let path = url.path.cString(using: .utf8)!
        
        return path.withUnsafeBufferPointer { pathPtr in
            info.path = pathPtr.baseAddress
            
            guard let success = withUnsafePointer(to: &info, { retro_load_game?($0) }), success else {
                print("[SNES] Failed to load game path")
                return false
            }
            
            var avInfo = snes_retro_system_av_info()
            withUnsafeMutablePointer(to: &avInfo) { ptr in
                retro_get_system_av_info?(ptr)
            }
            

            var audioRate = avInfo.timing.sample_rate
            if avInfo.timing.fps > 60.05 {
                let ratio = 60.0 / avInfo.timing.fps
                audioRate *= ratio
                print(" [SNESCore] Adjusting Audio Rate: \(avInfo.timing.sample_rate) -> \(audioRate) (Ratio: \(ratio))")
            }
            
            self.currentSampleRate = audioRate // Store for resume
            SNESAudio.shared.start(rate: audioRate)
            
            // Load Save RAM (Battery Save) if exists
            loadSaveRAM()
            
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
            SNESAudio.shared.stop()
            print("sh [SNESCore] Paused")
        }
    }
    
    public func resume() {
        if !isRunning && displayLink != nil {
            isRunning = true
            displayLink?.isPaused = false
            SNESAudio.shared.start(rate: currentSampleRate)
            print(" [SNESCore] Resumed at \(currentSampleRate)Hz")
        } else if !isRunning {
            startLoop(fps: currentFPS)
            SNESAudio.shared.start(rate: currentSampleRate)
        }
    }

    private func startLoop(fps: Double) {
        currentFPS = fps
        isRunning = true
        displayLink = CADisplayLink(target: self, selector: #selector(gameLoop))
        
        let targetFPS = Float(fps > 0 ? fps : 60.0)
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: targetFPS, maximum: targetFPS, preferred: targetFPS)
        } else {
            displayLink?.preferredFramesPerSecond = Int(targetFPS)
        }
        
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopLoop() {
        // Always save RAM
        saveSaveRAM()

        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        SNESAudio.shared.stop()
    }
    

    // MARK: - Fast Forward
    private static var _fastForward = false
    public static var fastForward: Bool {
        get { return _fastForward }
        set {
            if _fastForward && !newValue {
                // Turning OFF Fast Forward -> Flush Audio Buffer to prevent lag
                SNESAudio.shared.flush()
            }
            _fastForward = newValue
        }
    }
    
    @objc private func gameLoop() {
        if SNESCore.fastForward {
            retro_run?()
            retro_run?()
            retro_run?()
        } else {
            retro_run?()
        }
    }
    
    // Save States
    func saveState() -> Data? {
        guard let getSize = retro_serialize_size, let serialize = retro_serialize else { return nil }
        let size = getSize()
        var data = Data(count: size)
        let res = data.withUnsafeMutableBytes { serialize($0.baseAddress!, size) }
        return res ? data : nil
    }
    
    func loadState(data: Data) -> Bool {
        guard let unserialize = retro_unserialize else { return false }
        return data.withUnsafeBytes { unserialize($0.baseAddress!, data.count) }
    }
    
    // MARK: - Save RAM (Memory Card) Manual Handling
    private func getSaveRAMPath(extension: String = "sav") -> URL? {
        guard let romURL = currentROMURL,
              let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let saveDir = docDir.appendingPathComponent("saves/snes")
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        
        let saveName = romURL.deletingPathExtension().lastPathComponent + ".\(`extension`)"
        return saveDir.appendingPathComponent(saveName)
    }
    
    func loadSaveRAM() {
        // Try loading .sav first (User Preference), then .srm (Libretro Standard)
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
                print(" [SNESCore] Save RAM loaded: \(finalPath.lastPathComponent)")
            }
        }
    }
    
    func saveSaveRAM() {
        // Enforce .sav for new saves
        guard let path = getSaveRAMPath(extension: "sav") else { return }
        
        guard let getData = retro_get_memory_data,
              let getSize = retro_get_memory_size else { return }
        
        let targetSize = getSize(0) // RETRO_MEMORY_SAVE_RAM = 0
        guard targetSize > 0 else { return }
        
        if let ptr = getData(0) {
            let data = Data(bytes: ptr, count: targetSize)
            do {
                try data.write(to: path)
                print("[SNESCore] Save RAM saved: \(path.lastPathComponent)")
            } catch {
                print(" [SNESCore] Failed to write Save RAM: \(error)")
            }
        }
    }
}
