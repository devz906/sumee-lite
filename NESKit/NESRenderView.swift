import SwiftUI
import MetalKit

public struct NESRenderView: UIViewRepresentable {
    public let renderer: NESRenderer

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = renderer.device
        mtkView.delegate = renderer
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true
        
        mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.contentMode = .scaleToFill
        
        renderer.addView(mtkView)
        return mtkView
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {}
}

public class NESRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var texture: MTLTexture?
    
    private struct WeakMTKView { weak var value: MTKView? }
    private var mtkViews: [WeakMTKView] = []
    
    var currentPixelFormat: MTLPixelFormat = .b5g6r5Unorm // Default 16-bit
    
    public func setPixelFormat(_ format: MTLPixelFormat) {
        if currentPixelFormat != format {
            print("🎨 [NESRenderer] Switching Pixel Format to: \(format == .bgra8Unorm ? "BGRA8888 (32-bit)" : "RGB565 (16-bit)")")
            currentPixelFormat = format
            texture = nil // Force recreation
        }
    }
    
    // Fullscreen Quad
    let vertices: [Float] = [
        -1, -1, 0, 1,
         1, -1, 0, 1,
        -1,  1, 0, 1,
         1,  1, 0, 1
    ]
    let texCoords: [Float] = [
        0, 1,
        1, 1,
        0, 0,
        1, 0
    ]
    var vertexBuffer: MTLBuffer?
    var texCoordBuffer: MTLBuffer?
    
    public override init() {
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal not supported") }
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        
        // Buffers
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
        texCoordBuffer = device.makeBuffer(bytes: texCoords, length: texCoords.count * MemoryLayout<Float>.size, options: [])
        
        buildPipeline()
    }
    
    public func addView(_ view: MTKView) {
        mtkViews.removeAll { $0.value == nil }
        mtkViews.append(WeakMTKView(value: view))
    }
    
    func buildPipeline() {
        // Load Shaders from Default Lib (app bundle)
        // NOTE: Using SNES shaders because NESShaders.metal is not in the project target.
        // The logic is identical (Pass-through Vertex + Texture Sample).
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc = library.makeFunction(name: "snes_vertex"),
              let fragmentFunc = library.makeFunction(name: "snes_fragment") else { 
            print(" [NESRenderer] Failed to load shaders (using snes_vertex/fragment)")
            return 
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print(" [NESRenderer] Pipeline Error: \(error)")
        }
    }
    
    func updateTexture(width: Int, height: Int, pitch: Int, data: UnsafeRawPointer) {
        // NES cores often use aligned pitch (e.g., 512 bytes for 256px width)
       
        let bytesPerPixel = (currentPixelFormat == .bgra8Unorm) ? 4 : 2
        let expectedPitch = width * bytesPerPixel
        
        if texture == nil || texture?.width != width || texture?.height != height {
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: currentPixelFormat, width: width, height: height, mipmapped: false)
            desc.usage = [.shaderRead]
            texture = device.makeTexture(descriptor: desc)
            print("🎬 [NESRenderer] Created texture: \(width)x\(height), fmt=\(bytesPerPixel*8)-bit, expectedPitch=\(expectedPitch), actualPitch=\(pitch)")
        }
        
        let region = MTLRegionMake2D(0, 0, width, height)
        
        if pitch == expectedPitch {
            // Pitch matches - direct copy
            texture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: pitch)
        } else {
            // Pitch is aligned (common in NES cores: 512 bytes for 256px)
            // i need to copy line by line, skipping padding
            // Use a static debug flag to avoid spamming log
            // hope this works
            
            var buffer = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
            let srcPtr = data.assumingMemoryBound(to: UInt8.self)
            
            for y in 0..<height {
                let srcOffset = y * pitch
                let dstOffset = y * expectedPitch
                for x in 0..<expectedPitch {
                    buffer[dstOffset + x] = srcPtr[srcOffset + x]
                }
            }
            
            buffer.withUnsafeBytes { bufferPtr in
                texture?.replace(region: region, mipmapLevel: 0, withBytes: bufferPtr.baseAddress!, bytesPerRow: expectedPitch)
            }
        }
        
        DispatchQueue.main.async {
            self.mtkViews.forEach { $0.value?.setNeedsDisplay() }
        }
    }
    
    public func draw(in view: MTKView) {
        guard let pipelineState = pipelineState,
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let texture = texture,
              let vertBuf = vertexBuffer,
              let texBuf = texCoordBuffer else { return }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertBuf, offset: 0, index: 0)
        encoder.setVertexBuffer(texBuf, offset: 0, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
