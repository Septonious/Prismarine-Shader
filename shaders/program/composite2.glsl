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

#if defined LIGHT_SHAFT || defined VOLUMETRIC_CLOUDS
varying vec3 sunVec, upVec;
#endif

//Uniforms//
uniform float rainStrength;

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

#if defined BLUR_FILTERING || defined VOLUMETRIC_CLOUDS
uniform float viewWidth, viewHeight;
#endif

#if defined LIGHT_SHAFT || defined VOLUMETRIC_CLOUDS
uniform ivec2 eyeBrightnessSmooth;
#endif

#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
uniform sampler2D colortex1;

//Optifine Constants//
const bool colortex1MipmapEnabled = true;
#endif

//Common Variables//
#if defined LIGHT_SHAFT || defined VOLUMETRIC_CLOUDS
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;
#endif

//Includes//
#ifdef BLUR_FILTERING
#include "/lib/filters/blur.glsl"
#endif

#ifdef LIGHT_SHAFT
#include "/lib/color/waterColor.glsl"
#include "/lib/color/lightColor.glsl"
#endif

//Program//
void main() {
    vec3 color = texture2D(colortex0, texCoord.xy).rgb;

	#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
	#ifdef BLUR_FILTERING
	vec3 vl = GaussianBlur(colortex1, texCoord.xy * VOLUMETRICS_RENDER_RESOLUTION, 1.0).rgb;
	#else
	vec3 vl = texture2D(colortex1, texCoord * VOLUMETRICS_RENDER_RESOLUTION).rgb;
	#endif

	#ifdef LIGHT_SHAFT
	if (isEyeInWater != 1.0){
		#ifdef FOG_PERBIOME
		lightCol = mix(lightCol, getBiomeFog(lightCol.rgb), 0.5 * timeBrightness);
		#endif

		vl.rgb *= lightCol * 0.25;
	}
	else vl.rgb *= waterColor.rgb * 0.15 * (0.5 + eBS) * (0.25 + timeBrightness * 0.75) * (1.0 - isEyeInWater * 0.75);
    vl.rgb *= LIGHT_SHAFT_STRENGTH * shadowFade * (1.0 - blindFactor);
	#endif

	color += vl;
	#endif

	#ifdef VOLUMETRIC_CLOUDS
	vec2 newTexCoord = texCoord * VOLUMETRICS_RENDER_RESOLUTION;
    vec4 cloud1 = texture2DLod(colortex8, newTexCoord.xy + vec2( 0.0,  1 / viewHeight), 16.0);
    vec4 cloud2 = texture2DLod(colortex8, newTexCoord.xy + vec2( 0.0, -1 / viewHeight), 16.0);
    vec4 cloud3 = texture2DLod(colortex8, newTexCoord.xy + vec2( 1 / viewWidth,   0.0), 16.0);
    vec4 cloud4 = texture2DLod(colortex8, newTexCoord.xy + vec2(-1 / viewWidth,   0.0), 16.0);
    vec4 cloud = (cloud1 + cloud2 + cloud3 + cloud4) * 0.25;

	cloud.a = clamp(cloud.a, 0.0, 1.0);

	float rainFactor = 1.0 - rainStrength * 0.75;
	color.rgb = mix(color.rgb, pow(cloud.rgb, vec3(1.0 - rainStrength * 0.25)) * rainFactor, cloud.a * cloud.a);
	#endif

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(color, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

#if defined LIGHT_SHAFT || defined VOLUMETRIC_CLOUDS
varying vec3 sunVec, upVec;
#endif

//Uniforms//
#if defined LIGHT_SHAFT || defined VOLUMETRIC_CLOUDS
uniform float timeAngle;

uniform mat4 gbufferModelView;
#endif

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	#if defined LIGHT_SHAFT || defined VOLUMETRIC_CLOUDS
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	#endif
}

#endif