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

#ifdef LIGHT_SHAFT
varying vec3 sunVec, upVec;
#endif

//Uniforms//
#if defined VOLUMETRIC_CLOUDS || defined LIGHT_SHAFT
uniform float rainStrength;
#endif

#ifdef LIGHT_SHAFT
uniform int isEyeInWater;

uniform float blindFactor;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
#endif

uniform sampler2D colortex0;

#ifdef VOLUMETRIC_CLOUDS
uniform sampler2D colortex8;
#endif

#ifdef BLUR_FILTERING
uniform float viewWidth, viewHeight;
#endif

#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D colortex1;
#endif

//Optifine Constants//
#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
const bool colortex1MipmapEnabled = true;
#endif

//Common Variables//
#ifdef LIGHT_SHAFT
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;
#endif

//Includes//
#ifdef BLUR_FILTERING
#include "/lib/filters/blur.glsl"
#endif

#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
#ifdef LIGHT_SHAFT
#include "/lib/color/waterColor.glsl"
#include "/lib/color/lightColor.glsl"
#endif
#endif

//Program//
void main() {
    vec3 color = texture2D(colortex0, texCoord.xy).rgb;

	#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
	#ifdef BLUR_FILTERING
	vec3 vl = GaussianBlur(colortex1, texCoord.xy * VOLUMETRICS_RENDER_RESOLUTION).rgb;
	#else
	vec3 vl = texture2D(colortex1, texCoord * VOLUMETRICS_RENDER_RESOLUTION).rgb;
	#endif

	#if defined LIGHT_SHAFT && defined OVERWORLD
	if (isEyeInWater != 1.0) vl.rgb *= lightCol * 0.25;
	else vl.rgb *= waterColor.rgb * 0.15 * (0.5 + eBS) * (0.25 + timeBrightness * 0.75);
    vl.rgb *= LIGHT_SHAFT_STRENGTH * (1.0 - rainStrength) * shadowFade * (1.0 - blindFactor);
	#endif

	#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
	color += vl;
	#endif
	#endif

	/* DRAWBUFFERS:08 */
	gl_FragData[0] = vec4(color, 1.0);

	#ifdef VOLUMETRIC_CLOUDS

	vec4 cloud = texture2DLod(colortex8, texCoord.xy, 2.0);

	#ifdef BLUR_FILTERING
	cloud.rgb = GaussianBlur(colortex8, texCoord.xy).rgb;
	#endif

	gl_FragData[1] = cloud;
	#endif

}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

#ifdef LIGHT_SHAFT
varying vec3 sunVec, upVec;
#endif

//Uniforms//
#ifdef LIGHT_SHAFT
uniform float timeAngle;

uniform mat4 gbufferModelView;
#endif

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	#ifdef LIGHT_SHAFT
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	#endif
}

#endif