/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

#if defined SSGI && defined DENOISE
//Varyings//
varying vec2 texCoord;

//Uniforms//
uniform float viewWidth, viewHeight, aspectRatio;

uniform sampler2D colortex6, colortex11;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjection;

//Optifine Constants//
const bool colortex11MipmapEnabled = true;

//Includes//
#include "/lib/util/encode.glsl"
#include "/lib/filters/normalAwareBlur.glsl"

//Program//
void main() {
    vec3 gi = texture2D(colortex11, texCoord).rgb;

    gi = NormalAwareBlur(colortex11).rgb;

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
