import Cocoa

struct SLEntry {
    var kind = Int()
    var dateString = String()
    
    init(_ k:Int, _ str:String) { kind = k; dateString = str }
}

let populatedCellBackgroundColor = NSColor(red:0.1,  green:0.5,  blue:0.1, alpha: 1)
let noFileString = "** unused **"

protocol SLCellDelegate: class {
    func didTapButton(_ sender: NSButton)
}

class SaveLoadCell: NSTableCellView {
    weak var delegate: SLCellDelegate?
    @IBOutlet var legend: NSTextField!
    @IBOutlet var saveButton: NSButton!
    @IBAction func saveTapped(_ sender: NSButton) { delegate?.didTapButton(sender) }
    var isUnused = Bool()
    var kind = Int()
    
    override func draw(_ rect: CGRect) {
        let context = NSGraphicsContext.current?.cgContext
        
        if isUnused {
            context?.setFillColor(NSColor.darkGray.cgColor)
        }
        else {
            let cMap:[CGFloat] = [ 0.4, 0.5, 0.6, 1 ]
            var k = kind % 64
            let r = cMap[k % 4]; k /= 4
            let g = cMap[k % 4] + 0.1; k /= 4
            let b = cMap[k % 4]

            context?.setFillColor(NSColor(red:r, green:g, blue:b, alpha:1).cgColor)
        }
        
        context?.fill(rect)
        context?.setStrokeColor(NSColor.black.cgColor)
        context?.stroke(rect)
    }
}

//MARK:-

let versionNumber:Int32 = 0x55ac
var loadNextIndex:Int = -1   // first use will bump this to zero
var slEntry:[SLEntry] = []

class SaveLoadViewController: NSViewController,NSTableViewDataSource, NSTableViewDelegate,SLCellDelegate {
    @IBOutlet var legend: NSTextField!
    @IBOutlet var scrollView: NSScrollView!
    var tv:NSTableView! = nil
    var dateString:String = ""
    var fileURL:URL! = nil

    func numberOfSections(in tableView: NSTableView) -> Int { return 1 }
    func numberOfRows(in tableView: NSTableView) -> Int { return slEntry.count }
    
    func didTapButton(_ sender: NSButton) {
        let buttonPosition = sender.convert(CGPoint.zero, to:tv)
        saveAndDismissDialog(tv.row(at:buttonPosition))
    }
    
    func loadSLEntries() {
        slEntry.removeAll()
        
        var index = 0
        var cc = Control()
        var kind = Int()
        
        while(true) {
            let str = determineDateString(index)
            if str == noFileString { break }
            
            // ------------------------
            kind = 0
            determineURL(index)
            let data = NSData(contentsOf: fileURL)
            if data != nil {
                data?.getBytes(&cc, length:sz)
                kind = Int(cc.equation)
            }

            slEntry.append(SLEntry(kind,str))
            index += 1
        }
        
        slEntry.append(SLEntry(0,noFileString))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tv = scrollView.documentView as? NSTableView
        tv.dataSource = self
        tv.delegate = self
        
        loadSLEntries()
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell:SaveLoadCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SLCell"), owner: self) as! SaveLoadCell

        if slEntry[row].dateString == noFileString {
            cell.legend.stringValue = noFileString
            cell.isUnused = true
        }
        else {
            cell.legend.stringValue = String(format:"%2d %@  %@",row+1,  vc.titleString[slEntry[row].kind],  slEntry[row].dateString)
            cell.isUnused = false
        }
        
        cell.delegate = self
        cell.kind = slEntry[row].kind
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        loadAndDismissDialog(tv.selectedRow)
    }
    
    //MARK:-
    
    let sz = MemoryLayout<Control>.size
    
    func determineURL(_ index:Int) {
        let name = String(format:"Store%d.dat",index)
        fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(name)
    }
    
    func saveAndDismissDialog(_ index:Int) {
        func performSave() {
            do {
                self.determineURL(index)
                vc.control.version = versionNumber
                let data:NSData = NSData(bytes:&vc.control, length:self.sz)
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                print(error)
            }
        }
        
        func finishSession() {
            performSave()
            self.dismiss(self)
        }
        
        if slEntry[index].dateString == noFileString { // an 'add' session
            finishSession()
        }
        else {
            let alert = NSAlert()
            alert.messageText = "Save Settings"
            alert.informativeText = "Confirm overwrite of Settings storage"
            alert.addButton(withTitle: "NO")
            alert.addButton(withTitle: "YES")
            alert.beginSheetModal(for: self.view.window!) {( returnCode: NSApplication.ModalResponse) -> Void in
                finishSession()
            }
        }
    }
    
    //MARK:-
    
    func determineDateString(_ index:Int) -> String {
        var dStr = noFileString
        
        determineURL(index)
        
        do {
            let key:Set<URLResourceKey> = [.creationDateKey]
            let value = try fileURL.resourceValues(forKeys: key)
            if let date = value.creationDate { dStr = date.toString() }
        } catch {
            // print(error)
        }
        
        return dStr
    }
    
    //MARK:-
    
    var xs:Int32 = 0
    var ys:Int32 = 0
    
    func memorizeControlData() {
        xs = vc.control.xSize
        ys = vc.control.ySize
    }
    
    func updateControlData() {
        vc.control.xSize = xs
        vc.control.ySize = ys
        vc.control.isStereo = false
    }
    
    @discardableResult func loadData(_ index:Int) -> Bool {
        memorizeControlData()
        
        determineURL(index)
        
        let data = NSData(contentsOf: fileURL)
        if data == nil { return false } // clicked on empty entry
        
        data?.getBytes(&vc.control, length:sz)
        updateControlData()
        
        loadNextIndex = index // "load next" will continue after current selection
        return true
    }
    
    func loadAndDismissDialog(_ index:Int) {
        if loadData(index) {
            if vc.control.version != versionNumber { vc.reset() }
            self.dismiss(self)
            vc.controlJustLoaded()
        }
    }
    
    //MARK:-
    
    func loadNext() {
        var numTries:Int = 0
        
        while true {
            loadNextIndex += 1
            if loadNextIndex >= slEntry.count-1 { loadNextIndex = 0 } // skip past the last entry ("unused")
            
            print(loadNextIndex)
            
            determineURL(loadNextIndex)
            let data = NSData(contentsOf: fileURL)
            
            if data != nil {
                memorizeControlData()
                data?.getBytes(&vc.control, length:sz)
                updateControlData()
                return
            }
            
            numTries += 1       // nothing found?
            if numTries >= slEntry.count - 1 { return }
        }
    }
}

//MARK:-

extension Date {
    func toString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy hh:mm"
        return dateFormatter.string(from: self)
    }
    
    func toTimeStampedFilename(_ filename:String, _ extensionString:String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddhhmmss"
        let ds = dateFormatter.string(from: self)
        let str:String = String.init(format: "%@_%@.%@",filename,ds,extensionString)
        return str
    }
}

