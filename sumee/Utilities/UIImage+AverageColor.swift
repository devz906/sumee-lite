import UIKit

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        
        // Create an extent vector (the area of the image to average)
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                    y: inputImage.extent.origin.y,
                                    z: inputImage.extent.size.width,
                                    w: inputImage.extent.size.height)
        
        // Create the filter
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        
        // Get the output image
        guard let outputImage = filter.outputImage else { return nil }
        
        // Render the output image to a 1x1 bitmap
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                       green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255,
                       alpha: CGFloat(bitmap[3]) / 255)
    }
    
    var vibrantAverageColor: UIColor? {
        guard let color = self.averageColor else { return nil }
        
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        if color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            // Boost saturation significantly to avoid grey/muddy colors
       
            let newS = s < 0.1 ? s : max(s * 1.5, 0.6) // Boost saturation, min 0.6 if it has color
            
            // Normalize brightness to be pleasant (not too dark, not too bright)
   
            let newB = max(b, 0.5) // Ensure not black
             
            return UIColor(hue: h, saturation: min(newS, 1.0), brightness: min(newB, 1.0), alpha: 1.0)
        }
        return color
    }
}
