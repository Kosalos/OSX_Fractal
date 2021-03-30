import Cocoa
import MetalKit

class WinLightViewController: NSViewController, NSWindowDelegate, WidgetDelegate {
    var widget:Widget! = nil
    var lightIndex:Int32 = 1
    
    @IBOutlet var instructions: NSTextField!
    @IBOutlet var instructionsG: InstructionsG!
    
    @IBAction func resetButtonPressed(_ sender: NSButton) {
        resetAllLights()
        vc.control.OrbitStrength = 0
        vc.control.Cycles = 0
        vc.control.orbitStyle = 0
        vc.control.fog = 0

        displayWidgets()
        vc.flagViewToRecalcFractal()
    }
    
    @IBAction func helpPressed(_ sender: NSButton) {
        if !isHelpVisible {
            helpIndex = 3
            presentPopover("HelpVC")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        widget = Widget(self)
        instructionsG.initialize(widget)
    }
    
    override func viewDidAppear() {
        view.window?.delegate = self
        
        updateLayoutOfChildViews()
        defineWidgets()
    }
    
    //MARK: -
    
    func updateLayoutOfChildViews() {
        let widgetPanelHeight:Int = 700
        instructionsG.frame = CGRect(x:5, y:5, width:75, height:widgetPanelHeight)
        instructionsG.bringToFront()
        instructionsG.refresh()
        
        instructions.frame = CGRect(x:50, y:5, width:500, height:widgetPanelHeight)
        instructions.textColor = .white
        instructions.backgroundColor = .black
        instructions.bringToFront()
    }
    
    //MARK: -
    
    func defineWidgets() {
        let i:Int32 = lightIndex - 1  // base 0
        
        widget.reset()
        widget.addInt32("Light#",&lightIndex,1,3,1,false,2)
        widget.addLegend(" ")
        widget.addFloat("Bright",lightBright(i),0,10,0.2)
        widget.addFloat("Spread",lightPower(i),0.001,100,0.1)
        widget.addLegend(" ")
        widget.addFloat("X Position",lightX(i),-20,20,0.2)
        widget.addFloat("Y",lightY(i),-20,20,0.2)
        widget.addFloat("Z",lightZ(i),-10,20,0.2)
        widget.addLegend(" ")
        widget.addFloat("R Color",lightR(i),0,1,0.1)
        widget.addFloat("G",lightG(i),0,1,0.1)
        widget.addFloat("B",lightB(i),0,1,0.1)
        
        // ----------------------------
        widget.addLegend("")
        widget.addFloat("Fog Amount",&vc.control.fog,0,12,0.1)
        widget.addFloat("R",&vc.control.fogR,0,1,0.1)
        widget.addFloat("G",&vc.control.fogG,0,1,0.1)
        widget.addFloat("B",&vc.control.fogB,0,1,0.1)
        
        // ----------------------------
        widget.addLegend("")
        widget.addLegend("Orbit Trap --")
        widget.addFloat("O Strength",&vc.control.OrbitStrength,0,1,0.1)
        widget.addFloat("Cycles",&vc.control.Cycles,0,100,0.5)
        widget.addFloat("X Weight",&vc.control.xWeight,-5,5,0.1)
        widget.addFloat("Y",&vc.control.yWeight,-5,5,0.1)
        widget.addFloat("Z",&vc.control.zWeight,-5,5,0.1)
        widget.addFloat("R",&vc.control.rWeight,-5,5,0.1)
        widget.addFloat("X Color",&vc.control.xIndex,0,255,10)
        widget.addFloat("Y",&vc.control.yIndex,0,255,10)
        widget.addFloat("Z",&vc.control.zIndex,0,255,10)
        widget.addFloat("R",&vc.control.rIndex,0,255,10)
        
        widget.addInt32("Fixed Trap",&vc.control.orbitStyle,0,2,1)
        widget.addFloat("X",&vc.control.otFixedX,-10,10,0.1)
        widget.addFloat("Y",&vc.control.otFixedY,-10,10,0.1)
        widget.addFloat("Z",&vc.control.otFixedZ,-10,10,0.1)
        
        displayWidgets()
    }
    
    func displayWidgets() {
        let str = NSMutableAttributedString()
        widget.addinstructionEntries(str)
        instructions.attributedStringValue = str
        instructionsG.refresh()
    }
    
    func widgetCallback(_ index:Int) {
        if index == 1 { vc.flagViewToRecalcFractal() } // floats
        if index == 2 { defineWidgets() } // light index
    }

    //MARK: -
    
    func presentPopover(_ name:String) {
        let mvc = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let vc = mvc.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(name)) as! NSViewController
        self.present(vc, asPopoverRelativeTo: view.bounds, of: view, preferredEdge: .minX, behavior: .transient)
    }
    
    override func keyDown(with event: NSEvent) {
        if widget.keyPress(event,true) {
            displayWidgets()
            instructionsG.refresh()
        }
        else {
            if !widget.lastKeypressWasArrowKey { vc.keyDown(with:event) }
        }
    }
    
    override func keyUp(with event: NSEvent) {
        vc.keyUp(with:event)
    }
}

class BaseNSView2: NSView {
    override var isFlipped: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
    
    override func draw(_ rect: NSRect) {
        let c = CGFloat(0.2)
        NSColor(red:c, green:c + 0.1, blue:c, alpha:1).set()
        NSBezierPath(rect:bounds).fill()
    }
}

class BaseNSView3: NSView {
    override var isFlipped: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
    
    override func draw(_ rect: NSRect) {
        let c = CGFloat(94.0 / 256.0)
        NSColor(red:c, green:c, blue:c, alpha:1).set()
        NSBezierPath(rect:bounds).fill()
    }
}

class BaseNSView4: NSView {
    override var isFlipped: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
    
    override func draw(_ rect: NSRect) {
        let c = CGFloat(0.2)
        NSColor(red:c, green:c, blue:c + 0.1, alpha:1).set()
        NSBezierPath(rect:bounds).fill()
    }
}

