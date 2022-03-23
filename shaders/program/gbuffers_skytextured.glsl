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

varying vec3 upVec, sunVec;

varying vec4 color;

//Uniforms//
uniform int renderStage;

uniform float nightVision;
uniform float rainStrength;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;

uniform sampler2D texture;

#ifndef MC_RENDER_STAGE_SUN
#define MC_RENDER_STAGE_SUN 1
#endif

#ifndef MC_RENDER_STAGE_MOON
#define MC_RENDER_STAGE_MOON 1
#endif

#if defined END_NEBULA || defined END_STARS
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;

uniform int worldTime;
uniform float frameTimeCounter;

#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp((dot( sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/color/dimensionColor.glsl"

#ifdef END_NEBULA
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/clouds.glsl"
#endif

#ifdef END_STARS
float GetNoise2(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

void DrawStars2(inout vec3 color, vec3 viewPos, float size, float amount, float brightness) {
	vec3 wpos = vec3(gbufferModelViewInverse * vec4(viewPos, 1.0));
	vec3 planeCoord = wpos / (wpos.y + length(wpos.xz));

	vec2 wind = vec2(frametime, 0.0);
	vec2 coord = planeCoord.xz * size + cameraPosition.xz * 0.0001 + wind * 0.001;
		 coord = floor(coord * 1024.0) / 1024.0;

	float multiplier = 16.0 * (1.0 - rainStrength) * (1.0 - sunVisibility * 0.5);
	
	float star = GetNoise2(coord.xy);
		  star*= GetNoise2(coord.xy + 0.10);
		  star*= GetNoise2(coord.xy + 0.23);
	star *= amount;
	star = clamp(star - 0.75, 0.0, 1.0) * multiplier;

	color += star * vec3(0.5, 0.75, 1.00) * brightness;
}
#endif

//Program//
void main() {
	vec4 albedo = texture2D(texture, texCoord);

	#ifdef OVERWORLD
	albedo *= color;
	albedo.rgb = pow(albedo.rgb,vec3(2.2)) * SKYBOX_BRIGHTNESS * albedo.a;

	#ifdef ROUND_SUN_MOON
	if (renderStage == MC_RENDER_STAGE_SUN || renderStage == MC_RENDER_STAGE_MOON) {
		albedo *= 0.0;
	}
	#endif
	
	#ifdef SKY_DESATURATION
    vec3 desat = GetLuminance(albedo.rgb) * pow(lightNight,vec3(1.6)) * 4.0;
	albedo.rgb = mix(desat, albedo.rgb, sunVisibility);
	#endif

	#ifdef UNDERGROUND_SKY
	albedo.rgb *= mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	#endif
	#endif

	#ifdef END
	albedo.rgb = endCol.rgb * 0.01;

	#ifdef SKY_DESATURATION
	albedo.rgb = GetLuminance(albedo.rgb) * endCol.rgb;
	#endif

	vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	#ifdef END_STARS
	DrawStars2(albedo.rgb, viewPos.xyz, 0.45, 0.9, 8.0);
	#endif

	#ifdef END_NEBULA
	albedo.rgb += DrawNebula(viewPos.xyz);
	#endif

	albedo.rgb *= SKYBOX_BRIGHTNESS * 0.02;
	#endif

	#if ALPHA_BLEND == 0
	albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
	#endif
	
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

varying vec4 color;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

#ifdef TAA
uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;
#include "/lib/util/jitter.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	color = gl_Color;
	
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	
	gl_Position = ftransform();
	
	#ifdef TAA
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif