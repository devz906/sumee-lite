import Foundation
import SwiftUI
import Combine
import AVFoundation
import GameController
import Darwin

// --- Libretro Types for PicoDrive ---
typealias pico_retro_environment_t = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool
typealias pico_retro_video_refresh_t = @convention(c) (UnsafeRawPointer?, UInt32, UInt32, Int) -> Void
typealias pico_retro_audio_sample_t = @convention(c) (Int16, Int16) -> Void
typealias pico_retro_audio_sample_batch_t = @convention(c) (UnsafePointer<Int16>?, Int) -> Int
typealias pico_retro_input_poll_t = @convention(c) () -> Void
typealias pico_retro_input_state_t = @convention(c) (UInt32, UInt32, UInt32, UInt32) -> Int16

struct pico_retro_game_info {
    var path: UnsafePointer<CChar>? = nil
    var data: UnsafeRawPointer? = nil
    var size: Int = 0
    var meta: UnsafePointer<CChar>? = nil
}

struct pico_retro_system_av_info {
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

// Global instance for C callbacks
private let picoRendererInstance = PicoDriveRenderer()
private var picoFirstFrame = true

// --- C Callbacks ---

@_cdecl("pico_video_refresh")
func pico_video_refresh(data: UnsafeRawPointer?, width: UInt32, height: UInt32, pitch: Int) {
    guard let data = data else { return }
    
    if pitch > 0 && width > 0 && height > 0 {
        // Auto-Detect Pixel Format based on Pitch/Width ratio
        let bpp = pitch / Int(width)
        
        // Debug: Log first frame info
        if picoFirstFrame {
            print("🎬 [PicoDrive Video] First frame: \(width)x\(height), pitch=\(pitch), BPP=\(bpp)")
            picoFirstFrame = false
            
            // Switch format if detected 32-bit (BPP ~4)
            if bpp >= 4 {
                picoRendererInstance.setPixelFormat(.bgra8Unorm)
            } else {
                picoRendererInstance.setPixelFormat(.b5g6r5Unorm)
            }
        }
        
        picoRendererInstance.updateTexture(width: Int(width), height: Int(height), pitch: pitch, data: data)
    }
}

private var picoTempAudioBuffer: [Int16] = [0, 0]

@_cdecl("pico_audio_sample")
func pico_audio_sample(left: Int16, right: Int16) {
    picoTempAudioBuffer[0] = left
    picoTempAudioBuffer[1] = right
    PicoDriveAudio.shared.writeAudio(data: picoTempAudioBuffer, frames: 1)
}

@_cdecl("pico_audio_sample_batch")
func pico_audio_sample_batch(data: UnsafePointer<Int16>?, frames: Int) -> Int {
    guard let data = data else { return 0 }
    PicoDriveAudio.shared.writeAudio(data: data, frames: frames)
    return frames
}

@_cdecl("pico_input_poll")
func pico_input_poll() {
    PicoDriveInput.shared.pollInput()
}

@_cdecl("pico_input_state")
func pico_input_state(port: UInt32, device: UInt32, index: UInt32, id: UInt32) -> Int16 {
    // Port 0 = Player 1
    if port == 0 {
        let mask = UInt16(1 << id)
        return (PicoDriveInput.shared.buttonMask & mask) != 0 ? 1 : 0
    }
    return 0
}

@_cdecl("pico_environment")
func pico_environment(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
    switch cmd {
    case 10: // RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
        if let data = data {
            let format = data.bindMemory(to: UInt32.self, capacity: 1).pointee
            // 0 = 0RGB1555, 1 = XRGB8888, 2 = RGB565
            if format == 2 {
                // print("✅ [PicoDrive] Core set RGB565")
                return true
            } else if format == 1 {
                return true
            }
        }
        return false
    case 31: // RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY
        if let data = data {
            if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let saveDir = docDir.appendingPathComponent("saves/picodrive")
                try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
                let pathStr = saveDir.path
                let cString = strdup(pathStr)
                data.bindMemory(to: UnsafePointer<CChar>?.self, capacity: 1).pointee = UnsafePointer(cString)
                print("📂 [PicoDriveCore] Save Directory set to: \(pathStr)")
                return true
            }
        }
        return false
    default:
        return false
    }
}

// --- Wrapper ---

public class PicoDriveCore: ObservableObject {
    @Published public var isRunning = false
    private var coreHandle: UnsafeMutableRawPointer?
    private var displayLink: CADisplayLink?
    
    public var renderer: PicoDriveRenderer {
        return picoRendererInstance
    }
    
    // Core Functions
    private var retro_init: (@convention(c) () -> Void)?
    private var retro_deinit: (@convention(c) () -> Void)?
    private var retro_set_environment: (@convention(c) (pico_retro_environment_t) -> Void)?
    private var retro_set_video_refresh: (@convention(c) (pico_retro_video_refresh_t) -> Void)?
    private var retro_set_audio_sample: (@convention(c) (pico_retro_audio_sample_t) -> Void)?
    private var retro_set_audio_sample_batch: (@convention(c) (pico_retro_audio_sample_batch_t) -> Void)?
    private var retro_set_input_poll: (@convention(c) (pico_retro_input_poll_t) -> Void)?
    private var retro_set_input_state: (@convention(c) (pico_retro_input_state_t) -> Void)?
    
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
        let libName = "picodrive_libretro_ios"
        
        // 1. Check Frameworks Directory (Preferred - if embedded)
        if let frameworksURL = Bundle.main.privateFrameworksURL {
            let flatPath = frameworksURL.appendingPathComponent("picodrive_libretro_ios.dylib").path
            if FileManager.default.fileExists(atPath: flatPath) {
                print(" [PicoDriveCore] Found in Frameworks: \(flatPath)")
                corePath = flatPath
            } else {
                 // Check inside a theoretical PicoDrive.framework
                 let frameworkPath = frameworksURL.appendingPathComponent("PicoDrive.framework/PicoDrive").path
                  if FileManager.default.fileExists(atPath: frameworkPath) {
                      corePath = frameworkPath
                  }
            }
        }
        
        // 2. Fallback: Check Bundle Root / Resources
        if corePath == nil {
            if let path = Bundle.main.path(forResource: "picodrive_libretro_ios", ofType: "dylib") {
                corePath = path
            }
        }
        
        guard let validPath = corePath else {
            print(" [PicoDriveCore] Could not find PicoDrive library. Please add 'picodrive_libretro_ios.dylib' to the target.")
            return
        }
        
        print("📂 [PicoDriveCore] Loading core from: \(validPath)")
        
        coreHandle = dlopen(validPath, RTLD_NOW)
        guard coreHandle != nil else {
            let error = String(cString: dlerror())
            print(" [PicoDriveCore] dlopen failed: \(error)")
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
        retro_set_environment?(pico_environment)
        retro_set_video_refresh?(pico_video_refresh)
        retro_set_audio_sample?(pico_audio_sample)
        retro_set_audio_sample_batch?(pico_audio_sample_batch)
        retro_set_input_poll?(pico_input_poll)
        retro_set_input_state?(pico_input_state)
        
        retro_init?()
        print(" [PicoDriveCore] Initialized")
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
        
        var info = pico_retro_game_info()
        let path = url.path.cString(using: .utf8)!
        
        return path.withUnsafeBufferPointer { pathPtr in
            info.path = pathPtr.baseAddress
            
            guard let success = withUnsafePointer(to: &info, { retro_load_game?($0) }), success else {
                print("❌ [PicoDrive] Failed to load game path")
                return false
            }
            
            var avInfo = pico_retro_system_av_info()
            withUnsafeMutablePointer(to: &avInfo) { ptr in
                retro_get_system_av_info?(ptr)
            }
            
            self.currentSampleRate = avInfo.timing.sample_rate // Store for resume
            PicoDriveAudio.shared.start(rate: avInfo.timing.sample_rate)
            
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
            PicoDriveAudio.shared.stop()
            print("sh [PicoDriveCore] Paused")
        }
    }
    
    public func resume() {
        if !isRunning && displayLink != nil {
            isRunning = true
            displayLink?.isPaused = false
            PicoDriveAudio.shared.start(rate: currentSampleRate) // Use valid rate
            print("▶️ [PicoDriveCore] Resumed at \(currentSampleRate)Hz")
        } else if !isRunning {
            startLoop(fps: currentFPS)
            PicoDriveAudio.shared.start(rate: currentSampleRate)
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
        PicoDriveAudio.shared.stop()
    }
    

    // MARK: - Fast Forward
    public var isFastForwarding = false
    
    @objc private func gameLoop() {
        if isFastForwarding {
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
    
    // MARK: - Save RAM (Battery Save) Manual Handling
    private func getSaveRAMPath() -> URL? {
        guard let romURL = currentROMURL,
              let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let saveDir = docDir.appendingPathComponent("saves/picodrive")
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
                print("💾 [PicoDriveCore] Save RAM loaded: \(path.lastPathComponent)")
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
                print(" [PicoDriveCore] Save RAM saved: \(path.lastPathComponent)")
            } catch {
                print(" [PicoDriveCore] Failed to write Save RAM: \(error)")
            }
        }
    }
}
