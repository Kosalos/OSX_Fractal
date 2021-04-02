import Cocoa
import MetalKit

var vcColor:WinColorViewController! = nil

class WinColorViewController: NSViewController, NSWindowDelegate, WidgetDelegate {
    var widget:Widget! = nil
    var colorIndex:Int32 = 1
    
    @IBOutlet var instructions: NSTextField!
    @IBOutlet var instructionsG: InstructionsG!
    
    @IBAction func resetButtonPressed(_ sender: NSButton) {
        vc.control.coloring1 = Float.random(in: 0 ... 1)
        vc.control.coloring2 = Float.random(in: 0 ... 1)
        vc.control.coloring3 = Float.random(in: 0 ... 1)
        vc.control.coloring4 = Float.random(in: 0 ... 1)
        vc.control.coloring5 = Float.random(in: 0 ... 1)
        vc.control.coloring6 = Float.random(in: 0 ... 1)
        vc.control.coloring7 = Float.random(in: 0 ... 1)
        vc.control.coloring8 = Float.random(in: 0 ... 1)
        vc.control.coloring9 = Float.random(in: 0 ... 1)
        vc.control.coloringa = Float.random(in: 0 ... 1)
        vc.control.secondSurface = Float.random(in: 0 ... 12)
        vc.control.refractAmount = Float.random(in: 0 ... 0.25)
        vc.control.transparentAmount = Float.random(in: 0 ... 3)
        
        defineWidgets()
        vc.flagViewToRecalcFractal()
    }
    
    @IBAction func helpPressed(_ sender: NSButton) {
        if !isHelpVisible {
            helpIndex = 5
            presentPopover("HelpVC")
        }
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        vcColor = self
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
        
        instructions.frame = CGRect(x:50, y:5, width:120, height:widgetPanelHeight)
        instructions.textColor = .white
        instructions.backgroundColor = .red
        instructions.bringToFront()
    }
    
    //MARK: -
    
    func defineWidgets() {
        widget.reset(true)
        widget.addFloat("Bright",&vc.control.bright,0.01,10,0.02)
        widget.addFloat("Enhance",&vc.control.enhance,0,30,0.03)
        widget.addFloat("Contrast",&vc.control.contrast,0.1,0.7,0.02)
        widget.addFloat("Specular",&vc.control.specular,0,2,0.1)
        widget.addFloat("Light Position",&vc.lightAngle,-3,3,0.3)
        
        widget.addLegend(" ")
        widget.addInt32("Style#",&vc.control.colorScheme,0,7,1,true,98)
        widget.addLegend(" ")
        
        switch vc.control.colorScheme {
        case 0 :
            widget.addFloat("Color 1",&vc.control.coloring1,0.0001,1,0.01)
            widget.addFloat("Color 2",&vc.control.coloring2,-1,1,0.01)
        case 1 :
            widget.addFloat("Color 1",&vc.control.coloring1,0,1,0.01)
            widget.addFloat("Color 2",&vc.control.coloring2,0,1,0.01)
            widget.addFloat("Color 3",&vc.control.coloring3,0,1,0.01)
        case 2 :
            widget.addFloat("Color 1",&vc.control.coloring1,0,1,0.01)
            widget.addFloat("Color 2",&vc.control.coloring2,0,1,0.01)
            widget.addFloat("Color 3",&vc.control.coloring3,0,1,0.01)
            widget.addFloat("Color 4",&vc.control.coloring4,0,1,0.01)
            widget.addFloat("Color 5",&vc.control.coloring5,0,1,0.01)
        case 3 :
            widget.addFloat("Color 1",&vc.control.coloring1,0,1,0.01)
            widget.addFloat("Color 2",&vc.control.coloring2,0,1,0.01)
        case 6 :
            widget.addFloat("Color 1",&vc.control.coloring1,0.0001,1,0.01)
            widget.addFloat("Color 2",&vc.control.coloring2,-1,1,0.01)
            widget.addFloat("Color 3",&vc.control.coloring3,-1,1,0.01)
            widget.addFloat("Color 4",&vc.control.coloring4,-1,1,0.01)
            widget.addFloat("Color 5",&vc.control.coloring5,-1,1,0.01)
            widget.addFloat("Color 6",&vc.control.coloring6,-1,1,0.01)
            widget.addFloat("Color 7",&vc.control.coloring7,-1,1,0.01)
            widget.addFloat("Color 8",&vc.control.coloring8,-1,1,0.01)
            widget.addFloat("Color 9",&vc.control.coloring9,-1,1,0.01)
           // widget.addFloat("Color a",&vc.control.coloringa,-1,1,0.01)
        case 7 :
            widget.addFloat("Color 1",&vc.control.coloring1,0,1,0.01)
            widget.addFloat("Color 2",&vc.control.coloring2,0,1,0.01)
            widget.addFloat("Color 3",&vc.control.coloring3,0,1,0.01)
            widget.addFloat("Color 4",&vc.control.coloring4,0,1,0.01)
        default : break
        }

        widget.addFloat("Glass",&vc.control.coloringa,0,1,0.01)

        widget.addLegend(" ")
        widget.addFloat("Second Surface",&vc.control.secondSurface,0,12,0.02)
        widget.addFloat("Reflect 1",&vc.control.refractAmount, 0,0.25,0.01)
        widget.addFloat("Reflect 2",&vc.control.transparentAmount, 0,3,0.01)
        
        widget.addLegend(" ")
        widget.addFloat("C Normal",&vc.control.normalOffset, 0.00001,1,0.01)
        
        widget.addLegend(" ")
        widget.addLegend("Blur")
        widget.addFloat("Strength (0 = Off)", &vc.control.blurStrength, 0,500,5)
        widget.addFloat("Distance", &vc.control.blurFocalDistance, 0.001,4,0.01)
        
        widget.addLegend(" ")
        widget.addFloat("Radial Symmetry",&vc.control.radialAngle,0,Float.pi,0.03)
        
        displayWidgets()
    }
    
    func displayWidgets() {
        let str = NSMutableAttributedString()
        widget.addinstructionEntries(str)
        instructions.attributedStringValue = str
        instructionsG.refresh()
    }
    
    func widgetCallback(_ index:Int) {
        switch(index) {
        case 1 :
            defineWidgets()
            vc.flagViewToRecalcFractal()
        case 98 :  // change color scheme
            vc.changeColorScheme()
            defineWidgets()
            vc.flagViewToRecalcFractal()
        default : break
        }
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
        else { // pass to main window?
            if !widget.lastKeypressWasArrowKey { vc.keyDown(with:event) }
        }
    }
    
    override func keyUp(with event: NSEvent) { vc.keyUp(with:event) }
}
