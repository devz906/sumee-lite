import SwiftUI
import MetalKit

public struct PSXRenderView: UIViewRepresentable {
    public let renderer: PSXRenderer

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

    public func updateUIView(_ uiView: MTKView, context: Context) {
    }
}

public class PSXRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var texture: MTLTexture?
    // Support for multiple views (Main + Glow)
    private struct WeakMTKView {
        weak var value: MTKView?
    }
    private var mtkViews: [WeakMTKView] = []
    
    
    var currentPixelFormat: MTLPixelFormat = .b5g6r5Unorm
    
    public override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("[PSXRenderer] Metal no soportado")
        }
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        
        buildPipeline()
    }
    
    public func addView(_ view: MTKView) {
        // Remove released views
        mtkViews.removeAll { $0.value == nil }
        // Add new one
        mtkViews.append(WeakMTKView(value: view))
    }
    
    func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else { 
            print(" [PSXRenderer] Failed to load Default Metal Library")
            return 
        }
        
        guard let vertexFunc = library.makeFunction(name: "psx_vertex"),
              let fragmentFunc = library.makeFunction(name: "psx_fragment") else {
            print(" [PSXRenderer] Shaders 'psx_vertex' or 'psx_fragment' not found")
            return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            print(" [PSXRenderer] Pipeline State Created")
        } catch {
            print("[PSXRenderer] Error pipeline: \(error)")
        }
    }
    
    func updateTexture(width: Int, height: Int, pitch: Int, data: UnsafeRawPointer) {
        // PCSXReARMed typically outputs RGB565 (16 bit) default
    
       
        if texture == nil || texture?.width != width || texture?.height != height {
            print("[PSXRenderer] Nueva textura: \(width)x\(height) (Pitch: \(pitch))")
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: currentPixelFormat, width: width, height: height, mipmapped: false)
            texture = device.makeTexture(descriptor: desc)
        }
        
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
              let texture = texture else { return }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setCullMode(.none) 
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
