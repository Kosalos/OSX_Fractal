import Cocoa
import MetalKit

class WinColorViewController: NSViewController, NSWindowDelegate, WidgetDelegate {
    var widget:Widget! = nil
    var colorIndex:Int32 = 1
    
    @IBOutlet var instructions: NSTextField!
    @IBOutlet var instructionsG: InstructionsG!
    
    @IBAction func resetButtonPressed(_ sender: NSButton) {
    }
    
    @IBAction func helpPressed(_ sender: NSButton) {
        if !isHelpVisible {
            helpIndex = 5
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
        let widgetPanelHeight:Int = 400
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
        widget.reset()
        widget.addInt32("Style#",&colorIndex,1,8,1)
        widget.addLegend(" ")
        widget.addFloat("Color 1",&vc.control.coloring1,0.0001,1,0.01)
        widget.addFloat("Color 2",&vc.control.coloring2,-1,1,0.01)
        widget.addFloat("Color 3",&vc.control.coloring3,-1,1,0.01)
        widget.addFloat("Color 4",&vc.control.coloring4,-1,1,0.01)
        widget.addFloat("Color 5",&vc.control.coloring5,-1,1,0.01)
        widget.addFloat("Color 6",&vc.control.coloring6,-1,1,0.01)
        widget.addFloat("Color 7",&vc.control.coloring7,-1,1,0.01)
        widget.addFloat("Color 8",&vc.control.coloring8,-1,1,0.01)
        widget.addFloat("Color 9",&vc.control.coloring9,-1,1,0.01)
        widget.addFloat("Color a",&vc.control.coloringa,-1,1,0.01)
        widget.addFloat("Color b",&vc.control.coloringb,-1,1,0.01)
        widget.addFloat("Color c",&vc.control.coloringc,-1,1,0.01)
        widget.addFloat("Color d",&vc.control.coloringd,-1,1,0.01)
        widget.addFloat("Color e",&vc.control.coloringe,-1,1,0.01)
        widget.addFloat("Color f",&vc.control.coloringf,-1,1,0.01)
        widget.addFloat("Color g",&vc.control.coloringg,-1,1,0.01)
        widget.addFloat("Reflect 1",&vc.control.reflect1, 0,0.25,0.01)
        widget.addFloat("Reflect 2",&vc.control.reflect2, 0,3,0.01)
        widget.addFloat("C Normal",&vc.control.reflect3, 0.0001,1,0.001)

        displayWidgets()
    }
    
    func displayWidgets() {
        let str = NSMutableAttributedString()
        widget.addinstructionEntries(str)
        instructions.attributedStringValue = str
        instructionsG.refresh()
    }
    
    func widgetCallback(_ index:Int) { }
    
    //MARK: -
    
    func presentPopover(_ name:String) {
        let mvc = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let vc = mvc.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(name)) as! NSViewController
        self.present(vc, asPopoverRelativeTo: view.bounds, of: view, preferredEdge: .minX, behavior: .transient)
    }
    
    override func keyDown(with event: NSEvent) {
        if widget.keyPress(event) {
            displayWidgets()
            instructionsG.refresh()
            
            if widget.focus != 0 && event.keyCode != UP_ARROW && event.keyCode != DOWN_ARROW {
                vc.setShaderToFastRender()
                vc.flagViewToRecalcFractal()
            }
        }
        else { // pass to main window?
            if !widget.lastKeypressWasArrowKey { vc.keyDown(with:event) }
        }
    }
    
    override func keyUp(with event: NSEvent) { vc.keyUp(with:event) }
}
