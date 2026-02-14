import SwiftUI
import MetalKit

public struct SNESRenderView: UIViewRepresentable {
    public let renderer: SNESRenderer

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

public class SNESRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var texture: MTLTexture?
    
    private struct WeakMTKView { weak var value: MTKView? }
    private var mtkViews: [WeakMTKView] = []
    
    var currentPixelFormat: MTLPixelFormat = .b5g6r5Unorm // SNES standard
    
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
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc = library.makeFunction(name: "snes_vertex"),
              let fragmentFunc = library.makeFunction(name: "snes_fragment") else { return }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print(" [SNESRenderer] Pipeline Error: \(error)")
        }
    }
    
    func updateTexture(width: Int, height: Int, pitch: Int, data: UnsafeRawPointer) {
        if texture == nil || texture?.width != width || texture?.height != height {
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: currentPixelFormat, width: width, height: height, mipmapped: false)
            texture = device.makeTexture(descriptor: desc)
        }
        
        // SNES9x pitch usually matches width * 2 (16 bits), but we respect pitch
        let region = MTLRegionMake2D(0, 0, width, height)
        texture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: pitch)
        
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
