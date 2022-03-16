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

uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
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
#ifdef LIGHT_SHAFT
#include "/lib/color/waterColor.glsl"
#include "/lib/color/lightColor.glsl"
#endif

//Program//
void main() {
    vec3 color = texture2D(colortex0, texCoord.xy).rgb;
	vec2 newTexCoord = texCoord * VOLUMETRICS_RENDER_RESOLUTION;

	#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
	#ifdef BLUR_FILTERING
    vec3 vl1 = texture2DLod(colortex1, newTexCoord.xy + vec2( 0.0,  1.0 / viewHeight) * 3.0, 0.0).rgb;
    vec3 vl2 = texture2DLod(colortex1, newTexCoord.xy + vec2( 0.0, -1.0 / viewHeight) * 3.0, 0.0).rgb;
    vec3 vl3 = texture2DLod(colortex1, newTexCoord.xy + vec2( 1.0 / viewHeight,  0.0) * 3.0, 0.0).rgb;
    vec3 vl4 = texture2DLod(colortex1, newTexCoord.xy + vec2(-1.0 / viewHeight,  0.0) * 3.0, 0.0).rgb;
    vec3 vl = (vl1 + vl2 + vl3 + vl4) * 0.25;
	#else
	vec3 vl = texture2DLod(colortex1, newTexCoord.xy, 0.0).rgb;
	#endif

	#ifdef LIGHT_SHAFT
	float z0 = texture2D(depthtex0, texCoord).r;
    vec4 screenPos = vec4(texCoord, z0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;

	float VoL = clamp(dot(normalize(viewPos.xyz), sunVec), 0.0, 1.0);
	float scattering = 1.0 + pow4(VoL) * 2.0;

	if (isEyeInWater != 1.0){
		#ifdef FOG_PERBIOME
		lightCol = mix(lightCol, getBiomeFog(lightCol.rgb), 0.6 * timeBrightness);
		#endif

		vl.rgb *= lightCol * (0.5 + rainStrength * 0.5);
		vl.b *= 1.25 + timeBrightness * 0.75;
	}
	else vl.rgb *= sqrt(waterColor.rgb) * 0.25 * (0.25 + eBS * 0.75) * (0.25 + timeBrightness * 0.75) * (2.0 - sunVisibility);
    vl.rgb *= LIGHT_SHAFT_STRENGTH * shadowFade * (1.0 - blindFactor) * scattering;
	#endif

	color += vl;
	#endif

	#ifdef VOLUMETRIC_CLOUDS
    vec4 cloud1 = texture2DLod(colortex8, newTexCoord.xy + vec2( 0.0,  1.0 / viewHeight) * 2.0, 2.0);
    vec4 cloud2 = texture2DLod(colortex8, newTexCoord.xy + vec2( 0.0, -1.0 / viewHeight) * 2.0, 2.0);
    vec4 cloud3 = texture2DLod(colortex8, newTexCoord.xy + vec2( 1.0 / viewHeight,  0.0) * 2.0, 2.0);
    vec4 cloud4 = texture2DLod(colortex8, newTexCoord.xy + vec2(-1.0 / viewHeight,  0.0) * 2.0, 2.0);
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