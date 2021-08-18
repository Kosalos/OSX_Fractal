import Cocoa
import MetalKit

let MSZ = CGFloat(50)
let MMARGIN = CGFloat(4)
let MXB = CGFloat(10)
let MYB = CGFloat(10)
let MXS = Int(10)
let MYS = Int(10)
let MTOTAL = MXS * MYS

struct MemoryData {
    var image = NSImageView()
    var control = Control()
}

var vcMemory:MemoryViewController! = nil

class MemoryViewController: NSViewController, NSWindowDelegate {
    var index = Int()
    var focusIndex = Int()
    var data:[MemoryData] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        vcMemory = self
        
        var i = Int(0)
        for y in 0 ..< MYS {
            let yp = MYB + CGFloat(y) * (MMARGIN + MSZ)
            
            for x in 0 ..< MXS {
                let xp = MXB + CGFloat(x) * (MMARGIN + MSZ)
                
                var d = MemoryData()
                d.image = NSImageView.init(frame:CGRect(x:xp, y:yp, width:MSZ, height:MSZ))
                d.control = vc.control
                
                data.append(d)
                self.view.addSubview(data[i].image)
                
                i += 1
            }
        }
    }
    
    override func viewDidAppear() {
        view.window?.delegate = self
    }
    
    @IBAction func helpPressed(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Select Image to Return To"
        alert.informativeText = "Mouse click/drag to select which settings to retrieve."
        alert.beginSheetModal(for: view.window!) { ( returnCode: NSApplication.ModalResponse) -> Void in () }
    }
    
    func addImage(_ t:MTLTexture) {
        data[index].control = vc.control
        data[index].image.imageFromTexture(t)
        index += 1
        if index >= MTOTAL { index = 0 }
        view.setNeedsDisplay(view.bounds)
    }
    
    override func mouseDown(with event: NSEvent) {
        let pt = event.locationInWindow
        let x = Int((pt.x - MXB) / (MMARGIN + MSZ))
        let y = MYS - 1 - Int((pt.y - MYB) / (MMARGIN + MSZ))
        let temp = x + y * MXS
        
        if temp >= 0 && temp < MTOTAL {
            focusIndex = temp
            view.setNeedsDisplay(view.bounds)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        mouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        if data[focusIndex].control.cx != 0 {
            vc.control = data[focusIndex].control
            vc.control.skip = 1
            vc.controlJustLoaded()
        }
        
        focusIndex = -1
        view.setNeedsDisplay(view.bounds)
    }
    
    override func keyDown(with event: NSEvent) {
        switch Int32(event.keyCode) {
        case ESC_KEY :
            vc.repeatCount = 0
        default : break
        }
        
        vc.keyDown(with:event)
    }
    
    override func keyUp(with event: NSEvent) { vc.keyUp(with:event) }
}

class BaseNSViewMemory: NSView {
    override var isFlipped: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
    
    override func draw(_ rect: NSRect) {
        let c = CGFloat(0.3)
        NSColor(red:c, green:c, blue:c + 0.1, alpha:1).set()
        NSBezierPath(rect:bounds).fill()
        
        var index = vcMemory.index-1; if index < 0 { index = MTOTAL-1 }
        var r = vcMemory.data[index].image.frame.insetBy(dx: -2, dy: -2)
        let context = NSGraphicsContext.current?.cgContext
        context?.setLineWidth(4.0)
        NSColor.red.set()
        NSBezierPath(rect:r).stroke()
        
        if vcMemory.focusIndex >= 0 {
            index = vcMemory.focusIndex
            r = vcMemory.data[index].image.frame.insetBy(dx: -2, dy: -2)
            NSColor.yellow.set()
            NSBezierPath(rect:r).stroke()
        }
    }
}

extension NSImageView {
    func imageFromTexture(_ tt:MTLTexture) {
        image = tt.toNSImage(NSSize(width:50, height:50))!
    }
}

// https://stackoverflow.com/questions/33844130/take-a-snapshot-of-current-screen-with-metal-in-swift

extension MTLTexture {
    func imageBytes(_ width:Int, _ height:Int) -> UnsafeMutableRawPointer {
        let rowBytes = width * 4
        let p = malloc(width * height * 4)
        self.getBytes(p!, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        return p!
    }
    
    func toImage(_ desiredSize:NSSize) -> CGImage? {
        // scale src pixels to dst pixel size
        let xs = Int(desiredSize.width)
        let ys = Int(desiredSize.height)
        let srcPixels = imageBytes(self.width,self.height).assumingMemoryBound(to: Float.self) // 4 bytes per pixel
        let dstPixels = imageBytes(xs,ys).assumingMemoryBound(to: Float.self)

        let xHop = self.width / xs
        let yHop = self.height / ys

        for y in 0 ..< ys {
            for x in 0 ..< xs {
                let sIndex = y * self.width * yHop + x * xHop
                let dIndex = y * xs + x
                
                dstPixels[dIndex] = srcPixels[sIndex]
            }
        }

        free(srcPixels)

        // make cgImage from dstPixels
        let pColorSpace = CGColorSpaceCreateDeviceRGB()
        let rawBitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: rawBitmapInfo)
        let callback:CGDataProviderReleaseDataCallback = { (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in return }

        let rowBytes = xs * 4
        let size = rowBytes * ys
        let provider = CGDataProvider(dataInfo:nil, data:dstPixels, size:size, releaseData:callback)
        let cgImageRef = CGImage(width:xs, height:ys, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes, space: pColorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)!

        return cgImageRef
    }
    
    func toNSImage(_ desiredSize:NSSize) -> NSImage? {
        return NSImage(cgImage:toImage(desiredSize)!, size:desiredSize)
    }
}










//import Cocoa
//import MetalKit
//
//let MSZ = CGFloat(50)
//let MMARGIN = CGFloat(4)
//let MXB = CGFloat(10)
//let MYB = CGFloat(10)
//let MXS = Int(10)
//let MYS = Int(10)
//let MTOTAL = MXS * MYS
//
//struct MemoryData {
//    var image = NSImageView()
//    var control = Control()
//}
//
//var vcMemory:MemoryViewController! = nil
//var data:[MemoryData] = []
//
//class MemoryViewController: NSViewController, NSWindowDelegate {
//    var index = Int()
//    var focusIndex = Int()
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        vcMemory = self
//
//        var i = Int(0)
//        for y in 0 ..< MYS {
//            let yp = MYB + CGFloat(y) * (MMARGIN + MSZ)
//
//            for x in 0 ..< MXS {
//                let xp = MXB + CGFloat(x) * (MMARGIN + MSZ)
//
//                var d = MemoryData()
//                d.image = NSImageView.init(frame:CGRect(x:xp, y:yp, width:MSZ, height:MSZ))
//                d.control = vc.control
//
//                data.append(d)
//                self.view.addSubview(data[i].image)
//
//                i += 1
//            }
//        }
//    }
//
//    override func viewDidAppear() {
//        view.window?.delegate = self
//    }
//
//    @IBAction func helpPressed(_ sender: NSButton) {
//        let alert = NSAlert()
//        alert.messageText = "Select Image to Return To"
//        alert.informativeText = "Mouse click/drag to select which settings to retrieve."
//        alert.beginSheetModal(for: view.window!) { ( returnCode: NSApplication.ModalResponse) -> Void in () }
//    }
//
//    func addImage(_ t:MTLTexture) {
//// zorro add memory
//       data[index].control = vc.control
//        data[index].image.imageFromTexture(t)
//        index += 1
//        if index >= MTOTAL { index = 0 }
//        view.setNeedsDisplay(view.bounds)
//    }
//
//    override func mouseDown(with event: NSEvent) {
//        let pt = event.locationInWindow
//        let x = Int((pt.x - MXB) / (MMARGIN + MSZ))
//        let y = MYS - 1 - Int((pt.y - MYB) / (MMARGIN + MSZ))
//        let temp = x + y * MXS
//
//        if temp >= 0 && temp < MTOTAL {
//            focusIndex = temp
//            view.setNeedsDisplay(view.bounds)
//        }
//    }
//
//    override func mouseDragged(with event: NSEvent) {
//        mouseDown(with: event)
//    }
//
//    override func mouseUp(with event: NSEvent) {
//        if data[focusIndex].control.cx != 0 {
//            vc.control = data[focusIndex].control
//            vc.control.skip = 1
//            vc.controlJustLoaded()
//        }
//
//        focusIndex = -1
//        view.setNeedsDisplay(view.bounds)
//    }
//
//    override func keyDown(with event: NSEvent) {
//        switch Int32(event.keyCode) {
//        case ESC_KEY :
//            vc.repeatCount = 0
//        default : break
//        }
//
//        vc.keyDown(with:event)
//    }
//
//    override func keyUp(with event: NSEvent) { vc.keyUp(with:event) }
//
//    //////////////////////////
//    // https://stackoverflow.com/questions/38574867/changing-specific-pixels-in-a-uiimage-based-on-rbg-values-to-a-different-rbg-col
//
//    struct RGBA32: Equatable {
//        private var color: UInt32
//
//        init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
//            color = (UInt32(red) << 24) | (UInt32(green) << 16) | (UInt32(blue) << 8) | (UInt32(alpha) << 0)
//        }
//
//        static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
//
//        static func ==(lhs: RGBA32, rhs: RGBA32) -> Bool {
//            return lhs.color == rhs.color
//        }
//
//        static let black = RGBA32(red: 0, green: 0, blue: 0, alpha: 255)
//        static let red   = RGBA32(red: 255, green: 0, blue: 0, alpha: 255)
//        static let green = RGBA32(red: 24, green: 183, blue: 3, alpha: 255)
//        static let darkgreen = RGBA32(red: 70, green: 105, blue: 35, alpha: 255)
//        static let blue  = RGBA32(red: 0, green: 127, blue: 255, alpha: 255)
//        static let lightblue = RGBA32(red: 33, green: 255, blue: 255, alpha: 255)
//        static let brown = RGBA32(red: 127, green: 63, blue: 0, alpha: 255)
//    }
//
//
//    func processPixelsInImage(_ inputCGImage: CGImage) -> NSImage? {
//        let colorSpace       = CGColorSpaceCreateDeviceRGB()
//        let width            = 50 // inputCGImage.width
//        let height           = 50 // inputCGImage.height
//        let bytesPerPixel    = 4
//        let bitsPerComponent = 8
//        let bytesPerRow      = bytesPerPixel * width
//        let bitmapInfo       = RGBA32.bitmapInfo
//
//        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
//            //print("unable to create context")
//            return nil
//        }
//        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
//
//        guard let buffer = context.data else {
//            //print("unable to get context data")
//            return nil
//        }
//
//        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)
//
////        let white = RGBA32(red: 255, green: 255, blue: 255, alpha: 255)
////        let clear = RGBA32(red: 0, green: 0, blue: 0, alpha: 0)
//
//        for row in 0 ..< Int(height) {
//            for column in 0 ..< Int(width) {
//                let offset = row * width + column
//                pixelBuffer[offset] = RGBA32(red: UInt8(row & 255), green: UInt8(column & 255), blue:0, alpha:255)
//            }
//        }
//
//        let outputCGImage = context.makeImage()!
//        let sz = NSSize(width:50, height:50)
//        let outputImage = NSImage(cgImage: outputCGImage, size:sz) // , scale: 1, orientation: 0) //image.imageOrientation)
//
//        return outputImage
//
//    }
//
////    struct m_RGBColor // My own data-type to hold the picture information
////    {
////        var Alpha: UInt8 = 255
////        var Red:   UInt8 = 0
////        var Green: UInt8 = 0
////        var Blue:  UInt8 = 0
////    }
////
////    func harry() -> CGImage {
////        var onePixel = m_RGBColor()
////        let width = 50
////        let height = 50
////        var pixelArray: [m_RGBColor] = [m_RGBColor]()
////
////        for y in 0 ..< height // Height of your Pixture
////        {
////            for x in 0 ..< width // Width of your Picture
////            {
////                onePixel.Alpha = 1 // Fill one Pixel with your Picture Data
////                onePixel.Red   = UInt8(x & 255) // Fill one Pixel with your Picture Data
////                onePixel.Green = UInt8(y & 255) // Fill one Pixel with your Picture Data
////                onePixel.Blue  = 0 // Fill one Pixel with your Picture Data
////                pixelArray.append(onePixel)
////            }
////        }
////
////        let bitmapCount: Int = pixelArray.count
////        let elmentLength: Int = 4 //     sizeof(m_RGBColor)
////        let render: CGColorRenderingIntent = CGColorRenderingIntent.defaultIntent
////        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
////        let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
////        let providerRef: CGDataProvider? = CGDataProvider(data: NSData(bytes: &pixelArray, length: bitmapCount * elmentLength))
////        let cgimage: CGImage? = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * elmentLength, space: rgbColorSpace, bitmapInfo: bitmapInfo, provider: providerRef!, decode: nil, shouldInterpolate: true, intent: render)
////
////        return cgimage!
////
//////        if cgimage != nil
//////        {
//////            let hk = cgimage?.width
//////            let jk = cgimage?.height
//////        }
////    }
//}
//
//    //https://stackoverflow.com/questions/24091025/how-can-i-manipulate-the-pixel-values-in-a-cgimageref-in-xcode
//    //https://stackoverflow.com/questions/40970644/crop-and-scale-mtltexture
//    //extension MTLTexture {
//    //    func makeScaledCopy(_ dest:MTLTexture, _ width:Int, _ height:Int) {
//    //    let scaleX = Double(width) / Double(self.width)
//    //let scaleY = Double(height) / Double(self.height)
//    //let translateX = Double(0) // -sourceRegion.origin.x) * scaleX
//    //let translateY = Double(0) //-sourceRegion.origin.y) * scaleY
//    //        let filter = MPSImageLanczosScale(device: device)
//    //var transform = MPSScaleTransform(scaleX: scaleX, scaleY: scaleY, translateX: translateX, translateY: translateY)
//    //        let commandBuffer = vc.commandQueue!.makeCommandBuffer()!
//    //withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) -> () in
//    //    filter.scaleTransform = transformPtr
//    //    filter.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destTexture)
//    //}
//    //commandBuffer.commit()
//    //commandBuffer.waitUntilCompleted()
//    //    }
//
//struct m_RGBColor // My own data-type to hold the picture information
//{
//    var Alpha: UInt8 = 255
//    var Red:   UInt8 = 0
//    var Green: UInt8 = 0
//    var Blue:  UInt8 = 0
//}
//
//
//struct RGBA32: Equatable {
//    private var color: UInt32
//
//    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
//        color = (UInt32(red) << 24) | (UInt32(green) << 16) | (UInt32(blue) << 8) | (UInt32(alpha) << 0)
//    }
//
//    static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
//
//    static func ==(lhs: RGBA32, rhs: RGBA32) -> Bool {
//        return lhs.color == rhs.color
//    }
//
//    static let black = RGBA32(red: 0, green: 0, blue: 0, alpha: 255)
//    static let red   = RGBA32(red: 255, green: 0, blue: 0, alpha: 255)
//    static let green = RGBA32(red: 24, green: 183, blue: 3, alpha: 255)
//    static let darkgreen = RGBA32(red: 70, green: 105, blue: 35, alpha: 255)
//    static let blue  = RGBA32(red: 0, green: 127, blue: 255, alpha: 255)
//    static let lightblue = RGBA32(red: 33, green: 255, blue: 255, alpha: 255)
//    static let brown = RGBA32(red: 127, green: 63, blue: 0, alpha: 255)
//}
//
//
//
//// https://stackoverflow.com/questions/33844130/take-a-snapshot-of-current-screen-with-metal-in-swift
//extension MTLTexture {
//    func bytes() -> UnsafeMutableRawPointer {
//        let width = self.width
//        let height   = self.height
//        let rowBytes = self.width * 4
//        let p = malloc(width * height * 4)
//
//        self.getBytes(p!, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
//
//        return p!
//    }
//
//    func toImage() -> CGImage? {
//        let p = bytes()
//
//        let pColorSpace = CGColorSpaceCreateDeviceRGB()
//
//        let rawBitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
//        let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: rawBitmapInfo)
//
//        let selftureSize = self.width * self.height * 4
//        let rowBytes = self.width * 4
//        let releaseMaskImagePixelData: CGDataProviderReleaseDataCallback = { (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in
//            return
//        }
//        let provider = CGDataProvider(dataInfo: nil, data: p, size: selftureSize, releaseData: releaseMaskImagePixelData)
//        let cgImageRef = CGImage(width: self.width, height: self.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes, space: pColorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)!
//
//        return cgImageRef
//    }
//
//
////    func john() -> NSImage? {
////        let colorSpace       = CGColorSpaceCreateDeviceRGB()
////        let width            = 50 // inputCGImage.width
////        let height           = 50 // inputCGImage.height
////        let bytesPerPixel    = 4
////        let bitsPerComponent = 8
////        let bytesPerRow      = bytesPerPixel * width
////        let bitmapInfo       = RGBA32.bitmapInfo
////
////        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
////            //print("unable to create context")
////            return nil
////        }
////
////       context.draw(CGLayer(), in: CGRect(x: 0, y: 0, width: width, height: height))
////
////        guard let buffer = context.data else {
////            //print("unable to get context data")
////            return nil
////        }
////
////        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)
////
//////        let white = RGBA32(red: 255, green: 255, blue: 255, alpha: 255)
//////        let clear = RGBA32(red: 0, green: 0, blue: 0, alpha: 0)
////
////        for row in 0 ..< Int(height) {
////            for column in 0 ..< Int(width) {
////                let offset = row * width + column
////                pixelBuffer[offset] = RGBA32(red: UInt8(row & 255), green: UInt8(column & 255), blue:0, alpha:255)
////            }
////        }
////
////        let outputCGImage = context.makeImage()!
////        let sz = NSSize(width:50, height:50)
////
////        let outputImage = NSImage(cgImage: outputCGImage, size:sz) // , scale: 1, orientation: 0) //image.imageOrientation)
//// //       ptr = NSImage(cgImage: outputCGImage, size:sz) // , scale: 1, orientation: 0) //image.imageOrientation)
//// //       ptr = outputImage
//////
////        return outputImage
////
////    }
//
//
////    // outputCGImage
////    func harry() -> CGImage {
////        var onePixel = m_RGBColor()
////        let width = 50
////        let height = 50
////        var pixelArray: [m_RGBColor] = [m_RGBColor]()
////
////        for y in 0 ..< height
////        {
////            for x in 0 ..< width
////            {
////                onePixel.Alpha = 255
////                onePixel.Red   = UInt8(x & 25)
////                onePixel.Green = UInt8(y & 255)
////                onePixel.Blue  = 255
////                pixelArray.append(onePixel)
////            }
////        }
////
////        let bitmapCount: Int = pixelArray.count
////        let elmentLength: Int = 4
////        let render: CGColorRenderingIntent = CGColorRenderingIntent.defaultIntent
////        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
////        let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
////        let providerRef: CGDataProvider? = CGDataProvider(data: NSData(bytes: &pixelArray, length: bitmapCount * elmentLength))
////        let cgimage: CGImage? = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * elmentLength, space: rgbColorSpace, bitmapInfo: bitmapInfo, provider: providerRef!, decode: nil, shouldInterpolate: true, intent: render)
////
////        return cgimage!
////    }
//
////    func toNSImage(_ sz:NSSize) -> NSImage? {
////        john(data[0].image.image!)  // harry()
////        //let sz = NSSize(width: i.width, height: i.height)
////        //return NSImage(cgImage:i, size:sz) //     toImage()!, size:sz)
////    }
//
////    func updateImage(_ ptr:NSImage?) {
////        john(ptr)
////    }
//
//}
//
//extension NSImageView {
//    func imageFromTexture(_ tt:MTLTexture) {
//        //image = tt.toNSImage(frame.size)!
//        //tt.updateImage(self.image)
//
//        let bundle = Bundle.main
//        let i = bundle.image(forResource: "grid.png")
//        image = i
//
//        image.
////        let sz = NSSize(width:50, height:50)
////        //var z = NSImage(cgImage:tt.harry(), size:sz) //     toImage()!, size:sz)
////        image = tt.john()
//    }
//
//    func paint() {
//        NSColor.red.set()
//
//            let path = NSBezierPath()
//            path.lineWidth = 2.0
//        path.move(to: NSPoint(x:0,y:0))
//        path.line(to: NSPoint(x:110,y:110))
//            path.stroke()
//
//    }
//
//    open override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        paint()
//        }
//}
//
//
//
//
//
//
//
//
//////////////////////////
//
////    func peekImage() {
////        let v1:NSImageView = data[10].image
////        let v2:NSImage = v1.image!
////        let v3:CGImage = v2.
////
//////        let provider = CGDataProvider(dataInfo: nil, data: p, size: selftureSize, releaseData: releaseMaskImagePixelData)
//////        let cgImageRef = CGImage(width: self.width, height: self.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes, space: pColorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)!
////
////
////        guard let cgImage:CGImage = data[10].image.image?.cgImage,
////            let data = cgImage.dataProvider?.data,
////            let bytes = CFDataGetBytePtr(data) else {
////            fatalError("Couldn't access image data")
////        }
////        assert(cgImage.colorSpace?.model == .rgb)
////
////        let bytesPerPixel = cgImage.bitsPerPixel / cgImage.bitsPerComponent
////        for y in 0 ..< cgImage.height {
////            for x in 0 ..< cgImage.width {
////                let offset = (y * cgImage.bytesPerRow) + (x * bytesPerPixel)
////                let components = (r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2])
////                print("[x:\(x), y:\(y)] \(components)")
////            }
////            print("---")
////        }
////
////    }
//
//class BaseNSViewMemory: NSView {
//    override var isFlipped: Bool { return true }
//    override var acceptsFirstResponder: Bool { return true }
//
//    override func draw(_ rect: NSRect) {
//        let c = CGFloat(0.3)
//        NSColor(red:c, green:c, blue:c + 0.1, alpha:1).set()
//        NSBezierPath(rect:bounds).fill()
//
//        var index = vcMemory.index-1; if index < 0 { index = MTOTAL-1 }
//        var r = data[index].image.frame.insetBy(dx: -2, dy: -2)
//        let context = NSGraphicsContext.current?.cgContext
//        context?.setLineWidth(4.0)
//        NSColor.red.set()
//        NSBezierPath(rect:r).stroke()
//
//        if vcMemory.focusIndex >= 0 {
//            index = vcMemory.focusIndex
//            r = data[index].image.frame.insetBy(dx: -2, dy: -2)
//            NSColor.yellow.set()
//            NSBezierPath(rect:r).stroke()
//        }
//    }
//}

