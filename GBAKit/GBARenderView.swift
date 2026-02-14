import SwiftUI
import MetalKit

public struct GBARenderView: UIViewRepresentable {
    public let renderer: GBARenderer
    
    public init(renderer: GBARenderer) {
        self.renderer = renderer
    }

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
        
        renderer.registerView(mtkView)
        
        return mtkView
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
    }
}

public class GBARenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var texture: MTLTexture?
    // Support multiple views (Main + Glow)
    private var activeViews = NSHashTable<MTKView>.weakObjects()
    
    public override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("[GBARenderer] Metal no soportado en este dispositivo")
        }
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        
        buildPipeline()
    }
    
    public func registerView(_ view: MTKView) {
        activeViews.add(view)
    }
    
    func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else { 
            print(" [GBARenderer] Failed to load Default Metal Library")
            return 
        }
        

        guard let vertexFunc = library.makeFunction(name: "gba_vertex"),
              let fragmentFunc = library.makeFunction(name: "gba_fragment") else {
            print(" [GBARenderer] Shaders 'gba_vertex' or 'gba_fragment' not found in library")
            return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            print(" [GBARenderer] Pipeline State Created Successfully")
        } catch {
            print("[GBARenderer] Error compilando pipeline: \(error)")
        }
    }
    
   
    func updateTexture(width: Int, height: Int, pitch: Int, data: UnsafeRawPointer) {
        let pixelFormat: MTLPixelFormat = .b5g6r5Unorm 
        
        if texture == nil || texture?.width != width || texture?.height != height {
            print("[GBARenderer] METAL: Creada nueva textura de \(width)x\(height) fmt=\(pixelFormat.rawValue)")
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
            texture = device.makeTexture(descriptor: desc)
        }
        
        let region = MTLRegionMake2D(0, 0, width, height)
        texture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: pitch)
        
        // Notify all registered views (Main + Glow)
        DispatchQueue.main.async {
            self.activeViews.allObjects.forEach { $0.setNeedsDisplay() }
        }
    }
    
    // Dibujado (llamado cada frame)

    public func draw(in view: MTKView) {
        guard let pipelineState = pipelineState else {
            print(" [GBARenderer] Pipeline State is NIL")
            return
        }
        
        guard let drawable = view.currentDrawable else {
  
            return
        }
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            print("[GBARenderer] currentRenderPassDescriptor is NIL")
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("[GBARenderer] Failed to make command buffer")
            return
        }
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        encoder.setRenderPipelineState(pipelineState)
        encoder.setCullMode(.none) 
        
        if let texture = texture {
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
