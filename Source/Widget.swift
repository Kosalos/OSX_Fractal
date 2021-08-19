import Cocoa

protocol WidgetDelegate {
    func displayWidgets()
    func widgetCallback(_ index:Int)
}

enum WidgetKind { case integer32,float,legend,boolean }

let NO_FOCUS = -1
var alterationSpeed:Float = 1

struct WidgetData {
    var kind:WidgetKind = .float
    var legend:String = ""
    var valuePtr:UnsafeMutableRawPointer! = nil
    var delta:Float = 0
    var range = simd_float2()
    var showValue:Bool = false
    var wrap:Bool = false
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

            if wrap {
                if value < 0 { value = Int32(range.y) }
                if value > Int32(range.y) { value = 0 }
            }
            else {
                value = max( min(value, Int32(range.y)), Int32(range.x))
            }
            
            if value != oldValue {
                valuePtr.storeBytes(of:value, as:Int32.self)
                vcControl.refreshControlPanels()
                return true
            }
            
        default : break
        }

        return false
    }
    
    func randomFloatValue(_ optionKeyDown:Bool) {
        if kind != .float { return }
        
        if optionKeyDown {
            let r:Float = (range.y - range.x) / 30
            var value:Float = valuePtr.load(as:Float.self) + Float.random(in: -r ... r)
            value = max( min(value, range.y), range.x)
            valuePtr.storeBytes(of:value, as:Float.self)
        }
        else {
            let value:Float = Float.random(in: range.x ... range.y)
            valuePtr.storeBytes(of:value, as:Float.self)
        }
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
            return String(format: "%6.3f", value)
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

        if(range.x == range.y) {
            print("Error:  widget range is zero")
            exit(-1)
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
    var focus:Int = NO_FOCUS
    var previousFocus:Int = NO_FOCUS
    
    init(_ d:WidgetDelegate) {
        delegate = d
        reset()
    }
    
    func reset(_ rememberFocusIndex:Bool = false) {
        data.removeAll()
        if !rememberFocusIndex { focus = 0 }
        previousFocus = focus
    }
    
    func gainFocus() {
        focus = previousFocus
        if focus == NO_FOCUS { focus = 0 }
        focusChanged()
    }
    
    func loseFocus() {
        if focus != NO_FOCUS { previousFocus = focus }
        focus = NO_FOCUS
        focusChanged()
    }
    
    func addFloat(_ nLegend:String,
                  _ nValuePtr:UnsafeMutableRawPointer,
                  _ minValue:Float, _ maxValue:Float, _ nDelta:Float,
                  _ nShowValue:Bool = false,
                  _ callbackIndex:Int = 1) {
        var w = WidgetData()
        w.legend = nLegend
        w.valuePtr = nValuePtr
        w.range.x = minValue
        w.range.y = maxValue
        w.delta = nDelta
        w.kind = .float
        w.showValue = nShowValue
        w.ensureValueIsInRange()
        w.callbackIndex = callbackIndex
        data.append(w)
    }
    
    func addInt32(_ legend:String,
                  _ nValuePtr:UnsafeMutableRawPointer,
                  _ minValue:Int, _ maxValue:Int, _ nDelta:Int,
                  _ wrap:Bool = false,
                  _ callbackIndex:Int = -1) {
        var w = WidgetData()
        w.legend = legend
        w.valuePtr = nValuePtr
        w.kind = .integer32
        w.range.x = Float(minValue)
        w.range.y = Float(maxValue)
        w.delta = Float(nDelta)
        w.showValue = true
        w.wrap = wrap
        w.callbackIndex = callbackIndex
        data.append(w)
    }

    func addLegend(_ legend:String = "") {
        var w = WidgetData()
        w.kind = .legend
        w.legend = legend
        data.append(w)
    }
    
    func addBoolean(_ legend:String,
                    _ nValuePtr:UnsafeMutableRawPointer,
                    _ callbackIndex:Int = -1) {
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
        updateModifierKeyFlags(event)
        
        alterationSpeed = 1
        if shiftKeyDown && optionKeyDown { alterationSpeed = 50 } else
            if shiftKeyDown { alterationSpeed = 0.1 } else if optionKeyDown { alterationSpeed = 10 }
        
        if speed1000 { alterationSpeed *= 0.01 }
    }
    
    var lastKeypressWasArrowKey = false // if true then do not pass keypress onto main window
    
    func keyPress(_ event:NSEvent, _ flagReCalc:Bool = false) -> Bool { // true == key caused value change & reCalc of image
        updateAlterationSpeed(event)
        lastKeypressWasArrowKey = false

        var changeMade:Bool = false
        
        switch Int32(event.keyCode) {
        case LEFT_ARROW :
            if focus < 0 { break }
            lastKeypressWasArrowKey = true
            if data[focus].alterValue(-1) {
                vc.flagViewToRecalcFractal()
                if data[focus].showValue { delegate?.displayWidgets() }
                if data[focus].callbackIndex >= 0 { delegate?.widgetCallback(data[focus].callbackIndex) }
                changeMade = true
            }
        case RIGHT_ARROW :
            if focus < 0 { break }
            lastKeypressWasArrowKey = true
            if data[focus].alterValue(+1) {
                vc.flagViewToRecalcFractal()
                if data[focus].showValue { delegate?.displayWidgets() }
                if data[focus].callbackIndex >= 0 { delegate?.widgetCallback(data[focus].callbackIndex) }
                changeMade = true
            }
        case DOWN_ARROW :
            lastKeypressWasArrowKey = true
            moveFocus(+1)
        case UP_ARROW :
            lastKeypressWasArrowKey = true
            moveFocus(-1)
        default : break
        }
        
        if changeMade && focus != NO_FOCUS && event.keyCode != UP_ARROW && event.keyCode != DOWN_ARROW {
            vc.setShaderToFastRender()
            vc.flagViewToRecalcFractal()
        }

        return changeMade
    }
    
    func focusString() -> String {
        if focus == NO_FOCUS { return "" }
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
    
    func randomValues(_ shiftKeyDown:Bool, _ optionKeyDown:Bool) {
        if shiftKeyDown && focus >= 0 {
            data[focus].randomFloatValue(optionKeyDown)
            return
        }

        for i in 0 ..< data.count {
            data[i].randomFloatValue(optionKeyDown)
        }
    }
}
