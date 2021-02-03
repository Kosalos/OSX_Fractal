import Cocoa
import Foundation
import MetalKit

var vc:ViewController! = nil
var winControl:NSWindowController! = nil
var videoRecorderWindow:NSWindowController! = nil
var controlBuffer:MTLBuffer! = nil
var coloringTexture:MTLTexture! = nil

var device: MTLDevice! = nil

class ViewController: NSViewController, NSWindowDelegate, MetalViewDelegate, WidgetDelegate {
    var control = Control()
    var widget:Widget! = nil
    var commandQueue: MTLCommandQueue?
    var pipeline:[MTLComputePipelineState] = []
    var threadsPerGroup:[MTLSize] = []
    var threadsPerGrid:[MTLSize] = []
    var isFullScreen:Bool = false
    var lightAngle:Float = 0
    var palletteIndex:Int = 0
    var texture:MTLTexture! = nil

    @IBOutlet var instructions: NSTextField!
    @IBOutlet var instructionsG: InstructionsG!
    @IBOutlet var metalView: MetalView!
    
    let PIPELINE_FRACTAL = 0
    let PIPELINE_NORMAL  = 1
    let PIPELINE_EFFECTS = 2
    let shaderNames = [ "rayMarchShader","normalShader","effectsShader" ]
    
    //MARK:
    
    override func viewDidLoad() {
        super.viewDidLoad()
        vc = self
        setControlPointer(&control)
    }
    
    override func viewDidAppear() {
        super.viewWillAppear()
        widget = Widget(self)
        instructionsG.initialize(widget)
        
        metalView.window?.delegate = self
        (metalView).delegate2 = self
        
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        //------------------------------
        let defaultLibrary:MTLLibrary! = device.makeDefaultLibrary()
        
        func loadShader(_ name:String) -> MTLComputePipelineState {
            do {
                guard let fn = defaultLibrary.makeFunction(name: name)  else { print("shader not found: " + name); exit(0) }
                return try device.makeComputePipelineState(function: fn)
            }
            catch { print("pipeline failure for : " + name); exit(0) }
        }
        
        for i in 0 ..< shaderNames.count {
            pipeline.append(loadShader(shaderNames[i]))
            threadsPerGroup.append(MTLSize()) // determined in updateThreadGroupsAccordingToWindowSize()
            threadsPerGrid.append(MTLSize())
        }
        //------------------------------
        
        controlBuffer = device.makeBuffer(length:MemoryLayout<Control>.stride, options:MTLResourceOptions.storageModeShared)
        
        control.equation = Int32(EQU_01_MANDELBULB)
        control.txtOnOff = false    // 'no texture'
        control.skip = 1            // "fast render" defaults to 'not active'
        control.isStereo = false
        control.parallax = 0.003
        
        reset()
        ensureWindowSizeIsNotTooSmall()
        
        resetAllLights()
//        showLightWindow()
//        showColorWindow()
        showControlWindow()
        
        winHandler = WindowHandler()
        winHandler.initialize()
        
        Timer.scheduledTimer(withTimeInterval:0.033, repeats:true) { timer in self.timerHandler() }
        
        helpIndex = 0
        // presentPopover("HelpVC")
        
        winHandler.cycleWindowFocus() // sets focus to main window
    }
    
    func showControlWindow() {
        if winControl == nil {
            let mainStoryboard = NSStoryboard.init(name: NSStoryboard.Name("Main"), bundle: nil)
            winControl = mainStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Control")) as? NSWindowController
        }
        
        winControl.showWindow(self)
    }

    //MARK: -
    
    var fastRenderEnabled:Bool = true
    var slowRenderCountDown:Int = 0
    
    /// direct shader to sparsely calculate, and copy results to neighboring pixels, for faster fractal rendering
    func setShaderToFastRender() {
        if fastRenderEnabled && control.skip == 1 {
            control.skip = max(control.xSize / 150, 8)
        }

        slowRenderCountDown = 20 // 30 = 1 second
    }
    
    /// direct 2D fractal view to re-calculate image on next draw call
    func flagViewToRecalcFractal() {
        metalView.viewIsDirty = true
    }
    
    /// ensure companion 3D window is also closed
    func windowWillClose(_ aNotification: Notification) {
        if let v = videoRecorderWindow { v.close() }
        
        winHandler.closeAllWindows()
        winControl.close()
    }
    
    //MARK: -
    
    @objc func timerHandler() {
        var isDirty:Bool = (vr != nil) && vr.isRecording
        
        if performJog() { isDirty = true }
        
        if control.skip > 1 && slowRenderCountDown > 0 {
            slowRenderCountDown -= 1
            if slowRenderCountDown == 0 {
                control.skip = 1
                isDirty = true
            }
        }
        
        // hold down jog keys cause increasing pixeation (hopefully to speed up shader)
        if control.skip > 1 && control.skip < 40 {
            control.skip += 1
        }
        
        if isDirty {
            flagViewToRecalcFractal()
        }
    }
    
    //MARK: -
    
    func toRectangular(_ sph:simd_float3) -> simd_float3 {
        let ss = sph.x * sin(sph.z);
        return simd_float3( ss * cos(sph.y), ss * sin(sph.y), sph.x * cos(sph.z))
    }
    
    func toSpherical(_ rec:simd_float3) -> simd_float3 { return simd_float3(length(rec), atan2(rec.y,rec.x), atan2(sqrt(rec.x*rec.x+rec.y*rec.y), rec.z)) }
    
    func updateShaderDirectionVector(_ v:simd_float3) {
        control.viewVector = normalize(v)
        control.topVector = toSpherical(control.viewVector)
        control.topVector.z += Float.pi / 2
        control.topVector = normalize(toRectangular(control.topVector))
        control.sideVector = cross(control.viewVector,control.topVector)
        control.sideVector = normalize(control.sideVector) * length(control.topVector)
    }
    
    /// window title displays fractal name and number, and name of focused widget
    let titleString:[String] =
        [ "MandelBulb","Apollonian2","Jos Leys Kleinian","MandelBox","Quaternion Julia",
          "Monster","Kali Tower","Gold","Spider","Knighty's Kleinian",
          "Half Tetrahedron","Knighty Polychora","3Dickulus Quaternion Julia","Spudsville","Flower Hive",
          "Pupukuusikkos Spiralbox", "SurfBox","TwistBox","Vertebrae", "DarkBeam Surfbox",
          "Klienian Sponge","Donuts","PDOF" ]
    
    func updateWindowTitle() {
        let index = Int(control.equation)
        view.window?.title = Int(index + 1).description + ": " + titleString[index] + " : " + widget.focusString()
    }
    
    /// reset widget focus index, update window title, recalc fractal.  Called after Load and LoadNext
    func controlJustLoaded() {
        defineWidgetsForCurrentEquation()
        widget.focus = 0
        updateWindowTitle()

        vcControl.refreshControlPanels()
        vcColor.defineWidgets()
        winHandler.refreshWidgetsAndImage()
    }
    
    /// load initial parameter values and view vectors for the current fractal (control.equation holds index)
    func reset() {
        updateShaderDirectionVector(simd_float3(0,0.1,1))
        control.bright = 1.1
        control.contrast = 0.5
        control.specular = 0
        control.angle1 = 0.1
        control.angle2 = 0.1
        control.radialAngle = 0
        control.InvCx = 0.1
        control.InvCy = 0.1
        control.InvCz = 0.1
        control.InvRadius = 0.3
        control.InvAngle = 0.1
        control.secondSurface = 0
        control.OrbitStrength = 0
        control.Cycles = 0
        control.orbitStyle = 0
        control.fog = 0
        control.LVIenable = false
        control.LVIiter = 5
        control.isteps = 5
        
        control.blurStrength = 0    // no blurring
        control.coloring1 = 0.9
        control.coloring2 = 0.9

        switch Int(control.equation) {
        case EQU_01_MANDELBULB :
            updateShaderDirectionVector(simd_float3(0.010000015, 0.41950363, 0.64503753))
            control.camera = simd_float3(0.038563743, -1.1381346, -1.8405379)
            control.cx = 80
            control.fx = 8
            control.isteps = 10
            
            if control.bcy {
                control.camera = simd_float3( -0.138822 , -1.4459486 , -1.9716375 )
                updateShaderDirectionVector(simd_float3( 0.012995179 , 0.54515165 , 0.8382366 ))
                control.InvCenter = simd_float3( -0.10600001 , -0.74200004 , -1.3880001 )
                control.InvRadius =  2.14
                control.InvAngle =  0.9100002
            }
            
        case EQU_02_APOLLONIAN2 :
            control.camera = simd_float3(0.42461035, 10.847559, 2.5749633)
            control.cy = 1.05265248
            control.cz = 1.06572711
            control.cw = 0.0202780124
            control.cx = 25
            control.isteps = 8
            
            if control.bcy {
                control.camera = simd_float3(-4.4953876, -6.3138175, -29.144863)
                updateShaderDirectionVector(simd_float3(0.0, 0.09950372, 0.9950372))
                control.cy =  1.0326525
                control.cz =  0.9399999
                control.cw =  0.01
                control.InvCx = 0.56
                control.InvCy = 0.34
                control.InvCz = 0.46000004
                control.InvRadius = 2.7199993
            }
        case EQU_03_KLEINIAN :
            control.camera = simd_float3(0.5586236, 1.1723881, -1.8257363)
            control.isteps = 70
            control.cx = 21
            control.cy = 17
            control.bcx = true
            control.bcz = false
            control.dz = 0.221299887
            control.dw = 0.00999999977
            control.cz = 0.6318979
            control.cw = 1.3839532
            control.dx = 1.9324
            control.dy = 0.04583
            control.InvCenter = simd_float3(1.0517285, 0.7155759, 0.9883028)
            control.InvAngle = 5.5392437
            control.InvRadius = 2.06132293
            
            if control.bcy {
                control.camera = simd_float3(-1.5613757, -0.61350304, 0.41508165)
                updateShaderDirectionVector(simd_float3(0.0, 0.09950372, 0.9950372))
                control.InvCx = -1.67399943
                control.InvCy = -0.494000345
                control.InvCz = 0.721998572
                control.InvAngle = 4.15921211
                control.InvRadius = 0.639999986
                control.cw = 0.38800019
                control.cz = 0.6880005
                control.dx = 1.97239995
                control.dy = 0.00999999977
                control.dz = 0.201299876
                control.dw = 0.00999999977
            }
        case EQU_04_MANDELBOX :
            control.camera = simd_float3(-1.3771019, 0.9999971, -5.037427)
            control.cx = 1.42
            control.cy = 2.997
            control.cz = 1.0099998
            control.cw = 0.02
            control.dx = 4.3978653
            control.isteps = 17
            control.juliaX =  0.0
            control.juliaY =  -6.0
            control.juliaZ =  -8.0
            control.bright = 1.3299997
            control.contrast = 0.3199999
            control.fx = 2.42
            control.juliaboxMode = true
            
            if control.bcy {
                control.camera = simd_float3( -1.4471021 , 0.23879418 , -4.3080645 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950371 , 0.99503714 ))
                control.InvCenter = simd_float3( -0.13600002 , 0.30600032 , 0.011999967 )
                control.InvRadius =  0.62999976
                control.InvAngle =  0.37999997
            }
        case EQU_05_QUATJULIA :
            control.camera = simd_float3(-0.010578117, -0.49170083, -2.4)
            control.cx = -1.74999952
            control.cy = -0.349999964
            control.cz = -0.0499999635
            control.cw = -0.0999999642
            control.isteps = 7
            control.contrast = 0.28
            control.specular = 0.9
            
            if control.bcy {
                control.camera = simd_float3( -0.010578117 , -0.49170083 , -2.4 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950371 , 0.99503714 ))
                control.InvCx =  0.098000005
                control.InvCy =  0.19999999
                control.InvCz =  -1.0519996
                control.InvRadius =  1.5200003
                control.InvAngle =  -0.29999992
            }
        case EQU_06_MONSTER :
            control.camera = simd_float3(0.0012031387, -0.106357165, -1.1865364)
            control.cx = 120
            control.cy = 4
            control.cz = 1
            control.cw = 1.3
            control.isteps = 10
            
            if control.bcy {
                control.camera = simd_float3( 0.0012031387 , -0.106357165 , -1.1865364 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.025999993
                control.InvCy =  -0.062000014
                control.InvCz =  -0.74199986
                control.InvRadius =  0.40999997
                control.InvAngle =  -0.8200002
            }
        case EQU_07_KALI_TOWER :
            control.camera = simd_float3(-0.051097937, 5.059899, -4.0350704)
            control.cx = 8.65
            control.cy = 1
            control.cz = 2.3
            control.cw = 0.13
            control.isteps = 2
            
            if control.bcy {
                control.camera = simd_float3( 0.06890213 , 4.266852 , -1.0111475 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.29999992
                control.InvCy =  3.6779976
                control.InvCz =  0.15800123
                control.InvRadius =  1.2900001
                control.InvAngle =  0.089999974
            }
        case EQU_08_GOLD :
            updateShaderDirectionVector(simd_float3(0.010000015, 0.41950363, 0.64503753))
            control.camera = simd_float3(0.038563743, -1.1381346, -1.8405379)
            control.cx = -0.09001912
            control.cy = 0.43999988
            control.cz = 1.0499994
            control.cw = 1
            control.dx = 0
            control.dy = 0.6
            control.dz = 0
            control.isteps = 15
            
            if control.bcy {
                control.camera = simd_float3( 0.042072453 , -0.99094355 , -1.6142143 )
                updateShaderDirectionVector(simd_float3( 0.012995181 , 0.54515177 , 0.83823675 ))
                control.InvCx =  0.036
                control.InvCy =  0.092000015
                control.InvCz =  -0.15200002
                control.InvRadius =  0.17999996
                control.InvAngle =  -0.25999996
            }
        case EQU_09_SPIDER :
            control.camera = simd_float3(0.04676684, -0.50068825, -3.4419205)
            control.cx = 0.13099998
            control.cy = 0.21100003
            control.cz = 0.041
            
            if control.bcy {
                control.camera = simd_float3( 0.04676684 , -0.46387178 , -3.0737557 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.28600028
                control.InvCy =  0.18000007
                control.InvCz =  -0.07799993
                control.InvRadius =  0.13
                control.InvAngle =  -0.079999976
            }
        case EQU_10_KLEINIAN2 :
            control.camera = simd_float3(4.1487565, 2.6955016, 1.3862593)
            control.cx = -0.7821867
            control.cy = -0.5424057
            control.cz = -0.4748369
            control.cw = 0.7999992
            control.dx = 0.5
            control.dy = 1.3
            control.dz = 1.5499997
            control.dw = 0.9000002
            control.fx = 1
            
            if control.bcy {
                control.camera = simd_float3( 4.1487565 , 2.6955016 , 1.3862593 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  -0.092
                control.InvCy =  0.01999999
                control.InvCz =  -0.47600016
                control.InvRadius =  4.2999983
                control.InvAngle =  0.13000003
            }
        case EQU_11_HALF_TETRA :
            control.camera = simd_float3(-0.023862544, -0.113349974, -0.90810966)
            control.cx = 1.2040006
            control.cy = 9.236022
            control.angle1 = -3.9415956
            control.angle2 = 0.79159856
            control.isteps = 53
            
            if control.bcy {
                control.camera = simd_float3( 0.13613744 , 0.07272194 , -0.85636866 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.07199999
                control.InvCy =  0.070000015
                control.InvCz =  0.037999995
                control.InvRadius =  0.33999994
                control.InvAngle =  0.44
            }
        case EQU_12_POLYCHORA :
            control.camera = simd_float3(-0.00100744, -0.16238609, -1.7581517)
            control.cx = 5.0
            control.cy = 1.3159994
            control.cz = 2.5439987
            control.cw = 4.5200005
            control.dx = 0.08000006
            control.dy = 0.008000016
            control.dz = -1.5999997
            
            if control.bcy {
                control.camera = simd_float3( 0.54899234 , -0.03701113 , -0.7053995 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.5320001
                control.InvCy =  0.012000054
                control.InvCz =  -0.023999948
                control.InvRadius =  0.36999995
                control.InvAngle =  0.15
            }
        case EQU_13_QUATJULIA2 :
            control.camera = simd_float3(-0.010578117, -0.49170083, -2.4)
            control.cx = -1.7499995
            control.isteps = 7
            control.bright = 0.5
            control.juliaX =  0.0
            control.juliaY =  0.0
            control.juliaZ =  0.0
            control.bright = 0.9000001
            
            if control.bcy {
                control.camera = simd_float3( -0.010578117 , -0.49170083 , -2.4 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.1
                control.InvCy =  0.006000016
                control.InvCz =  -0.072
                control.InvRadius =  0.51
                control.InvAngle =  0.1
            }
        case EQU_14_SPUDS :
            control.camera = simd_float3(0.98336715, -1.2565054, -3.960955)
            control.cx = 3.7524672
            control.cy = 1.0099992
            control.cz = -1.0059854
            control.cw = -1.0534152
            control.dx = 1.1883448
            control.dz = -4.100001
            control.dw = -3.2119942
            control.isteps = 8
            control.bright = 0.92
            control.fx = 3.2999988
            
            if control.bcy {
                control.camera = simd_float3( 0.18336754 , -0.29131955 , -4.057477 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  -0.544
                control.InvCy =  -0.18200001
                control.InvCz =  -0.44799998
                control.InvRadius =  1.3700002
                control.InvAngle =  0.1
            }
        case EQU_15_FLOWER :
            control.camera = simd_float3(-0.16991696, -2.5964863, -12.54011)
            control.cx = 1.6740334
            control.cy = 2.1570902
            control.isteps = 10
            control.juliaX =  6.0999966
            control.juliaY =  13.999996
            control.juliaZ =  3.0999992
            control.bright = 1.5000001
            
            if control.bcy {
                control.camera = simd_float3( -0.16991696 , -2.5964863 , -12.54011 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.03800006
                control.InvCy =  0.162
                control.InvCz =  0.11799997
                control.InvRadius =  0.7099998
                control.InvAngle =  0.18000002
            }
        case EQU_16_SPIRALBOX :
            control.camera = simd_float3(0.047575176, -0.122939646, 1.5686907)
            control.cx = 0.8810008
            control.juliaX =  1.9000009
            control.juliaY =  1.0999998
            control.juliaZ =  0.19999993
            control.isteps = 9
            
            if control.bcy {
                control.camera = simd_float3( 0.047575176 , -0.122939646 , 1.5686907 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.1
                control.InvCy =  0.07600006
                control.InvCz =  -0.46800002
                control.InvRadius =  2.31
                control.InvAngle =  0.1
            }
        case EQU_17_SURFBOX :
            control.camera = simd_float3(-0.37710285, 0.4399976, -5.937426)
            control.cx = 1.4199952
            control.cy = 4.1000023
            control.cz = 1.2099996
            control.cw = 0.0
            control.dx = 4.3978653
            control.isteps = 17
            control.juliaX =  -0.6800002
            control.juliaY =  -4.779989
            control.juliaZ =  -7.2700005
            control.bright = 1.01
            control.contrast = 0.5
            control.fx = 2.5600004
            control.juliaboxMode = true
            
            if control.bcy {
                control.camera = simd_float3( -0.37710285 , 0.4399976 , -5.937426 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.10799999
                control.InvCy =  0.19999999
                control.InvCz =  0.1
                control.InvRadius =  0.47000003
                control.InvAngle =  -0.15999997
            }
        case EQU_18_TWISTBOX :
            control.camera = simd_float3(0.24289839, -2.1800025, -9.257425)
            control.cx = 1.5611011
            control.isteps = 24
            control.juliaX =  3.2779012
            control.juliaY =  -3.0104024
            control.juliaZ =  -3.2913034
            control.bright = 1.4100001
            control.contrast = 0.3399999
            control.fx = 8.21999
            
            if control.bcy {
                control.camera = simd_float3( 0.23289838 , 0.048880175 , -1.2394277 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.068000056
                control.InvCy =  0.1
                control.InvCz =  0.029999983
                control.InvRadius =  0.24000005
                control.InvAngle =  -0.7099997
            }
        case EQU_19_VERTEBRAE :
            control.camera = simd_float3(0.5029001, -1.3100017, -9.947422)
            control.cx = 5.599995
            control.cy = 8.699999
            control.cz = -3.6499987
            control.cw = 0.089999855
            control.dx = 1.0324188
            control.dy = 9.1799965
            control.dz = -0.68002427
            control.dw = 1.439993
            control.ex = -0.6299968
            control.ey = 2.0999985
            control.ez = -4.026443
            control.ew = -4.6699996
            control.fx = -9.259983
            control.fy = 0.8925451
            control.fz = -0.0112106
            control.fw = 2.666039
            control.isteps = 2
            control.bright = 1.47
            control.contrast = 0.22000006
            control.specular = 2.0
            
            if control.bcy {
                control.camera = simd_float3( 1.0229 , -1.1866168 , -8.713577 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  -0.9600001
                control.InvCy =  -0.5200006
                control.InvCz =  -3.583999
                control.InvRadius =  4.01
                control.InvAngle =  3.1000001
            }
        case EQU_20_DARKSURF :
            control.camera = simd_float3(-0.4870995, -1.9200011, -1.7574148)
            control.cx = 7.1999893
            control.cy = 0.34999707
            control.cz = -4.549979
            control.dx = 0
            control.dy = 0.549999
            control.dz = 0.88503367
            control.ex = 0.99998015
            control.ey = 1.8999794
            control.ez = 3.3499994
            control.isteps = 10
            control.angle1 = -1.5399991
            control.bright = 1.0
            control.contrast = 0.5
            control.specular = 0.0
            
            if control.bcy {
                control.camera = simd_float3( -0.10709968 , -0.06923248 , -1.9424983 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.068000056
                control.InvCy =  0.10799999
                control.InvCz =  0.09400001
                control.InvRadius =  0.13999999
                control.InvAngle =  -0.95000005
            }
        case EQU_21_SPONGE :
            control.camera = simd_float3(0.7610872, -0.7994865, -3.8773263)
            control.cx = -0.8064072
            control.cy = -0.74000216
            control.cz = -1.0899884
            control.cw = 1.2787694
            control.dx = 0.26409245
            control.dy = -0.76119435
            control.dz = 0.2899983
            control.dw = 0.27301705
            control.ex = 6
            control.ey = -6
            control.isteps = 3
            control.bright = 2.31
            control.contrast = 0.17999999
            control.specular = 0.3
            
            if control.bcy {
                control.camera = simd_float3( 0.25108737 , -0.9736173 , -2.603676 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950372 , 0.9950372 ))
                control.InvCx =  0.35200006
                control.InvCy =  0.009999977
                control.InvCz =  -0.092
                control.InvRadius =  1.0600003
                control.InvAngle =  -0.019999992
            }
        case EQU_22_DONUTS :
            control.camera = simd_float3(-0.2254057, -7.728364, -19.269318)
            control.cx = 7.9931593
            control.cy = 0.35945648
            control.cz = 2.8700645
            control.dx = 0.0
            control.dy = 0.0
            control.isteps = 4
            control.bright = 1.0100001
            control.contrast = 0.36000004
            control.specular = 1.2000002
            updateShaderDirectionVector( simd_float3(-2.0272768e-08, 0.46378687, 0.89157283) )
            
            if control.bcy {
                control.camera = simd_float3( -0.2254057 , -7.728364 , -19.269318 )
                updateShaderDirectionVector(simd_float3( -2.0172154e-08 , 0.4614851 , 0.8871479 ))
                control.InvCx =  -1.8719988
                control.InvCy =  -4.1039987
                control.InvCz =  -1.367999
                control.InvRadius =  7.589995
                control.InvAngle =  -2.7999995
            }
        case EQU_23_PDOF :
            control.camera = simd_float3(-0.1589123, -0.17758754, -2.984771)
            updateShaderDirectionVector(simd_float3(0.0, 0.09950372, 0.9950372))
            control.isteps = 15
            control.cx = 0.94000006
            control.cy = 0.42999986
            control.cz = -0.42000043
            control.cw = 0.0010999999
            control.juliaboxMode = true
            control.juliaX =  0.109999985
            control.juliaY =  0.11999998
            control.juliaZ =  -0.55999994
            
            if control.bcy {
                control.camera = simd_float3( -0.1589123 , -0.4561975 , -1.5499284 )
                updateShaderDirectionVector(simd_float3( 0.0 , 0.09950371 , 0.99503714 ))
                control.InvCx =  0.07000005
                control.InvCy =  0.1
                control.InvCz =  0.1
                control.InvRadius =  0.3
                control.InvAngle =  0.1
            }
        default : break
        }
        
        defineWidgetsForCurrentEquation()
        if vcControl != nil { vcControl.checkAllWidgetIndices() }
        updateWindowTitle()
    }
    
    var timeInterval:Double = 0.1
    
    //MARK: -
    //MARK: -
    //MARK: -
    
    /// call shader to update 2D fractal window(s), and 3D vertex data
    func computeTexture(_ drawable:CAMetalDrawable) {
        // this appears to stop beachball delays if I cause key roll-over?
        Thread.sleep(forTimeInterval: timeInterval)
        
        var c = control
        
        func prepareJulia() { c.julia = simd_float3(control.juliaX,control.juliaY,control.juliaZ) }
        
        c.light = c.camera + simd_float3(sin(lightAngle)*100,cos(lightAngle)*100,-100)
        c.nlight = normalize(c.light)
        
        c.InvCenter = simd_float3(c.InvCx, c.InvCy, c.InvCz)
        encodeWidgetDataForAllLights()
        
        //-----------------------------------------------
        let colMap = [ colorMap1,colorMap2,colorMap3,colorMap4 ]
        
        func getColor(_ fIndex:Float, _ weight:Float) -> simd_float4 {
            let cm = colMap[palletteIndex]
            let index = max(Int(fIndex),4)  // 1st 4 entries are black
            let cc = cm[index]
            
            return simd_float4(cc.x,cc.y,cc.z,weight)
        }
        
        c.X = getColor(control.xIndex,control.xWeight)
        c.Y = getColor(control.yIndex,control.yWeight)
        c.Z = getColor(control.zIndex,control.zWeight)
        c.R = getColor(control.rIndex,control.rWeight)
        //-----------------------------------------------
        
        prepareJulia()
        control.otFixed = simd_float3(control.otFixedX,control.otFixedY,control.otFixedZ)
        
        switch Int(control.equation) {
        case EQU_06_MONSTER :
            c.mm[0][0] = 99   // mark as needing calculation in shader
        case EQU_10_KLEINIAN2, EQU_21_SPONGE :
            c.v4a = simd_float4(control.cx,control.cy,control.cz,control.cw);
            c.v4b = simd_float4(control.dx,control.dy,control.dz,control.dw);
        case EQU_11_HALF_TETRA :
            c.v3a = normalize(simd_float3(-control.cz,control.cy-control.cz,1.0/control.cy-control.cz))
        case EQU_12_POLYCHORA :
            let pabc:simd_float4 = simd_float4(0,0,0,1)
            let pbdc:simd_float4 = 1.0/sqrt(2) * simd_float4(1,0,0,1)
            let pcda:simd_float4 = 1.0/sqrt(2) * simd_float4(0,1,0,1)
            let pdba:simd_float4 = 1.0/sqrt(2) * simd_float4(0,0,1,1)
            let aa = c.cx * pabc
            let bb = c.cy * pbdc
            let cc = c.cz * pcda
            let dd = c.cw * pdba
            c.v4b = normalize(aa + bb + cc + dd)
            c.ex = cos(c.dx)
            c.ey = sin(c.dx)
            c.ez = cos(c.dy)
            c.ew = sin(c.dy)
            c.fx = cos(c.dz)
            c.fy = sin(c.dz)
            c.v4a = simd_float4(-0.5,-0.5,-0.5,0.5)
        case EQU_17_SURFBOX :
            c.dx = c.cx * c.cy  // foldMod
        case EQU_20_DARKSURF :
            c.v3a = simd_float3(c.dx,c.dy,c.dz)
            c.v3b = simd_float3(c.ex,c.ey,c.ez)
            c.v3c = simd_float3(c.fx,c.fy,c.fz)
        default : break
        }
        
        prepareJulia()

        if let vr = vr { if vr.isRecording { c.skip = 1 }}  // editing params while recording was causing 'blocky fast renders' to be recorded
        
        controlBuffer.contents().copyMemory(from:&c, byteCount:MemoryLayout<Control>.stride)
        
        let start = NSDate()
        
        if c.blurStrength == 0 {    // NO blurring
            if true {
                let commandBuffer = commandQueue?.makeCommandBuffer()!
                let renderEncoder = commandBuffer!.makeComputeCommandEncoder()!
                renderEncoder.setComputePipelineState(pipeline[PIPELINE_FRACTAL])
                renderEncoder.setTexture(drawable.texture, index: 0)
                renderEncoder.setTexture(coloringTexture,  index: 1)
                renderEncoder.setBuffer(controlBuffer, offset: 0, index: 0)
                renderEncoder.dispatchThreads(threadsPerGrid[PIPELINE_FRACTAL], threadsPerThreadgroup:threadsPerGroup[PIPELINE_FRACTAL])
                renderEncoder.endEncoding()
                commandBuffer?.present(drawable)
                commandBuffer?.commit()
                commandBuffer?.waitUntilCompleted()
            }
        }
        else {  // blurring
            if true {
                let commandBuffer = commandQueue?.makeCommandBuffer()!
                let renderEncoder = commandBuffer!.makeComputeCommandEncoder()!
                renderEncoder.setComputePipelineState(pipeline[PIPELINE_FRACTAL])
                renderEncoder.setTexture(texture, index: 0)
                renderEncoder.setTexture(coloringTexture,  index: 1)
                renderEncoder.setBuffer(controlBuffer, offset: 0, index: 0)
                renderEncoder.dispatchThreads(threadsPerGrid[PIPELINE_FRACTAL], threadsPerThreadgroup:threadsPerGroup[PIPELINE_FRACTAL])
                renderEncoder.endEncoding()
                commandBuffer?.commit()
                commandBuffer?.waitUntilCompleted()
            }
            if true {
                let commandBuffer = commandQueue?.makeCommandBuffer()!
                let renderEncoder = commandBuffer!.makeComputeCommandEncoder()!
                renderEncoder.setComputePipelineState(pipeline[PIPELINE_EFFECTS])
                renderEncoder.setTexture(texture, index: 0)
                renderEncoder.setTexture(drawable.texture,  index: 1)
                renderEncoder.setBuffer(controlBuffer, offset: 0, index: 0)
                renderEncoder.dispatchThreads(threadsPerGrid[PIPELINE_FRACTAL], threadsPerThreadgroup:threadsPerGroup[PIPELINE_FRACTAL])
                renderEncoder.endEncoding()
                
                commandBuffer?.present(drawable)
                commandBuffer?.commit()
                commandBuffer?.waitUntilCompleted()
            }
        }
        
        if control.skip > 1 {   // 'fast' renders will have ~50% utilization
            timeInterval = NSDate().timeIntervalSince(start as Date)
        }
        
        if let vr = vr { vr.saveVideoFrame(drawable.texture) }
        instructionsG.refresh()
    }
    
    //MARK: -
    //MARK: -
    //MARK: -
    
    func toggleInversion() {
        control.bcy = !control.bcy
        defineWidgetsForCurrentEquation()
        reset()
        flagViewToRecalcFractal()
    }
    
    //MARK: -
    
    var pt1 = NSPoint()
    var pt2 = NSPoint()
    
    override func mouseDown(with event: NSEvent) { pt1 = event.locationInWindow }
    override func rightMouseDown(with event: NSEvent) { pt1 = event.locationInWindow }
    
    func mouseDrag2DImage(_ rightMouse:Bool) {
        var dx:Int = 0
        var dy:Int = 0
        let px = pt2.x - pt1.x
        let py = pt2.y - pt1.y
        if abs(px) > 4 { if px > 0 { dx = 1 } else if px < 0 { dx = -1 }}
        if abs(py) > 4 { if py > 0 { dy = 1 } else if py < 0 { dy = -1 }}
        alterationSpeed = -3
        
        if !rightMouse {
            if instructionsG.isHidden || pt1.x > 75 { // not if over the instructions panel
                jogCameraAndFocusPosition(dx,dy,0)
            }
        }
        else {
            jogCameraAndFocusPosition(dx,0,dy)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        pt2 = event.locationInWindow
        mouseDrag2DImage(false)
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        pt2 = event.locationInWindow
        mouseDrag2DImage(true)
    }
    
    var control2 = Control()
    
    override func mouseUp(with event: NSEvent) { jogRelease(1,1,1) }
    override func rightMouseUp(with event: NSEvent) { jogRelease(1,1,1) }
    
    //MARK: -
    
    func presentPopover(_ name:String) {
        let mvc = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let vc = mvc.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(name)) as! NSViewController
        self.present(vc, asPopoverRelativeTo: view.bounds, of: view, preferredEdge: .minX, behavior: .semitransient) 
    }
    
    var ctrlKeyDown:Bool = false
    var optionKeyDown:Bool = false
    var cmdKeyDown:Bool = false

    func updateModifierKeyFlags(_ ev:NSEvent) {
        let rv = ev.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        ctrlKeyDown     = rv & (1 << 18) != 0
        optionKeyDown   = rv & (1 << 19) != 0
        cmdKeyDown      = rv & (1 << 20) != 0
    }
    
    override func keyDown(with event: NSEvent) {
        func toggle2() {
            defineWidgetsForCurrentEquation()
            flagViewToRecalcFractal()
        }
        
        updateModifierKeyFlags(event)
        widget.updateAlterationSpeed(event)
        
        if widget.keyPress(event) {
            setShaderToFastRender()
            return
        }
        
        switch Int32(event.keyCode) {
        case HOME_KEY :
            presentPopover("SaveLoadVC")
            return
        case PAGE_UP :
            if !isHelpVisible {
                helpIndex = 0
                presentPopover("HelpVC")
            }
            return
        case END_KEY :
            let s = SaveLoadViewController()
            s.loadNext()
            controlJustLoaded()
            return
        default : break
        }
        
        if cmdKeyDown {
        switch event.charactersIgnoringModifiers!.uppercased() {
        case "1" : winHandler.setWindowFocus(0)
        case "2" : winHandler.setWindowFocus(1)
        case "3" : winHandler.setWindowFocus(2)
        case "4" : winHandler.setWindowFocus(3)
        default : break
            }
            return
        }
        
        switch event.charactersIgnoringModifiers!.uppercased() {
        case "O" :
            presentPopover("EquationPickerVC")
            return

        case "0" :
            view.window?.toggleFullScreen(self)
            isFullScreen = !isFullScreen
            updateLayoutOfChildViews()
        case "1" : changeEquationIndex(-1)
        case "2" : changeEquationIndex(+1)
        case "3" :
            control.isStereo = !control.isStereo
            adjustWindowSizeForStereo()
            defineWidgetsForCurrentEquation()
            flagViewToRecalcFractal()
        case "4","$" : jogCameraAndFocusPosition(-1,0,0)
        case "5","%" : jogCameraAndFocusPosition(+1,0,0)
        case "6","^" : jogCameraAndFocusPosition(0,-1,0)
        case "7","&" : jogCameraAndFocusPosition(0,+1,0)
        case "8","*" : jogCameraAndFocusPosition(0,0,-1)
        case "9","(" : jogCameraAndFocusPosition(0,0,+1)
        case "?","/" : fastRenderEnabled = !fastRenderEnabled
            
        case "C" :
            palletteIndex += 1
            if(palletteIndex > 3) { palletteIndex = 0 }
            flagViewToRecalcFractal()
            
        case "B" : control.bcx = !control.bcx; toggle2()
        case "F" : control.bcz = !control.bcz; toggle2()
        case "K" : control.bcx = !control.bcx; toggle2()
        case "P" :
            if control.txtOnOff {
                control.txtOnOff = false
                defineWidgetsForCurrentEquation()
                flagViewToRecalcFractal()
            }
            else {
                loadImageFile()
            }
            
        case " " :
            instructions.isHidden = !instructions.isHidden
            instructionsG.isHidden = !instructionsG.isHidden
        case "H" : setControlParametersToRandomValues(); flagViewToRecalcFractal()
        case "V" : displayControlParametersInConsoleWindow()
        case "Q" :
            control.bcx = !control.bcx
            control.bcw = !control.bcw
            toggle2()
        case "W" :
            control.bcy = !control.bcy
            control.bdx = !control.bdx
            toggle2()
        case "E" :
            control.bcz = !control.bcz
            control.bdy = !control.bdy
            toggle2()
        case "R" :
            control.bcw = !control.bcw
            control.bdz = !control.bdz
            toggle2()
        case "T" :
            control.bdx = !control.bdx
            control.bdw = !control.bdw
            toggle2()
        case "Y" :
            control.bdy = !control.bdy
            control.bex = !control.bex
            toggle2()
        case "U" :
            control.bdz = !control.bdz
            control.bey = !control.bey
            toggle2()
        case "G" :
            control.colorScheme += 1
            if control.colorScheme > 6 { control.colorScheme = 0 }
            defineWidgetsForCurrentEquation()
            vcColor.defineWidgets()
            flagViewToRecalcFractal()
        case "L" :
            winHandler.cycleWindowFocus()
        case ",","<" : adjustWindowSize(-1)
        case ".",">" : adjustWindowSize(+1)
        case "[" : launchVideoRecorder()
        case "]" : if let vr = vr { vr.addKeyFrame() }
            
        case "Z" :
            control.LVIenable = !control.LVIenable; toggle2()

        default : break
        }
    }
    
    override func keyUp(with event: NSEvent) {
        super.keyUp(with: event)
        
        switch event.charactersIgnoringModifiers!.uppercased() {
        case "4","$","5","%" : jogRelease(1,0,0)
        case "6","^","7","&" : jogRelease(0,1,0)
        case "8","*","9","(" : jogRelease(0,0,1)
        default : break
        }
    }
    
    /// update 2D fractal camera position
    
    var jogAmount:simd_float3 = simd_float3()
    
    func jogCameraAndFocusPosition(_ dx:Int, _ dy:Int, _ dz:Int) {
        if dx != 0 { jogAmount.x = Float(dx) * alterationSpeed * 0.01 }
        if dy != 0 { jogAmount.y = Float(dy) * alterationSpeed * 0.01 }
        if dz != 0 { jogAmount.z = Float(dz) * alterationSpeed * 0.01 }
    }
    
    func jogRelease(_ dx:Int, _ dy:Int, _ dz:Int) {
        if dx != 0 { jogAmount.x = 0 }
        if dy != 0 { jogAmount.y = 0 }
        if dz != 0 { jogAmount.z = 0 }
    }
    
    func performJog() -> Bool {
        if jogAmount.x == 0 && jogAmount.y == 0 && jogAmount.z == 0 { return false}
        
        if ctrlKeyDown {
            updateShaderDirectionVector(control.viewVector + jogAmount)
        }
        else {
            control.camera += jogAmount.x * control.sideVector
            control.camera += jogAmount.y * control.topVector
            control.camera += jogAmount.z * control.viewVector
        }
        
        setShaderToFastRender()
        return true
    }
    
    /// toggle display of video recorder window
    func launchVideoRecorder() {
        if videoRecorderWindow == nil {
            let mainStoryboard = NSStoryboard.init(name: NSStoryboard.Name("Main"), bundle: nil)
            videoRecorderWindow = mainStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("VideoRecorder")) as? NSWindowController
            videoRecorderWindow.showWindow(self)
        }
        
        videoRecorderWindow.showWindow(self)
    }
    
    /// press 'V' to display control parameter values in console window
    func displayControlParametersInConsoleWindow() {
        print("camera =",control.camera.debugDescription)
        print("viewVector = ",control.viewVector.debugDescription)
        print("topVector = ",control.topVector.debugDescription)
        print("sideVector = ",control.sideVector.debugDescription)
        print("cx = ",control.cx)
        print("cy = ",control.cy)
        print("cz = ",control.cz)
        print("cw = ",control.cw)
        print("InvCenter = ",control.InvCx,",",control.InvCy,",",control.InvCz)
        print("InvRadius = ",control.InvRadius)
        print(" ")
        print("control.cx =",control.cx)
        print("control.cy =",control.cy)
        print("control.cz =",control.cz)
        print("control.cw =",control.cw)
        print("control.dx =",control.dx)
        print("control.dy =",control.dy)
        print("control.dz =",control.dz)
        print("control.dw =",control.dw)
        print("control.ex =",control.ex)
        print("control.ey =",control.ey)
        print("control.ez =",control.ez)
        print("control.ew =",control.ew)
        print("control.fx =",control.fx)
        print("control.fy =",control.fy)
        print("control.fz =",control.fz)
        print("control.fw =",control.fw)
        
        print("control.isteps =",control.isteps)
        
        print("control.angle1 =",control.angle1)
        print("control.angle2 =",control.angle2)
        print("control.juliaX = ",control.juliaX)
        print("control.juliaY = ",control.juliaY)
        print("control.juliaZ = ",control.juliaZ)
        print("control.fx =",control.fx)
        
        print("control.bright =",control.bright)
        print("control.contrast =",control.contrast)
        print("control.specular =",control.specular)
        
        print("updateShaderDirectionVector(",control.viewVector.debugDescription,")")

        
        print("control.icx =",control.cx)
        print("control.icy =",control.cy)
        print("control.dz =",control.dz)
        print("control.dw =",control.dw)
        print("control.dx =",control.dx)
        print("control.dy =",control.dy)
        print("control.cw =",control.cw)
        print("control.cz =",control.cz)
        
        print("radial symmetry =",control.radialAngle)

//        int icx;
//        int icy;
//        int isteps;
//        
//        float cx;
//        float cy;
//        float isteps;
//        bool bcx;
//        bool bcy;
//        bool bcz;
//        
//        float dz;
//        float dw;
//        float cw;
//        float cz;
//        
//        float dx;
//        float dy;
        
        //----------------------------------
        print(" ")
        print("if control.bcy {")
        print("    control.camera = simd_float3(",control.camera.x,",",control.camera.y,",",control.camera.z,")")
        print("    updateShaderDirectionVector(simd_float3(",control.viewVector.x,",",control.viewVector.y,",",control.viewVector.z,"))")
        print("    control.InvCx = ",control.InvCx)
        print("    control.InvCy = ",control.InvCy)
        print("    control.InvCz = ",control.InvCz)
        print("    control.InvRadius = ",control.InvRadius)
        print("    control.InvAngle = ",control.InvAngle)
        print("}")
    }
    
    /// press 'H" to set control parameters to random values
    func setControlParametersToRandomValues() {
        func fRandom() -> Float { return Float.random(in: -1 ..< 0) }
        func fRandom2() -> Float { return Float.random(in: 0 ..< 1) }
        func fRandom3() -> Float { return Float.random(in: -5 ..< 5) }
        
        //control.camera.x = Float.random(in: -2 ..< 2)
        //control.camera.y = Float.random(in: -2 ..< 2)
        //control.camera.z = Float.random(in: -2 ..< 2)
        control.cx = fRandom3()
        control.cy = fRandom3()
        control.cz = fRandom3()
        control.cw = fRandom3()
        control.dx = fRandom3()
        control.dy = fRandom3()
        control.dz = fRandom3()
        control.dw = fRandom3()
        control.ex = fRandom3()
        control.ey = fRandom3()
        control.ez = fRandom3()
        control.ew = fRandom3()
        control.fx = fRandom3()
        control.fy = fRandom3()
        control.fz = fRandom3()
        control.fw = fRandom3()
    }
    
    //MARK: -
    
    /// alter equation selection, reset it's parameters, display it's widgets, calculate fractal
    func changeEquationIndex(_ dir:Int) {
        control.equation += Int32(dir)
        if control.equation >= EQU_MAX { control.equation = 0 } else
            if control.equation < 0 { control.equation = Int32(EQU_MAX - 1) }
        reset()
        defineWidgetsForCurrentEquation()
        flagViewToRecalcFractal()
    }
    
    /// define widget entries for current equation
    func defineWidgetsForCurrentEquation() {
        func juliaGroup(_ range:Float = 10, _ delta:Float = 1) {
            widget.addBoolean("Julia Mode",&control.juliaboxMode,3)
            
            if control.juliaboxMode {
                widget.addFloat("  X",&control.juliaX,-range,range, delta)
                widget.addFloat("  Y",&control.juliaY,-range,range, delta)
                widget.addFloat("  Z",&control.juliaZ,-range,range, delta)
            }
        }
        
        widget.reset()
        
        if control.isStereo { widget.addFloat("Parallax",&control.parallax,0.001,1,0.01) }
//        widget.addFloat("Bright",&control.bright,0.01,10,0.02)
//        
//        widget.addFloat("Enhance",&control.enhance,0,30,0.03)
//        widget.addFloat("Contrast",&control.contrast,0.1,0.7,0.02)
//        widget.addFloat("Specular",&control.specular,0,2,0.1)
//        widget.addFloat("Light Position",&lightAngle,-3,3,0.3)
        
        switch Int(control.equation) {
        case EQU_01_MANDELBULB :
            widget.addInt32("Iterations",&control.isteps,3,30,1)
            widget.addFloat("Power",&control.fx,1.5,12,0.02)
        case EQU_02_APOLLONIAN2 :
            widget.addInt32("Iterations",&control.isteps,2,10,1)
            widget.addFloat("Multiplier",&control.cx,10,300,0.2)
            widget.addFloat("Foam",&control.cy,0.1,3,0.02)
            widget.addFloat("Foam2",&control.cz,0.1,3,0.02)
            widget.addFloat("Bend",&control.cw,0.01,0.03,0.0001)
        case EQU_03_KLEINIAN :
            widget.addInt32("Final Iterations",&control.icx, 1,69,1)
            widget.addInt32("Box Iterations",&control.icy,1,40,1)
            widget.addFloat("Box Size X",&control.cz, 0.01,2,0.006)
            widget.addFloat("Box Size Z",&control.cw, 0.01,2,0.006)
            widget.addFloat("Klein R",&control.dx, 0.001,2.5,0.005)
            widget.addFloat("Klein I",&control.dy, 0.001,2.5,0.005)
            widget.addFloat("Clamp Y",&control.dz, 0.001,2,0.01)
            widget.addFloat("Clamp DF",&control.dw, 0.001,2,0.03)
            widget.addBoolean("B: ShowBalls",&control.bcx)
            widget.addBoolean("F: FourGen",&control.bcz)
        case EQU_04_MANDELBOX :
            widget.addInt32("Iterations",&control.isteps,3,60,1)
            widget.addFloat("Scale Factor",&control.fx,0.6,10,0.04)
            widget.addFloat("Box",&control.cx, 0,10,0.02)
            widget.addFloat("Sphere 1",&control.cz, 0,4,0.02)
            widget.addFloat("Sphere 2",&control.cw, 0,4,0.02)
            juliaGroup(10,0.01)
        case EQU_05_QUATJULIA :
            widget.addInt32("Iterations",&control.isteps,3,10,1)
            widget.addFloat("X",&control.cx,-5,5,0.05)
            widget.addFloat("Y",&control.cy,-5,5,0.05)
            widget.addFloat("Z",&control.cz,-5,5,0.05)
            widget.addFloat("W",&control.cw,-5,5,0.05)
        case EQU_06_MONSTER :
            widget.addInt32("Iterations",&control.isteps,3,30,1)
            widget.addFloat("X",&control.cx,-500,500,0.5)
            widget.addFloat("Y",&control.cy,3.5,7,0.1)
            widget.addFloat("Z",&control.cz,0.45,2.8,0.05)
            widget.addFloat("Scale",&control.cw,1,1.6,0.02)
        case EQU_07_KALI_TOWER :
            widget.addInt32("Iterations",&control.isteps,2,7,1)
            widget.addFloat("X",&control.cx,0.01,10,0.05)
            widget.addFloat("Y",&control.cy,0,30,0.1)
            widget.addFloat("Twist",&control.cz,0,5,0.1)
            widget.addFloat("Waves",&control.cw,0.1,0.34,0.01)
        case EQU_08_GOLD :
            widget.addInt32("Iterations",&control.isteps,2,40,1)
            widget.addFloat("T",&control.cx,-5,5,0.02)
            widget.addFloat("U",&control.cy,-5,5,0.02)
            widget.addFloat("V",&control.cz,-5,5,0.02)
            widget.addFloat("W",&control.cw,-5,5,0.02)
            widget.addFloat("X",&control.dx,-5,5,0.05)
            widget.addFloat("Y",&control.dy,-5,5,0.05)
            widget.addFloat("Z",&control.dz,-5,5,0.05)
        case EQU_09_SPIDER :
            widget.addFloat("X",&control.cx,0.001,5,0.01)
            widget.addFloat("Y",&control.cy,0.001,5,0.01)
            widget.addFloat("Z",&control.cz,0.001,5,0.01)
        case EQU_10_KLEINIAN2 :
            widget.addInt32("Iterations",&control.isteps,1,12,1)
            widget.addFloat("Shape",&control.fx,0.01,2,0.005)
            widget.addFloat("minX",&control.cx,-5,5,0.01)
            widget.addFloat("minY",&control.cy,-5,5,0.01)
            widget.addFloat("minZ",&control.cz,-5,5,0.01)
            widget.addFloat("minW",&control.cw,-5,5,0.01)
            widget.addFloat("maxX",&control.dx,-5,5,0.01)
            widget.addFloat("maxY",&control.dy,-5,5,0.01)
            widget.addFloat("maxZ",&control.dz,-5,5,0.01)
            widget.addFloat("maxW",&control.dw,-5,5,0.01)
        case EQU_11_HALF_TETRA :
            widget.addInt32("Iterations",&control.isteps,9,150,1)
            widget.addFloat("Scale",&control.cx,0.1,20,0.02)
            widget.addFloat("Y",&control.cy,0.02,50,0.3)
            widget.addFloat("Z",&control.cz,0.02,50,0.3)
            widget.addFloat("Angle1",&control.angle1,-2,2,0.01)
            widget.addFloat("Angle2",&control.angle2,-2,2,0.01)
        case EQU_12_POLYCHORA :
            widget.addFloat("Distance 1",&control.cx,-2,10,0.1)
            widget.addFloat("Distance 2",&control.cy,-2,10,0.1)
            widget.addFloat("Distance 3",&control.cz,-2,10,0.1)
            widget.addFloat("Distance 4",&control.cw,-2,10,0.1)
            widget.addFloat("Ball",&control.dx,0,0.35,0.02)
            widget.addFloat("Stick",&control.dy,0,0.35,0.02)
            widget.addFloat("Spin",&control.dz,-15,15,0.05)
        case EQU_13_QUATJULIA2 :
            widget.addInt32("Iterations",&control.isteps,3,10,1)
            widget.addFloat("Mul",&control.cx,-5,5,0.05)
            widget.addFloat("Offset X",&control.juliaX,-15,15,0.1)
            widget.addFloat("Offset Y",&control.juliaY,-15,15,0.1)
            widget.addFloat("Offset Z",&control.juliaZ,-15,15,0.1)
        case EQU_14_SPUDS :
            widget.addInt32("Iterations",&control.isteps,3,30,1)
            widget.addFloat("Power",&control.fx,1.5,12,0.1)
            widget.addFloat("MinRad",&control.cx,-5,5,0.1)
            widget.addFloat("FixedRad",&control.cy,-5,5,0.02)
            widget.addFloat("Fold Limit",&control.cz,-5,5,0.02)
            widget.addFloat("Fold Limit2",&control.cw,-5,5,0.02)
            widget.addFloat("ZMUL",&control.dx,-5,5,0.1)
            widget.addFloat("Scale",&control.dz,-5,5,0.1)
            widget.addFloat("Scale2",&control.dw,-5,5,0.1)
        case EQU_15_FLOWER :
            widget.addInt32("Iterations",&control.isteps,2,30,1)
            widget.addFloat("Scale",&control.cx,0.5,3,0.01)
            widget.addFloat("Offset X",&control.juliaX,-15,15,0.1)
            widget.addFloat("Offset Y",&control.juliaY,-15,15,0.1)
            widget.addFloat("Offset Z",&control.juliaZ,-15,15,0.1)
        case EQU_16_SPIRALBOX :
            widget.addInt32("Iterations",&control.isteps,6,20,1)
            widget.addFloat("Fold",&control.cx,0.5,1,0.003)
            juliaGroup(2,0.1)
        case EQU_17_SURFBOX :
            widget.addInt32("Iterations",&control.isteps,3,60,1)
            widget.addFloat("Scale Factor",&control.fx,0.6,3,0.05)
            widget.addFloat("Box 1",&control.cx, 0,3,0.02)
            widget.addFloat("Box 2",&control.cy, 4,5.6,0.02)
            widget.addFloat("Sphere 1",&control.cz, 0,4,0.05)
            widget.addFloat("Sphere 2",&control.cw, 0,4,0.05)
            juliaGroup(10,0.01)
        case EQU_18_TWISTBOX :
            widget.addInt32("Iterations",&control.isteps,3,60,1)
            widget.addFloat("Scale Factor",&control.fx,0.6,10,0.2)
            widget.addFloat("Box",&control.cx, 0,10,0.001)
            juliaGroup(10,0.0001)
        case EQU_19_VERTEBRAE :
            widget.addInt32("Iterations",&control.isteps,1,50,1)
            widget.addFloat("X",&control.cx,       -10,10,0.1)
            widget.addFloat("Y",&control.cy,       -10,10,0.1)
            widget.addFloat("Z",&control.cz,       -10,10,0.1)
            widget.addFloat("W",&control.cw,       -10,10,0.1)
            widget.addFloat("ScaleX",&control.dx,  -10,10,0.05)
            widget.addFloat("Sine X",&control.dw,  -10,10,0.05)
            widget.addFloat("Offset X",&control.ez,-10,10,0.05)
            widget.addFloat("Slope X",&control.fy, -10,10,0.05)
            widget.addFloat("ScaleY",&control.dy,  -10,10,0.05)
            widget.addFloat("Sine Y",&control.ex,  -10,10,0.05)
            widget.addFloat("Offset Y",&control.ew,-10,10,0.05)
            widget.addFloat("Slope Y",&control.fz, -10,10,0.05)
            widget.addFloat("ScaleZ",&control.dz,  -10,10,0.05)
            widget.addFloat("Sine Z",&control.ey,  -10,10,0.05)
            widget.addFloat("Offset Z",&control.fx,-10,10,0.05)
            widget.addFloat("Slope Z",&control.fw, -10,10,0.05)
        case EQU_20_DARKSURF :
            widget.addInt32("Iterations",&control.isteps,2,10,1)
            widget.addFloat("scale",&control.cx,    -10,10,0.05)
            widget.addFloat("MinRad",&control.cy,   -10,10,0.05)
            widget.addFloat("Scale",&control.cz,    -10,10,0.5)
            widget.addFloat("Fold X",&control.dx,   -10,10,0.05)
            widget.addFloat("Fold Y",&control.dy,   -10,10,0.05)
            widget.addFloat("Fold Z",&control.dz,   -10,10,0.05)
            widget.addFloat("FoldMod X",&control.ex,-10,10,0.05)
            widget.addFloat("FoldMod Y",&control.ey,-10,10,0.05)
            widget.addFloat("FoldMod Z",&control.ez,-10,10,0.05)
            widget.addFloat("Angle",&control.angle1,-4,4,0.05)
        case EQU_21_SPONGE :
            widget.addInt32("Iterations",&control.isteps,1,16,1)
            widget.addFloat("minX",&control.cx,-5,5,0.01)
            widget.addFloat("minY",&control.cy,-5,5,0.01)
            widget.addFloat("minZ",&control.cz,-5,5,0.01)
            widget.addFloat("minW",&control.cw,-5,5,0.01)
            widget.addFloat("maxX",&control.dx,-5,5,0.01)
            widget.addFloat("maxY",&control.dy,-5,5,0.01)
            widget.addFloat("maxZ",&control.dz,-5,5,0.01)
            widget.addFloat("maxW",&control.dw,-5,5,0.01)
            widget.addFloat("Scale",&control.ex,1,20,1)
            widget.addFloat("Shape",&control.ey,-10,10,0.1)
        case EQU_22_DONUTS :
            widget.addInt32("Iterations",&control.isteps,1,5,1)
            widget.addFloat("X",&control.cx, 0.01,20,0.05)
            widget.addFloat("Y",&control.cy, 0.01,20,0.05)
            widget.addFloat("Z",&control.cz, 0.01,20,0.05)
            widget.addFloat("Spread",&control.dx, 0.01,2,0.01)
            widget.addFloat("Mult",&control.dy, 0.01,2,0.01)
        case EQU_23_PDOF :
            widget.addInt32("Iterations",&control.isteps,1,25,1)
            widget.addFloat("box Size",&control.cx,0,2,0.01)
            widget.addFloat("size",&control.cy,0,2,0.01)
            widget.addFloat("Offset",&control.cz,-1,1,0.02)
            widget.addFloat("DE Offset",&control.cw,0,0.01,0.0001)
            juliaGroup(10,0.01)
        default : break
        }

        widget.addLegend("")

        widget.addBoolean(" Texture",&control.txtOnOff,2)
        if control.txtOnOff {
            widget.addFloat("   X",&control.tCenterX,0.01,1,0.02)
            widget.addFloat("   Y",&control.tCenterY,0.01,1,0.02)
            widget.addFloat("   Scale",&control.tScale,0.01,1,0.02)
        }
        
        widget.addBoolean(" Spherical Inversion",&control.bcy,1)
        if control.bcy {
            widget.addFloat("   X",&control.InvCx,-5,5,0.002)
            widget.addFloat("   Y",&control.InvCy,-5,5,0.002)
            widget.addFloat("   Z",&control.InvCz,-5,5,0.002)
            widget.addFloat("   Radius",&control.InvRadius,0.01,10,0.01)
            widget.addFloat("   Angle",&control.InvAngle,-10,10,0.01)
        }
        
        widget.addBoolean(" LVI enable",&control.LVIenable)
        if control.LVIenable {
            widget.addInt32("   LVI Iter",&control.LVIiter,0,20,1)
            widget.addFloat("   LVI r",&control.LVIr,0,1,0.01)
            widget.addFloat("   LVI g",&control.LVIg,0,1,0.01)
            widget.addFloat("   LVI b",&control.LVIb,0,1,0.01)
        }

        displayWidgets()
        updateWindowTitle()
    }
    
    func displayWidgets() {
        let str = NSMutableAttributedString()
        widget.addinstructionEntries(str)
        instructions.attributedStringValue = str        
        instructionsG.refresh()
    }
    
    func widgetCallback(_ index:Int) {
        switch index {
        case 2 :  // texture
            if control.txtOnOff {
                loadImageFile()
                return
            }
        default : break
        }

        let index = widget.focus
        defineWidgetsForCurrentEquation()
  //gus      reset()
        widget.focus = index
        displayWidgets()
        flagViewToRecalcFractal()
    }

    //MARK: -
    
    /// detemine shader threading settings for 2D and 3D windows (varies according to window size)
    func updateThreadGroupsAccordingToWindowSize() {
        var w = pipeline[PIPELINE_FRACTAL].threadExecutionWidth
        var h = pipeline[PIPELINE_FRACTAL].maxTotalThreadsPerThreadgroup / w
        threadsPerGroup[PIPELINE_FRACTAL] = MTLSizeMake(w, h, 1)
        
        let wxs = Int(metalView.bounds.width) * 2     // why * 2 ??
        let wys = Int(metalView.bounds.height) * 2
        control.xSize = Int32(wxs)
        control.ySize = Int32(wys)
        threadsPerGrid[PIPELINE_FRACTAL] = MTLSizeMake(wxs,wys,1)
        
        //------------------------
        w = pipeline[PIPELINE_NORMAL].threadExecutionWidth
        h = pipeline[PIPELINE_NORMAL].maxTotalThreadsPerThreadgroup / w
        threadsPerGroup[PIPELINE_NORMAL] = MTLSizeMake(w, h, 1)
        
        let sz:Int = Int(SIZE3D)
        threadsPerGrid[PIPELINE_NORMAL] = MTLSizeMake(sz,sz,1)
    }
    
    /// ensure initial 2D window size is large enough to display all widget entries
    func ensureWindowSizeIsNotTooSmall() {
        var r:CGRect = (view.window?.frame)!
        if r.size.width < 700 { r.size.width = 700 }
        if r.size.height < 700 { r.size.height = 700 }
        view.window?.setFrame(r, display:true)
    }
    
    /// toggling stereo viewing automatically adjusts window size to accomodate (unless we are already full screen)
    func adjustWindowSizeForStereo() {
        if !isFullScreen {
            var r:CGRect = (view.window?.frame)!
            r.size.width *= CGFloat(control.isStereo ? 2.0 : 0.5)
            view.window?.setFrame(r, display:true)
        }
        else {
            updateLayoutOfChildViews()
        }
    }
    
    /// key commands direct 2D window to grow/shrink
    func adjustWindowSize(_ dir:Int) {
        if !isFullScreen {
            var r:CGRect = (view.window?.frame)!
            let ratio:CGFloat = 1.0 + CGFloat(dir) * 0.1
            r.size.width *= ratio
            r.size.height *= ratio
            view.window?.setFrame(r, display:true)
            
            updateLayoutOfChildViews()
        }
    }
    
    /// 2D window has resized. adjust child views to fit.
    func updateLayoutOfChildViews() {
        var r:CGRect = view.frame
        
        if isFullScreen {
            r = NSScreen.main!.frame
            metalView.frame = CGRect(x:0, y:0, width:r.size.width, height:r.size.height)
        }
        else {
            let minWinSize:CGSize = CGSize(width:300, height:300)
            var changed:Bool = false
            
            if r.size.width < minWinSize.width {
                r.size.width = minWinSize.width
                changed = true
            }
            if r.size.height < minWinSize.height {
                r.size.height = minWinSize.height
                changed = true
            }
            
            if changed {  view.window?.setFrame(r, display:true) }
            
            metalView.frame = CGRect(x:1, y:1, width:r.size.width-2, height:r.size.height-2)
        }
        
        //-------------------------------
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(r.size.width * 2),
            height: Int(r.size.height * 2),
            mipmapped: false)
        
        textureDescriptor.usage = [.shaderRead, .shaderWrite]

        texture = nil
        texture = device.makeTexture(descriptor: textureDescriptor)!
        //-------------------------------

        let widgetPanelHeight:Int = 1200
        instructionsG.frame = CGRect(x:5, y:5, width:75, height:widgetPanelHeight)
        instructionsG.bringToFront()
        instructionsG.refresh()
        
        instructions.frame = CGRect(x:50, y:5, width:500, height:widgetPanelHeight)
        instructions.textColor = .white
        instructions.backgroundColor = .black
        instructions.bringToFront()
        
        updateThreadGroupsAccordingToWindowSize()
        flagViewToRecalcFractal()
    }
    
    func windowDidResize(_ notification: Notification) { updateLayoutOfChildViews() }
    
    //MARK: -
    
    /// store just loaded .png picture to texture
    func loadTexture(from image: NSImage) -> MTLTexture? {
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        
        let textureLoader = MTKTextureLoader(device: device)
        var textureOut:MTLTexture! = nil
        
        do {
            textureOut = try textureLoader.newTexture(cgImage:cgImage)
            
            control.txtSize.x = Float(cgImage.width)
            control.txtSize.y = Float(cgImage.height)
            control.tCenterX = 0.5
            control.tCenterY = 0.5
            control.tScale = 0.5
        }
        catch {
            let alert = NSAlert()
            alert.messageText = "Cannot Continue"
            alert.informativeText = "Error while trying to load this texture."
            alert.beginSheetModal(for: view.window!) { ( returnCode: NSApplication.ModalResponse) -> Void in () }
        }
        
        return textureOut
    }
    
    /// launch file open dialog for picking .png picture for texturing
    func loadImageFile() {
        control.txtOnOff = false
        
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "Select Image for Texture"
        openPanel.allowedFileTypes = ["jpg","png"]
        
        openPanel.beginSheetModal(for:self.view.window!) { (response) in
            if response.rawValue == NSApplication.ModalResponse.OK.rawValue {
                let selectedPath = openPanel.url!.path
                
                if let image:NSImage = NSImage(contentsOfFile: selectedPath) {
                    coloringTexture = self.loadTexture(from: image)
                    self.control.txtOnOff = coloringTexture != nil
                }
            }
            
            openPanel.close()
            
            if self.control.txtOnOff { // just loaded a texture
                self.defineWidgetsForCurrentEquation()
                self.flagViewToRecalcFractal()
            }
            else {
                self.displayWidgets() // display 'off' status
            }
        }
    }
}

//MARK: -

class BaseNSView: NSView {
    override var isFlipped: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
}

extension NSView {
    public func bringToFront() {
        let superlayer = self.layer?.superlayer
        self.layer?.removeFromSuperlayer()
        superlayer?.addSublayer(self.layer!)
    }
}

extension NSMutableAttributedString {
    @discardableResult func colored(_ text: String , _ color:NSColor) -> NSMutableAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [ NSAttributedString.Key.foregroundColor: color]
        let cString = NSMutableAttributedString(string:text + "\n", attributes: attrs)
        append(cString)
        return self
    }
    
    @discardableResult func normal(_ text: String) -> NSMutableAttributedString {
        let normal = NSAttributedString(string: text + "\n")
        append(normal)
        return self
    }
}
