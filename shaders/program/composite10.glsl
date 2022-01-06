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
#ifdef DENOISE
uniform float viewHeight, viewWidth;

uniform sampler2D colortex6;
uniform sampler2D depthtex0, depthtex1;

uniform mat4 gbufferProjectionInverse;
#endif

uniform sampler2D colortex1, colortex9, colortex11;

//Includes//
#ifdef DENOISE
#include "/lib/util/encode.glsl"
#include "/lib/filters/normalAwareBlur.glsl"
#endif

//Program//
void main() {
    vec3 color = texture2D(colortex1, texCoord).rgb;
    vec3 gi = texture2D(colortex11, texCoord).rgb;

    #ifdef DENOISE
    gi = NormalAwareBlur();
    #endif

    float skyLightmap = clamp(texture2D(colortex9, texCoord).b, 0.0, 1.0);

    gi *= (1.00 - skyLightmap * 0.5) * 24.0;
    color.rgb *= 1.0 + gi;

    /* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(color, 1.0);
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