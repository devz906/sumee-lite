import Foundation
import AVFoundation

class PSXAudio {
    static let shared = PSXAudio()
    
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var audioFormat: AVAudioFormat?
    
    // Reduced buffer to ~140ms (12288 samples for stereo) to force low latency.
    // 44100Hz * 2 channels * 0.14s ~= 12348, this works
    private var bufferCapacity: Int = 12288
    
    // Ring Buffer Properties
    private var ringBuffer: [Int16]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    
    private let bufferLock = NSLock()
    
    init() {
        // Initialize buffer
        ringBuffer = Array(repeating: 0, count: bufferCapacity)
    }
    
    func start(rate: Double) {
        // Reset Buffer
        bufferLock.lock()
        writeIndex = 0
        readIndex = 0
        ringBuffer = Array(repeating: 0, count: bufferCapacity)
        bufferLock.unlock()
        
        print(" [PSXAudio] Configuring Audio Engine at requested Core Rate: \(rate) Hz")
        
        // Re-configure Engine if needed or first start
        if audioEngine.isRunning { audioEngine.stop() }
        if let existingNode = sourceNode { audioEngine.detach(existingNode) }
        
        // Configure Format
 
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: false) else {
            print(" [PSXAudio] Failed to create audio format")
            return
        }
        self.audioFormat = format
        
        // Create Source Node (Pull Model)
        let srcNode = AVAudioSourceNode { [weak self] (_, _, frameCount, audioBufferList) -> OSStatus in
            guard let self = self else { return noErr }
            
            let ptr = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let leftBuf = ptr[0].mData?.assumingMemoryBound(to: Float.self)
            let rightBuf = ptr[1].mData?.assumingMemoryBound(to: Float.self)
            
            self.bufferLock.lock()
            defer { self.bufferLock.unlock() }
            
            for i in 0..<Int(frameCount) {
                if self.readIndex != self.writeIndex {
         
                    let sampleL = Float(self.ringBuffer[self.readIndex]) / 32768.0
                    self.readIndex = (self.readIndex + 1) % self.bufferCapacity
                    
                    let sampleR = Float(self.ringBuffer[self.readIndex]) / 32768.0
                    self.readIndex = (self.readIndex + 1) % self.bufferCapacity
                    
                    leftBuf?[i] = sampleL
                    rightBuf?[i] = sampleR
                } else {
                    // Buffer Underrun - Output Silence
                    leftBuf?[i] = 0.0
                    rightBuf?[i] = 0.0
                }
            }
            return noErr
        }
        
        self.sourceNode = srcNode
        audioEngine.attach(srcNode)
        
        // Connect Source -> Mixer
        audioEngine.connect(srcNode, to: audioEngine.mainMixerNode, format: format)
        
        // Activate Session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .gameChat) 
            try session.setActive(true)
        } catch {
            print(" [PSXAudio] Audio Session Warning: \(error)")
        }
        
        // Start Engine
        do {
            try audioEngine.start()
            print(" [PSXAudio] Engine Started. Mixer Rate: \(audioEngine.mainMixerNode.outputFormat(forBus: 0).sampleRate) Hz")
        } catch {
            print(" [PSXAudio] Engine Start Error: \(error)")
        }
    }
    
    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            print(" [PSXAudio] Engine Stopped")
        }
    }
    
    // Called by Core (potentially background thread)
    func writeAudio(data: UnsafePointer<Int16>, frames: Int) {
        if frames <= 0 { return }
        
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Interleaved input: L, R, L, R...
        // Total samples = frames * 2
        let totalSamples = frames * 2
        
        for i in 0..<totalSamples {
            ringBuffer[writeIndex] = data[i]
            
            let nextIndex = (writeIndex + 1) % bufferCapacity
            
            if nextIndex == readIndex {
                // Buffer Full: Push readIndex forward (Drop oldest sample)

                readIndex = (readIndex + 1) % bufferCapacity
            }
            
            writeIndex = nextIndex
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
        // Effectively clears the ring buffer data
    }
}
