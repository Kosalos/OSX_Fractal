import Cocoa

var winHandler:WindowHandler! = nil

// 0 = widgets on Main window
// 1 = widgets on Color window
// 2 = widgets on Lights window
// 3 = control window

class WindowHandler {
    var windows:[NSWindow] = []
    var widgets:[Widget] = []
    var focusIndex = -1

    init() {
        winHandler = self
    }
    
    func initialize() {
        let mainStoryboard = NSStoryboard.init(name: NSStoryboard.Name("Main"), bundle: nil)

        func addWindowToList(_ windowControllerSceneID:String) {
            let wc = mainStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(windowControllerSceneID)) as? NSWindowController
            wc!.showWindow(vc)
            
            windows.append(wc!.window!)
        }
        
        windows.append(vc.view.window!) // main window
        addWindowToList("Color")
        addWindowToList("Lights")
        
        // widget instances do not exist until their parent window is launched
        let w1 = windows[0].contentViewController as! ViewController
        widgets.append(w1.widget)

        let w2 = windows[1].contentViewController as! WinColorViewController
        widgets.append(w2.widget)

        let w3 = windows[2].contentViewController as! WinLightViewController
        widgets.append(w3.widget)
    }

    func widgetCountInWindow(_ index:Int) -> Int { return widgets[index].data.count }
    func widgetPointer(_ index:Int) -> Widget { return widgets[index] }
    func stringForRow(_ index:Int, _ row:Int) -> String { return widgets[index].data[row].displayString() }

    func refreshWidgetsAndImage() {
        let w1 = windows[0].contentViewController as! ViewController
        w1.flagViewToRecalcFractal()

        let w2 = windows[1].contentViewController as! WinColorViewController
        w2.displayWidgets()

        let w3 = windows[2].contentViewController as! WinLightViewController
        w3.displayWidgets()
    }

    func cycleWindowFocus() {  // with kludge to put Control window in the List
        focusIndex = (focusIndex + 1) % (windows.count+1)
        
        if focusIndex == windows.count {
            focusIndex = -1
            winControl.window!.makeKeyAndOrderFront(nil)
            return
        }

        windows[focusIndex].makeKeyAndOrderFront(nil)
    }

    func setWindowFocus(_ index:Int) {
        focusIndex = index-1
        cycleWindowFocus()
    }
        
    func closeAllWindows() {
        for i in 1 ..< windows.count {   // skip 0 (main window)
            windows[i].close()
        }
    }
}
