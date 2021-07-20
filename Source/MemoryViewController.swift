import Cocoa
import MetalKit

let MSZ = CGFloat(50)
let MMARGIN = CGFloat(4)
let MXB = CGFloat(10)
let MYB = CGFloat(10)
let MXS = Int(10)
let MYS = Int(10)
let MTOTAL = MXS * MYS

struct MemoryData {
    var image = NSImageView()
    var control = Control()
}

var vcMemory:MemoryViewController! = nil

class MemoryViewController: NSViewController, NSWindowDelegate {
    var index = Int()
    var focusIndex = Int()
    var data:[MemoryData] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        vcMemory = self
        
        var i = Int(0)
        for y in 0 ..< MYS {
            let yp = MYB + CGFloat(y) * (MMARGIN + MSZ)
            
            for x in 0 ..< MXS {
                let xp = MXB + CGFloat(x) * (MMARGIN + MSZ)
                
                var d = MemoryData()
                d.image = NSImageView.init(frame:CGRect(x:xp, y:yp, width:MSZ, height:MSZ))
                d.control = vc.control
                
                data.append(d)
                self.view.addSubview(data[i].image)
                
                i += 1
            }
        }
    }
    
    override func viewDidAppear() {
        view.window?.delegate = self
    }    
    
    @IBAction func helpPressed(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Select Image to Return To"
        alert.informativeText = "Mouse click/drag to select which settings to retrieve."
        alert.beginSheetModal(for: view.window!) { ( returnCode: NSApplication.ModalResponse) -> Void in () }
    }
    
    func addImage(_ t:MTLTexture) {
        data[index].control = vc.control
        data[index].image.imageFromTexture(t)
        index += 1
        if index >= MTOTAL { index = 0 }
        view.setNeedsDisplay(view.bounds)
    }
    
    override func mouseDown(with event: NSEvent) {
        let pt = event.locationInWindow
        let x = Int((pt.x - MXB) / (MMARGIN + MSZ))
        let y = MYS - 1 - Int((pt.y - MYB) / (MMARGIN + MSZ))
        let temp = x + y * MXS
        
        if temp >= 0 && temp < MTOTAL {
            focusIndex = temp
            view.setNeedsDisplay(view.bounds)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        mouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        if data[focusIndex].control.cx != 0 {
            vc.control = data[focusIndex].control
            vc.control.skip = 1
            vc.controlJustLoaded()
        }
        
        focusIndex = -1
        view.setNeedsDisplay(view.bounds)
    }
    
    override func keyDown(with event: NSEvent) {
        switch Int32(event.keyCode) {
        case ESC_KEY :
            vc.repeatCount = 0
        default : break
        }
        
        vc.keyDown(with:event)
    }
    
    override func keyUp(with event: NSEvent) { vc.keyUp(with:event) }
}

class BaseNSViewMemory: NSView {
    override var isFlipped: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
    
    override func draw(_ rect: NSRect) {
        let c = CGFloat(0.3)
        NSColor(red:c, green:c, blue:c + 0.1, alpha:1).set()
        NSBezierPath(rect:bounds).fill()
        
        var index = vcMemory.index-1; if index < 0 { index = MTOTAL-1 }
        var r = vcMemory.data[index].image.frame.insetBy(dx: -2, dy: -2)
        let context = NSGraphicsContext.current?.cgContext
        context?.setLineWidth(4.0)
        NSColor.red.set()
        NSBezierPath(rect:r).stroke()
        
        if vcMemory.focusIndex >= 0 {
            index = vcMemory.focusIndex
            r = vcMemory.data[index].image.frame.insetBy(dx: -2, dy: -2)
            NSColor.yellow.set()
            NSBezierPath(rect:r).stroke()
        }
    }
}
