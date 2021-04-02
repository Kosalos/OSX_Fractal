import Cocoa

struct SLEntry {
    var kind = Int()
    var dateValue = TimeInterval()
    var dateString = String()
    var filenameNumber = Int()
    
    init(_ k:Int, _ str:String, _ value:TimeInterval, _ number:Int) { kind = k; dateString = str; dateValue = value; filenameNumber = number }
    
    mutating func copy(_ other:SLEntry) {
        kind = other.kind
        dateValue = other.dateValue
        dateString = other.dateString
        filenameNumber = other.filenameNumber
    }
}

let populatedCellBackgroundColor = NSColor(red:0.1,  green:0.5,  blue:0.1, alpha: 1)
let noFileString = "** unused **"

protocol SLCellDelegate: class {
    func didTapOverwriteButton(_ sender: NSButton)
    func didTapDeleteButton(_ sender: NSButton)
}

class SaveLoadCell: NSTableCellView {
    weak var delegate: SLCellDelegate?
    @IBOutlet var legend: NSTextField!
    @IBAction func overwriteTapped(_ sender: NSButton) { delegate?.didTapOverwriteButton(sender) }
    @IBAction func deleteTapped(_ sender: NSButton) { delegate?.didTapDeleteButton(sender) }
    var isUnused = Bool()
    var kind = Int()
    @IBOutlet var overwriteButton: NSButton!
    @IBOutlet var deleteButton: NSButton!
    
    override func draw(_ rect: CGRect) {
        let context = NSGraphicsContext.current?.cgContext
        
        if isUnused {
            context?.setFillColor(NSColor.darkGray.cgColor)
        }
        else {
            let cMap:[CGFloat] = [ 0.2, 0.5, 0.8 ]
            var k = kind % 27
            let r = cMap[k % 3]; k /= 3
            let g = cMap[k % 3] + 0.1; k /= 3
            let b = cMap[k % 3]
            context?.setFillColor(NSColor(red:r, green:g, blue:b, alpha:1).cgColor)
        }
        
        context?.fill(rect)
        context?.setStrokeColor(NSColor.black.cgColor)
        context?.stroke(rect)
        
        let s = NSShadow()
        s.shadowOffset = NSSize(width:1,height:1)
        s.shadowBlurRadius = 1
        s.shadowColor = .black
        
        legend.textColor = .white
        legend.shadow = s
        overwriteButton.set(textColor: .white)
        deleteButton.set(textColor: .yellow)
    }
}

//MARK:-

let versionNumber:Int32 = 0x55ac
var loadNextIndex:Int = -1   // first use will bump this to zero
var slEntry:[SLEntry] = []
var dateSort:Bool = true
var dateAscending:Bool = false

class SaveLoadViewController: NSViewController,NSTableViewDataSource, NSTableViewDelegate,SLCellDelegate {
    @IBOutlet var legend: NSTextField!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var DateRadio: NSButton!
    @IBOutlet var KindRadio: NSButton!
    @IBOutlet var saveNewButton: NSButton!
    var tv:NSTableView! = nil
    var dateString:String = ""
    var fileURL:URL! = nil
    
    @IBAction func saveNewPressed(_ sender: NSButton) {
        let index = slEntry.count
        slEntry.append(SLEntry(99,noFileString,0,0))
        overwriteAndDismissDialog(index)
    }
    
    func numberOfSections(in tableView: NSTableView) -> Int { return 1 }
    func numberOfRows(in tableView: NSTableView) -> Int { return slEntry.count }

    func rowForButton(_ sender: NSButton) -> Int {
        let buttonPosition = sender.convert(CGPoint.zero, to:tv)
        return 1 + tv.row(at:buttonPosition)
    }
    
    func didTapOverwriteButton(_ sender: NSButton) { overwriteAndDismissDialog(rowForButton(sender)) }
    func didTapDeleteButton(_ sender: NSButton) { deleteAndReloadList(rowForButton(sender)) }
    
    @IBAction func radioPressed(_ sender: NSButton) {
        if sender == DateRadio {
            if dateSort { dateAscending = !dateAscending }
            dateSort = true
        }
        else { dateSort = false }
        
        DateRadio.title = dateAscending ? "Date Asc" : "Date Desc"
        
        updateSortButtons()
        sortSLEntries()
        tv.reloadData()
    }
    
    func loadSLEntries() {
        slEntry.removeAll()
        
        var cc = Control()
        var kind = Int()
        
        for index in 0 ..< 1000 {
            let str = determineDateString(index)
            if str == noFileString { continue }
            
            // ------------------------
            kind = 0
            determineURL(index, usefilenameNumber:false)
            let data = NSData(contentsOf: fileURL)
            if data != nil {
                data?.getBytes(&cc, length:sz)
                kind = Int(cc.equation)
            }
            
            slEntry.append(SLEntry(kind,str,dateValue,index))
        }
        
        sortSLEntries()
    }
    
    func sortSLEntries() {
        var okay:Bool = true
        
        func swap(_ i:Int) {
            let t = slEntry[i+1]
            slEntry[i+1].copy(slEntry[i])
            slEntry[i].copy(t)
            okay = false
        }
        
        func dSort(_ i:Int) {
            if dateAscending { if slEntry[i].dateValue > slEntry[i+1].dateValue { swap(i) }}
            else { if slEntry[i].dateValue < slEntry[i+1].dateValue { swap(i) }}
        }
        
        while true {
            okay = true
            
            for i in 0 ..< slEntry.count-1 {
                if dateSort {
                    dSort(i)
                }
                else { // Kind sort
                    if slEntry[i].kind > slEntry[i+1].kind {
                        swap(i)
                    }
                    else if slEntry[i].kind == slEntry[i+1].kind { dSort(i) }
                }
            }
            
            if okay { break }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tv = scrollView.documentView as? NSTableView
        tv.dataSource = self
        tv.delegate = self
        
        updateSortButtons()
        loadSLEntries()
    }
    
    func updateSortButtons() {
        DateRadio.set(textColor: dateSort ? .red : .white)
        KindRadio.set(textColor: !dateSort ? .red : .white)
        saveNewButton.set(textColor: .white)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell:SaveLoadCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SLCell"), owner: self) as! SaveLoadCell
        
        if row >= slEntry.count { return cell }
        
        cell.legend.stringValue = String(format:"%2d %@  %@",row+1,  vc.titleString[slEntry[row].kind],  slEntry[row].dateString)
        cell.isUnused = false
        cell.delegate = self
        cell.kind = slEntry[row].kind
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        loadAndDismissDialog(tv.selectedRow)
    }
    
    //MARK:-
    
    let sz = MemoryLayout<Control>.size
    
    func determineURL(_ number:Int, usefilenameNumber:Bool) {
        var number = number
        if usefilenameNumber { number = slEntry[number].filenameNumber }
        
        let name = String(format:"Store%d.dat",number)
        fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(name)
    }
    
    func writeDataToFileURLAndDismiss() {
        do {
            vc.control.version = versionNumber
            let data:NSData = NSData(bytes:&vc.control, length:self.sz)
            try data.write(to: self.fileURL, options: .atomic)
        } catch {
            print(error)
        }
        
        dismiss(self)
    }
    
    func overwriteAndDismissDialog(_ index:Int) {
        func finishSession() {
            determineURL(index, usefilenameNumber:true)
            writeDataToFileURLAndDismiss()
        }
        
        if slEntry[index].dateString == noFileString { // an 'add' session
            // determine first unused filenameNumber
            var i = 0
            let fileManager = FileManager.default
            
            while true {
                self.determineURL(i, usefilenameNumber:false)
                if !fileManager.fileExists(atPath: fileURL.path) { break }
                i += 1
            }
            
            writeDataToFileURLAndDismiss()
        }
        else {
            let alert = NSAlert()
            alert.messageText = "Overwrite Entry"
            alert.informativeText = "Confirm overwrite of Entry"
            alert.addButton(withTitle: "NO")
            alert.addButton(withTitle: "YES")
            alert.beginSheetModal(for: self.view.window!) {( returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode.rawValue == 1001 {
                    do {
                        self.determineURL(index, usefilenameNumber:true)
                        self.writeDataToFileURLAndDismiss()
                    }}
                else { self.dismiss(self) }
            }
        }
    }
    
    func deleteEntry(_ index:Int) {
        self.determineURL(index, usefilenameNumber:true)
        
        do {
            let fileManager = FileManager.default
            
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(atPath: fileURL.path)
            }
        }
        catch let error as NSError { print("delete error: \(error)") }
    }
    
    func deleteAndReloadList(_ index:Int) {
        let alert = NSAlert()
        alert.messageText = "Delete Entry"
        alert.informativeText = "Confirm deletion of Entry"
        alert.addButton(withTitle: "NO")
        alert.addButton(withTitle: "YES")
        alert.beginSheetModal(for: self.view.window!) {( returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode.rawValue == 1001 {
                do {
                    self.deleteEntry(index)
                    self.loadSLEntries()
                    self.tv.reloadData()
                }
            }
            else { self.dismiss(self) }
        }
    }
    
    //MARK:-
    
    var dateValue = TimeInterval()
    
    func determineDateString(_ index:Int) -> String {
        var dStr = noFileString
        
        determineURL(index, usefilenameNumber:false)
        
        do {
            let key:Set<URLResourceKey> = [.creationDateKey]
            let value = try fileURL.resourceValues(forKeys: key)
            if let date = value.creationDate {
                dateValue = date.timeIntervalSince1970
                dStr = date.toString()
            }
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
        
        determineURL(index, usefilenameNumber:true)
        
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
            if loadNextIndex >= slEntry.count { loadNextIndex = 0 }
            
            print(loadNextIndex)
            
            determineURL(loadNextIndex, usefilenameNumber:true)
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

extension NSButton {
    
    func set(textColor color: NSColor) {
        let newAttributedTitle = NSMutableAttributedString(attributedString: attributedTitle)
        let range = NSRange(location: 0, length: attributedTitle.length)
        
        newAttributedTitle.addAttributes([
            .foregroundColor: color,
        ], range: range)
        
        attributedTitle = newAttributedTitle
    }
}

