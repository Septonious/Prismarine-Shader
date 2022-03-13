/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float star;

varying vec3 upVec, sunVec;

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;

#ifdef RAINBOW
uniform float wetness;
#endif

uniform float blindFactor;
uniform float frameCounter;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float shadowFade, voidFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse, gbufferProjection;

uniform sampler2D noisetex;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp((dot( sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);

vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

void RoundSunMoon(inout vec3 color, vec3 viewPos, vec3 sunColor, vec3 moonColor) {
	float VoL = dot(normalize(viewPos), sunVec);
	float isMoon = float(VoL < 0.0);
	float sun = pow(abs(VoL), 3600.0 * isMoon + 1800.0 * (1.0 - isMoon)) * (1.0 - sqrt(rainStrength));

	vec3 sunMoonCol = mix(moonColor * moonVisibility, sunColor * sunVisibility, float(VoL > 0.25));

	#if MC_VERSION >= 11800
	sunMoonCol *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	sunMoonCol *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif
	
	color += sun * sunMoonCol;
}

void SunGlare(inout vec3 color, vec3 viewPos, vec3 lightCol) {
	float VoL = dot(normalize(viewPos), lightVec);
	float visfactor = 0.05 * (-0.8 * timeBrightness + 1.0) * (3.0 * rainStrength + 1.0);
	float invvisfactor = 1.0 - visfactor;

	float visibility = clamp(VoL * 0.5 + 0.5, 0.0, 1.0);
    visibility = visfactor / (1.0 - invvisfactor * visibility) - visfactor;
	visibility = clamp(visibility * 1.015 / invvisfactor - 0.015, 0.0, 1.0);
	visibility = mix(1.0, visibility, 0.25 * eBS + 0.75) * (1.0 - rainStrength * eBS * 0.875);
	visibility *= shadowFade * 0.25;

	#if MC_VERSION >= 11800
	visibility *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	visibility *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif

	color += lightCol * visibility * (0.5 + 0.5 * isEyeInWater);
}

//Includes//
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/util/dither.glsl"
#if (defined OVERWORLD && defined PLANAR_CLOUDS) || defined STARS || defined AURORA
#include "/lib/atmospherics/clouds.glsl"
#endif
#include "/lib/atmospherics/sky.glsl"

#if defined OVERWORLD && defined OVERWORLD_NEBULA
vec3 GetSmoke(vec3 viewPos) {
	float VoL = dot(normalize(viewPos.xyz), -sunVec);
	float VoU = dot(normalize(viewPos.xyz), upVec);

	float halfVoL = VoL * shadowFade * 0.5 + 0.5;
	float visibility = sqrt(sqrt(clamp(VoU * 10.0 - 1.0, 0.0, 1.0))) * (1.0 - rainStrength) * (1.0 - timeBrightness) * eBS;

	vec3 wpos = mat3(gbufferModelViewInverse) * viewPos;
	vec2 wind = vec2(frametime, 0.0);
	vec2 planeCoord = wpos.xz / (wpos.y + length(wpos.xz) * 0.5) * 0.25 + wind * 0.001;

	float smokeNoise  = texture2D(noisetex, planeCoord * 0.025).r;
		  smokeNoise -= texture2D(noisetex, planeCoord * 0.050).r * 0.35;
		  smokeNoise -= texture2D(noisetex, planeCoord * 0.300).r * 0.30;
		  smokeNoise -= texture2D(noisetex, planeCoord * 0.600).r * 0.15;
		  smokeNoise -= texture2D(noisetex, planeCoord * 0.900).r * 0.10;

	lightNight *= mix(lightNight, lightNight * vec3(0.3, 1.4, 0.7), smokeNoise);

	vec3 smoke = clamp(pow2(smokeNoise), 0.0, 1.0) * lightNight * visibility;

	return smoke * OVERWORLD_NEBULA_BRIGHTNESS * OVERWORLD_NEBULA_BRIGHTNESS;
}
#endif

#ifdef RAINBOW
vec3 RainbowLens(vec3 viewPos, vec2 lightPos, float size, float dist, float rad) {
	vec3 wpos = mat3(gbufferModelViewInverse) * viewPos;

	vec3 planeCoord = wpos / (wpos.y + length(wpos.xz) * 0.5);
	vec2 lensCoord = planeCoord.xz + vec2(2.5, 0.0);

	float VoU = dot(normalize(viewPos), upVec);
	float lens = clamp(1.0 - length(lensCoord) / size, 0.0, 1.0);
	
	vec3 rainbowLens = 
		(smoothstep(0.0, rad, lens) - smoothstep(rad, rad * 2.0, lens)) * vec3(1.0, 0.0, 0.0) +
		(smoothstep(rad * 0.5, rad * 1.5, lens) - smoothstep(rad * 1.5, rad * 2.5, lens)) * vec3(0.0, 1.0, 0.0) +
		(smoothstep(rad, rad * 2.0, lens) - smoothstep(rad * 2.0, rad * 3.0, lens)) * vec3(0.0, 0.0, 1.0)
	;

	return rainbowLens * float(VoU > 0.0) * wetness * (1.0 - rainStrength);
}
#endif

/*

#define sstep(x, low, high) smoothstep(low, high, x)
#define PI 3.14

float rayleigh_phase(float cosTheta) {
    float phase = 1.0 * (1.4 + 0.5 * cosTheta);
    phase *= rcp(PI * 4);
  	return phase;
}

float getMiePhase(float mu, float g) {
    float numerator = (1.0 - g * g) * (1.0 + mu * mu);
    float denominator = (2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.5);
    return ((3.0 / (8.0 * PI)) * numerator / denominator) * 0.5 + 0.5;
}

const vec3 light_coeff  = vec3(0.25, 0.5, 0.75);
const vec3 zenith_coeff = vec3(0.05, 0.20, 1.0);

const vec3 sunLight    = vec3(DAYSKY_R, DAYSKY_G, DAYSKY_B) * DAYSKY_I;
const vec3 moonLight   = vec3(NIGHTSKY_R, NIGHTSKY_B, NIGHTSKY_B) * NIGHTSKY_I;

float density_coeff = 0.75 * max(timeBrightness, 0.5);
const float horizon_offset = -0.04;

float atmos_density(float x) {
    return density_coeff * rcp(max(x - horizon_offset, 0.35e-3));
}
vec3 atmos_absorbtion(vec3 x, float y){
	vec3 absorption = x * -y;
	     absorption = exp(absorption) * 2.0;
    
    return absorption;
}

vec3 atmos_light(vec3 lightvec) {
    vec3 magic_ozone = light_coeff;
    
    return atmos_absorbtion(magic_ozone, atmos_density(lightvec.y));
}

vec3 atmos_approx(vec3 dir, vec3 sunvec, vec3 moonvec) {
    float vDotS = dot(sunvec, dir);
    float vDotM = dot(moonvec, dir);

    mat2x3 phase    = mat2x3(rayleigh_phase(vDotS), getMiePhase(vDotS, 0.74), getMiePhase(vDotS, 0.65),
                        rayleigh_phase(vDotM), getMiePhase(vDotM, 0.74), getMiePhase(vDotM, 0.65));
                
    float sun_mult  = sqrt(clamp(length(max(sunvec.y - horizon_offset, 0.0)), 0.0, 1.0)) * 0.9;
    float moon_mult = sqrt(clamp(length(max(moonvec.y - horizon_offset, 0.0)), 0.0, 1.0)) * 0.9;

    vec3 magic_ozone = zenith_coeff * mix(vec3(1.0, 1.1, 1.0), vec3(1.0), smoothstep(0.0, 0.2, max(sunvec.y, moonvec.y)));

    float density   = atmos_density(dir.y);
    vec3 absorption = atmos_absorbtion(magic_ozone, density);

    vec3 sunlight   = atmos_light(sunvec) * sunLight;
    vec3 moonlight  = atmos_light(moonvec) * moonLight;

    float sun_ms    = phase[0].x * smoothstep(horizon_offset, horizon_offset + 0.2, sunvec.y) * 1.5 + phase[0].z * 0.5 + 0.1;
        sun_ms     *= 0.5 + smoothstep(horizon_offset, horizon_offset + 0.4, sunvec.y) * 0.5;

    float moon_ms   = phase[1].x * smoothstep(horizon_offset, horizon_offset + 0.2, moonvec.y) * 1.5 + phase[1].z;
        moon_ms    *= 0.5 + smoothstep(horizon_offset, horizon_offset + 0.4, moonvec.y) * 0.5;

    float sun_visibility = smoothstep(-0.14, horizon_offset, sunvec.y);
        phase[0].y *= sun_visibility;

    float moon_visibility = smoothstep(-0.14, horizon_offset, sunvec.y);
        phase[1].y *= moon_visibility;
    
    //float sun_rmult  = atmos_rayleigh(dir, sunvec);
    vec3 sun_scatter = zenith_coeff * density;
        sun_scatter  = mix(sun_scatter * absorption, mix(1.0 - exp2(-0.5 * sun_scatter), 0.5 * magic_ozone / (1.0 + magic_ozone), 1.0 - exp2(-0.25 * density)), sun_mult);
        sun_scatter *= sunlight * 0.5 + 0.5 * length(sunlight);
        sun_scatter += (1.0 - exp(-density * magic_ozone)) * sun_ms * sunlight;
        sun_scatter += phase[0].y * sunlight * rcp(PI);

    //float moon_rmult  = atmos_rayleigh(dir, moonvec);
    vec3 moon_scatter = zenith_coeff * density;
        moon_scatter  = mix(moon_scatter * absorption, mix(1.0 - exp2(-0.5 * moon_scatter), 0.5 * magic_ozone / (1.0 + magic_ozone), 1.0 - exp2(-0.25 * density)), moon_mult);
        moon_scatter *= moonlight * 0.5 + 0.5 * length(moonlight);
        moon_scatter += (1.0 - exp(-density * magic_ozone)) * moon_ms * moonlight;
        moon_scatter += phase[1].y * moonlight * rcp(PI);
        moon_scatter  = mix(moon_scatter, dot(moon_scatter, vec3(1.0/3.0)) * vec3(0.2, 0.55, 1.0), 0.8);

    vec3 result     = (sun_scatter) + (moon_scatter);

    return result * rcp(PI);
}
*/

//Program//
void main() {
	vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;
	
	vec3 albedo = GetSkyColor(viewPos.xyz, false);

	#ifdef RAINBOW
	albedo += RainbowLens(viewPos.xyz, viewPos.xy, 1.5, -0.5, 0.05) * 0.1;
	#endif

	#if defined OVERWORLD && defined OVERWORLD_NEBULA
	albedo += GetSmoke(viewPos.xyz);
	#endif

	#ifdef ROUND_SUN_MOON
	vec3 lightMA = mix(lightMorning, lightEvening, mefade);
    vec3 sunColor = mix(lightMA, sqrt(lightDay * lightMA * LIGHT_DI), timeBrightness);
    vec3 moonColor = sqrt(lightNight) * 1.5;

	RoundSunMoon(albedo, viewPos.xyz, sunColor * 1.5, moonColor);
	SunGlare(albedo.rgb, viewPos.xyz, lightCol.rgb);
	#endif

	#ifdef STARS
	DrawStars(albedo.rgb, viewPos.xyz, 0.2, 0.9, 1.5);
	DrawStars(albedo.rgb, viewPos.xyz, 0.35, 1.1, 0.75);
	#endif

	float dither = Bayer64(gl_FragCoord.xy);

	#ifdef AURORA
	albedo.rgb += DrawAurora(viewPos.xyz, dither, 12);
	#endif

	#if defined PLANAR_CLOUDS
	vec4 cloud = DrawCloud(viewPos.xyz, dither, lightCol, ambientCol);
	albedo.rgb = mix(albedo.rgb, cloud.rgb, cloud.a);
	#endif

	albedo.rgb *= 1.0 + nightVision;

	#if ALPHA_BLEND == 0
	albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
	albedo.rgb = albedo.rgb + dither / vec3(64.0);
	#endif
	
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(albedo, 1.0 - star);
    #if defined OVERWORLD && defined PLANAR_CLOUDS
    /* DRAWBUFFERS:04 */
	gl_FragData[1] = vec4(cloud.a, 0.0, 0.0, 0.0);
    #endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float star;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main() {
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	
	gl_Position = ftransform();

	star = float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0);
}

#endif