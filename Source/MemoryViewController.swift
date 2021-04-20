import Cocoa
import MetalKit

let MSZ = CGFloat(50)
let MMARGIN = CGFloat(4)
let MXB = CGFloat(10)
let MYB = CGFloat(10)
let MXS = Int(10)
let MYS = Int(10)
let MTOTAL = MXS * MYS

//class MemoryView : NSImageView {
//    init() {
//        super.init(frame: frame:CGRect(x:xp, y:yp, width:MSZ, height:MSZ)))
//    }
//
//    required init(coder: NSCoder) {
//        super.init(coder: coder)!
//    }
//
//    override func keyDown(with event: NSEvent) {
//        print(self.frame.debugDescription)
//    }
//}

struct MemoryData {
    var image = NSImageView()
    var control = Control()
}

var vcMemory:MemoryViewController! = nil

class MemoryViewController: NSViewController, NSWindowDelegate {
    var index = Int()
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
                d.image = NSImageView.init(frame:CGRect(x:xp, y:yp, width:MSZ, height:MSZ)) // as! MemoryView
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
        let index = x + y * MXS
        //print(x," ",y,"  ",index)
        
        if(index >= 0 && index < MTOTAL) {
            vc.control = data[index].control
            vc.control.skip = 1
            vc.controlJustLoaded()
        }
    }
    
    override func keyDown(with event: NSEvent) { vc.keyDown(with:event) }
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
        let r = vcMemory.data[index].image.frame.insetBy(dx: -2, dy: -2)
        let context = NSGraphicsContext.current?.cgContext
        context?.setLineWidth(2.0)
        NSColor.red.set()
        NSBezierPath(rect:r).stroke()
    }
}
