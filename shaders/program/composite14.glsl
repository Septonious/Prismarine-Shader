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
uniform float viewWidth, viewHeight, aspectRatio;

uniform sampler2D colortex1;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferModelViewInverse;

uniform sampler2D colortex2;
uniform sampler2D depthtex1;

#if defined GI_ACCUMULATION && defined SSPT
uniform sampler2D depthtex0, colortex6;
#endif

//Optifine Constants//
#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
const bool colortex1MipmapEnabled = true;
#endif

//Includes//
#include "/lib/antialiasing/taa.glsl"

//Program//
void main() {
	vec3 color = texture2D(colortex1, texCoord).rgb;
    vec4 prev = vec4(texture2D(colortex2, texCoord).r, 0.0, 0.0, 0.0);

	#ifdef TAA
	prev = TemporalAA(color, prev.r, colortex1, colortex2);
	#endif

	#if defined GI_ACCUMULATION && defined SSPT
	prev = TemporalAccumulation(color, prev.r, colortex1, colortex2);
	#endif

    /*DRAWBUFFERS:12*/
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = vec4(prev);
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