import SwiftUI
import SceneKit
import UIKit

struct Real3DIconView: UIViewRepresentable {
    let textureImage: UIImage?
    let isRotating: Bool
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = true
        
        let scene = SCNScene()
        scnView.scene = scene
        
        // 1. Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 5)
        scene.rootNode.addChildNode(cameraNode)
        
        // 2. Light
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(x: 10, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor(white: 0.5, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLightNode)
        
        // 3. Hierarchy: Root -> Pivot (Rotates Y) -> CylinderContainer (Rotates X) -> Cylinder
        
        let pivotNode = SCNNode()
        pivotNode.name = "pivot"
        scene.rootNode.addChildNode(pivotNode)
        
        // Geometry Construction: Cylinder + Torus = Lozenge (Rounded Edge Disc)
        
        let totalRadius: CGFloat = 1.6
        let totalHeight: CGFloat = 0.4
        let edgeRadius: CGFloat = totalHeight / 2 // 0.2
        let innerRadius: CGFloat = totalRadius - edgeRadius // 1.4
        
        // 1. Materials
        // Extract vibrant color from image for the edge, or fallback to silver
        let edgeColor = textureImage?.averageColor ?? UIColor(white: 0.8, alpha: 1.0)
        
        let edgeMaterial = SCNMaterial()
        edgeMaterial.diffuse.contents = edgeColor
        edgeMaterial.specular.contents = UIColor.white
        edgeMaterial.shininess = 1.0
        
        let faceMaterial = SCNMaterial()
        if let image = textureImage {
            faceMaterial.diffuse.contents = image
        } else {
            faceMaterial.diffuse.contents = UIColor.blue
        }
        
        // 2. Inner Cylinder (The Face)
        let cylinder = SCNCylinder(radius: innerRadius, height: totalHeight)
        cylinder.materials = [edgeMaterial, faceMaterial, faceMaterial] // Side, Top, Bottom
        let cylinderNode = SCNNode(geometry: cylinder)
        
        // 3. Edge Torus (The Rounded Rim)
        let torus = SCNTorus(ringRadius: innerRadius, pipeRadius: edgeRadius)
        torus.materials = [edgeMaterial]
        let torusNode = SCNNode(geometry: torus)
        
        // 4. Container for Composite Shape
        let shapeContainer = SCNNode()
        shapeContainer.addChildNode(cylinderNode)
        shapeContainer.addChildNode(torusNode)
        
        // Rotate Container 90 degrees on X to face camera (Both Cylinder and Torus align on Y axis)
        shapeContainer.eulerAngles.x = Float.pi / 2
        
        pivotNode.addChildNode(shapeContainer)
        
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        guard let pivotNode = scnView.scene?.rootNode.childNode(withName: "pivot", recursively: false) else { return }
        
        if isRotating {
            // Check if already rotating to avoid restarting or doubling speed
            if pivotNode.action(forKey: "spin") == nil {
                // Rotate 720 degrees (4 * pi) to simulate high-speed spin
                // Uses EaseInOut for smoothness
                let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 4, z: 0, duration: 0.8)
                rotateAction.timingMode = .easeInEaseOut
                pivotNode.runAction(rotateAction, forKey: "spin")
            }
        } else {
       
        }
    }
}
