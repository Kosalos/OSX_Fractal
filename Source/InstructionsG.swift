import Cocoa

private let X1:CGFloat = 1  // Auto box
private let X1S:CGFloat = 10
private let X2:CGFloat = X1 + X1S + 4 // value barchart
private let X2S:CGFloat = 40 - X2

class InstructionsG: NSView {
    var parent:Widget! = nil
    let YTOP = 5
    let YHOP = 17
    let YS = 10

    func initialize(_ parentPtr:Widget) {
        parent = parentPtr
        parent.instructionsG = self
    }
    
    override func draw(_ rect: NSRect) {
        if parent == nil { print("Need to initialze instructionsG");  exit(0) }
        let context = NSGraphicsContext.current?.cgContext
        context?.setFillColor(NSColor.clear.cgColor)
        context?.fill(rect)
        
        var y = YTOP

        for i in 0 ..< parent.data.count {
            if parent.data[i].kind == .float || parent.data[i].kind == .integer32 {
                
                // auto Change circle ---------------------------------------
                if parent.data[i].kind == .float {
                    let path = CGMutablePath()
                    path.addEllipse(in: NSMakeRect(X1,CGFloat(y),X1S,CGFloat(YS)))
                    context?.addPath(path)
                    
                    if parent.data[i].autoChange {
                        context?.setFillColor(NSColor.yellow.cgColor)
                        context?.drawPath(using:.fill)
                    }
                    
                    context?.setStrokeColor(i == parent.focus ? NSColor.red.cgColor : NSColor.white.cgColor)
                    context?.setLineWidth(1.0)
                    context?.drawPath(using:.stroke)
                }
                
                // value barchart -----------------------------------------
                var color = NSColor.white.cgColor
                if parent.data[i].isAtLimit() { color = NSColor.green.cgColor }
                else { if i == parent.focus { color = NSColor.red.cgColor }}
                context?.setStrokeColor(color)
                
                context?.setLineWidth(1.0)
                context?.stroke(NSMakeRect(X2,CGFloat(y),X2S,CGFloat(YS)))
                
                let xp = X2 + X2S * CGFloat(parent.data[i].valuePercent()) / 100
                context?.setLineWidth(2.0)
                context?.stroke(NSMakeRect(xp,CGFloat(y),2,CGFloat(YS)))
            }
            
            y += YHOP
        }
    }
    
    func refresh() {
        setNeedsDisplay(NSMakeRect(-30,0,140,frame.height))
    }

    override func mouseDown(with event: NSEvent) {
        var pt:NSPoint = event.locationInWindow
        pt.y = (parent.delegate as! NSViewController).view.frame.height - pt.y
        let index = Int(pt.y - 5)/17
        
        parent.focusDirect(index)
        
        if pt.x < X2  && parent.data[index].kind == .float {
            parent.data[index].autoChange = !parent.data[index].autoChange
            refresh()
        }
    }
    
    override var isFlipped: Bool { return true }
}
