import Cocoa

var winHandler:WindowHandler! = nil

// 0 = widgets on Main window
// 1 = widgets on Color window
// 2 = widgets on Lights window
// 3 = widgets on Billboards window
// 4 = control window
// 5 = memory window

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
        
        windows.append(vc.view.window!) // 0 main window
        addWindowToList("Color")        // 1
        addWindowToList("Lights")       // 2
        addWindowToList("Billboards")   // 3
        
        //addWindowToList("Control")      // 4 no widgets
        windows.append(winControl.window!)

        addWindowToList("Memory")       // 5 no widgets

        // widget instances do not exist until their parent window is launched
        let w0 = windows[0].contentViewController as! ViewController
        widgets.append(w0.widget)

        let w1 = windows[1].contentViewController as! WinColorViewController
        widgets.append(w1.widget)

        let w2 = windows[2].contentViewController as! WinLightViewController
        widgets.append(w2.widget)

        let w3 = windows[3].contentViewController as! WinBillboardViewController
        widgets.append(w3.widget)

        func windowGainedFocus(notification: Notification) {
            // so only widget list on the active window has the red colored highlight
            for i in 0 ..< windows.count-2 {
                if windows[i].isMainWindow {
                    focusIndex = i
                    break
                }
            }
            
            updateWindowWidgetFocus()
         }

         _ = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
             object: nil, queue: nil,
             using: windowGainedFocus)
    }

    func widgetCountInWindow(_ index:Int) -> Int { return widgets[index].data.count }
    func widgetPointer(_ index:Int) -> Widget { return widgets[index] }
    func stringForRow(_ index:Int, _ row:Int) -> String { return widgets[index].data[row].displayString() }

    func refreshWidgetsAndImage() {
        let w0 = windows[0].contentViewController as! ViewController
        w0.flagViewToRecalcFractal()

        let w1 = windows[1].contentViewController as! WinColorViewController
        w1.displayWidgets()

        let w2 = windows[2].contentViewController as! WinLightViewController
        w2.displayWidgets()

        let w3 = windows[3].contentViewController as! WinBillboardViewController
        w3.displayWidgets()
    }
    
    func updateWindowWidgetFocus() { // so only widget list on the active window has the red colored highlight
        if focusIndex > windows.count-2 { return } // no widgets on last 2 windows
        
        if focusIndex != NO_FOCUS && focusIndex < windows.count-2 {
            widgets[focusIndex].gainFocus()
            for i in 0 ..< windows.count-2 {
                if i != focusIndex {
                    widgets[i].loseFocus()
                }
            }
        }
    }
    
    func cycleWindowFocus() {  // with kludge to put Control window in the List
        focusIndex = (focusIndex + 1) % (windows.count+1)
        
        if focusIndex == windows.count {
            focusIndex = -1
            winControl.window!.makeKeyAndOrderFront(nil)
            return
        }

        windows[focusIndex].makeKeyAndOrderFront(nil)
        updateWindowWidgetFocus()
        
        let w0 = windows[0].contentViewController as! ViewController
        w0.displayWidgets()

        let w1 = windows[1].contentViewController as! WinColorViewController
        w1.displayWidgets()

        let w2 = windows[2].contentViewController as! WinLightViewController
        w2.displayWidgets()

        let w3 = windows[3].contentViewController as! WinBillboardViewController
        w3.displayWidgets()
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
