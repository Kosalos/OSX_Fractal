#pragma once

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

enum {
    EQU_01_MANDELBULB, EQU_02_APOLLONIAN2, EQU_03_KLEINIAN, EQU_04_MANDELBOX,EQU_05_QUATJULIA,
    EQU_06_MONSTER, EQU_07_KALI_TOWER, EQU_08_GOLD, EQU_09_SPIDER, EQU_10_KLEINIAN2,
    EQU_11_HALF_TETRA, EQU_12_POLYCHORA, EQU_13_QUATJULIA2, EQU_14_SPUDS, EQU_15_FLOWER,
    EQU_16_SPIRALBOX, EQU_17_SURFBOX, EQU_18_TWISTBOX, EQU_19_VERTEBRAE, EQU_20_DARKSURF,
    EQU_21_SPONGE, EQU_22_DONUTS, EQU_23_PDOF, EQU_24_MAGNETO, EQU_25_SPUDS2018,
    EQU_26_KALEIDO, EQU_27_MANDELNEST,EQU_28_KALI_RONTGEN,EQU_29_ENGINE,EQU_30_FRACTAL_CAGE,
    EQU_31_GAZ_42,EQU_32_BONEYTUNNEL,EQU_33_GAZ_19,EQU_34_RADIOBASE,EQU_MAX };

#define NUM_LIGHT   3
#define NUM_BILLBOARD 10

#define ESC_KEY      53
#define HOME_KEY    115
#define END_KEY     119
#define PAGE_UP     116
#define PAGE_DOWN   121
#define LEFT_ARROW  123
#define RIGHT_ARROW 124
#define DOWN_ARROW  125
#define UP_ARROW    126

typedef struct {
    float bright,fx;
    float x,y,z;                // relative position as separate values for widgets
    float r,g,b;                // light color as separate values for widgets
    vector_float3 relativePos;  // user specified offset fromcamera position and aim for Light
    vector_float3 pos;          // calculated light position used by shader
    vector_float3 nrmPos;       // normalized light position used by shader
    vector_float3 color;        // light color used by shader
} FLightData;

typedef struct {
    bool  active;
    float u1,v1,u2,v2;          // texture atlas region
    float x,y;                  // position of UL corner as ratio
    float xs,ys;                // size as ratio
    float z;                    // distance from camera
    float fudge,unused1,unused2;        // color when no texture
} BillboardData;

typedef struct {
    int version;
    int xSize,ySize;
    int equation;
    int skip;
    bool isStereo;
    float parallax;

    bool txtOnOff;
    vector_float2 txtSize;
    float tCenterX,tCenterY,tScale;

    vector_float3 camera;
    vector_float3 viewVector,topVector,sideVector;
    vector_float3 light,nlight;
    float bright;
    float contrast;
    float specular;

    float cx,cy,cz,cw;
    float dx,dy,dz,dw;
    float ex,ey,ez,ew;
    float fx,fy,fz,fw;

    int isteps;
    int icx,icy,icz,icw;

    bool bcx,doInversion,bcz,bcw;
    bool bdx,bdy,bdz,bdw;
    bool bex,bey;

    vector_float2 v2a,v2b;
    vector_float3 v3a,v3b,v3c;
    vector_float4 v4a,v4b;

    vector_float3 InvCenter;
    float InvCx,InvCy,InvCz;
    float InvAngle;
    float InvRadius;
    
    vector_float3 julia;
    bool juliaboxMode;
    float juliaX,juliaY,juliaZ;

    matrix_float4x4 mm;
    
    int colorScheme;

    float radialAngle;
    float enhance;
    float secondSurface;
    float angle1,angle2;
    
    // orbit Trap -----------
    float Cycles;
    float OrbitStrength;
    vector_float4 X,Y,Z,R;                  // color RGB from lookup table
    float xIndex,yIndex,zIndex,rIndex;      // color palette index
    float xWeight,yWeight,zWeight,rWeight;  // color weight
    int orbitStyle;
    float otFixedX,otFixedY,otFixedZ;
    vector_float3 otFixed;
    
    float fog,fogR,fogG,fogB;
    
    FLightData flight[NUM_LIGHT];
    
    // control panel -------
    int panel00,panel01,panel10,panel11,panel20,panel21,panel30,panel31;

    float refractAmount;
    float transparentAmount;
    float normalOffset;
    float coloring1,coloring2,coloring3,coloring4,coloring5;
    float coloring6,coloring7,coloring8,coloring9,coloringa;

    float blurFocalDistance,blurStrength,blurDim;
    float coloringM1,coloringM2,coloringM3;
    
    BillboardData billboard[NUM_BILLBOARD];

} Control;

// 3D window ---------------------------------

#define SIZE3D 255
#define SIZE3Dm (SIZE3D - 1)

typedef struct {
    vector_float3 position;
    vector_float3 normal;
    vector_float2 texture;
    vector_float4 color;
    float height;
} TVertex;

typedef struct {
    int count;
} Counter;

typedef struct {
    vector_float3 base;
    float radius;
    float deltaAngle;
    float fx;        // 1 ... 3
    float ambient;
    float height;
    
    vector_float3 position;
    float angle;
} LightData;

typedef struct {
    matrix_float4x4 mvp;
    float pointSize;
    LightData light;
    
    float yScale3D,ceiling3D,floor3D;
} Uniforms;

// ----------------------------------------------

#ifndef __METAL_VERSION__

void setControlPointer(Control *ptr);
void resetAllLights(void);
void resetShaderArrayData(void);
void encodeShaderArrayData(void);
float* lightBright(int index);
float* lightPower(int index);
float* lightX(int index);
float* lightY(int index);
float* lightZ(int index);
float* lightR(int index);
float* lightG(int index);
float* lightB(int index);

//-----------------------

bool*  billboardActive(int index);
float* billboardU1(int index);
float* billboardU2(int index);
float* billboardV1(int index);
float* billboardV2(int index);
float* billboardX(int index);
float* billboardY(int index);
float* billboardXS(int index);
float* billboardYS(int index);
float* billboardZ(int index);
float* billboardFudge(int index);
//vector_float3* billboardColor(int index);

#endif

