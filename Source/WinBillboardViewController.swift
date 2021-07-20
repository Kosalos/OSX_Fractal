import Cocoa
import MetalKit

class WinBillboardViewController: NSViewController, NSWindowDelegate, WidgetDelegate {
    var widget:Widget! = nil
    var bIndex:Int32 = 1
    
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
    
    @IBAction func helpPressed(_ sender: NSButton) { showHelpPage(view,.Billboard) }
    
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
        let widgetPanelHeight:Int = 230
        instructionsG.frame = CGRect(x:5, y:5, width:44, height:widgetPanelHeight)
        instructionsG.bringToFront()
        instructionsG.refresh()
        
        instructions.frame = CGRect(x:50, y:5, width:500, height:widgetPanelHeight)
        instructions.textColor = .white
        instructions.backgroundColor = .black
        instructions.bringToFront()
    }
    
    //MARK: -
    
    func defineWidgets() {
        let i:Int32 = bIndex - 1  // base 0
        
        widget.reset()
        widget.addInt32("Billboard#",&bIndex,1,Int(NUM_BILLBOARD),1,false,2)
        widget.addLegend(" ")
        widget.addBoolean("Active",billboardActive(i))
        widget.addFloat("X",billboardX(i), 0,1,0.01)
        widget.addFloat("Y",billboardY(i), 0,1,0.01)
        widget.addFloat("Z",billboardZ(i), 0,15,0.01)
        widget.addFloat("XS",billboardXS(i), 0,1,0.01)
        widget.addFloat("YS",billboardYS(i), 0,1,0.01)
        widget.addFloat("U1",billboardU1(i), 0,1,0.01)
        widget.addFloat("U2",billboardU2(i), 0,1,0.01)
        widget.addFloat("V1",billboardV1(i), 0,1,0.01)
        widget.addFloat("V2",billboardV2(i), 0,1,0.01)
        widget.addFloat("Fud",billboardFudge(i),-2,12,0.01)

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
