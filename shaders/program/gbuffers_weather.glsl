/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 upVec, sunVec;

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;

uniform float nightVision;
uniform float rainStrength;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;

uniform sampler2D texture;
uniform sampler2D depthtex0;

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;

//Common Functions//
void Defog(inout vec3 albedo, float fogDensity) {
	float z = texture2D(depthtex0,gl_FragCoord.xy/vec2(viewWidth,viewHeight)).r;
	if (z == 1.0) return;

    vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), z, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;

    float fog = length(viewPos) * fogDensity / 256.0;
	float clearDay = sunVisibility * (1.0 - rainStrength);
	fog *= (0.5 * rainStrength + 1.0) / (3.0 * clearDay + 1.0);
	fog = 1.0 - exp(-2.0 * pow(fog, 0.25 * clearDay + 1.25) * eBS);
    albedo.rgb /= 1.0 - fog;
}

//Includes//
#include "/lib/color/lightColor.glsl"
#include "/lib/color/blocklightColor.glsl"
#include "/lib/atmospherics/weatherDensity.glsl"

//Program//
void main() {
	#if defined NETHER || defined END
	discard;
	#endif

    vec4 albedo = vec4(0.0);
	
	albedo.a = texture2D(texture, texCoord).a;
	
	if (albedo.a > 0.001) {
		albedo.rgb = texture2D(texture, texCoord).rgb;

		albedo.a *= 0.25 * rainStrength * length(albedo.rgb / 3.0) * float(albedo.a > 0.1);
		albedo.rgb = sqrt(albedo.rgb);
		albedo.rgb *= (ambientCol + lmCoord.x * lmCoord.x * blocklightCol) * WEATHER_OPACITY;

		#if MC_VERSION < 10800
		albedo.a *= 4.0;
		albedo.rgb *= 0.525;
		#endif
		
		#if defined FOG && MC_VERSION < 11500
		if (gl_FragCoord.z > 0.991) Defog(albedo.rgb, fogDensity);
		#endif

		#if ALPHA_BLEND == 0
		albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
		albedo.a *= 1.4;
		#endif
	}
	
/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp(lmCoord * 2.0 - 1.0, 0.0, 1.0);

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	
	gl_Position = ftransform();
}

#endif