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
uniform float viewWidth, viewHeight, aspectRatio;

uniform sampler2D colortex1;

//Optifine Constants//
#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
const bool colortex1MipmapEnabled = true;
#endif

#ifdef VOLUMETRIC_CLOUDS
const bool colortex8MipmapEnabled = true;
#endif

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/antialiasing/fxaa.glsl"

//Program//
void main() {
	vec3 color = texture2D(colortex1, texCoord).rgb;

	#ifdef FXAA
	color = FXAA311(color);	
	#endif

    /*DRAWBUFFERS:1*/
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