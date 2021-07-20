import Cocoa

enum HelpPageID: Int { case Main = 1, Color, Light, Billboard, Control, Video, SaveLoad }

var isHelpVisible:Bool = false

class HelpViewController: NSViewController {
    var id:HelpPageID = .Main
    
    @IBOutlet var scrollView: NSScrollView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.resignFirstResponder()
        let textView = scrollView.documentView as? NSTextView
        
        do {
            let filename = String(format: "help%d.txt",id.rawValue)
            textView!.string = try String(contentsOfFile: Bundle.main.path(forResource:filename, ofType: "")!)
            isHelpVisible = true
        } catch {
            fatalError("\n\nload help text failed\n\n")
        }
    }
    
    override func viewDidDisappear() {
        isHelpVisible = false
    }
    
    // so user can issue commands while viewing the help page
    override func keyDown(with event: NSEvent) {
        switch id {
        case .Main,.Video :
            let vlist = [ nil,vc,videoRecorderWindow ]
            vlist[id.rawValue]?.keyDown(with: event)
        default : break
        }
    }
}

func showHelpPage(_ parentView:NSView, _ pageID:HelpPageID) {
    if !isHelpVisible {
        let mvc = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let helpVC = mvc.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("HelpVC")) as! HelpViewController
        
        helpVC.id = pageID
        vc.present(helpVC, asPopoverRelativeTo: parentView.bounds, of: parentView, preferredEdge: .minX, behavior: .semitransient)
    }
}


