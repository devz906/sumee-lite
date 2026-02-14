import Foundation
import AVFoundation

class GBAAudio {
    static let shared = GBAAudio()
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    private var audioFormat: AVAudioFormat?
    

    private let queueLock = NSLock()
    private var buffersInFlight = 0
    private let maxBuffersInFlight = 6
    
    init() {
    }
    
    func start(rate: Double) {
        print("[GBAAudio] Iniciando Audio Engine a \(rate) Hz")
        
        // Reset counters
        queueLock.lock()
        buffersInFlight = 0
        queueLock.unlock()
        
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)
        
        guard let format = audioFormat else {
             print("[GBAAudio] Error creando formato de audio")
             return
        }
        

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("[GBAAudio] AVAudioSession activada. Output Volume: \(session.outputVolume)")
        } catch {
            print("[GBAAudio] AVAudioSession Falló: \(error)")
        }


        engine.detach(playerNode) 
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
    
        playerNode.volume = 1.0
        engine.mainMixerNode.outputVolume = 1.0
        
        do {
            try engine.start()
            playerNode.play()
            print(" [GBAAudio] Audio PlayerNode iniciado. Engine Running: \(engine.isRunning)")
        } catch {
            print(" [GBAAudio] Error iniciando audio: \(error)")
        }
    }
    
    func stop() {
        if engine.isRunning {
            playerNode.stop()
            engine.stop()
            print(" [GBAAudio] Audio Engine Detenido")
        }
    }
    
    // Buffer
    private var tempBuffer: [Int16] = []
    private let bufferFrameThreshold = 4096
    
    func writeAudio(data: UnsafePointer<Int16>, frames: Int) {
        if frames == 0 { return }
        
        queueLock.lock()

        let count = frames * 2
        for i in 0..<count {
            tempBuffer.append(data[i])
        }
        
 
        if tempBuffer.count < (bufferFrameThreshold * 2) {
            queueLock.unlock()
            return
        }
        

        let processingData = Array(tempBuffer)
        tempBuffer.removeAll(keepingCapacity: true)
        let processingFrames = processingData.count / 2
        
   
        if buffersInFlight > maxBuffersInFlight {
   
            queueLock.unlock()
            return 
        }
        buffersInFlight += 1
        queueLock.unlock()
        
        guard let format = audioFormat else { return }
        
        // 1. Buffer PCM
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(processingFrames)) else {
            queueLock.lock()
            buffersInFlight -= 1
            queueLock.unlock()
            return 
        }
        buffer.frameLength = AVAudioFrameCount(processingFrames)
        
        // 2. Int16 -> Float32
        let scale: Float = 1.0 / 32768.0
        let leftChannel = buffer.floatChannelData![0]
        let rightChannel = buffer.floatChannelData![1]
        
        for i in 0..<processingFrames {
            // data interleaved: L R L R
            leftChannel[i] = Float(processingData[i*2]) * scale
            rightChannel[i] = Float(processingData[i*2 + 1]) * scale
        }
        
        // 3. Encolar buffer

        if engine.isRunning {
             playerNode.scheduleBuffer(buffer) { [weak self] in
                 guard let self = self else { return }
                 self.queueLock.lock()
                 self.buffersInFlight -= 1
                 self.queueLock.unlock()
             }
             if !playerNode.isPlaying { playerNode.play() }
        } else {
             queueLock.lock()
             buffersInFlight -= 1
             queueLock.unlock()
             
             try? engine.start()
             playerNode.play()
        }
    }
}
