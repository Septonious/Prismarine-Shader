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
#ifdef LIGHT_SHAFT
uniform int isEyeInWater;

uniform float rainStrength;
uniform float blindFactor;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
#endif

uniform sampler2D colortex0;

#if defined LIGHT_SHAFT || defined VOLUMETRIC_CLOUDS
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
#endif

#ifdef VOLUMETRIC_CLOUDS
uniform sampler2D colortex8;

uniform float eyeAltitude;
#endif

#if defined BLUR_FILTERING || defined VOLUMETRIC_CLOUDS
uniform float viewWidth, viewHeight;
#endif

#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
uniform sampler2D colortex1;

//Optifine Constants//
const bool colortex1MipmapEnabled = true;
#endif

//Common Variables//
#if defined LIGHT_SHAFT || defined VOLUMETRIC_CLOUDS
float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;
vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
#endif

//Includes//
#if defined BLUR_FILTERING && (defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE)
#include "/lib/filters/blur.glsl"
#endif

#ifdef LIGHT_SHAFT
#include "/lib/color/waterColor.glsl"
#include "/lib/color/lightColor.glsl"
#endif

//Program//
void main() {
    vec3 color = texture2D(colortex0, texCoord.xy).rgb;
	vec2 newTexCoord = texCoord * VOLUMETRICS_RENDER_RESOLUTION;

	#if defined LIGHT_SHAFT || defined VOLUMETRIC_CLOUDS
	float z0 = texture2D(depthtex0, texCoord).r;
    vec4 screenPos = vec4(texCoord, z0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
	#endif

	#if defined LIGHT_SHAFT || defined NETHER_SMOKE || defined END_SMOKE
	#ifdef BLUR_FILTERING
	vec3 vl = GaussianBlur(colortex1, newTexCoord, 1.0).rgb;
	#else
	vec3 vl = texture2D(colortex1, newTexCoord).rgb;
	#endif

	#ifdef LIGHT_SHAFT
	float VoL = clamp(dot(normalize(viewPos.xyz), lightVec), 0.0, 1.0);
	float scattering = 1.0 + pow4(VoL);

	if (isEyeInWater != 1){
		#if defined FOG_PERBIOME && defined WEATHER_PERBIOME
		lightCol = mix(lightCol, getBiomeFog(lightCol.rgb), 0.75 * timeBrightness);
		#endif

		vl.rgb *= lightCol * 0.5;
	} else {
		vl.rgb *= waterColor.rgb * 0.25;
	}
    vl.rgb *= LIGHT_SHAFT_STRENGTH * (0.2 + isEyeInWater * 0.8) * shadowFade * (1.0 - blindFactor) * scattering;
	#endif

	color += vl;
	#endif

	#ifdef VOLUMETRIC_CLOUDS
	float VoU = dot(normalize(viewPos.xyz), upVec);

    vec4 cloud1 = texture2D(colortex8, newTexCoord.xy + vec2( 0.0,  1.0 / viewHeight));
    vec4 cloud2 = texture2D(colortex8, newTexCoord.xy + vec2( 0.0, -1.0 / viewHeight));
    vec4 cloud3 = texture2D(colortex8, newTexCoord.xy + vec2( 1.0 / viewHeight,  0.0));
    vec4 cloud4 = texture2D(colortex8, newTexCoord.xy + vec2(-1.0 / viewHeight,  0.0));
    vec4 cloud = (cloud1 + cloud2 + cloud3 + cloud4) * 0.25;

	float cloudA = clamp(pow(cloud.a, 4.0) * (1.0 - sunVisibility * 0.8 + pow4(timeBrightness) * 0.3), 0.0, 1.0);

	cloud.a = mix(cloudA, cloud.a, clamp(eyeAltitude * 0.002, 0.0, 1.0));
	cloud.a = mix(cloud.a * clamp(1.0 - exp(-8.0 * VoU + 0.5), 0.0, 1.0), cloud.a, clamp(eyeAltitude * 0.005, 0.0, 1.0));

	color.rgb = mix(color.rgb, cloud.rgb, cloud.a);
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