import Foundation
import AVFoundation
import Combine

class SNESAudio: ObservableObject {
    static let shared = SNESAudio()
    
    private var audioEngine: AVAudioEngine
    private var sourceNode: AVAudioSourceNode?
    private var audioFormat: AVAudioFormat?
    
    // Ring Buffer
    private var ringBuffer: [Int16]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var bufferCapacity: Int = 16384
    private let bufferLock = NSLock()
    
    private let targetSampleRate: Double = 44100.0
    
    init() {
        audioEngine = AVAudioEngine()
        ringBuffer = Array(repeating: 0, count: bufferCapacity)
    }
    
    func start(rate: Double) {
        // Reset Buffer
        bufferLock.lock()
        writeIndex = 0
        readIndex = 0
        ringBuffer = Array(repeating: 0, count: bufferCapacity)
        bufferLock.unlock()
        
        // Re-configure Engine if needed or first start
        if audioEngine.isRunning { audioEngine.stop() }
        
        // SNES usually provides ~32000Hz or 44100Hz.

        let outputNode = audioEngine.outputNode
        var engineFormat = outputNode.outputFormat(forBus: 0)
        
        // Force Standard Format

        
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: false)!
        self.audioFormat = format
        
        print("🔊 [SNESAudio] Core Rate: \(rate)Hz. Engine Mixer Rate: \(engineFormat.sampleRate)Hz")
        
        // Create Source Node
        let srcNode = AVAudioSourceNode { [weak self] (_, _, frameCount, audioBufferList) -> OSStatus in
            guard let self = self else { return noErr }
            
            let ptr = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let leftBuf = ptr[0].mData?.assumingMemoryBound(to: Float.self)
            let rightBuf = ptr[1].mData?.assumingMemoryBound(to: Float.self)
            
            self.bufferLock.lock()
            defer { self.bufferLock.unlock() }
            
            for i in 0..<Int(frameCount) {
                if self.readIndex != self.writeIndex {
                    // Read sample
                    let sampleL = Float(self.ringBuffer[self.readIndex]) / 32768.0
                    self.readIndex = (self.readIndex + 1) % self.bufferCapacity
                    
                    let sampleR = Float(self.ringBuffer[self.readIndex]) / 32768.0
                    self.readIndex = (self.readIndex + 1) % self.bufferCapacity
                    
                    leftBuf?[i] = sampleL
                    rightBuf?[i] = sampleR
                } else {
                    // Buffer Underrun
                    leftBuf?[i] = 0.0
                    rightBuf?[i] = 0.0
                }
            }
            return noErr
        }
        
        self.sourceNode = srcNode
        audioEngine.attach(srcNode)
        
        // Important: Connect using the format matching the CORE rate.
      
        audioEngine.connect(srcNode, to: audioEngine.mainMixerNode, format: format)
        
        do {
            try audioEngine.start()
        } catch {
            print("[SNESAudio] Start error: \(error)")
        }
    }
    
    func stop() {
        audioEngine.stop()
        if let node = sourceNode {
            audioEngine.detach(node)
            sourceNode = nil
        }
    }
    
    // Core calls this (likely Main Thread or Emulation Thread)
    func writeAudio(data: UnsafePointer<Int16>, frames: Int) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // We receive interleaved Int16 (L, R, L, R...)

        
        let totalSamples = frames * 2
        
        // Simple write loop
        for i in 0..<totalSamples {
            let nextIndex = (writeIndex + 1) % bufferCapacity
            
            if nextIndex != readIndex {
                // Space available
                ringBuffer[writeIndex] = data[i]
                writeIndex = nextIndex
            } else {
   
  
                break 
            }
        }
    }
    
    func writeAudio(data: [Int16], frames: Int) {
        data.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                writeAudio(data: base, frames: frames)
            }
        }
    }
    
    func flush() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        writeIndex = 0
        readIndex = 0
        // Optional: clear array, but resetting indices is enough invalidation
    }
}
