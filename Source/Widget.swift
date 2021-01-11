import Cocoa

protocol WidgetDelegate {
    func displayWidgets()
    func widgetCallback(_ index:Int)
}

enum WidgetKind { case integer32,float,legend,boolean }

var alterationSpeed:Float = 1

struct WidgetData {
    var kind:WidgetKind = .float
    var legend:String = ""
    var valuePtr:UnsafeMutableRawPointer! = nil
    var delta:Float = 0
    var range = simd_float2()
    var showValue:Bool = false
    var callbackIndex:Int = 0
    
    func alterValue(_ direction:Int) -> Bool {
        switch kind {
        case .boolean :
            var value:Bool = valuePtr.load(as:Bool.self)
            value = !value
            valuePtr.storeBytes(of:value, as:Bool.self)
            return true
        case .float :
            
            var value:Float = valuePtr.load(as:Float.self)
            let oldValue = value
            let amt:Float = delta * alterationSpeed
            
            value += direction > 0 ? amt : -amt
            value = max( min(value, range.y), range.x)
            
            if value != oldValue {
                valuePtr.storeBytes(of:value, as:Float.self)
                vcControl.refreshControlPanels()
                return true
            }
            
        case .integer32 :
            var value:Int32 = valuePtr.load(as:Int32.self)
            let oldValue = value
            
            var amt:Int32 = Int32(Float(delta) * alterationSpeed)
            if amt == 0 { amt = delta < 0 ? -1 : 1 }
            
            value += direction > 0 ? amt : -amt
            value = max( min(value, Int32(range.y)), Int32(range.x))
            
            if value != oldValue {
                valuePtr.storeBytes(of:value, as:Int32.self)
                vcControl.refreshControlPanels()
                return true
            }
            
        default : break
        }

        return false
    }
    
    func setValue(_ v:Float) {
        if valuePtr != nil {
            valuePtr.storeBytes(of:v, as:Float.self)
            vcControl.refreshControlPanels() 
        }
    }
    
    func ensureValueIsInRange() {
        if valuePtr != nil {
            var value:Float = valuePtr.load(as:Float.self)
            value = max( min(value, range.y), range.x)
            valuePtr.storeBytes(of:value, as:Float.self)
        }
    }
    
    func valueString() -> String {
        switch kind {
        case .boolean :
            let value:Bool = valuePtr.load(as:Bool.self)
            return value ? "Yes" : "No"
        case .integer32 :
            let value:Int32 = valuePtr.load(as:Int32.self)
            return value.description
        case .float :
            let value:Float = valuePtr.load(as:Float.self)
            return value.debugDescription
            default : break
        }
        
        return ""
    }
    
    func displayString() -> String {
        var s:String = legend
        if showValue { s = s + " : " + valueString() }
        return s
    }
    
    func valuePercent() -> Int {
        if kind == .integer32 {
            let value:Int32 = valuePtr.load(as:Int32.self)
            return Int((Float(value) - range.x) * 100 / (range.y - range.x))
        }

        let value:Float = valuePtr.load(as:Float.self)
        return Int((value - range.x) * 100 / (range.y - range.x))
    }
    
    func isAtLimit() -> Bool {
        let value:Float = valuePtr.load(as:Float.self)
        return value == range.x || value == range.y
    }
    
    func getRatio() -> Float {
        let value:Float = valuePtr.load(as:Float.self)
        return (value - range.x) / (range.y - range.x)
    }
    
    func setRatio(_ v:Float) {
        setValue(range.x + v * (range.y - range.x))
    }
}

class Widget {
    var delegate:WidgetDelegate?
    var data:[WidgetData] = []
    var focus:Int = 0
    var previousFocus:Int = 0
    
    var shiftKeyDown = Bool()
    var optionKeyDown = Bool()
    
    init(_ d:WidgetDelegate) {
        delegate = d
        reset()
    }
    
    func reset() {
        data.removeAll()
        focus = 0
        previousFocus = focus
    }
    
    func gainFocus() {
        focus = previousFocus
        focusChanged()
    }
    
    func loseFocus() {
        if focus >= 0 { previousFocus = focus }
        focus = -1
        focusChanged()
    }
    
    func addFloat(_ nLegend:String,
                  _ nValuePtr:UnsafeMutableRawPointer,
                  _ minValue:Float, _ maxValue:Float, _ nDelta:Float,
                  _ nKind:WidgetKind = .float,
                  _ nShowValue:Bool = false) {
        var w = WidgetData()
        w.legend = nLegend
        w.valuePtr = nValuePtr
        w.range.x = minValue
        w.range.y = maxValue
        w.delta = nDelta
        w.kind = nKind
        w.showValue = nShowValue
        w.ensureValueIsInRange()
        data.append(w)
    }
    
    func addInt32(_ legend:String,
                  _ nValuePtr:UnsafeMutableRawPointer,
                  _ minValue:Int, _ maxValue:Int, _ nDelta:Int,
                  _ callbackIndex:Int = 0) {
        var w = WidgetData()
        w.legend = legend
        w.valuePtr = nValuePtr
        w.kind = .integer32
        w.range.x = Float(minValue)
        w.range.y = Float(maxValue)
        w.delta = Float(nDelta)
        w.showValue = true
        w.callbackIndex = callbackIndex
        data.append(w)
    }

    func addLegend(_ legend:String = "") {
        var w = WidgetData()
        w.kind = .legend
        w.legend = legend
        data.append(w)
    }
    
    func addBoolean(_ legend:String, _ nValuePtr:UnsafeMutableRawPointer, _ callbackIndex:Int = 0) {
        var w = WidgetData()
        w.legend = legend
        w.valuePtr = nValuePtr
        w.kind = .boolean
        w.showValue = true
        w.callbackIndex = callbackIndex
        data.append(w)
    }
    
    func focusChanged() {
        delegate?.displayWidgets()
        vc.updateWindowTitle()
    }
    
    func moveFocus(_ direction:Int) {
        if data.count > 1 {
            focus += direction
            if focus < 0 { focus = data.count-1 }
            if focus >= data.count { focus = 0 }
            
            if data[focus].kind == .legend { moveFocus(direction) }
            
            focusChanged()
        }
    }
    
    func focusDirect(_ index:Int) {
        if index < 0 || index >= data.count { return }
        if data[index].kind == .float {
            focus = index
            focusChanged()
        }
    }
    
    func updateAlterationSpeed(_ event:NSEvent) {
        let rv = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        shiftKeyDown  = rv & (1 << 17) != 0
        optionKeyDown = rv & (1 << 19) != 0
        
        alterationSpeed = 1
        if shiftKeyDown && optionKeyDown { alterationSpeed = 50 } else
            if shiftKeyDown { alterationSpeed = 0.1 } else if optionKeyDown { alterationSpeed = 10 }
    }
    
    var lastKeypressWasArrowKey = false // if true then do not pass keypress onto main window
    
    func keyPress(_ event:NSEvent) -> Bool { // true == key caused valie change & reCalc of image
        updateAlterationSpeed(event)

        lastKeypressWasArrowKey = false

        switch Int32(event.keyCode) {
        case LEFT_ARROW :
            lastKeypressWasArrowKey = true
            if data[focus].alterValue(-1) {
                vc.flagViewToRecalcFractal()
                if data[focus].showValue { delegate?.displayWidgets() }
                if data[focus].kind == .boolean { delegate?.widgetCallback(data[focus].callbackIndex) }
                return true
            }
        case RIGHT_ARROW :
            lastKeypressWasArrowKey = true
            if data[focus].alterValue(+1) {
                vc.flagViewToRecalcFractal()
                if data[focus].showValue { delegate?.displayWidgets() }
                if data[focus].kind == .boolean { delegate?.widgetCallback(data[focus].callbackIndex) }
                return true
            }
        case DOWN_ARROW :
            lastKeypressWasArrowKey = true
            moveFocus(+1)
            return false
        case UP_ARROW :
            lastKeypressWasArrowKey = true
            moveFocus(-1)
            return false
        default : break
        }
        
        return false
    }
    
    func focusString() -> String {
        if focus < 0 { return "" }
        return data[focus].displayString()
    }
    
    func addinstructionEntries(_ str:NSMutableAttributedString) {
        for i in 0 ..< data.count {
            switch data[i].kind {
            case .integer32, .float, .boolean :
                str.colored(data[i].displayString(), i == focus ? .red : .white)
            case .legend :
                str.normal(data[i].legend != "" ? data[i].legend : "-------------")
            }
        }
    }
    
    func isLegalControlPanelIndex(_ index:Int) -> Bool {
        if index >= data.count { return false }
        if data[index].kind == .float { return true }
        if data[index].kind == .integer32 { return true }
        return false
    }
}
