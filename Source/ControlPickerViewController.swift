import Cocoa

class ControlPickerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet var scrollView1: NSScrollView!    // main
    @IBOutlet var scrollView2: NSScrollView!    // lights
    @IBOutlet var scrollView3: NSScrollView!    // color
    var tv1:NSTableView! = nil
    var tv2:NSTableView! = nil
    var tv3:NSTableView! = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        tv1 = scrollView1.documentView as? NSTableView
        tv1.dataSource = self
        tv1.delegate = self

        tv2 = scrollView2.documentView as? NSTableView
        tv2.dataSource = self
        tv2.delegate = self
        
        tv3 = scrollView3.documentView as? NSTableView
        tv3.dataSource = self
        tv3.delegate = self
    }

    override func viewDidAppear() {
        super.viewWillAppear()
    }
    
    func numberOfSections(in tableView: NSTableView) -> Int { return 1 }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { return CGFloat(20) }

    func tableIndex(_ tableView: NSTableView) -> Int {
        switch tableView {
        case tv1 : return 0
        case tv2 : return 1
        case tv3 : return 2
        default : print("picker error"); exit(-1)
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int { return winHandler.widgetCountInWindow(tableIndex(tableView)) }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        //print("T",tableIndex(tableView), "  R",row)
        
        let view = NSTextField(string:"")
        view.isEditable = false
        view.isBordered = false
        view.backgroundColor = .clear
        view.stringValue = Int(row + 1).description + ": "
        view.stringValue += winHandler.stringForRow(tableIndex(tableView),row)
        return view
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let tIndex = tableIndex(tableView)
        let widget = winHandler.widgetPointer(tIndex)

        if !widget.isLegalControlPanelIndex(row) { return false } // can only select float or integer

        // Parallax widget offset so widget selection isn't altered when toggling stereo
        var row = row
        if (tIndex == 0) && vc.control.isStereo { row -= 1 }

        encodePickerSelection(row,tIndex)        
        vcControl.widgetSelectionMade()
        
        dismiss(self)
        return true
    }
}

func encodePickerSelection(_ row:Int, _ tableIndex:Int) { controlPickerSelection = row + tableIndex * 100 }
func decodePickerSelection(_ value:Int) -> (Int,Int) { return (value % 100, value / 100) }

