import Cocoa

let PanelSize = 120
let NUMAXES = 2
let NUMPANELS = 4
var panelIndex = Int()
var selectIndex = Int()

var controlPickerSelection = Int()

var vcControl:ControlViewController! = nil
var panelList:[ControlPanelView]! = nil
var panelRect:[NSRect]! = nil

class ControlViewController: NSViewController {
    @IBOutlet var panel1: ControlPanelView!
    @IBOutlet var panel2: ControlPanelView!
    @IBOutlet var panel3: ControlPanelView!
    @IBOutlet var panel4: ControlPanelView!
    @IBAction func x1(_ sender: NSButton) { panelIndex = 0; selectIndex = 0;    presentPopover("ControlPickerVC") }
    @IBAction func y1(_ sender: NSButton) { panelIndex = 0; selectIndex = 1;    presentPopover("ControlPickerVC") }
    @IBAction func x2(_ sender: NSButton) { panelIndex = 1; selectIndex = 0;    presentPopover("ControlPickerVC") }
    @IBAction func y2(_ sender: NSButton) { panelIndex = 1; selectIndex = 1;    presentPopover("ControlPickerVC") }
    @IBAction func x3(_ sender: NSButton) { panelIndex = 2; selectIndex = 0;    presentPopover("ControlPickerVC") }
    @IBAction func y3(_ sender: NSButton) { panelIndex = 2; selectIndex = 1;    presentPopover("ControlPickerVC") }
    @IBAction func x4(_ sender: NSButton) { panelIndex = 3; selectIndex = 0;    presentPopover("ControlPickerVC") }
    @IBAction func y4(_ sender: NSButton) { panelIndex = 3; selectIndex = 1;    presentPopover("ControlPickerVC") }
    
    @IBAction func helpPressed(_ sender: NSButton) {
        if !isHelpVisible {
            helpIndex = 4
            presentPopover("HelpVC")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        vcControl = self
        panelList = [ panel1,panel2,panel3,panel4 ]
        
        panelRect = [  // UL corner, flipped Y
            NSRect(x:020, y:320, width:PanelSize, height:PanelSize),
            NSRect(x:150, y:320, width:PanelSize, height:PanelSize),
            NSRect(x:020, y:166, width:PanelSize, height:PanelSize),
            NSRect(x:150, y:166, width:PanelSize, height:PanelSize)]
        
        for i in 0 ..< 4 { panelList[i].panelID = i }
    }
    
    // so user can issue commands while viewing the help page
    override func keyDown(with event: NSEvent) {
        func alterValueViaArrowKeys(_ axis:Int, _ direction:Int) {
            decodeSelectionIndex(getPanelWidgetIndex(panelIndex,axis))
            if winHandler.widgetPointer(selectedWindow).data[selectedRow].alterValue(direction) {
                winHandler.refreshWidgetsAndImage()
                refreshControlPanels()
            }
        }
        
        vc.updateModifierKeyFlags(event)
        vc.widget.updateAlterationSpeed(event)
        
        switch Int32(event.keyCode) {
        case LEFT_ARROW :   alterValueViaArrowKeys(0,-1); return
        case RIGHT_ARROW :  alterValueViaArrowKeys(0,+1); return
        case UP_ARROW :     alterValueViaArrowKeys(1,-1); return
        case DOWN_ARROW :   alterValueViaArrowKeys(1,+1); return
        case 48 : panelIndex = (panelIndex + 1) % 4; refreshControlPanels() // Tab
        default : break
        }
        
        vc.keyDown(with: event)
    }
    
    override func keyUp(with event: NSEvent) { vc.keyUp(with: event) }
    
    //MARK: -
    
    func presentPopover(_ name:String) {
        let mvc = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let vc = mvc.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(name)) as! NSViewController
        self.present(vc, asPopoverRelativeTo: view.bounds, of: view, preferredEdge: .minX, behavior: .semitransient)
    }
    
    func widgetSelectionMade() {
        setPanelWidgetIndex(panelIndex,selectIndex,controlPickerSelection)
        panelList[panelIndex].refresh()
    }
    
    func refreshControlPanels() { for p in panelList { p.refresh() }}
    
    func checkAllWidgetIndices() {
        for i in 0 ..< NUMPANELS {
            for j in 0 ..< NUMAXES {
                if !vc.widget.isLegalControlPanelIndex(getPanelWidgetIndex(i,j)) { setPanelWidgetIndex(i,j,0) }
            }
        }
    }
}

//MARK: -
// save encoded picker selection for X or Y axis of specified panel
func setPanelWidgetIndex(_ panelIndex:Int, _ axisIndex:Int, _ value:Int) {
    switch panelIndex * 2 + axisIndex {
    case 0 : vc.control.panel00 = Int32(value)
    case 1 : vc.control.panel01 = Int32(value)
    case 2 : vc.control.panel10 = Int32(value)
    case 3 : vc.control.panel11 = Int32(value)
    case 4 : vc.control.panel20 = Int32(value)
    case 5 : vc.control.panel21 = Int32(value)
    case 6 : vc.control.panel30 = Int32(value)
    case 7 : vc.control.panel31 = Int32(value)
    default : break
    }
}

// retrieve encoded picker selection from X or Y axis of specified panel
func getPanelWidgetIndex(_ panelIndex:Int, _ axisIndex:Int) -> Int {
    var index = Int()
    
    switch panelIndex * 2 + axisIndex {
    case 0 : index = Int(vc.control.panel00)
    case 1 : index = Int(vc.control.panel01)
    case 2 : index = Int(vc.control.panel10)
    case 3 : index = Int(vc.control.panel11)
    case 4 : index = Int(vc.control.panel20)
    case 5 : index = Int(vc.control.panel21)
    case 6 : index = Int(vc.control.panel30)
    case 7 : index = Int(vc.control.panel31)
    default : index = 0
    }

    return index
}

//MARK: -

var selectedRow = Int()
var selectedWindow = Int()

func decodeSelectionIndex(_ selection:Int) {
    selectedRow = decodePickerSelection(selection).0
    selectedWindow = decodePickerSelection(selection).1
    
    if (selectedWindow == 0) && vc.control.isStereo { selectedRow += 1 } // 'Parallax' widget offset
}

//MARK: -
//MARK: -

class ControlPanelView: NSView {
    var panelID = Int()
    var ratio:[Float] = [ 0,0 ]
    
    func refresh() {
        for i in 0 ..< NUMAXES {
            decodeSelectionIndex(getPanelWidgetIndex(panelID,i))
            ratio[i] = winHandler.widgetPointer(selectedWindow).data[selectedRow].getRatio()
        }
        
        setNeedsDisplay(self.bounds)
    }
    
    override func mouseDown(with event: NSEvent) {
        let pt:NSPoint = event.locationInWindow
        
        for i in 0 ..< NUMPANELS {
            let p = panelRect[i]
            if  pt.x >= p.minX && pt.x < p.minX + CGFloat(PanelSize) &&
                pt.y <= p.minY && pt.y > p.minY - CGFloat(PanelSize) {
                panelIndex = i
                
                decodeSelectionIndex(getPanelWidgetIndex(panelIndex,0))
                winHandler.widgetPointer(selectedWindow).data[selectedRow].setRatio(Float((pt.x - p.minX) / CGFloat(PanelSize)))
                
                decodeSelectionIndex(getPanelWidgetIndex(panelIndex,1))
                winHandler.widgetPointer(selectedWindow).data[selectedRow].setRatio(Float((p.minY - pt.y) / CGFloat(PanelSize)))
                
                winHandler.refreshWidgetsAndImage()
                refresh()
                return
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) { mouseDown(with:event) }
    
    override func draw(_ rect: NSRect) {
        let cr = (panelID == panelIndex) ? CGFloat(0.3) : CGFloat(0.1)
        let c = CGFloat(0.1)
        NSColor(red:cr, green:c, blue:c, alpha:1).set()
        NSBezierPath(rect:bounds).fill()
        
        func legend(_ index:Int) {
            let axisString:[String] = [ "X","Y" ]
            let tableString:[String] = [ "Main","Light","Color" ]
            var str = String()
            let encodedSelection = getPanelWidgetIndex(panelID,index)
            
            var r = decodePickerSelection(encodedSelection).0
            let w = decodePickerSelection(encodedSelection).1
            
            if w == 0 && vc.control.isStereo { r += 1 } // 'parallax' widget offset
            
            str = String(format:"%@: %@ %@",axisString[index],tableString[w],winHandler.stringForRow(w,r))
            drawText(5,5 + CGFloat(index) * 16,str,12,.white,0)
        }
        
        for i in 0 ..< NUMAXES { legend(i) }
        
        let r = NSRect(x:CGFloat(ratio[0] * Float(PanelSize) - 5), y:CGFloat(ratio[1] * Float(PanelSize) - 5), width:CGFloat(10), height:CGFloat(10))
        drawFilledCircle(r,.red)
    }
    
    func drawText(_ x:CGFloat, _ y:CGFloat, _ txt:String, _ fontSize:Int, _ color:NSColor, _ justifyCode:Int) {  // 0,1,2 = left,center,right
        let a1 = NSMutableAttributedString(
            string: txt,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key:NSFont(name: "Helvetica", size: CGFloat(fontSize))!,
                NSAttributedString.Key.foregroundColor : color
        ])
        
        var cx = CGFloat(x)
        let size = a1.size()
        
        switch justifyCode {
        case 1 : cx -= size.width/2
        case 2 : cx -= size.width
        default : break
        }
        
        a1.draw(at: CGPoint(x:cx, y:CGFloat(y)))
    }
    
    func drawFilledCircle(_ rect:NSRect, _ color:NSColor) {
        let context = NSGraphicsContext.current?.cgContext
        
        let path = CGMutablePath()
        path.addEllipse(in: rect)
        context?.setFillColor(color.cgColor)
        context?.addPath(path)
        context?.drawPath(using:.fill)
    }
    
    override var isFlipped: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
}