import Cocoa

protocol NSTableViewClickableDelegate: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, didClickRow row: Int, didClickColumn: Int)
}

class EquationPickerViewController: NSViewController, NSTableViewDataSource, NSTableViewClickableDelegate {
    @IBOutlet var scrollView: NSScrollView!
    var tv:NSTableView! = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        tv = scrollView.documentView as? NSTableView
        tv.dataSource = self
        tv.delegate = self
        
        let iset:IndexSet = [ Int(vc.control.equation) ]
        tv.selectRowIndexes(iset, byExtendingSelection:false)
    }
    
    func numberOfSections(in tableView: NSTableView) -> Int { return 1 }
    func numberOfRows(in tableView: NSTableView) -> Int { return vc.titleString.count }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { return CGFloat(20) }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let str = Int(row + 1).description + ": " + vc.titleString[row]
        let view = NSTextField(string:str)
        view.isEditable = false
        view.isBordered = false
        view.backgroundColor = .clear
        return view
    }
    
    var selectedRow:Int = 0
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        selectedRow = row
        return true
    }
    
    func loadRow(_ row:Int) {
        vc.control.equation = Int32(row)
        vc.reset()
        vc.controlJustLoaded()
        self.dismiss(self)
    }
    
    func tableView(_ tableView: NSTableView, didClickRow row: Int, didClickColumn: Int) {
        loadRow(row)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {    // Return key
            loadRow(selectedRow)
        }
    }
}

// https://blog.kulman.sk/detecting-click-on-a-nstableviewcell/
extension NSTableView {
    open override func mouseDown(with event: NSEvent) {
        let localLocation = self.convert(event.locationInWindow, to: nil)
        let clickedRow = self.row(at: localLocation)
        let clickedColumn = self.column(at: localLocation)

        super.mouseDown(with: event)

        guard clickedRow >= 0, clickedColumn >= 0, let delegate = self.delegate as? NSTableViewClickableDelegate else {
            return
        }

        delegate.tableView(self, didClickRow: clickedRow, didClickColumn: clickedColumn)
    }
}
