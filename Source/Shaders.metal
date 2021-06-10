#include <metal_stdlib>
#include "Shader.h"

// Define this to speed up compilation times
// in the DE() function you are editing: change "#ifdef SINGLE_EQUATION" to something else so that the function body is executed
//#define SINGLE_EQUATION 1

using namespace metal;

typedef float2 vec2;
typedef float3 vec3;
typedef float4 vec4;

constant int MAX_MARCHING_STEPS = 255;
constant float MIN_DIST = 0.00002;
constant float MAX_DIST = 60;
constant float PI = 3.1415926;

float  mod(float  x, float y) { return x - y * floor(x/y); }
float2 mod(float2 x, float y) { return x - y * floor(x/y); }
float3 mod(float3 x, float y) { return x - y * floor(x/y); }

float3 rotatePosition(float3 pos, int axis, float angle) {
    float ss = sin(angle);
    float cc = cos(angle);
    float qt;
    
    switch(axis) {
        case 0 :    // XY
            qt = pos.x;
            pos.x = pos.x * cc - pos.y * ss;
            pos.y =    qt * ss + pos.y * cc;
            break;
        case 1 :    // XZ
            qt = pos.x;
            pos.x = pos.x * cc - pos.z * ss;
            pos.z =    qt * ss + pos.z * cc;
            break;
        case 2 :    // YZ
            qt = pos.y;
            pos.y = pos.y * cc - pos.z * ss;
            pos.z =    qt * ss + pos.z * cc;
            break;
    }
    return pos;
}

float2 rotatePosition2(float2 pos, float angle) {
    float ss = sin(angle);
    float cc = cos(angle);
    float qt = pos.x;

    pos.x = pos.x * cc - pos.y * ss;
    pos.y =    qt * ss + pos.y * cc;

    return pos;
}

//MARK: - 1 MandelBulb
// mandelbulb: https://github.com/jtauber/mandelbulb/blob/master/mandel8.py

float DE_MANDELBULB(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float dr = 1;
    float r,theta,phi,pwr,ss;
    
    float3 ot,trap = control.otFixed;
    if(int(control.orbitStyle + 0.5) == 2) trap -= pos;
    
    for(int i=0; i < control.isteps; ++i) {
        r = length(pos);
        if(r > 2) break;
        
        theta = atan2(sqrt(pos.x * pos.x + pos.y * pos.y), pos.z);
        phi = atan2(pos.y,pos.x);
        pwr = pow(r,control.fx);
        ss = sin(theta * control.fx);
        
        pos.x += pwr * ss * cos(phi * control.fx);
        pos.y += pwr * ss * sin(phi * control.fx);
        pos.z += pwr * cos(theta * control.fx);
        
        dr = (pow(r, control.fx - 1.0) * control.fx * dr ) + 1.0;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        float4 hk = float4(ot,r);
        orbitTrap = min(orbitTrap, dot(hk,hk));
    }
    
    return 0.5 * log(r) * r/dr;
#endif
}

//MARK: - 2 Apollonian2
// apollonian2: https://www.shadertoy.com/view/llKXzh

float DE_APOLLONIAN2(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef zzzSINGLE_EQUATION
    return 0;
#else
    float t = control.cz + 0.25 * cos(control.cw * PI * control.cx * (pos.z - pos.x));
    float scale = 1;
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for(int i=0; i< control.isteps; ++i) {
        pos = -1.0 + 2.0 * fract(0.5 * pos + 0.5);
        pos -= sign(pos) * control.cy / 20;
        
        float k = t / dot(pos,pos);
        pos *= k;
        scale *= k;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    float d1 = sqrt( min( min( dot(pos.xy,pos.xy), dot(pos.yz,pos.yz) ), dot(pos.zx,pos.zx) ) ) - 0.02;
    float dmi = min(d1,abs(pos.y));
    return 0.5 * dmi / scale;
#endif
}

//MARK: - 3 JosKleinian

float dot2(float3 z) { return dot(z,z);}

float3 wrap(float3 x, float3 a, float3 s) {
    x -= s;
    return (x-a*floor(x/a)) + s;
}

float2 wrap(float2 x, float2 a, float2 s){
    x -= s;
    return (x-a*floor(x/a)) + s;
}

void TransA(thread float3 &z, thread float &DF, float a, float b) {
    float iR = 1. / dot2(z);
    z *= -iR;
    z.x = -b - z.x;
    z.y =  a + z.y;
    DF *= iR;
}

float DE_JOSKLEINIAN(float3 z,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float3 lz=z+float3(1.), llz=z+float3(-1.);
    float DE=1e10;
    float DF = 1.0;
    float a = control.dx, b = control.dy;
    float f = sign(b) ;
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= z;
    
    for (int i = 0; i < control.icy; i++) {
        z.x=z.x+b/a*z.y;
        if (control.bcz)
            z = wrap(z, float3(2. * control.cz, a, 2. * control.cw), float3(-control.cz, 0., -control.cw));
        else
            z.xz = wrap(z.xz, float2(2. * control.cz, 2. * control.cw), float2(-control.cz, -control.cw));
        z.x=z.x-b/a*z.y;
        
        //If above the separation line, rotate by 180∞ about (-b/2, a/2)
        if  (z.y >= a * (0.5 +  f * 0.25 * sign(z.x + b * 0.5)* (1. - exp( - 3.2 * abs(z.x + b * 0.5)))))
            z = float3(-b, a, 0.) - z;//
        //z.xy = float2(-b, a) - z.xy;//
        
        //Apply transformation a
        TransA(z, DF, a, b);
        
        //If the iterated points enters a 2-cycle , bail out.
        if(dot2(z-llz) < 1e-12) {
            break;
        }
        
        //Store previous iterates
        llz=lz; lz=z;
        
        ot = z;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    //WIP: Push the iterated point left or right depending on the sign of dy
    for (int i=0;i<control.icx;i++){
        float y = control.bcx ? min(z.y, a-z.y) : z.y;
        DE=min(DE,min(y,control.dz)/max(DF,control.dw));
        TransA(z, DF, a, b);
    }
    
    float y = control.bcx ? min(z.y, a-z.y) : z.y;
    DE=min(DE,min(y,control.dz)/max(DF,control.dw));
    
    return DE;
#endif
}

//MARK: - 4 MandelBox
// mandelbox : http://www.fractalforums.com/3d-fractal-generation/a-mandelbox-distance-estimate-formula/
// http://www.fractalforums.com/new-theories-and-research/mandelbox-variant-21/

float boxFold(float v, float fold) { return abs(v + fold) - fabs(v- fold) - v; }
float boxFold2(float v, float fold) { if(v < -fold) v = -2 * fold - v; return v; }

float DE_MANDELBOX(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef zzzSINGLE_EQUATION
    return 0;
#else
    // For the Juliabox, c is a constant. For the Mandelbox, c is variable.
    float3 c = control.juliaboxMode ? control.julia : pos;
    float r2,dr = control.fx;
    float cx = control.cx;
    float fR2 = control.cz * control.cz;
    float mR2 = control.cw * control.cw;
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    
    for(int i = 0; i < control.isteps; ++i) {
        if(control.doInversion) {
            pos.x = boxFold(pos.x,cx);
            pos.y = boxFold(pos.y,cx);
            pos.z = boxFold(pos.z,cx);
        }
        else {
            pos.x = boxFold2(pos.x,cx);
            pos.y = boxFold2(pos.y,cx);
            pos.z = boxFold2(pos.z,cx);
        }
        
        cx *= control.dx;
        
        r2 = pos.x*pos.x + pos.y*pos.y + pos.z*pos.z;
        
        if(r2 < mR2) {
            float temp = fR2 / mR2;
            pos *= temp;
            dr *= temp;
        }
        else if(r2 < fR2) {
            float temp = fR2 / r2;
            pos *= temp;
            dr *= temp;
        }
        
        pos = pos * control.fx + c;
        dr *= control.fx;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return length(pos)/abs(dr);
#endif
}

//MARK: - 5 Quaternion Julia
// quat julia 2 : https://github.com/3Dickulus/FragM/blob/master/Fragmentarium-Source/Examples/Experimental/Stereographic4DJulia.frag

float DE_QUATJULIA(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float4 c = 0.5 * float4(control.cx, control.cy, control.cz, control.cw);
    float4 nz;
    float md2 = 1.0;
    float4 z = float4(pos,0);
    float mz2 = dot(z,z);
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for(int i=0;i < control.isteps; ++i) {
        md2 *= 4.0 * mz2;
        nz.x = z.x * z.x - dot(z.yzw,z.yzw);
        nz.yzw = 2.0 * z.x * z.yzw;
        z = nz+c;
        
        mz2 = dot(z,z);
        if(mz2 > 12.0) break;
        
        ot = z.xyz;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), mz2));
    }
    
    return 0.3 * sqrt(mz2/md2) * log(mz2);
#endif
}

//MARK: - 6 Monster
// monster: https://www.shadertoy.com/view/4sX3R2

float4x4 rotationMat(float3 xyz )
{
    float3 si = sin(xyz);
    float3 co = cos(xyz);
    
    return float4x4( co.y*co.z, co.y*si.z, -si.y, 0.0,
                    si.x*si.y*co.z-co.x*si.z, si.x*si.y*si.z+co.x*co.z, si.x*co.y,  0.0,
                    co.x*si.y*co.z+si.x*si.z, co.x*si.y*si.z-si.x*co.z, co.x*co.y,  0.0,
                    0.0,                      0.0,                      0.0,        1.0 );
}

float DE_MONSTER(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float k = 1.0;
    float m = 1e10;
    float r,s = control.cw;
    float time1 = control.cx;
    
    if(control.mm[0][0] > 98) {     // Swift marked this before shader call. result will be shared by other threads
        control.mm = rotationMat( float3(control.cz,0.1,control.cy) +
                                 0.15*sin(0.1*float3(0.40,0.30,0.61)*time1) +
                                 0.15*sin(0.1*float3(0.11,0.53,0.48)*time1));
        control.mm[0].xyz *= s;
        control.mm[1].xyz *= s;
        control.mm[2].xyz *= s;
        control.mm[3].xyz = float3( 0.15, 0.05, -0.07 ) + 0.05*sin(float3(0.0,1.0,2.0) + 0.2*float3(0.31,0.24,0.42)*time1);
    }
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for( int i=0; i < control.isteps; i++ ) {
        m = min( m, dot(pos,pos) /(k*k) );
        pos = (control.mm * float4((abs(pos)),1.0)).xyz;
        
        r = dot(pos,pos);
        if(r > 2) break;
        
        k *= control.cw;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    float d = (length(pos)-0.5)/k;
    return d * 0.25;
#endif
}

//MARK: - 7 Kali Tower
// tower: https://www.shadertoy.com/view/MtBGDG

float smin(float a, float b, float k ) {
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

float4 rotateXZ(float4 pos, float angle) {
    float ss = sin(angle);
    float cc = cos(angle);
    float qt = pos.x;
    pos.x = pos.x * cc - pos.z * ss;
    pos.z =    qt * ss + pos.z * cc;
    return pos;
}

float DE_KALI_TOWER(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float aa = smoothstep(0.,1.,clamp(cos(control.cy - pos.y * 0.4)*1.5,0.,1.)) * PI;
    float4 p = float4(pos,1);
    
    p.y -= control.cy * 0.25;
    p.y = abs(3.-fract((p.y - control.cy) / 2));
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for (int i=0; i < control.isteps; i++) {
        p.xyz = abs(p.xyz) - float3(.0,control.cx,.0);
        p = p * 2./clamp(dot(p.xyz,p.xyz),.3,1.) - float4(0.5,1.5,0.5,0.);
        
        p = rotateXZ(p,aa * control.cz);
        
        ot = p.xyz;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    float fl = pos.y-3.7 - length(sin(pos.xz * 60))*.01;
    float fr = max(abs(p.z/p.w)-.01,length(p.zx)/p.w-.002);
    float bl = max(abs(p.x/p.w)-.01,length(p.zy)/p.w-.0005);
    fr = smin(bl,fr,.02);
    fr *= 0.9;
    fl -= (length(p.xz)*.005+length(sin(pos * 3. + control.cy * 5.)) * control.cw);
    fl *=.9;
    
    return abs(smin(fl,fr,.7));
#endif
}

//MARK: - 8 Gold
// Gold: https://www.shadertoy.com/view/XdGXRV

float DE_GOLD(float3 p,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    p.xz = mod(p.xz + 1.0, 2.0) - 1.0;
    float4 q = float4(p, 1);
    float3 offset1 = float3(control.cx, control.cy, control.cz);
    float4 offset2 = float4(control.cw, control.dx, control.dy, control.dz);
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= p;
    
    for(int i = 0; i < control.isteps; ++i) {
        q.xyz = abs(q.xyz) - offset1;
        q = 2.0*q/clamp(dot(q.xyz, q.xyz), 0.4, 1.0) - offset2;
        
        ot = q.xyz;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return length(q.xyz)/q.w;
#endif
}

//MARK: - 9 Spider
// spider : https://www.shadertoy.com/view/XtKcDm

float smax(float a, float b, float s) { // iq smin
    float h = clamp( 0.5 + 0.5*(a-b)/s, 0.0, 1.0 );
    return mix(b, a, h) + h*(1.0-h)*s;
}

float DE_SPIDER(float3 p,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float q = sin(p.z * control.cx) * control.cy * 10 + 0.6;
    float t = length(p.xy);
    float s = 1.0;
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= p;
    
    for(int i = 0; i < 2; ++i) {
        float m = dot(p,p);
        p = abs(fract(p/m)-0.5);
        p = rotatePosition(p,0,q);
        s *= m;
        
        ot = p;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    float d = (length(p.xz) - control.cz) * s;
    return smax(d,-t, 0.3);
#endif
}

//MARK: - 10 Knighty's Kleinian
// knighty's kleinian : https://www.shadertoy.com/view/lstyR4

float DE_KLEINIAN2(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float k, scale = 1;
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for(int i=0; i < control.isteps; ++i) {
        pos = 2 * clamp(pos, control.v4a.xyz, control.v4b.xyz) - pos;
        k = max(control.v4a.w / dot(pos,pos), control.fx);
        pos *= k;
        scale *= k;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    float rxy = length(pos.xy);
    return .7 * max(rxy - control.v4b.w, rxy * pos.z / length(pos)) / scale;
#endif
}

//MARK: - 11 IFS Tetrahedron
// IFS Tetrahedron : https://github.com/3Dickulus/FragM/blob/master/Fragmentarium-Source/Examples/Kaleidoscopic%20IFS/Tetrahedron.frag

float DE_HALF_TETRA(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    int i;
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for(i=0;i < control.isteps; ++i) {
        pos = rotatePosition(pos,0,control.angle1);
        
        if(pos.x - pos.y < 0.0) pos.xy = pos.yx;
        if(pos.x - pos.z < 0.0) pos.xz = pos.zx;
        if(pos.y - pos.z < 0.0) pos.zy = pos.yz;
        
        pos = rotatePosition(pos,2,control.angle2);
        pos = pos * control.cx - control.v3a * (control.cx - 1.0);
        if(length(pos) > 4) break;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return (length(pos) - 2) * pow(control.cx, -float(i));
#endif
}

//MARK: - 12 Polychora
// polychora : https://github.com/Syntopia/Fragmentarium/blob/master/Fragmentarium-Source/Examples/Knighty%20Collection/polychora-special.frag

float4 Rotate(float4 p,device Control &control) {
    //this is a rotation on the plane defined by RotVector and w axis
    //We do not need more because the remaining 3 rotation are in our 3D space
    //That would be redundant.
    //This rotation is equivalent to translation inside the hypersphere when the camera is at 0,0,0
    float4 p1=p;
    float3 rv = normalize(control.sideVector);
    float vp=dot(rv,p.xyz);
    p1.xyz += rv * (vp * (control.fx-1.) - p.w * control.fy);
    p1.w += vp * control.fy + p.w * (control.fx-1.);
    return p1;
}

float4 fold(float4 pos,device Control &control) {
    for(int i=0;i<3;i++){
        pos.xyz=abs(pos.xyz);
        float t =-2.*min(0.,dot(pos,control.v4a));
        pos += t * control.v4a;
    }
    return pos;
}

float DDV(float ca, float sa, float r,device Control &control) {
    //magic formula to convert from spherical distance to planar distance.
    //involves transforming from 3-plane to 3-sphere, getting the distance
    //on the sphere (which is an angle -read: sa==sin(a) and ca==cos(a))
    //then going back to the 3-plane.
    //return r-(2.*r*ca-(1.-r*r)*sa)/((1.-r*r)*ca+2.*r*sa+1.+r*r);
    return (2. * r * control.ex-(1.-r*r) * control.ey)/((1.-r*r) * control.ex + 2.*r * control.ey+1.+r*r)-(2.*r*ca-(1.-r*r)*sa)/((1.-r*r)*ca+2.*r*sa+1.+r*r);
}

float DDS(float ca, float sa, float r,device Control &control) {
    return (2.*r * control.ez-(1.-r*r) * control.ew)/((1.-r*r) * control.ez+2.*r * control.ew+1.+r*r)-(2.*r*ca-(1.-r*r)*sa)/((1.-r*r)*ca+2.*r*sa+1.+r*r);
}

float dist2Vertex(float4 z, float r,device Control &control) {
    float ca=dot(z,control.v4b);
    float sa=0.5*length(control.v4b-z) * length(control.v4b+z);
    return DDV(ca,sa,r,control);
}

float dist2Segment(float4 z, float4 n, float r,device Control &control) {
    //pmin is the orthogonal projection of z onto the plane defined by p and n
    //then pmin is projected onto the unit sphere
    float zn=dot(z,n);
    float zp=dot(z,control.v4b);
    float np=dot(n,control.v4b);
    float alpha= zp-zn*np;
    float beta = zn-zp*np;
    float4 pmin=normalize(alpha * control.v4b + min(0.,beta)*n);
    //ca and sa are the cosine and sine of the angle between z and pmin. This is the spherical distance.
    float ca =dot(z,pmin);
    float sa =0.5*length(pmin-z)*length(pmin+z);//sqrt(1.-ca*ca);//
    return DDS(ca,sa,r,control);//-SRadius;
}

float dist2Segments(float4 z, float r,device Control &control) {
    float da = dist2Segment(z, float4(1,0,0,0), r,control);
    float db = dist2Segment(z, float4(0,1,0,0), r,control);
    float dc = dist2Segment(z, float4(0,0,1,0), r,control);
    float dd = dist2Segment(z, control.v4a, r,control);
    
    return min(min(da,db),min(dc,dd));
}

float DE_POLYCHORA(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float r = length(pos);
    float4 z4 = float4(2.*pos,1.-r*r)*1./(1.+r*r);//Inverse stereographic projection of pos: z4 lies onto the unit 3-sphere centered at 0.
    z4=Rotate(z4,control);//z4.xyw=rot*z4.xyw;
    z4=fold(z4,control);//fold it
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    ot = z4.xyz;
    if(control.orbitStyle > 0) ot -= trap;
    orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    
    float ans = min(dist2Vertex(z4,r,control),dist2Segments(z4,r,control));
    return ans;
#endif
}

//MARK: - 13 Quaternion Julia 2
// quat julia 2 : https://github.com/3Dickulus/FragM/blob/master/Fragmentarium-Source/Examples/Experimental/Stereographic4DJulia.frag

float4 stereographic3Sphere(float3 pos,device Control &control) {
    float n = dot(pos,pos)+1.;
    return float4(control.cx * pos,n-2.) / n;
}

float2 complexMul(float2 a, float2 b) { return float2(a.x*b.x - a.y*b.y, a.x*b.y + a.y * b.x); }

float DE_QUATJULIA2(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float4 p4 = stereographic3Sphere(pos,control);
    
    p4.xyz += control.julia;    // "offset"
    
    float2 p = p4.xy;
    float2 c = p4.zw;
    float dp = 1.0;
    float d;
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for (int i = 0; i < control.isteps; ++i) {
        dp = 2.0 * length(p) * dp + 1.0;
        p = complexMul(p,p) + c;
        
        d = dot(p,p);
        if(d > 10) break;
        
        ot = float3(p,1);
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    float r = length(p);
    return r * log(r) / abs(dp);
#endif
}

//MARK: - 14 Spudsville
// spudsville : https://github.com/3Dickulus/FragM/blob/master/Fragmentarium-Source/Examples/Experimental/Spudsville2.frag

#define Q1 control.cx
#define Q2 control.cy
#define Q3 control.cz
#define Q4 control.cw
#define Q5 control.fx
#define Q6 control.dx
#define Q7 control.dy
#define Q8 control.dz
#define Q9 control.dw

float3 spudsBoxFold(float3 pos, float fold, float mult) {
    return clamp(pos, -fold, fold) * mult - pos;
}

float DE_SPUDS(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef zSINGLE_EQUATION
    return 0;
#else
    int n = 0;
    float dz = 1.0;
    float temp,r2,r = length(pos);
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    while(n < control.isteps) {
        if (n <= control.isteps/2) {
            pos = spudsBoxFold(pos,Q3,Q9);
            
            r2 = dot(pos,pos);
            if (r2 < Q1) {
                temp = (Q2 / Q1);
                pos *= temp;
                dz *= temp;
            } else if (r2 < Q2) {
                temp = Q2 /r2;
                pos *= temp;
                dz *= temp;
            }

            pos *= Q7;
            dz *= abs(Q7);
        } else {
            pos = spudsBoxFold(pos,Q4,Q9);
            r = length(pos);
            
            float zo0 = asin(pos.z / r);
            float zi0 = atan2(pos.y, pos.x);
            float zr = pow(r, Q5 - 1.0);
            float zo = zo0 * Q5;
            float zi = zi0 * Q5;
            dz = zr * dz * Q5 * abs(length(float3(1.0,1.0,Q6)/sqrt(3.0))) + 1.0;
            zr *= r;
            pos = zr * float3(cos(zo)*cos(zi), cos(zo)*sin(zi), Q6 * sin(zo));

            pos = Q8 * pos;
            dz *= abs(Q8);
        }
        
        r = length(pos);

        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
        
        n++;
    }
    
    return r * log(r) / dz;
#endif
}

//MARK: - 15 Flower Hive
// FlowerHive: https://www.shadertoy.com/view/lt3Gz8

float DE_FLOWER(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float4 q = float4(pos, 1);
    float4 juliaOffset = float4(control.julia,0);
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for(int i = 0; i < control.isteps; ++i) {  //kaliset fractal with no mirroring offset
        q.xyz = abs(q.xyz);
        float r = dot(q.xyz, q.xyz);
        q /= clamp(r, 0.0, control.cx);
        
        q = 2.0 * q - juliaOffset;
        
        ot = q.xyz;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return (length(q.xy)/q.w - 0.003); // cylinder primative instead of a sphere primative.
#endif
}

//MARK: - 16 SpiralBox
// SpiralBox : https://fractalforums.org/fragmentarium/17/last-length-increase-colouring-well-sort-of/2515

float DE_SPIRALBOX(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float3 z = pos;
    float r,DF = 1.0;
    float3 offset = (control.juliaboxMode ? control.julia/10 : pos);
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for(int i=0; i < control.isteps; ++i) {
        z.xyz = clamp(z.xyz, -control.cx, control.cx)*2. - z.xyz;
        
        r = dot(z,z);
        if (r< 0.001 || r> 1000.) break;
        
        z/=-r;
        DF/= r;
        z.xz *= -1.;
        z += offset;
        
        ot = z;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    r = length(z);
    return 0.5 * sqrt(0.1*r) / (abs(DF)+1.);
#endif
}

//MARK: - 17 Surfbox
// Surfbox : http://www.fractalforums.com/amazing-box-amazing-surf-and-variations/httpwww-shaperich-comproshred-elite-review/

float surfBoxFold(float v, float fold, float foldModX) {
    float sg = sign(v);
    float folder = sg * v - fold; // fold is Tglad's
    folder += abs(folder);
    folder = min(folder, foldModX); // and Y,Z,W
    v -= sg * folder;
    
    return v;
}

float DE_SURFBOX(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float3 c = control.juliaboxMode ? control.julia : pos;
    float r2,dr = control.fx;
    float fR2 = control.cz * control.cz;
    float mR2 = control.cw * control.cw;
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for(int i = 0; i < control.isteps; ++i) {
        pos.x = surfBoxFold(pos.x,control.cx,control.dx);
        pos.y = surfBoxFold(pos.y,control.cx,control.dx);
        pos.z = surfBoxFold(pos.z,control.cx,control.dx);
        
        r2 = pos.x*pos.x + pos.y*pos.y + pos.z*pos.z;
        
        if(r2 < mR2) {
            float temp = fR2 / mR2;
            pos *= temp;
            dr *= temp;
        }
        else if(r2 < fR2) {
            float temp = fR2 / r2;
            pos *= temp;
            dr *= temp;
        }
        
        pos = pos * control.fx + c;
        dr *= control.fx;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return length(pos)/abs(dr);
#endif
}

//MARK: - 18 Twistbox
// Twistbox: http://www.fractalforums.com/amazing-box-amazing-surf-and-variations/twistbox-spiralling-1-scale-box-variant/

float DE_TWISTBOX(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float3 c = control.juliaboxMode ? control.julia : pos;
    float r,DF = control.fx;
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for(int i = 0; i < control.isteps; ++i) {
        pos = clamp(pos, -control.cx,control.cx)*2 - pos;
        
        r = dot(pos,pos);
        if(r< 0.001 || r> 1000.) break;
        pos/=-r;
        DF/= r;
        pos.xz *= -1;
        pos += c;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    r = length(pos);
    return 0.5 * sqrt(r)/(abs(DF)+1);
#endif
}

//MARK: - 19 Vertebrae

#define scalelogx  control.dx
#define scalelogy  control.dy
#define scalelogz  control.dz
#define scalesinx  control.dw
#define scalesiny  control.ex
#define scalesinz  control.ey
#define offsetsinx control.ez
#define offsetsiny control.ew
#define offsetsinz control.fx
#define slopesinx  control.fy
#define slopesiny  control.fz
#define slopesinz  control.fw

float DE_VERTEBRAE(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float4 c = 0.5 * float4(control.cx, control.cy, control.cz, control.cw);
    float4 nz;
    float md2 = 1.0;
    float4 z = float4(pos,0);
    float mz2 = dot(z,z);
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for(int i=0;i < control.isteps; ++i) {
        md2 *= 4.0 * mz2;
        nz.x = z.x * z.x - dot(z.yzw,z.yzw);
        nz.yzw = 2.0 * z.x * z.yzw;
        z = nz+c;
        
        z.x = scalelogx*log(z.x + sqrt(z.x*z.x + 1.));
        z.y = scalelogy*log(z.y + sqrt(z.y*z.y + 1.));
        z.z = scalelogz*log(z.z + sqrt(z.z*z.z + 1.));
        z.x = scalesinx*sin(z.x + offsetsinx)+(z.x*slopesinx);
        z.y = scalesiny*sin(z.y + offsetsiny)+(z.y*slopesiny);
        z.z = scalesinz*sin(z.z + offsetsinz)+(z.z*slopesinz);
        
        mz2 = dot(z,z);
        if(mz2 > 12.0) break;
        
        ot = z.xyz;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return 0.3 * sqrt(mz2/md2) * log(mz2);
#endif
}

//MARK: - 20 DarkSurf

#define scale_43 control.cx
#define MinRad2_43 control.cy
#define Scale_43 control.cz
#define fold_43 control.v3a
#define foldMod_43 control.v3b

float DE_DARKSURF(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float absScalem1 = abs(Scale_43 - 1.0);
    float AbsScaleRaisedTo1mIters = pow(abs(Scale_43), float(1-control.isteps));
    
    float4 p = float4(pos,1), p0 = p;  // p.w is the distance estimate
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for(int i=0;i < control.isteps; ++i) {
        p.xyz = rotatePosition(p.xyz,0,control.angle1);
        p.xyz = rotatePosition(p.xyz,1,control.angle1);
        
        //dark-beam's surfboxfold ported by mclarekin-----------------------------------
        float3 sg = p.xyz; // or 0,0,0
        sg.x = sign(p.x);
        sg.y = sign(p.y);
        sg.z = sign(p.z);
        
        float3 folder = p.xyz; // or 0,0,0
        float3 Tglad = abs(p.xyz + fold_43) - abs(p.xyz - fold_43) - p.xyz;
        
        folder.x = sg.x * (p.x - Tglad.x);
        folder.y = sg.y * (p.y - Tglad.y);
        folder.z = sg.z * (p.z - Tglad.z);
        
        folder = abs(folder);
        
        folder.x = min(folder.x, foldMod_43.x);
        folder.y = min(folder.y, foldMod_43.y);
        folder.z = min(folder.z, foldMod_43.z);
        
        p.x -= sg.x * folder.x;
        p.y -= sg.y * folder.y;
        p.z -= sg.z * folder.z;
        //----------------------------------------------------------
        
        float r2 = dot(p.xyz, p.xyz);
        p *= clamp(max(MinRad2_43/r2, MinRad2_43), 0.0, 1.0);
        p = p * scale_43 + p0;
        if ( r2>1000.0) break;
        
        ot = p.xyz;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return ((length(p.xyz) - absScalem1) / p.w - AbsScaleRaisedTo1mIters);
#endif
}

//MARK: - 21 Sponge
// Sponge : https://www.shadertoy.com/view/3dlXWn

float sdSponge(float3 z,device Control &control) {
    z *= control.ey; //3;
    //folding
    for (int i=0; i < 4; i++) {
        z = abs(z);
        z.xy = (z.x < z.y) ? z.yx : z.xy;
        z.xz = (z.x < z.z) ? z.zx : z.xz;
        z.zy = (z.y < z.z) ? z.yz : z.zy;
        z = z * 3.0 - 2.0;
        z.z += (z.z < -1.0) ? 2.0 : 0.0;
    }
    
    //distance to cube
    z = abs(z) - float3(1.0);
    float dis = min(max(z.x, max(z.y, z.z)), 0.0) + length(max(z, 0.0));
    //scale cube size to iterations
    return dis * 0.2 * pow(3.0, -3.0);
}

float DE_SPONGE(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
#define param_min control.v4a
#define param_max control.v4b
    float k, r2;
    float scale = 1.0;
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for (int i=0; i < control.isteps; i++) {
        pos = 2.0 * clamp(pos, param_min.xyz, param_max.xyz) - pos;
        r2 = dot(pos, pos);
        k = max(param_min.w / r2, 1.0);
        pos *= k;
        scale *= k;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    pos /= scale;
    pos *= param_max.w * control.ex;
    return float(0.1 * sdSponge(pos,control) / (param_max.w * control.ex));
#endif
}

//MARK: - 22 Donuts
// Donuts : https://www.shadertoy.com/view/lttcWn

float DE_DONUTS(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
#define MAJOR_RADIUS control.cx
#define MINOR_RADIUS control.cy
#define SCALE        control.cz
    float3 n = -float3(control.dx,0,control.dy);
    float dis = 1e20;
    float newdis,s = 1.;
    float2 q;
    
    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;
    
    for (int i=0; i < control.isteps; i++) {
        q = float2(length(pos.xz) - MAJOR_RADIUS,pos.y);
        
        newdis = (length(q)-MINOR_RADIUS)*s;
        if(newdis<dis) dis = newdis;
        
        //folding
        pos.xz = abs(pos.xz);//fold to positive quadrant
        if(pos.x < pos.z) pos.xz = pos.zx;//fold 45 degrees
        pos -= 2. * min(0.,dot(pos, n)) * n;//fold 22.5 degrees
        
        //rotation
        pos.yz = float2(-pos.z,pos.y);
        
        //offset
        pos.x -= MAJOR_RADIUS;
        
        //scaling
        pos *= SCALE;
        s /= SCALE;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return dis;
#endif
}

//MARK: - 23 PDOF
// PDOF : https://fractalforums.org/fragmentarium/17/fragm-2-5-5/4006/msg26494#msg26494

float DE_PDOF(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION_disabled
    return 0;
#else
    float DEfactor = 1;
    float3 ap;

    float3 ot,trap = control.otFixed;
    if(control.orbitStyle == 2) trap -= pos;

    for(int i=0; i < control.isteps; ++i) {
        ap = pos;
        pos = control.dx * clamp(pos, -control.cx, control.cx) - pos;
        
        float r2=dot(pos,pos);
        orbitTrap = min(orbitTrap, abs(float4(pos,r2)));
        
        float k = max(control.cy/r2, 1.0);
        pos *= k;
        DEfactor *= k;
        
        if(control.juliaboxMode)
            pos += control.julia;
        
        ot = pos * 0.1;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return abs(0.5 * abs(pos.z - control.cz)/DEfactor - control.cw);
#endif
}

//MARK: - 24 MagnetoBulb

float DE_MAGNETO(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION_disabled
    return 0;
#else
    float p0 = control.cx;
    float4 z = float4(fmod(pos, control.cy),  control.dx);
    for(int i=0; i < control.isteps; ++i) {
        z.xyz = clamp(z.xyz, -p0, p0) * control.cw - z.xyz;
        z *= control.cz / max(dot(z.xyz, z.xyz), 0.0);
        
        p0 *= control.dy;
    }
    
    return (length(max(abs(z.xyz) - float3(0.0, 20.0, 0.0), 0.0))) / z.w;
#endif
}

//MARK: - 25 Spuds2018
// https://www.shadertoy.com/view/ltjBRz

float spuds2018_apollonian(float3 p,device Control &control)
{
    float scale = 1.0;
    
    for( int i=0; i < control.isteps;i++) {
        p = -1.0 + 2.0*fract(0.5*p+0.5);
        float r2 = dot(p,p);
        float k = 2./ r2;
        p *= k;
        scale *= k;
    }
    
    return 0.25*abs(p.y)/scale;
}

float boundingBox(float3 p, float3 b)
{
    float3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float DE_SPUDS2018(float3 p,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    p = rotatePosition(p,1,control.cx);
    float d0 = spuds2018_apollonian(p * 0.5,control) * control.dz;
    float d1=abs(p.y + 0.2);
    float d3 = boundingBox(p + float3(0.,control.cy,0.),
                           control.cz * float3(control.cw,control.dx,control.dy));
    float d = max(d0, d3);
    return min(d,d1);
#endif
}

//MARK: - 26 KaleidoScope

float DE_KALEIDO(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    int i;
    
    float3 ot,trap = control.otFixed;
    if(int(control.orbitStyle + 0.5) == 2) trap -= pos;
    
    for(i=0;i < control.isteps; ++i) {
        pos = rotatePosition(pos,0,control.angle1);
        
        pos = abs(pos);
        if(pos.x - pos.y < 0.0) pos.xy = pos.yx;
        if(pos.x - pos.z < 0.0) pos.xz = pos.zx;
        if(pos.y - pos.z < 0.0) pos.zy = pos.yz;
        
        pos -= 0.5 * control.cz * (control.cx - 1) / control.cx;
        pos = -abs(-pos);
        pos += 0.5 * control.cz * (control.cx - 1) / control.cx;
        
        pos = rotatePosition(pos,1,control.angle2);
        pos = pos * control.cx - control.v3a * (control.cx - 1.0);
        if(length(pos) > 4) break;
        
        ot = pos;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return (length(pos) - 2) * pow(control.cx, -float(i));
#endif
}

//MARK: - 27 MandelNest

float DE_MANDELNEST(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef zzzSINGLE_EQUATION
    return 0;
#else
    float jk,r,dr = 1;
    float fx = control.fx;
    float shift = control.cx;
    float3 julia = control.julia;
//    float3 deltaJulia = float3(control.dx,control.dy,control.dz);
    
    for(int i=0; i < control.isteps; ++i) {
        r = length(pos);
        if(r > 3) break;
        
        if(r < abs(dr))
                pos = sin(shift + fx * asin(pos/r));
         else
             pos = cos(shift + fx * acos(pos/r));

//        if(control.bcx && !(i & 2)) {
//            pos = sin(shift + fx * atan(pos/r));
//        } else {
//            pos = cos(shift + fx * atan(pos/r));
//        }
        
        dr = pow(r, fx - 1.0) * fx * dr + 1.0;

        jk = r * control.dy;
        
        pos *= pow(jk,fx);
        pos += control.juliaboxMode ? julia : pos;
        
        shift += control.angle1;
        fx += control.angle2;
        
        if(control.juliaboxMode)
            julia = mix(julia,pos,control.dx); //deltaJulia;

        float4 hk = float4(pos,r);
        orbitTrap = min(orbitTrap, dot(hk,hk));
    }
    
    return control.dz * log(r) * r/dr;
#endif
}

/*
 float DE_MANDELNEST(float3 pos,device Control &control,thread float4 &orbitTrap) {
 #ifdef zzzSINGLE_EQUATION
     return 0;
 #else
     float r,dr = 1;
     float fx = control.fx;
     float shift = control.cx;
     float3 julia = control.julia;
     float3 deltaJulia = float3(control.dx,control.dy,control.dz);
     
     for(int i=0; i < control.isteps; ++i) {
         r = length(pos);
         if(r > 3) break;
         
         if(control.bcx && !(i & 2)) {
             pos = sin(shift + fx * asin(pos/r));
         } else {
             pos = cos(shift + fx * acos(pos/r));
         }
         
         pos *= pow(r,fx);
         pos += control.juliaboxMode ? julia : pos;
         
         dr = pow(r, fx - 1.0) * fx * dr + 1.0;
         
         shift += control.angle1;
         fx += control.angle2;
         
         if(control.juliaboxMode)
             julia += deltaJulia;

         float4 hk = float4(pos,r);
         orbitTrap = min(orbitTrap, dot(hk,hk));
     }
     
     return 0.25 * log(r) * r/dr;
 #endif
 }

 */

//MARK: - 28 Kali Rontgen
// https://www.shadertoy.com/view/XlXcRj

float DE_KALI_RONTGEN(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float d = 10000.;
    float4 p = float4(pos, 1.);
    float3 param = float3(control.cx,control.cy,control.cz);
    
    float3 ot,trap = control.otFixed;
    if(int(control.orbitStyle + 0.5) == 2) trap -= pos;
    
    for(int i = 0; i < control.isteps; ++i) {
        p = abs(p) / dot(p.xyz, p.xyz);
        
        d = min(d, (length(p.xy - float2(0,.01))-.03) / p.w);
        if(d > 4) break;
        
        p.xyz -= param;
        p.xyz = rotatePosition(p.xyz,1,control.angle1);
        
        ot = p.xyz;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }
    
    return d;
#endif
}

//MARK: - 29 Engine
// https://www.shadertoy.com/view/ttSBRm

float DE_ENGINE(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
//    #define hash(n) fract(sin(n * 234.567+123.34))
#define hash(n) fract(sin(n * control.cx + control.cy))
    float scale = control.dy;
    float mr2 =  control.dz;
    float s=3.;

    pos -= clamp(pos,-control.cz,control.cz) * 2;
    pos.xy *= rotatePosition2(pos.xy,control.angle1);
    pos.yz *= rotatePosition2(pos.yz,control.angle2);
    
    
    float3 p0 = pos;
    pos = abs(pos + pos * control.dw);
    p0 = pos;
    
    float g; // ,loopEnd = 4.+ hash(seed)*6.;
    
    for(int i = 0; i < control.isteps; ++i) {
        pos = control.cw - abs(pos -control.cw);
        g = clamp(mr2*max(1.2/dot(pos,pos),1.),0.,1.);
        pos = pos * scale * g + p0 * control.dx;
        s = s * abs(scale) * g + control.dx;
    }

    return length(cross(pos,normalize(float3(1))))/s-.005;
#endif
}

//MARK: - 30 FRACTAL_CAGE
//https://www.shadertoy.com/view/3l2yDd

#define R(p,a,r) mix(a*dot(p,a),p,cos(r))+sin(r)*cross(p,a)

float DE_FRACTAL_CAGE(float3 p,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float lp,r2,s = 1;
    float icy = 1.0 / control.cy;
    float3 p2,cy3 = float3(control.cy);

    for (int i=0; i<control.isteps; i++) {
        p -= control.cx * round(p / control.cx);

        p2 = pow(abs(p),cy3);
        lp = pow(p2.x + p2.y + p2.z, icy);

        r2 = control.dx / max( pow(lp,control.cz), control.cw);
        p *= r2;
        s *= r2;
    }
    return length(p)/s-.001;
#endif
}

//MARK: - 31 GAZ_42
// https://www.shadertoy.com/view/Nss3WB

float DE_GAZ_42(float3 p,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float e,s = 1.5;
    float3 q = p;
    
    for (int i=0; i<control.isteps; i++) {
        p=sign(p)*(control.cx - abs(p - control.cx));
        e = control.cy/clamp(dot(p,p),control.cz,control.cz+control.cw);
        p = p * e + q;
        s *= e;
        
        orbitTrap = min(orbitTrap, float4(abs(p), dot(p,p)));
    }
    return length(p)/ s - 0.001;
#endif
}

//MARK: - 32 BONEY
// boney tunnel  https://www.shadertoy.com/view/3sGXzD

float DE_BONEYTUNNEL(float3 z,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    vec3 offset = z;
    float dr = 1.0;
    float fd = 0.0;
    float fl = control.cx;
    float fr = control.cy;
    float r,r2,scale = control.cw;

    float3 ot,trap = control.otFixed;
    if(int(control.orbitStyle + 0.5) == 2) trap -= z;

    for (int i=0; i<control.isteps; i++) {
        // box_fold
        z = clamp(z, -fl, fl) * 2.0 - z;

        // sphere_fold
        r2 = dot(z,z);

        if(r2 < control.cz) {
            float temp = (fr / control.cz);
            z *= temp;
            dr *= temp;
        } else
            if(r2 < fr) {
                float temp = (fr / r2);
                z *= temp;
                dr *= temp;
            }

        z = scale * z + offset;
        dr = dr * abs(scale) + 1.0;

        if(i < control.icx) { // torus
            vec2 q = vec2(length(z.xz) - control.dy ,z.y);
            r = length(q) - control.dz;
        }
        else { // sphere
            r = length(z) - control.dx;
        }

        float dd = r / abs(dr);
        if (i < 3 || dd < fd) fd = dd;
        
        ot = z;
        if(control.orbitStyle > 0) ot -= trap;
        orbitTrap = min(orbitTrap, float4(abs(ot), dot(ot,ot)));
    }

    return fd;
#endif
}

//MARK: - 33 GAZ_19
// https://www.shadertoy.com/view/WttfWM
//https://www.shadertoy.com/view/3ttBWn

float DE_GAZ_19(float3 p,device Control &control,thread float4 &orbitTrap) {
#ifdef SINGLE_EQUATION
    return 0;
#else
    float s=2.;
    for(int j=0;j < control.isteps;++j) {
        p = abs(p - control.cx) - control.cy;
        p.z > p.x ? p = p.zyx:p;
        p.y > p.z ? p = p.xzy:p;
        p.z = abs(p.z)- control.cz * sin(p.z) / s;
        p.y += control.cw * sin(p.y) / s;
        p.x -= p.y * control.dx * sin(p.x) / s;
        
//        p = 3 * p - vec3(9,2,3);
        p = control.dy * p - vec3(control.ex,control.ey,control.ez);
        s *= 3; // control.dz;

        orbitTrap = min(orbitTrap, float4(abs(p), dot(p,p)));
    }

    return length(p)/ s - 0.001;
#endif
}



float planet_surface(vec3 p,float i,float size){
    vec3 p1 = p/size;
    p = (sin(sin(p1)+p1))*size;
    return length(p) - size;
}

////MARK: - 34 Space Station
//// https://www.shadertoy.com/view/tddfDr
//
//float DE_RADIOBASE(float3 p,device Control &control,thread float4 &orbitTrap) {
//#ifdef zzzSINGLE_EQUATION
//    return 0;
//#else
//    float p1,scale = control.cx;
//    float result = 0.0;
//    float i = 1.0;
//
//    for(int i1=0;i1 < control.isteps;++i1) {
////        p1 = planet_surface(p*i,i,control.cy)/(i);
//
//        vec3 p2 = p * i / control.cy;
//        vec3 p3 = i1 & 1 ? cos(sin(p2) + p2) : sin(cos(p2) + p2);
//        p3 *= control.cz;
//        p1 = (length(p3) - control.cw) / i;
//
//        p += rotatePosition(p,0,control.dy);
//        p += rotatePosition(p,1,control.dz);
//
//
//        result = max(result, -p1);
//        i *= -5.0;
//
//        orbitTrap = min(orbitTrap, float4(abs(p), dot(p,p)));
//    }
//
//    return result * scale/2.0;
//#endif
//}


// //MARK: - 34 Space Station
// // https://www.shadertoy.com/view/tddfDr
//
// float DE_RADIOBASE(float3 p,device Control &control,thread float4 &orbitTrap) {
// #ifdef zzzSINGLE_EQUATION
//     return 0;
// #else
//     float p1,scale = control.cx;
//     float result = 0.0;
//     float scale2 = 1.0;
//
//     for(int i1=0;i1 < control.isteps;++i1) {
// //        p1 = planet_surface(p*i,i,control.cy)/(i);
//
//         vec3 p2 = p * scale / control.cy;
//         vec3 p3 = sin(sin(p2) + p2) * control.cz;
//         p1 = (length(p3) - control.cw) / scale;
//
//         result = max(result, -p1);
//         scale *= scale2;
//         scale2 *= control.dx;
//
// //        p += rotatePosition(p,0,control.dy);
// //        p += rotatePosition(p,1,control.dz);
//         p += control.julia;
//
//         orbitTrap = min(orbitTrap, float4(p3, dot(p2,p2)));
//     }
//
//     return result * scale/2.0;
// #endif
// }

/*
 
 //MARK: - 34 Space Station
 // https://www.shadertoy.com/view/tddfDr

 float DE_RADIOBASE(float3 p,device Control &control,thread float4 &orbitTrap) {
 #ifdef zzzSINGLE_EQUATION
     return 0;
 #else
     float p1,scale = control.cx;
     float result = 0.0;
     float scale2 = 1.0;

     for(int i1=0;i1 < control.isteps;++i1) {
 //        p1 = planet_surface(p*i,i,control.cy)/(i);
         
         vec3 p2 = p * scale / control.cy;
         vec3 p3 = sin(sin(p2) + p2) * control.cz;
         p1 = (length(p3) - control.cw) / scale;

         result = max(result, -p1);
         scale *= scale2;
         scale2 *= control.dx;
         
 //        p += rotatePosition(p,0,control.dy);
 //        p += rotatePosition(p,1,control.dz);
         p += control.julia;

         orbitTrap = min(orbitTrap, float4(p3, dot(p2,p2)));
     }

     return result * scale/2.0;
 #endif
 }

 */


//MARK: - 34 Radio Base
// https://www.shadertoy.com/view/WlcczS

float DE_RADIOBASE(float3 pos,device Control &control,thread float4 &orbitTrap) {
#ifdef zzzSINGLE_EQUATION
    return 0;
#else
    float r,s = 1;
    float3 p = pos;
    float3 offset = p * control.cx;

    for(int i=0;i < control.isteps;++i) {
        p = control.cy - abs(sin(p - control.cz) - control.cw);

        r = control.dx * clamp(control.dy * max(control.dz / dot(p,p),control.dw), -control.ex, control.ex);
        s *= r;
        p *= r;
        p += offset;

        orbitTrap = min(orbitTrap, float4(abs(p), dot(p,p)));
    }

    return length(cross(p,normalize(float3(control.ey,control.ez,control.ew))))/s - 0.006;
#endif
}

// new
//float DE_RADIOBASE(float3 pos,device Control &control,thread float4 &orbitTrap) {
//#ifdef zzzSINGLE_EQUATION
//    return 0;
//#else
//    float r,s = 1;
//    float3 p = pos;
//    float3 offset = p * control.cx;
//
//    for(int i=0;i < control.isteps;++i) {
//        p = control.cy - abs(abs(p - control.cz) - control.cw);
//
//        r = control.dx * clamp(control.dy * max(control.dz / dot(p,p),control.dw), 0.0, control.ex);
//        s *= r;
//        p *= r;
//        p += offset;
//
//        orbitTrap = min(orbitTrap, float4(abs(p), dot(p,p)));
//    }
//
//    return length(cross(p,normalize(float3(control.ey,control.ez,control.ew))))/s - 0.006;
//#endif
//}

/*  good
 //MARK: - 34 Radio Base
 // https://www.shadertoy.com/view/WlcczS

 float DE_RADIOBASE(float3 pos,device Control &control,thread float4 &orbitTrap) {
 #ifdef zzzSINGLE_EQUATION
     return 0;
 #else
     float r,s = 4;
     float3 p = pos; //abs(pos);
     float3 offset = p * control.cx;

     for(int i=0;i < control.isteps;++i) {
         p = control.cy - abs(abs(p - control.cz) - control.cw);

         r = control.dx * clamp(control.dy * max(control.dz / dot(p,p),control.dw), 0.0, control.ex);
         s *= r;
         p *= r;
         p += offset;

         orbitTrap = min(orbitTrap, float4(abs(p), dot(p,p)));
     }

     return length(cross(p,normalize(float3(1,3,3))))/s - 0.006;
 #endif
 }

 */
//MARK: - distance estimate
// ===========================================

float DE_Inner(float3 pos,device Control &control,thread float4 &orbitTrap) {
    switch(control.equation) {
        case EQU_01_MANDELBULB  : return DE_MANDELBULB(pos,control,orbitTrap);
        case EQU_02_APOLLONIAN2 : return DE_APOLLONIAN2(pos,control,orbitTrap);
        case EQU_03_KLEINIAN    : return DE_JOSKLEINIAN(pos,control,orbitTrap);
        case EQU_04_MANDELBOX   : return DE_MANDELBOX(pos,control,orbitTrap);
        case EQU_05_QUATJULIA   : return DE_QUATJULIA(pos,control,orbitTrap);
        case EQU_06_MONSTER     : return DE_MONSTER(pos,control,orbitTrap);
        case EQU_07_KALI_TOWER  : return DE_KALI_TOWER(pos,control,orbitTrap);
        case EQU_08_GOLD        : return DE_GOLD(pos,control,orbitTrap);
        case EQU_09_SPIDER      : return DE_SPIDER(pos,control,orbitTrap);
        case EQU_10_KLEINIAN2   : return DE_KLEINIAN2(pos,control,orbitTrap);
        case EQU_11_HALF_TETRA  : return DE_HALF_TETRA(pos,control,orbitTrap);
        case EQU_12_POLYCHORA   : return DE_POLYCHORA(pos,control,orbitTrap);
        case EQU_13_QUATJULIA2  : return DE_QUATJULIA2(pos,control,orbitTrap);
        case EQU_14_SPUDS       : return DE_SPUDS(pos,control,orbitTrap);
        case EQU_15_FLOWER      : return DE_FLOWER(pos,control,orbitTrap);
        case EQU_16_SPIRALBOX   : return DE_SPIRALBOX(pos,control,orbitTrap);
        case EQU_17_SURFBOX     : return DE_SURFBOX(pos,control,orbitTrap);
        case EQU_18_TWISTBOX    : return DE_TWISTBOX(pos,control,orbitTrap);
        case EQU_19_VERTEBRAE   : return DE_VERTEBRAE(pos,control,orbitTrap);
        case EQU_20_DARKSURF    : return DE_DARKSURF(pos,control,orbitTrap);
        case EQU_21_SPONGE      : return DE_SPONGE(pos,control,orbitTrap);
        case EQU_22_DONUTS      : return DE_DONUTS(pos,control,orbitTrap);
        case EQU_23_PDOF        : return DE_PDOF(pos,control,orbitTrap);
        case EQU_24_MAGNETO     : return DE_MAGNETO(pos,control,orbitTrap);
        case EQU_25_SPUDS2018   : return DE_SPUDS2018(pos,control,orbitTrap);
        case EQU_26_KALEIDO     : return DE_KALEIDO(pos,control,orbitTrap);
        case EQU_27_MANDELNEST  : return DE_MANDELNEST(pos,control,orbitTrap);
        case EQU_28_KALI_RONTGEN: return DE_KALI_RONTGEN(pos,control,orbitTrap);
        case EQU_29_ENGINE      : return DE_ENGINE(pos,control,orbitTrap);
        case EQU_30_FRACTAL_CAGE: return DE_FRACTAL_CAGE(pos,control,orbitTrap);
        case EQU_31_GAZ_42      : return DE_GAZ_42(pos,control,orbitTrap);
        case EQU_32_BONEYTUNNEL : return DE_BONEYTUNNEL(pos,control,orbitTrap);
        case EQU_33_GAZ_19      : return DE_GAZ_19(pos,control,orbitTrap);
        case EQU_34_RADIOBASE   : return DE_RADIOBASE(pos,control,orbitTrap);
    }
    
    return 0;
}

float DE(float3 pos,device Control &control,thread float4 &orbitTrap) {
    if(control.doInversion) {
        pos = pos - control.InvCenter;
        float r = length(pos);
        float r2 = r*r;
        pos = (control.InvRadius * control.InvRadius / r2 ) * pos + control.InvCenter;
        
        float an = atan2(pos.y,pos.x) + control.InvAngle;
        float ra = length(pos.xy); // sqrt(pos.y * pos.y + pos.x * pos.x);
        pos.x = cos(an)*ra;
        pos.y = sin(an)*ra;
        float de = DE_Inner(pos,control,orbitTrap);
        de = r2 * de / (control.InvRadius * control.InvRadius + r * de);
        return de;
    }
    
    return DE_Inner(pos,control,orbitTrap);
}

//MARK: -
// x = distance, y = iteration count, z = average distance hop

float3 shortest_dist(float3 eye, float3 marchingDirection,device Control &control,thread float4 &orbitTrap) {
    float dist,hop = 0;
    float3 ans = float3(MIN_DIST,0,0);
    //    float secondSurface = control.secondSurface;
    int i = 0;
    
    for(; i < MAX_MARCHING_STEPS; ++i) {
        dist = DE(eye + ans.x * marchingDirection,control,orbitTrap);
        if(dist < MIN_DIST) break;
        
        ans.x += dist;
        if(ans.x >= MAX_DIST) break;
        
        // don't let average distance be driven into the dirt
        if(dist >= 0.0001) hop = mix(hop,dist,0.95);
    }
    
    ans.y = float(i);
    ans.z = hop;
    return ans;
}

float3 calcNormal(float3 pos, device Control &control) {
    float4 temp = float4(10000);
    float2 e = float2(1.0,-1.0) * control.normalOffset;
    float3 ans = normalize(e.xyy * DE( pos + e.xyy, control,temp) +
                           e.yyx * DE( pos + e.yyx, control,temp) +
                           e.yxy * DE( pos + e.yxy, control,temp) +
                           e.xxx * DE( pos + e.xxx, control,temp) );
    
    return normalize(ans);
}

//MARK: -
// boxplorer's method altered
float3 getBlinnShading(float3 normal, float3 direction, float3 light,device Control &control) {
    float3 halfLV = normalize(light + direction);
    float dif = dot(normal, light) * 0.5;
    
    dif += pow(dot(normal, halfLV), control.fz) * control.specular;
    dif = max(0.0,dif);
    
    return dif;
}

//float3 halfLV = normalize(light + direction);
//float dif = dot(normal, light) * 0.5 + 0.75;
//
//dif += pow(dot(normal, halfLV), 3) * control.specular * 4;
//dif = min(10.0,dif);

float3 lerp(float3 a, float3 b, float w) { return a + w*(b-a); }

float3 hsv2rgb(float3 c) {
    return lerp(saturate((abs(fract(c.x + float3(1,2,3)/3) * 6 - 3) - 1)),1,c.y) * c.z;
}

float3 HSVtoRGB(float3 hsv) {
    /// Implementation based on: http://en.wikipedia.org/wiki/HSV_color_space
    hsv.x = mod(hsv.x,2.*PI);
    int Hi = int(mod(hsv.x / (2.*PI/6.), 6.));
    float f = (hsv.x / (2.*PI/6.)) -float( Hi);
    float p = hsv.z*(1.-hsv.y);
    float q = hsv.z*(1.-f*hsv.y);
    float t = hsv.z*(1.-(1.-f)*hsv.y);
    if (Hi == 0) { return float3(hsv.z,t,p); }
    if (Hi == 1) { return float3(q,hsv.z,p); }
    if (Hi == 2) { return float3(p,hsv.z,t); }
    if (Hi == 3) { return float3(p,q,hsv.z); }
    if (Hi == 4) { return float3(t,p,hsv.z); }
    if (Hi == 5) { return float3(hsv.z,p,q); }
    return float3(0.);
}

//MARK: -

float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.28318 * (c*t+d));
}

float3 doPalette(float val, matrix_float4x4 pType ) {
    return palette( val ,  pType[0].xyz , pType[1].xyz , pType[2].xyz , pType[3].xyz );
}

float3 applyColoring6
(
 float3 position,
 float3 direction,
 float3 distAns,
 float3 normal,
 device Control &control)
{
    matrix_float4x4 paletteVal = matrix_float4x4
    ( 0.5 , 0.5 , 0.5 , 0,
     0.5 , 0.5 , 0.5 , 0,
     2.0 , 1.0 , 0.0 , 0,
     0.5 , 0.2 , .25 , 0
     );
    paletteVal[0].x = control.coloring1;
    paletteVal[0].y = control.coloring2;
    paletteVal[0].z = control.coloring3;
    paletteVal[1].x = control.coloring4;
    paletteVal[1].y = control.coloring5;
    paletteVal[1].z = control.coloring6;
    paletteVal[2].x = control.coloring7;
    paletteVal[2].y = control.coloring8;
    paletteVal[3].x = control.coloring9;
    paletteVal[3].y = control.coloringa;
    
    float3 refl = reflect( float3( 0. , control.coloring2 , 0. ) , normal );
    refl = normalize( refl );
    
    float reflectVal = pow( max( 0. , dot( refl , direction ) ), control.coloring1 * 50);
    float3 palCol = doPalette( distAns.x / 8, paletteVal );
    float3 refCol = doPalette( reflectVal , paletteVal ) * reflectVal;
    
    return refCol + palCol;
}

//MARK: -

float3 applyColoring7
(
 float3 p,
 float3 direction,
 float3 distAns,
 float3 normal,
 device Control &control)
{
    float k,r2,col = 0;
    float kMax = control.coloring4 / 10;
    float3 p1,CSize = float3(control.coloring1,control.coloring2,control.coloring3);
    
    for( int i=0; i < control.icz;i++ ) {
        p1 = 2.0 * clamp(p, -CSize, CSize) - p;
        col += abs(p.z - p1.z);
        p = p1;
        r2 = dot(p,p);
        k = max( 1.1/r2, kMax);
        p *= k;
    }
    
    return (0.5 + 0.5 * sin(col * vec3(control.coloring5,control.coloring6,control.coloring7)));
}

//MARK: -

float3 applyColoring
(
 float3 position,
 float3 direction,
 float3 distAns,
 float3 normal,
 device Control &control)
{
    float3 cc,nn,a2,ans;
    float f1,f2,f3,f4,f5;
    
    switch(control.colorScheme) {
        case 0 :
            f1 = 1 + control.coloring1 * 100;
            f2 = 1 + control.coloring2 * 10;
            ans = float3(1 - (normal / f2 + sqrt(distAns.y / f1)));
            break;
        case 1 :
            f1 = 5 + control.coloring1 * 10;
            f2 = 5 + control.coloring2 * 20;
            f3 = 0.01 + control.coloring3 * 5;
            ans = float3(abs(1 - (normal * f3 + sqrt(distAns.y / f1)))) / f2;
            break;
        case 2 :
            f1 = 5 + control.coloring1 * 10;
            f2 = 5 + control.coloring2 * 20;
            f3 = 0.01 + control.coloring3 * 5;
            f4 = 0.01 + control.coloring4 * 6;
            f5 = control.coloring5 * 2;
            ans = float3((1 - (normal * f3 + sqrt(distAns.y / f1)))) / f2;
            cc = 0.5 + 0.5 * cos(f4 * position.z + float3(0.0,1.0,f5) );
            ans = mix(ans,cc,0.5);
            break;
        case 3 :
            f1 = 0.01 + control.coloring1 * 0.05;
            f2 = 0.01 + control.coloring2 * 0.1;
            ans = abs(normal) * f1;
            ans += HSVtoRGB(ans * distAns.y * f2);
            break;
        case 4 :
            ans = float3(1 - (normal / 10 + sqrt(distAns.y / 80)));
            ans.x = (ans.x + ans.y + ans.z)/3;
            ans.y = ans.x;
            ans.z = ans.y;
            break;
        case 5 :
            nn = normal;
            nn.x += nn.z;
            nn.y += nn.z;
            ans = hsv2rgb(normalize(0.5 - nn));
            break;
        case 6 :
            ans = applyColoring6(position,direction,distAns,normal,control);
            break;
        case 7 :
            ans = applyColoring7(position,direction,distAns,normal,control);
            break;
    }

    a2 = ans;
    ans.x = mix(a2.x,a2.y,control.coloringM1);
    ans.y = mix(a2.y,a2.z,control.coloringM2);
    ans.z = mix(a2.z,a2.x,control.coloringM3);

    return ans;
}

//MARK: -

float3 cycle(float3 c, float s, device Control &control) {
    float ss = s * control.Cycles;
    return float3(0.5) + 0.5 * float3( cos(ss + c.x), cos(ss + c.y), cos(ss + c.z));
}

float3 getOrbitColor(device Control &control,float4 orbitTrap) {
    float3 orbitColor;

    orbitTrap.w = sqrt(orbitTrap.w);
    
    if (control.Cycles > 0.0) {
        orbitColor =
        cycle(control.X.xyz, orbitTrap.x, control) * control.X.w * orbitTrap.x +
        cycle(control.Y.xyz, orbitTrap.y, control) * control.Y.w * orbitTrap.y +
        cycle(control.Z.xyz, orbitTrap.z, control) * control.Z.w * orbitTrap.z +
        cycle(control.R.xyz, orbitTrap.w, control) * control.R.w * orbitTrap.w;
    } else {
        orbitColor =
        control.X.xyz * control.X.w * orbitTrap.x +
        control.Y.xyz * control.Y.w * orbitTrap.y +
        control.Z.xyz * control.Z.w * orbitTrap.z +
        control.R.xyz * control.R.w * orbitTrap.w;
    }
    
    return orbitColor;
}

//MARK: -

kernel void rayMarchShader
(
 texture2d<float, access::write> outTexture     [[texture(0)]],
 texture2d<float, access::read> coloringTexture [[texture(1)]],
 device Control &c    [[ buffer(0) ]],
 uint2 p [[thread_position_in_grid]]
 )
{
    uint2 srcP = p; // copy of pixel coordinate, altered during radial symmetry
    if(srcP.x >= uint(c.xSize)) return; // screen size not evenly divisible by threadGroups
    if(srcP.y >= uint(c.ySize)) return;
    if(c.skip > 1 && ((srcP.x % c.skip) != 0 || (srcP.y % c.skip) != 0)) return;
    
    // apply radial symmetry? ---------
    if(c.radialAngle > 0.01) { // 0 = don't apply
        float centerX = c.xSize/2;
        float centerY = c.ySize/2;
        float dx = float(p.x - centerX);
        float dy = float(p.y - centerY);
        float angle = fabs(atan2(dy,dx));
        float dRatio = 0.01 + c.radialAngle;
        
        while(angle > dRatio) angle -= dRatio;
        if(angle > dRatio/2) angle = dRatio - angle;
        
        float dist = sqrt(dx * dx + dy * dy);
        
        srcP.x = uint(centerX + cos(angle) * dist);
        srcP.y = uint(centerY + sin(angle) * dist);
    }
    
    uint2 q = srcP;                 // copy of current pixel coordinate; x is altered for stereo
    unsigned int xsize = c.xSize;   // copy of current window size; x is altered for stereo
    float3 camera = c.camera;       // copy of camera position; x is altered for stereo
    
    if(c.isStereo) {
        xsize /= 2;                 // window x size adjusted for 2 views side by side
        float3 offset = c.sideVector * c.parallax;
        
        if(srcP.x >= xsize) {   // right side of stereo pair?
            q.x -= xsize;       // base 0  X coordinate
            camera -= offset;   // adjust for right side parallax
        }
        else {
            camera += offset;   // adjust for left side parallax
        }
    }
    
    float3 color = float3();
    float4 orbitTrap = float4(10000.0);
    
    float den = float(xsize);
    float dx =  1.5 * (float(q.x)/den - 0.5);
    float dy = -1.5 * (float(q.y)/den - 0.5);
    float3 direction = normalize((c.sideVector * dx) + (c.topVector * dy) + c.viewVector);
    
    float3 distAns = shortest_dist(camera,direction,c,orbitTrap);
    
    ////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////
    // billboards

    bool billboard = false;
    
    for(int i=0;i<NUM_BILLBOARD;++i) {
        device BillboardData &bb = c.billboard[i];
        if(!bb.active) continue;

        if(distAns.x > bb.z) {
            float pixelX = float(q.x) / float(c.xSize);
            float pixelY = float(q.y) / float(c.ySize);
            float x1 = max(0.0, bb.x);
            float x2 = min(1.0, x1 + bb.xs);
            float y1 = max(0.0, bb.y);
            float y2 = min(1.0, y1 + bb.ys);
            
            if(c.isStereo) {
                float distanceFactor = 1 / (1 + (bb.z - 0.5) * 0.667);
                float offset = c.sideVector.x * c.parallax * distanceFactor * c.billboard[i].fudge;
//junk                float distanceFactor = 2 - bb.z * 0.667;
//                float offset = c.sideVector.x * pow(c.parallax,distanceFactor);

                x1 *= 0.5;
                x2 *= 0.5;
                
                if(q.x >= xsize) {   // right side of stereo pair
                    pixelX -= 0.5;
                    x1 -= offset;
                    x2 -= offset;
                }
                else {
                    x1 += offset;
                    x2 += offset;
                }
            }
            
            if(pixelX >= x1 && pixelX < x2 && pixelY >= y1 && pixelY < y2) {
                if(c.txtOnOff) {
                    uint2 pt;
                    float ratioU = (pixelX - x1) / (x2-x1);
                    float ratioV = (pixelY - y1) / (y2-y1);
                    float u = bb.u1 + ratioU * (bb.u2 - bb.u1);
                    float v = bb.v1 + ratioV * (bb.v2 - bb.v1);

                    pt.x = uint(c.txtSize.x * u);
                    pt.y = uint(c.txtSize.y * v);
                    
                    float4 cc = coloringTexture.read(pt);
                    if(cc.w > 0.1) {
                        billboard = true;
                        color = cc.xyz;
                    }
                }
                else {
                    billboard = true;
                    color = vector_float3(1,1,1);
                }
            }
        }
    }
    
    
//    bool billboard = false;
//
//    if(distAns.x > c.fw) {
//        float rx = float(q.x) / float(c.xSize);
//        float ry = float(q.y) / float(c.ySize);
//        float x1 = 0.35;
//        float x2 = 1;
//        float y1 = 0.3;
//        float y2 = 0.7;
//
//        if(c.isStereo) {
//            float distanceFactor = 1 / (1 + c.fw * 0.667);
//            float offset = (c.sideVector * c.parallax).x * distanceFactor;
//
//            x1 *= 0.5;
//            x2 *= 0.5;
//
//            if(q.x >= xsize) {   // right side of stereo pair
//                rx -= 0.5;
//                x1 -= offset;
//                x2 -= offset;
//            }
//            else {
//                x1 += offset;
//                x2 += offset;
//            }
//        }
//
//        if(rx >= x1 && rx < x2 && ry >= y1 && ry < y2) {
//            billboard = true;
//
//            if(c.txtOnOff) {
//                uint2 pt;
//                float u,v;
//                u = (rx - x1) / (x2-x1);
//                v = (ry - y1) / (y2-y1);
//
//                pt.x = uint(c.txtSize.x * u);
//                pt.y = uint(c.txtSize.y * v);
//
//                float4 cc = coloringTexture.read(pt);
//                if(cc.w > 0.1)
//                    color = cc.xyz;
//                else
//                    billboard = false;
//            }
//            else
//                color = float3(255,0,255);
//        }
//    }

    
    ////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////

    if (!billboard && distAns.x <= MAX_DIST) { // hit object
        float3 position = camera + distAns.x * direction;
        float3 normal = calcNormal(position,c);
        
//        // use texture
//        if(c.txtOnOff) {
//            float xscale = abs(c.tScale);
//            float yscale = c.tScale < 0 ? -xscale : xscale;
//            float len = length(position) / distAns.x;
//            float x = normal.x / len;
//            float y = normal.z / len;
//            float w = c.txtSize.x;
//            float h = c.txtSize.y;
//            float xx = w + (c.tCenterX * 4 + x * xscale) * (w + len);
//            float yy = h + (c.tCenterY * 4 + y * yscale) * (h + len);
//
//            uint2 pt;
//            pt.x = uint(fmod(xx,w));
//            pt.y = uint(c.txtSize.y - fmod(yy,h)); // flip Y coord
//
//            color = coloringTexture.read(pt).xyz;
//        }
        
        color += applyColoring(position,direction,distAns,normal,c);
        
        // second surface
        if(c.secondSurface > 0) {
            if(c.refractAmount > 0)
                direction = refract(direction, normal / 10,c.refractAmount - 0.5);
            
            float3 distAns2 = shortest_dist(position + direction * c.secondSurface,direction,c,orbitTrap);
            
            distAns = mix(distAns,distAns2,c.transparentAmount);
            position = camera + distAns.x * direction;
            normal = calcNormal(position,c);
            
            float3 color2 = applyColoring(position,direction,distAns,normal,c);
            color = saturate(color + color2 * c.transparentAmount);
        }
        
        // ======================================================
        if(c.specular > 0) {
            float3 light = getBlinnShading(normal, direction, c.nlight, c);
            color = mix(light, color, c.fy); // 0.8);
        }
        
        // ======================================================
        if(c.enhance > 0) {
            float4 temp = float4(10000);
            float3 diff = c.viewVector * distAns.y / 10;
            float d1 = DE(position - diff,c,temp);
            float d2 = DE(position + diff,c,temp);
            float d3 = d1-d2;
            color *= (1 + (1-d3) * c.enhance);
        }
        
        // ======================================================
        color *= c.bright;
        color = saturate(0.5 + (color - 0.5) * c.contrast * 4);
        
        // ======================================================
        if(c.OrbitStrength > 0) {
            float3 oColor = getOrbitColor(c,orbitTrap);
//            color = mix(color, 3.0 * oColor, c.OrbitStrength);
            color = mix(color, oColor, c.OrbitStrength);
        }
        
        // ======================================================
        if(c.fog > 0) {
            float3 backColor = float3(c.fogR,c.fogG,c.fogB);
            color = mix(color, backColor, 1.0-exp(-pow(c.fog,4.0) * distAns.x * distAns.x));
        }
        
        // ======================================================
        for(int i=0;i<NUM_LIGHT;++i) {
            if(c.flight[i].bright > 0) {
                float distance = 0.001 + length_squared(c.flight[i].pos - position) * c.flight[i].fx;
                float intensity = max(float(c.flight[i].bright * dot(normal, c.flight[i].nrmPos) / distance),float(0));
                color += c.flight[i].color * intensity;
                color = saturate(color);
            }
        }
    }
//    else { // missed object
//
//        // background color from texture
//        if(c.txtOnOff) {
//            float scale = c.tScale;
//            float x = direction.x;
//            float y = direction.z;
//            float w = c.txtSize.x;
//            float h = c.txtSize.y;
//            float xx = w + (c.tCenterX * 4 + x * scale) * w;
//            float yy = h + (c.tCenterY * 4 + y * scale) * h;
//
//            uint2 pt;
//            pt.x = uint(fmod(xx,w));
//            pt.y = uint(c.txtSize.y - fmod(yy,h)); // flip Y coord
//            color = coloringTexture.read(pt).xyz;
//        }
//    }
    
    float alpha = distAns.x;
    
    if(c.skip == 1) { // drawing high resolution final image
        outTexture.write(float4(color.xyz,alpha),p);  // depth in alpha
    }
    else { // low resolution 'quick draw'
        uint2 pp;
        for(int x=0;x<c.skip;++x) {
            pp.x = p.x + x;
            for(int y=0;y<c.skip;++y) {
                pp.y = p.y + y;
                outTexture.write(float4(color.xyz,alpha),pp);
            }
        }
    }
}

//MARK: -
/////////////////////////////////////////////////////////////////////////
// add depth of field effect
// input pixel (rgba) :  rgb = color, a = distance from camera
// control.blurFocalDistance = focal distance;   0.001 ... 4
// control.blurStrength = size of color averaging effect;  1 ... 500

kernel void effectsShader
(
 texture2d<float, access::read> inTexture       [[texture(0)]],
 texture2d<float, access::write> outTexture     [[texture(1)]],
 device Control &control                        [[buffer(0)]],
 uint2 p [[thread_position_in_grid]]
 )
{
    const int2 oList[] = { {-1,-1}, {0,-1}, {1,-1}, {-1,0}, {+1,0}, {-1,+1}, {0,+1}, {+1,+1} };
    
    float4 color = inTexture.read(p);
    int maxWidth = int(abs(color.a - control.blurFocalDistance) * control.blurStrength);
    
    if(maxWidth < 2) {
        outTexture.write(color,p);
        return;
    }
    
    float4 total = color;
    int bCount = 1;
    int2 q;
    
    for(int w = 1;w <= maxWidth; ++w) {
        for(int i=0;i<8;++i) {
            q = int2(p);
            q += oList[i] * w;
            q.x = max(q.x,0);   q.x = min(q.x,control.xSize-1);
            q.y = max(q.y,0);   q.y = min(q.y,control.ySize-1);
            
            total += inTexture.read(uint2(q));
            bCount += 1;
        }
    }
    
    total /= float(bCount);
    
    if(control.blurDim > 0) 
        total *= (1.0 - control.blurDim/10);
    
    outTexture.write(total,p);
}


//MARK: -
/////////////////////////////////////////////////////////////////////////

kernel void normalShader
(
 device TVertex* v [[ buffer(0) ]],
 uint2 p [[thread_position_in_grid]])
{
    if(p.x >= SIZE3D || p.y >= SIZE3D) return; // data size not evenly divisible by threadGroups
    
    int i = int(p.y) * SIZE3D + int(p.x);
    int i2 = i + ((p.x < SIZE3Dm) ? 1 : -1);
    int i3 = i + ((p.y < SIZE3Dm) ? SIZE3D : -SIZE3D);
    
    TVertex v1 = v[i];
    TVertex v2 = v[i2];
    TVertex v3 = v[i3];
    
    v[i].normal = normalize(cross(v1.position - v2.position, v1.position - v3.position));
}

/////////////////////////////////////////////////////////////////////////

struct Transfer {
    float4 position [[position]];
    float4 lighting;
    float4 color;
};

vertex Transfer texturedVertexShader
(
 constant TVertex *data     [[ buffer(0) ]],
 constant Uniforms &uniforms[[ buffer(1) ]],
 unsigned int vid [[ vertex_id ]])
{
    TVertex in = data[vid];
    Transfer out;
    
    float4 p = float4(in.position,1);
    
    if(in.height > uniforms.ceiling3D) {
        p.y = uniforms.floor3D;
        float G = 0.1;
        out.color = float4(G,G,G,1);
    }
    else {
        p.y = in.height * uniforms.yScale3D;
        out.color = in.color;
    }
    
    out.position = uniforms.mvp * p;
    
    float distance = length(uniforms.light.position - in.position.xyz);
    float intensity = uniforms.light.ambient + saturate(dot(in.normal.rgb, uniforms.light.position) / pow(distance,uniforms.light.fx) );
    out.lighting = float4(intensity,intensity,intensity,1);
    
    return out;
}

fragment float4 texturedFragmentShader
(
 Transfer data [[stage_in]])
{
    return data.color * data.lighting;
}
