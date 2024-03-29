import MetalKit

protocol MetalViewDelegate {
    func computeTexture(_ drawable:CAMetalDrawable)
}

var metalCoder:NSCoder! = nil

class MetalView: MTKView {
    var delegate2:MetalViewDelegate?
    var viewIsDirty:Bool = true

    required init(coder: NSCoder) {
        super.init(coder: coder)
        
        metalCoder = coder
        
        self.framebufferOnly = false
        self.device = MTLCreateSystemDefaultDevice()
    }
    
    override func draw() {
        super.draw()
        if viewIsDirty {
            if let drawable = currentDrawable {
                delegate2?.computeTexture(drawable)
                viewIsDirty = false
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { return true }
}
