/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

//Uniforms//
uniform int frameCounter;

uniform float far, near;
uniform float frameTimeCounter;
uniform float viewWidth, viewHeight, aspectRatio;

uniform mat4 gbufferProjection;

uniform sampler2D depthtex0;
uniform sampler2D noisetex;

#ifdef DISTANT_HORIZONS
uniform float dhFarPlane, dhNearPlane;
uniform sampler2D dhDepthTex0;
#endif

//Common Functions//
float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

#ifdef DISTANT_HORIZONS
float GetDHLinearDepth(float depth) {
   return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - depth * (dhFarPlane - dhNearPlane));
}
#endif

//Includes//
#include "/lib/lighting/ambientOcclusion.glsl"

//Program//
void main() {
	float blueNoise = texture2D(noisetex, gl_FragCoord.xy / 512.0).b;
    float ao = AmbientOcclusion(blueNoise);

    #ifdef DISTANT_HORIZONS
    float z = texture2D(depthtex0, texCoord.xy).r;
    if (z == 1.0) {
        ao = DHAmbientOcclusion(blueNoise);
    }
    #endif
    
    /* DRAWBUFFERS:4 */
    gl_FragData[0] = vec4(ao, 0.0, 0.0, 0.0);
}

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
