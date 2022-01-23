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

#if defined BLOOM || defined LENS_FLARE
varying vec3 sunVec, upVec;
#endif

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float viewWidth, viewHeight;

#if defined BLOOM || defined LENS_FLARE
uniform ivec2 eyeBrightnessSmooth;
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;

#if defined TAA || (defined SSGI && defined GI_ACCUMULATION)
uniform sampler2D colortex2;
#endif

#ifdef LENS_FLARE
uniform float timeAngle, timeBrightness;
uniform float aspectRatio;

uniform vec3 sunPosition;
uniform mat4 gbufferProjection;
#endif

#ifdef UNDERGROUND_SKY
uniform vec3 cameraPosition;
#endif

//Optifine Constants//
#if defined TAA || (defined SSGI && defined GI_ACCUMULATION)
const bool colortex2Clear = false;
#endif

#ifdef AUTO_EXPOSURE
const bool colortex0MipmapEnabled = true;
#endif

//Common Variables//
#if defined BLOOM || defined LENS_FLARE
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp((dot( sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
#endif

float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void UnderwaterDistort(inout vec2 texCoord) {
	vec2 originalTexCoord = texCoord;

	texCoord += vec2(
		cos(texCoord.y * 32.0 + frameTimeCounter * 3.0),
		sin(texCoord.x * 32.0 + frameTimeCounter * 1.7)
	) * 0.0005;

	float mask = float(
		texCoord.x > 0.0 && texCoord.x < 1.0 &&
	    texCoord.y > 0.0 && texCoord.y < 1.0
	)
	;
	if (mask < 0.5) texCoord = originalTexCoord;
}

#ifdef LENS_FLARE
vec2 GetLightPos() {
	vec4 tpos = gbufferProjection * vec4(sunPosition, 1.0);
	tpos.xyz /= tpos.w;
	return tpos.xy / tpos.z * 0.5;
}
#endif

//Includes//
#include "/lib/post/tonemap.glsl"

#ifdef BLOOM
#include "/lib/post/bloom.glsl"
#endif

#ifdef LENS_FLARE
#include "/lib/color/lightColor.glsl"
#include "/lib/post/lensFlare.glsl"
#endif

//Program//
void main() {
    vec2 newTexCoord = texCoord;
	if (isEyeInWater == 1.0) UnderwaterDistort(newTexCoord);
	
	vec3 color = texture2D(colortex0, newTexCoord).rgb;
	
	float tempVisibleSun = 0.0; float tempExposure = 0.0;

	#if defined TAA || (defined SSGI && defined GI_ACCUMULATION)
	#ifdef AUTO_EXPOSURE
	tempExposure = texture2D(colortex2, vec2(pw, ph)).r;
	#endif

	#ifdef LENS_FLARE
	tempVisibleSun = texture2D(colortex2, vec2(3.0 * pw, ph)).r;
	#endif

	vec3 temporalColor = texture2D(colortex2, texCoord).gba;
	#endif
	
	#ifdef BLOOM
	Bloom(color, newTexCoord);
	#endif
	
	//Tonemapping
	#ifdef AUTO_EXPOSURE
	float exposure = 1.0;
	AutoExposure(color, exposure, tempExposure);
	#endif
	
	#ifdef COLOR_GRADING
	ColorGrading(color);
	#endif
	
	BSLTonemap(color);
	
	//Lens Flare
	#ifdef LENS_FLARE
	vec2 lightPos = GetLightPos();
	float truePos = sign(sunVec.z);
	      
    float visibleSun = float(texture2D(depthtex0, lightPos + 0.5).r >= 1.0);
	visibleSun *= max(1.0 - isEyeInWater, eBS) * (1.0 - blindFactor) * (1.0 - rainStrength);

	#ifdef UNDERGROUND_SKY
	visibleSun *= mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	#endif
	
	float multiplier = tempVisibleSun * LENS_FLARE_STRENGTH * 0.5;

	if (multiplier > 0.001) LensFlare(color, lightPos, truePos, multiplier);
	#endif
	
	#if defined TAA || (defined SSGI && defined GI_ACCUMULATION)
	float temporalData = 0.0;
	
	#ifdef AUTO_EXPOSURE
	if (texCoord.x < 2.0 * pw && texCoord.y < 2.0 * ph)
		temporalData = mix(tempExposure, sqrt(exposure), 0.033);
	#endif

	#ifdef LENS_FLARE
	if (texCoord.x > 2.0 * pw && texCoord.x < 4.0 * pw && texCoord.y < 2.0 * ph)
		temporalData = mix(tempVisibleSun, visibleSun, 0.125);
	#endif
	#endif

    #ifdef VIGNETTE
    color *= 1.0 - length(texCoord - 0.5) * (1.0 - GetLuminance(color));
	#endif
	
	color = pow(color, vec3(1.0 / 2.2));
	
	ColorSaturation(color);
	
	float filmGrain = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 512.0).b;
	color += (filmGrain - 0.25) / 128.0;
	
	/* DRAWBUFFERS:1 */
	gl_FragData[0] = vec4(color, 1.0);

	#if defined TAA || (defined SSGI && defined GI_ACCUMULATION)
	/* DRAWBUFFERS:12 */
	gl_FragData[1] = vec4(temporalData, temporalColor);
	#endif

}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

#if defined BLOOM || defined LENS_FLARE
varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;
#endif

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	#ifdef LENS_FLARE
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	#endif
}

#endif