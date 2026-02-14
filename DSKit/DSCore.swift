import Foundation
import SwiftUI
import Combine
import AVFoundation
import GameController
import Darwin
import UniformTypeIdentifiers
import CoreMotion



// MARK: - Libretro Type Definitions & Global Callbacks


// --- Libretro Type Definitions ---


struct retro_variable {
    var key: UnsafePointer<CChar>?
    var value: UnsafePointer<CChar>?
}

struct retro_input_descriptor {
    var port: UInt32
    var device: UInt32
    var index: UInt32
    var id: UInt32
    var description: UnsafePointer<CChar>?
}

// ------------------------------------------------


private let dsRendererInstance = DSRenderer()


private var dsTopRendererRef: DSRenderer? = nil
private var dsBottomRendererRef: DSRenderer? = nil


private var nds_TouchScreen: UnsafeMutableRawPointer? = nil
private var nds_ReleaseScreen: UnsafeMutableRawPointer? = nil


private func callCppVoid(_ funcPtr: UnsafeMutableRawPointer?) {
    guard let ptr = funcPtr else { return }
    let function = unsafeBitCast(ptr, to: (@convention(c) () -> Void).self)
    function()
}


private func callCppUInt16(_ funcPtr: UnsafeMutableRawPointer?, _ x: UInt16, _ y: UInt16) {
    guard let ptr = funcPtr else { return }
    let function = unsafeBitCast(ptr, to: (@convention(c) (UInt16, UInt16) -> Void).self)
    function(x, y)
}


@_cdecl("ds_video_refresh")
func ds_video_refresh(data: UnsafeRawPointer?, width: UInt32, height: UInt32, pitch: Int) {
    guard let data = data else { return }
    dsRendererInstance.updateTexture(width: Int(width), height: Int(height), pitch: pitch, data: data)
    

    dsTopRendererRef?.updateTexture(width: Int(width), height: Int(height), pitch: pitch, data: data)
    dsBottomRendererRef?.updateTexture(width: Int(width), height: Int(height), pitch: pitch, data: data)
}

private var dsTempAudioBuffer: [Int16] = [0, 0]

@_cdecl("ds_audio_sample")
func ds_audio_sample(left: Int16, right: Int16) {
    dsTempAudioBuffer[0] = left
    dsTempAudioBuffer[1] = right
    DSAudio.shared.writeAudio(data: dsTempAudioBuffer, frames: 1)
}

@_cdecl("ds_audio_sample_batch")
func ds_audio_sample_batch(data: UnsafePointer<Int16>?, frames: Int) -> Int {
    guard let data = data else { return 0 }
    DSAudio.shared.writeAudio(data: data, frames: frames)
    return frames
}

@_cdecl("ds_input_poll")
func ds_input_poll() {
    // Polling Input (Fix Latency)
    DSInput.shared.pollInput()
    

    let userIsTouching = DSInput.shared.isTouched
    let touchX = DSInput.shared.touchX
    let touchY = DSInput.shared.touchY
    
    if userIsTouching {
        callCppUInt16(nds_TouchScreen, UInt16(touchX), UInt16(touchY))
    } else {
        callCppVoid(nds_ReleaseScreen)
    }
}

@_cdecl("ds_input_state")
func ds_input_state(port: UInt32, device: UInt32, index: UInt32, id: UInt32) -> Int16 {
    // Port 0 es Player 1
    if port == 0 {
        if device == 1 || device == 0 { // Joypad or Generic
            
      
            if DSCore.isMicrophoneBlowing {
                if id == 12 || (id >= 16 && id <= 25) {
                    return 1
                }
            }

            if id < 16 {
                let mask = UInt16(1 << id)
                return (DSInput.shared.buttonMask & mask) != 0 ? 1 : 0
            }
        } else if device == 2 { // Pointer (Touch)
            if id == 0 { return DSInput.shared.touchX }
            if id == 1 { return DSInput.shared.touchY }
            if id == 2 { return DSInput.shared.isTouched ? 1 : 0 }
        }
    }
    return 0
}

@_cdecl("ds_environment")
func ds_environment(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
    switch cmd {
    case 3: // RETRO_ENVIRONMENT_GET_CAN_DUPE
        if let data = data {
            data.bindMemory(to: Bool.self, capacity: 1).pointee = true
        }
        return true
        
    case 9: // RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY
        if let data = data {
            // Define system directory: Documents/system
            if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let sysDir = docDir.appendingPathComponent("system")
                try? FileManager.default.createDirectory(at: sysDir, withIntermediateDirectories: true)
                
                let pathStr = sysDir.path
                // Use a static buffer or ensure lifetime. For bridging, usually temporary string is risky but common in Libretro wrappers if copied immediately.
       
                let cString = strdup(pathStr)
                data.bindMemory(to: UnsafePointer<CChar>?.self, capacity: 1).pointee = UnsafePointer(cString)
                print("📂 [DSCore] System Directory set to: \(pathStr)")
                return true
            }
        }
        return false

    case 31: // RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY
        if let data = data {
            if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let saveDir = docDir.appendingPathComponent("saves/ds")
                try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
                
                let pathStr = saveDir.path
                let cString = strdup(pathStr)
                data.bindMemory(to: UnsafePointer<CChar>?.self, capacity: 1).pointee = UnsafePointer(cString)
                print(" [DSCore] Save Directory set to: \(pathStr)")
                return true
            }
        }
        return false

    case 10: // RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
        if let data = data {
            let format = data.bindMemory(to: UInt32.self, capacity: 1).pointee
            
            if format == 1 { // RETRO_PIXEL_FORMAT_XRGB8888
                print("[DSCore] Core requested XRGB8888. Allowed. Using .bgra8Unorm.")
                dsRendererInstance.currentPixelFormat = .bgra8Unorm
                dsTopRendererRef?.currentPixelFormat = .bgra8Unorm
                dsBottomRendererRef?.currentPixelFormat = .bgra8Unorm
                return true
            } else if format == 2 { // RETRO_PIXEL_FORMAT_RGB565
                print(" [DSCore] Core requested RGB565. Allowed. Using .b5g6r5Unorm.")
                dsRendererInstance.currentPixelFormat = .b5g6r5Unorm
                dsTopRendererRef?.currentPixelFormat = .b5g6r5Unorm
                dsBottomRendererRef?.currentPixelFormat = .b5g6r5Unorm
                return true
            } else {
                 print("[DSCore] Core requested unsupported format \(format). Denied.")
                 return false 
            }
        }
        return false
        
    case 16: // RETRO_ENVIRONMENT_GET_VARIABLE
        if let data = data {
            let variable = data.bindMemory(to: retro_variable.self, capacity: 1).pointee
            if let key = variable.key {
                let keyString = String(cString: key)
                // print("🔍 [DSCore] Core requested variable: \(keyString)")
                
                if keyString == "melonds_jit_enable" {
                    // Critical Fix for Pokémon White 2 / Black 2 (IRE*, IRB*)
                    // These games require JIT enabled (or stricter timing) to prevent black screen on cutscenes.
                    // For other games, we keep JIT disabled by default for stability on this port.
                    let shouldEnableJIT = DSCore.activeGameID.hasPrefix("IRE") || DSCore.activeGameID.hasPrefix("IRB")
                    
                    if shouldEnableJIT {
                        print("⚙️ [DSCore] Enabling JIT for Pokémon BW2 (Fix Cutscene Freeze)")
                        let value = strdup("enabled")
                        data.bindMemory(to: retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                    } else {
                        print("⚙️ [DSCore] Disabling JIT (Default Stability)")
                        let value = strdup("disabled")
                        data.bindMemory(to: retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                    }
                    return true
                }
                
                // Microphone Configuration (Legacy MelonDS Key)
     
                if keyString == "melonds_mic_input" || keyString == "melonds_microphone_input" {
  
                     let value = strdup("blow")
                     data.bindMemory(to: retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                     return true
                }
                
                // Increase resolution for smoother 3D (Dynamic)
                if keyString == "melonds_internal_resolution" {
                    let res = DSCore.internalResolution
                    print(" [DSCore] Setting Internal Resolution -> \(res)x")
                    let value = strdup("\(res)") 
                    data.bindMemory(to: retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                    return true
                }
                
                // FORCE DS MODE (Fix for Pokemon White 2 and DSi-Enhanced games)
                if keyString == "melonds_console_mode" {
                    print(" [DSCore] Forcing Console Mode -> DS")
                    let value = strdup("DS")
                    data.bindMemory(to: retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                    return true
                }
                
                // Force Direct Boot (Bypass BIOS if missing)
                if keyString == "melonds_boot_directly" {
                     print(" [DSCore] Forcing Boot Directly -> enabled")
                     let value = strdup("enabled") 
                     data.bindMemory(to: retro_variable.self, capacity: 1).pointee.value = UnsafePointer(value)
                     return true
                }
            }
        }
        return false
        
    case 24:
          return true
        
    case 18:
         return true

    default:
  
        return false
    }
}


public class DSCore: ObservableObject {
    @Published public var isRunning = false
    private var coreHandle: UnsafeMutableRawPointer?
    private var displayLink: CADisplayLink?
    
    // Perform memory management for ROM data to prevent use-after-free
    private var romData: Data?

    private var hasPrintedLoop = false
    
    // Global Settings (Static for C-Bridge Access)
    public static var activeGameID: String = "" // Stores current Game Code (e.g. IREO)
    public static var internalResolution: Int = 4 // Default to 4x (Max)
    
    // Renderers para cada pantalla en modo horizontal
    private let dsTopRenderer: DSRenderer = DSRenderer()
    private let dsBottomRenderer: DSRenderer = DSRenderer()
    
    public var renderer: DSRenderer {
        return dsRendererInstance
    }
    
    public var topRenderer: DSRenderer {
        // Sync Pixel Format from main instance (in case we missed the environment call)
        dsTopRenderer.currentPixelFormat = dsRendererInstance.currentPixelFormat
        // Actualizar referencia global
        dsTopRendererRef = dsTopRenderer
        return dsTopRenderer
    }
    
    public var bottomRenderer: DSRenderer {
        // Sync Pixel Format from main instance
        dsBottomRenderer.currentPixelFormat = dsRendererInstance.currentPixelFormat
        // Actualizar referencia global
        dsBottomRendererRef = dsBottomRenderer
        return dsBottomRenderer
    }
    
    // Punteros Crudos (Raw Pointers)
    private var ptr_retro_init: UnsafeMutableRawPointer?
    private var ptr_retro_deinit: UnsafeMutableRawPointer?
    private var ptr_retro_set_environment: UnsafeMutableRawPointer?
    private var ptr_retro_set_video_refresh: UnsafeMutableRawPointer?
    private var ptr_retro_set_audio_sample: UnsafeMutableRawPointer?
    private var ptr_retro_set_audio_sample_batch: UnsafeMutableRawPointer?
    private var ptr_retro_set_input_poll: UnsafeMutableRawPointer?
    private var ptr_retro_set_input_state: UnsafeMutableRawPointer?
    
    // Controller Port
    private var ptr_retro_set_controller_port_device: UnsafeMutableRawPointer?
    
    private var ptr_retro_load_game: UnsafeMutableRawPointer?
    private var ptr_retro_get_system_av_info: UnsafeMutableRawPointer?
    private var ptr_retro_run: UnsafeMutableRawPointer?
    
    private var ptr_retro_serialize_size: UnsafeMutableRawPointer?
    private var ptr_retro_serialize: UnsafeMutableRawPointer?
    private var ptr_retro_unserialize: UnsafeMutableRawPointer?
    
    // Memory / SRAM (For native saves)
    private var ptr_retro_get_memory_data: UnsafeMutableRawPointer?
    private var ptr_retro_get_memory_size: UnsafeMutableRawPointer?
    
    private var currentROMURL: URL?
    
    // Punteros a funciones internas de NDS
    private var ptr_nds_TouchScreen: UnsafeMutableRawPointer?
    private var ptr_nds_ReleaseScreen: UnsafeMutableRawPointer?

    // Computed Properties (Safe Casting)
    private var retro_init: (@convention(c) () -> Void)? {
        guard let ptr = ptr_retro_init else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) () -> Void).self)
    }
    
    private var retro_deinit: (@convention(c) () -> Void)? {
        guard let ptr = ptr_retro_deinit else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) () -> Void).self)
    }
    
    private var retro_set_environment: (@convention(c) (retro_environment_t) -> Void)? {
        guard let ptr = ptr_retro_set_environment else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (retro_environment_t) -> Void).self)
    }
    
    private var retro_set_video_refresh: (@convention(c) (retro_video_refresh_t) -> Void)? {
        guard let ptr = ptr_retro_set_video_refresh else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (retro_video_refresh_t) -> Void).self)
    }
    
    private var retro_set_audio_sample: (@convention(c) (retro_audio_sample_t) -> Void)? {
        guard let ptr = ptr_retro_set_audio_sample else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (retro_audio_sample_t) -> Void).self)
    }
    
    private var retro_set_audio_sample_batch: (@convention(c) (retro_audio_sample_batch_t) -> Void)? {
        guard let ptr = ptr_retro_set_audio_sample_batch else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (retro_audio_sample_batch_t) -> Void).self)
    }
    
    private var retro_set_input_poll: (@convention(c) (retro_input_poll_t) -> Void)? {
        guard let ptr = ptr_retro_set_input_poll else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (retro_input_poll_t) -> Void).self)
    }
    
    private var retro_set_input_state: (@convention(c) (retro_input_state_t) -> Void)? {
        guard let ptr = ptr_retro_set_input_state else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (retro_input_state_t) -> Void).self)
    }
    
    private var retro_set_controller_port_device: (@convention(c) (UInt32, UInt32) -> Void)? {
         guard let ptr = ptr_retro_set_controller_port_device else { return nil }
         return unsafeBitCast(ptr, to: (@convention(c) (UInt32, UInt32) -> Void).self)
    }
    
    private var retro_load_game: (@convention(c) (UnsafeRawPointer) -> Bool)? {
        guard let ptr = ptr_retro_load_game else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (UnsafeRawPointer) -> Bool).self)
    }
    
    private var retro_get_system_av_info: (@convention(c) (UnsafeMutableRawPointer) -> Void)? {
        guard let ptr = ptr_retro_get_system_av_info else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (UnsafeMutableRawPointer) -> Void).self)
    }
    
    private var retro_run: (@convention(c) () -> Void)? {
        guard let ptr = ptr_retro_run else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) () -> Void).self)
    }
    
    private var retro_serialize_size: (@convention(c) () -> Int)? {
        guard let ptr = ptr_retro_serialize_size else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) () -> Int).self)
    }
    
    private var retro_serialize: (@convention(c) (UnsafeMutableRawPointer, Int) -> Bool)? {
        guard let ptr = ptr_retro_serialize else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (UnsafeMutableRawPointer, Int) -> Bool).self)
    }
    
    private var retro_unserialize: (@convention(c) (UnsafeRawPointer, Int) -> Bool)? {
        guard let ptr = ptr_retro_unserialize else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (UnsafeRawPointer, Int) -> Bool).self)
    }
    
    private var retro_get_memory_data: (@convention(c) (UInt32) -> UnsafeMutableRawPointer?)? {
        guard let ptr = ptr_retro_get_memory_data else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (UInt32) -> UnsafeMutableRawPointer?).self)
    }
    
    private var retro_get_memory_size: (@convention(c) (UInt32) -> Int)? {
        guard let ptr = ptr_retro_get_memory_size else { return nil }
        return unsafeBitCast(ptr, to: (@convention(c) (UInt32) -> Int).self)
    }
    
    public init() {
        // Lazy initialization: Core will be loaded when loadGame() is called.
    }
    
    public func saveState() -> Data? {
        guard let getSize = retro_serialize_size,
              let serialize = retro_serialize else {
            print("[DSCore] Save State functions not found in core.")
            return nil
        }
        
        let size = getSize()
        print(" [DSCore] State Size Needed: \(size) bytes")
        
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { ptr in
            return serialize(ptr.baseAddress!, size)
        }
        
        if result {
             print(" [DSCore] State captured successfully.")
             return data
        } else {
             print(" [DSCore] Failed to capture state.")
             return nil
        }
    }
    
    func loadState(data: Data) -> Bool {
        guard let unserialize = retro_unserialize else {
             print(" [DSCore] Load State function not found in core.")
             return false
        }
        
        let result = data.withUnsafeBytes { ptr in
            return unserialize(ptr.baseAddress!, data.count)
        }
        
        if result {
            print(" [DSCore] State loaded successfully.")
            return true
        } else {
            print(" [DSCore] Failed to load state.")
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
        
        // 1. Check Frameworks Directory (Production)
        if let frameworksURL = Bundle.main.privateFrameworksURL {
            let frameworkPath = frameworksURL.appendingPathComponent("melonds.framework/melonds").path
            print(" [DSCore] Checking Frameworks Path: \(frameworkPath)")
            if FileManager.default.fileExists(atPath: frameworkPath) {
                print(" [DSCore] Found in Frameworks!")
                corePath = frameworkPath
            }
        }
        
        // 2. Updated Fallback: Check Bundle Root directly for "melonds.framework"
        if corePath == nil {
             let rootFrameworkPath = Bundle.main.bundleURL.appendingPathComponent("melonds.framework/melonds").path
             print(" [DSCore] Checking Root Path: \(rootFrameworkPath)")
             if FileManager.default.fileExists(atPath: rootFrameworkPath) {
                 print(" [DSCore] Found in Root Bundle!")
                 corePath = rootFrameworkPath
             }
        }
        
        // 3. Search for raw dylib in Frameworks (Most likely for 'Embed & Sign')
        if corePath == nil, let frameworksURL = Bundle.main.privateFrameworksURL {
             let dylibPath = frameworksURL.appendingPathComponent("melonds_libretro_ios.dylib").path
             print(" [DSCore] Checking Frameworks dylib: \(dylibPath)")
             if FileManager.default.fileExists(atPath: dylibPath) {
                 print(" [DSCore] Found dylib in Frameworks!")
                 corePath = dylibPath
             }
        }

        // 4. Last Resort: Loose dylib in Bundle Resources
        if corePath == nil {
             print(" [DSCore] Checking Bundle Resource 'melonds_libretro_ios'")
             if let path = Bundle.main.path(forResource: "melonds_libretro_ios", ofType: "dylib") {
                 print(" [DSCore] Found as Resource dylib!")
                 corePath = path
             } else {
                 // Try cleaning up name if user renamed it
                  if let path = Bundle.main.path(forResource: "melonds", ofType: "dylib") {
                     print("[DSCore] Found as 'melonds.dylib'!")
                     corePath = path
                 }
             }
        }

        guard let validPath = corePath else {
            print(" [DSCore] FATAL: Could not find melonds binary anywhere.")
            return
        }
        
        print(" [DSCore] Loading Core from: \(validPath)")
        
        coreHandle = dlopen(validPath, RTLD_NOW)
        guard coreHandle != nil else {
            print(" [DSCore] Falló dlopen: \(String(cString: dlerror()))")
            return
        }
        
        // Cargar Símbolos (Directo a RawPointer)
        ptr_retro_init = dlsym(coreHandle, "retro_init")
        ptr_retro_deinit = dlsym(coreHandle, "retro_deinit")
        ptr_retro_set_environment = dlsym(coreHandle, "retro_set_environment")
        ptr_retro_set_video_refresh = dlsym(coreHandle, "retro_set_video_refresh")
        ptr_retro_set_audio_sample = dlsym(coreHandle, "retro_set_audio_sample")
        ptr_retro_set_audio_sample_batch = dlsym(coreHandle, "retro_set_audio_sample_batch")
        ptr_retro_set_input_poll = dlsym(coreHandle, "retro_set_input_poll")
        ptr_retro_set_input_state = dlsym(coreHandle, "retro_set_input_state")
        ptr_retro_set_controller_port_device = dlsym(coreHandle, "retro_set_controller_port_device")
        
        ptr_retro_load_game = dlsym(coreHandle, "retro_load_game")
        ptr_retro_run = dlsym(coreHandle, "retro_run")
        ptr_retro_get_system_av_info = dlsym(coreHandle, "retro_get_system_av_info")
        
        ptr_retro_serialize_size = dlsym(coreHandle, "retro_serialize_size")
        ptr_retro_serialize = dlsym(coreHandle, "retro_serialize")
        ptr_retro_unserialize = dlsym(coreHandle, "retro_unserialize")
        
        ptr_retro_get_memory_data = dlsym(coreHandle, "retro_get_memory_data")
        ptr_retro_get_memory_size = dlsym(coreHandle, "retro_get_memory_size")
        
        // Cargar funciones internas de NDS para acceso directo al toque
        ptr_nds_TouchScreen = dlsym(coreHandle, "_ZN3NDS11TouchScreenEtt")
        ptr_nds_ReleaseScreen = dlsym(coreHandle, "_ZN3NDS13ReleaseScreenEv")
        
        // Actualizar referencias globales para los callbacks
        nds_TouchScreen = ptr_nds_TouchScreen
        nds_ReleaseScreen = ptr_nds_ReleaseScreen
        
        // Inicializar
        retro_set_environment?(ds_environment)
        retro_set_video_refresh?(ds_video_refresh)
        retro_set_audio_sample?(ds_audio_sample)
        retro_set_audio_sample_batch?(ds_audio_sample_batch)
        retro_set_input_poll?(ds_input_poll)
        retro_set_input_state?(ds_input_state)
        
        retro_init?()
        print(" [DSCore] Core melonDS inicializado correctamente.")
    }
    

    
    public func loadGame(url: URL) -> Bool {
        // Ensure Core is initialized
        if coreHandle == nil {
            loadCore()
        }
        
        stopLoop()
        
        // Save current ROM URL for save data handling
        currentROMURL = url
        
        // OPTIMIZATION: Use Memory Mapping (.mappedIfSafe)

        
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            self.romData = data // Retain data to prevent deallocation
            print(" [DSCore] Mapped ROM data into memory (Size: \(data.count) bytes)")
            
            let path = url.path.cString(using: .utf8)!
            
            return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                guard let baseAddress = ptr.baseAddress else { return false }
                
                // Read Game ID (Offset 0x0C, Length 4)
                let gameID: String
                if data.count >= 0x10 {
                    let idData = data.subdata(in: 0x0C..<0x10)
                    gameID = String(data: idData, encoding: .ascii) ?? "UNKN"
                    print(" [DSCore] Detected Game ID: \(gameID)")
                } else {
                    gameID = "UNKN"
                }
                DSCore.activeGameID = gameID
                
                // Keep the path valid
                return path.withUnsafeBufferPointer { pathPtr in
                    
                    // Set Controller Port 0 to Joypad (Device 1)
                    print(" [DSCore] Setting Controller Port Device...")
                    retro_set_controller_port_device?(0, 1)
                    
                    var info = retro_game_info()
                    info.path = pathPtr.baseAddress
                    // Pass the MAPPED pointer. The core will likely copy this, 
                    // consuming 512MB of Core RAM, but simpler Swift RAM usage remains low.
                    info.data = baseAddress
                    info.size = data.count
                    info.meta = nil
                    
                    print(" [DSCore] Loading Game via Mapped Data: \(url.lastPathComponent)")
                    print(" [DSCore] Calling retro_load_game...")
                    
                    guard withUnsafePointer(to: &info, { infoPtr in
                        let result = retro_load_game?(infoPtr) ?? false
                        print("[DSCore] retro_load_game returned: \(result)")
                        return result
                    }) else {
                        print("❌ [DSCore] retro_load_game falló (returned false).")
                        return false
                    }
                    
                    print("[DSCore] Juego cargado exitosamente.")
                    
                    // Load Save RAM (Memory Card) if exists
                    loadSaveRAM()
                    
                    var avInfo = retro_system_av_info()
                    withUnsafeMutablePointer(to: &avInfo) { avPtr in
                        retro_get_system_av_info?(avPtr)
                    }
                    
                    let sampleRate = avInfo.timing.sample_rate
                    print(" [DSCore] Audio Sample Rate: \(sampleRate)Hz, FPS: \(avInfo.timing.fps)")
                    self.currentSampleRate = sampleRate // Store for resume
                    DSAudio.shared.start(rate: sampleRate)
                    
                    self.startLoop(fps: avInfo.timing.fps)
                    return true
                }
            }
        } catch {
            print(" [DSCore] Error mapping ROM: \(error)")
            return false
        }
    }
    
    private func startLoop(fps: Double) {
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
        
        // Monitor Micro, dosn't work it might never
        // startMicrophone() // Disabled
        
        // Monitor Motion (Lid)
        startMotion()
    }
    
    // MARK: - Pause/Resume Logic
    private var currentFPS: Double = 60.0
    private var currentSampleRate: Double = 44100.0
    
    public func pause() {
        if isRunning {
            isRunning = false
            displayLink?.isPaused = true
            DSAudio.shared.stop()
            stopMicrophone()
            stopMotion()
            print("sh [DSCore] Paused")
        }
    }
    
    public func resume() {
        if !isRunning && displayLink != nil {
            isRunning = true
            displayLink?.isPaused = false
            DSAudio.shared.start(rate: currentSampleRate) // Use valid rate
            startMotion() // Restart motion
            print("[DSCore] Resumed at \(currentSampleRate)Hz")
        } else if !isRunning {
            startLoop(fps: currentFPS)
            DSAudio.shared.start(rate: currentSampleRate)
        }
    }
    
    public func stopLoop() {
        // Save RAM before stopping - ALWAYS try to save
        saveSaveRAM()
        
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        DSAudio.shared.stop()
        stopMicrophone()
        stopMotion()
    }
    
    // MARK: - Microphone Support I really don't know why it dosen't wokr
    private var micRecorder: AVAudioRecorder?
    private var micTimer: Timer?
    
    private func setupMicrophone() {
        // Request Permission
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
            print("[DSCore] Mic Permission: \(allowed)")
        }
        
        // HACK: Reset Audio Session Category to PlayAndRecord to ensure mixing works
        // This is often needed if other apps or system sounds stole focus (i will keep this for now)
        /*
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
             print(" [DSCore] Failed to reset Audio Session: \(error)")
        }
        */
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]
        
        do {
            // NOTE: AudioSession is already configured by DSAudio.start() with .playAndRecord
            // We just need to attach the recorder.
            
            let url = URL(fileURLWithPath: "/dev/null")
            micRecorder = try AVAudioRecorder(url: url, settings: settings)
            micRecorder?.isMeteringEnabled = true
            micRecorder?.prepareToRecord()
            print(" [DSCore] Microphone Setup Complete")
        } catch {
            print(" [DSCore] Mic Setup Failed: \(error)")
        }
    }
    
    private func startMicrophone() {
        if micRecorder == nil { setupMicrophone() }
        micRecorder?.record()
        
        // Monitor levels
        micTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMicLevel()
        }
    }
    
    private func stopMicrophone() {
        micRecorder?.stop()
        micTimer?.invalidate()
        micTimer = nil
    }
    
    private func checkMicLevel() {
         micRecorder?.updateMeters()
         let power = micRecorder?.averagePower(forChannel: 0) ?? -160.0
         
         // Threshold: -20 dB (Adjust based on testing)
         let isBlowing = power > -10.0
         DSCore.isMicrophoneBlowing = isBlowing
         
         if isBlowing && !hasPrintedLoop {
             print(" [DSCore] Microphone BLOW Detected! (Power: \(power))")
             hasPrintedLoop = true // Anti-spam
         } else if !isBlowing {
             hasPrintedLoop = false
         }
    }
    
    // MARK: - Motion Support (Lid Close)
    private let motionManager = CMMotionManager()
    private var motionTimer: Timer?
    
    private func startMotion() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.2
            motionManager.startDeviceMotionUpdates()
            
            motionTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                self?.checkOrientation()
            }
            print("📱 [DSCore] Motion Monitoring Started")
        }
    }
    
    private func stopMotion() {
        motionManager.stopDeviceMotionUpdates()
        motionTimer?.invalidate()
        motionTimer = nil
    }
    
    private func checkOrientation() {
        guard let data = motionManager.deviceMotion else { return }
        
      
        let isFaceDown = data.gravity.z > 0.8

        DSInput.shared.setButton(DSInput.ID_LID, pressed: isFaceDown)

    }

    // MARK: - Fast Forward
    public static var fastForward = false
    public static var isMicrophoneBlowing = false
    
    @objc private func gameLoop() {
        if !hasPrintedLoop {
            print(" [DSCore] Game Loop Running...")
            hasPrintedLoop = true
        }
        
        if DSCore.fastForward {
            // Speed up 3x
            retro_run?()
            retro_run?()
            retro_run?()
        } else {
            retro_run?()
        }
    }
    

    
    // MARK: - Save RAM (Memory Card) Manual Handling
    private func getSaveRAMPath() -> URL? {
        guard let romURL = currentROMURL,
              let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let saveDir = docDir.appendingPathComponent("saves/ds")
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        
        let saveName = romURL.deletingPathExtension().lastPathComponent + ".dsv"
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
                print(" [DSCore] Save RAM loaded: \(path.lastPathComponent)")
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
                print(" [DSCore] Save RAM saved: \(path.lastPathComponent)")
            } catch {
                print(" [DSCore] Failed to write Save RAM: \(error)")
            }
        }
    }
}
