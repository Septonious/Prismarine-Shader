/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

#ifdef SSPT
//Varyings//
varying vec2 texCoord;

//Uniforms//
uniform int frameCounter;

uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D colortex6, colortex10;
uniform sampler2D depthtex0, depthtex1, depthtex2;

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;

//Includes//
#include "/lib/util/encode.glsl"
#include "/lib/lighting/ssgi.glsl"

//Program//
void main() {
    float z0 = texture2D(depthtex0, texCoord.xy).x;

	vec3 screenPos = vec3(texCoord, z0);
    vec3 normal = normalize(DecodeNormal(texture2D(colortex6, texCoord.xy).xy));

    vec3 gi = computeGI(screenPos, normal, float(z0 < 0.56));

    /* RENDERTARGETS:11 */
    gl_FragData[0] = vec4(gi, 1.0);
}

#else

void main(){
    discard;
}

#endif

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Program//
void main() {
    texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif
