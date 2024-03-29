import Cocoa
import MetalKit

var vcColor:WinColorViewController! = nil

class WinColorViewController: NSViewController, NSWindowDelegate, WidgetDelegate {
    var widget:Widget! = nil
    var colorIndex:Int32 = 1
    
    @IBOutlet var instructions: NSTextField!
    @IBOutlet var instructionsG: InstructionsG!
    
    @IBAction func resetButtonPressed(_ sender: NSButton) {
        randomizeColorSettings()
        vc.initRepeatation(.color)
    }

    func randomizeColorSettings() {
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
        defineWidgets()
    }
    
    @IBAction func helpPressed(_ sender: NSButton) { showHelpPage(view,.Color) }
 
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
        let widgetPanelHeight:Int = 720
        instructionsG.frame = CGRect(x:5, y:5, width:44, height:widgetPanelHeight)
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
        widget.addFloat("Enhance",&vc.control.enhance,0,10,0.03)
        widget.addFloat("Contrast",&vc.control.contrast,0.1,0.7,0.02)
        widget.addFloat("Specular",&vc.control.specular,0,2,0.1)
        widget.addFloat("Light Position",&vc.lightAngle,-4,4,0.3)
        widget.addFloat("SPower",&vc.control.fz, 0.001,15,0.01)
        widget.addFloat("SMix",&vc.control.fy, 0.0,1,0.01)

        
        widget.addLegend(" ")
        widget.addInt32("Style#",&vc.control.colorScheme,0,7,1,true,98)
        widget.addLegend(" ")
        
        switch vc.control.colorScheme {
        case 0 :
            widget.addFloat("Color 1",&vc.control.coloring1,0.0001,1,0.01)
            widget.addFloat("Color 2",&vc.control.coloring2,-1,1,0.01)
        case 1 :
//            widget.addFloat("Color 1",&vc.control.coloring1,0,1,0.01)
//            widget.addFloat("Color 2",&vc.control.coloring2,0,1,0.01)
//            widget.addFloat("Color 3",&vc.control.coloring3,0,1,0.01)
            widget.addFloat("Color 1",&vc.control.coloring1,-5,5,0.01)
            widget.addFloat("Color 2",&vc.control.coloring2,-5,5,0.01)
            widget.addFloat("Color 3",&vc.control.coloring3,-5,5,0.01)
            widget.addFloat("Color 4",&vc.control.coloring4,-5,5,0.01)
            widget.addFloat("Color 5",&vc.control.coloring5,-5,5,0.01)
            widget.addFloat("Color 6",&vc.control.coloring6,-5,5,0.01)
            widget.addFloat("Color 7",&vc.control.coloring7,-5,5,0.01)
            widget.addFloat("Color 8",&vc.control.coloring8,-5,5,0.01)
            widget.addFloat("Color 9",&vc.control.coloring9,-5,5,0.01)
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
        case 7 :
            widget.addFloat("Color 1",&vc.control.coloring1,0,1,0.01)
            widget.addFloat("Color 2",&vc.control.coloring2,0,1,0.01)
            widget.addFloat("Color 3",&vc.control.coloring3,0,1,0.01)
            widget.addFloat("Color 4",&vc.control.coloring4,0,1,0.01)
            widget.addFloat("Color 5",&vc.control.coloring5,-1,1,0.01)
            widget.addFloat("Color 6",&vc.control.coloring6,-1,1,0.01)
            widget.addFloat("Color 7",&vc.control.coloring7,-1,1,0.01)
            widget.addInt32("Iterations",&vc.control.icz,1,40,1)
        default : break
        }

        widget.addFloat("Mix X",&vc.control.coloringM1,0,1,0.1)
        widget.addFloat("Mix Y",&vc.control.coloringM2,0,1,0.1)
        widget.addFloat("Mix Z",&vc.control.coloringM3,0,1,0.1)

        widget.addFloat("Glass",&vc.control.coloringa,0,1,0.01)

        widget.addLegend(" ")
        widget.addFloat("Second Surface",&vc.control.secondSurface,0,12,0.1)
        widget.addFloat("Reflect 1",&vc.control.refractAmount, 0,0.25,0.02)
        widget.addFloat("Reflect 2",&vc.control.transparentAmount, 0,3,0.03)
        
        widget.addLegend(" ")
        widget.addFloat("C Normal",&vc.control.normalOffset, 0.00001,1,0.01)
        
        widget.addLegend(" ")
        widget.addLegend("Blur")
        widget.addFloat("Strength (0 = Off)", &vc.control.blurStrength, 0,500,15)
        widget.addFloat("Distance", &vc.control.blurFocalDistance, 0.001,4,0.02)
        widget.addFloat("Dimming", &vc.control.blurDim, 0,10,0.1)

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
            displayWidgets()
            vc.flagViewToRecalcFractal()
        case 98 :  // change color scheme
            vc.changeColorScheme()
            defineWidgets()
            vc.flagViewToRecalcFractal()
        default : break
        }
    }
        
    //MARK: -
    
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
