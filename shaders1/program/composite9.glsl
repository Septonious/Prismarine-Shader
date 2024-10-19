/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

#if defined SSPT

//Varyings//
varying vec2 texCoord;

//Uniforms//
#ifdef DENOISE
uniform float viewWidth, viewHeight, aspectRatio;
#endif

uniform sampler2D colortex1, colortex11;

#ifdef DENOISE
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjection;
#endif

//Optifine Constants//
const bool colortex11MipmapEnabled = true;

//Includes//
#ifdef DENOISE
#include "/lib/util/encode.glsl"
#include "/lib/filters/normalAwareBlur.glsl"
#endif

//Program//
void main() {
    vec3 gi = texture2D(colortex11, texCoord).rgb;
    vec3 color = texture2D(colortex1, texCoord).rgb;

    #ifdef DENOISE
    gi = NormalAwareBlur(colortex11).rgb;
    #endif

    #ifdef END
    gi *= 0.5;
    #endif

    color.rgb *= vec3(1.0) + gi * ILLUMINATION_STRENGTH;

    /* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(color, 1.0);
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