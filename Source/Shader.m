#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <simd/simd.h>
#include "Shader.h"

Control *c = NULL;

void setControlPointer(Control *ptr) { c = ptr; }

void resetAllLights(void) {
    for(int i=0;i<NUM_LIGHT;++i) {
        c->flight[i].bright = 0;
        c->flight[i].fx = 0.1;
        c->flight[i].x = 0;
        c->flight[i].y = 0;
        c->flight[i].z = 0;
        c->flight[i].r = 1;
        c->flight[i].g = 1;
        c->flight[i].b = 1;
    }
}

//static const vector_float3 bbC[] = {
//    { 1,0,0 },
//    { 0,1,0 },
//    { 1,1,0 },
//    { 0,0,1 },
//    { 1,0,1 },
//    { 0,1,1 },
//    { 1,1,1 },
//    { 1,0,0.5 },
//    { 1,0.5,0.5 },
//    { 1,0.5,1 }};

void resetShaderArrayData() {
    resetAllLights();
    
    for(int i=0;i<NUM_BILLBOARD;++i) {
        c->billboard[i].active = false;
  //      c->billboard[i].color = bbC[i];
    }
}

float max(float v1,float v2) { if(v1 > v2) return v1;  return v2; }

simd_float3 normalize(simd_float3 v) {
    float len = simd_length(v);
    if(len == 0) len += 0.0001;
    return v / len;
}

void encodeShaderArrayData(void) {
    for(int i=0;i<NUM_LIGHT;++i) {
        c->flight[i].bright = max(c->flight[i].bright,0);
        c->flight[i].fx = max(c->flight[i].fx,0.1);
        c->flight[i].relativePos.x = 0.001 + -(c->flight[i].x); // mirror image X
        c->flight[i].relativePos.y = c->flight[i].y;
        c->flight[i].relativePos.z = c->flight[i].z;
        
        c->flight[i].color.x = c->flight[i].r;
        c->flight[i].color.y = c->flight[i].g;
        c->flight[i].color.z = c->flight[i].b;

        // light position is relative to camera position and aim
        c->flight[i].pos = c->camera
            - (c->sideVector * c->flight[i].relativePos.x)
            + (c->topVector  * c->flight[i].relativePos.y)
            + (c->viewVector * c->flight[i].relativePos.z);
                
        c->flight[i].nrmPos = simd_normalize(c->flight[i].pos);
    }

//    int i = 0;
//    printf("Light %d: B %5.3f, P %5.3f, Pos %5.3f,%5.3f,%5.3f\n",i,c->flight[i].bright,c->flight[i].fx,c->flight[i].pos.x,
//           c->flight[i].pos.y,c->flight[i].pos.z);
}

float* lightBright(int index)   { return &c->flight[index].bright; }
float* lightPower(int index)    { return &c->flight[index].fx; }
float* lightX(int index)        { return &c->flight[index].x; }
float* lightY(int index)        { return &c->flight[index].y; }
float* lightZ(int index)        { return &c->flight[index].z; }
float* lightR(int index)        { return &c->flight[index].r; }
float* lightG(int index)        { return &c->flight[index].g; }
float* lightB(int index)        { return &c->flight[index].b; }

bool*  billboardActive(int index)   { return &c->billboard[index].active; }
float* billboardU1(int index)   { return &c->billboard[index].u1; }
float* billboardU2(int index)   { return &c->billboard[index].u2; }
float* billboardV1(int index)   { return &c->billboard[index].v1; }
float* billboardV2(int index)   { return &c->billboard[index].v2; }
float* billboardX(int index)   { return &c->billboard[index].x; }
float* billboardY(int index)   { return &c->billboard[index].y; }
float* billboardXS(int index)   { return &c->billboard[index].xs; }
float* billboardYS(int index)   { return &c->billboard[index].ys; }
float* billboardZ(int index)   { return &c->billboard[index].z; }
float* billboardFudge(int index)   { return &c->billboard[index].fudge; }
//vector_float3* billboardColor(int index)   { return &c->billboard[index].color; }

