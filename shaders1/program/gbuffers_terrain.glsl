/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float mat, recolor;

#ifdef INTEGRATED_EMISSION
varying float isPlant;
#endif

#ifdef SSPT
varying float isConcrete;
#endif

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
varying float dist;

varying vec3 binormal, tangent;
varying vec3 viewVector;

varying vec4 vTexCoord, vTexCoordAM;
#endif

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

uniform sampler2D depthtex1;

#ifdef ADVANCED_MATERIALS
uniform ivec2 atlasSize;

uniform sampler2D specular;
uniform sampler2D normals;

#ifdef REFLECTION_RAIN
uniform float wetness;

uniform mat4 gbufferModelView;
#endif
#endif

#ifdef DYNAMIC_HANDLIGHT
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp((dot( sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);

#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

#ifdef ADVANCED_MATERIALS
vec2 dcdx = dFdx(texCoord);
vec2 dcdy = dFdy(texCoord);
#endif

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/specularColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/surface/ggx.glsl"

#ifdef INTEGRATED_EMISSION
#include "/lib/surface/integratedEmissionTerrain.glsl"
#endif

#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#if defined ADVANCED_MATERIALS || defined SSPT
#include "/lib/util/encode.glsl"
#endif

#ifdef ADVANCED_MATERIALS
#include "/lib/reflections/complexFresnel.glsl"
#include "/lib/surface/directionalLightmap.glsl"
#include "/lib/surface/materialGbuffers.glsl"
#include "/lib/surface/parallax.glsl"

#ifdef REFLECTION_RAIN
#include "/lib/reflections/rainPuddles.glsl"
#endif
#endif

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * vec4(color.rgb, 1.0);
	vec3 newNormal = normal;
	vec3 shadow = vec3(0.0);
	float smoothness = 0.0;

	#ifdef ADVANCED_MATERIALS
	vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
	float surfaceDepth = 1.0;
	float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
	float skipAdvMat = float(mat > 3.98 && mat < 4.02);
	
	#ifdef PARALLAX
	if(skipAdvMat < 0.5) {
		newCoord = GetParallaxCoord(parallaxFade, surfaceDepth);
		albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * vec4(color.rgb, 1.0);
	}
	#endif

	float skyOcclusion = 0.0;
	vec3 fresnel3 = vec3(0.0);
	#endif

	vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
	float emission = 0.0; float lava = 0.0;

	vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
	#ifdef TAA
	vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
	#else
	vec3 viewPos = ToNDC(screenPos);
	#endif
	vec3 worldPos = ToWorld(viewPos);

	float emissive = float(mat > 2.98 && mat < 3.02) * 0.5;
	float foliage  = float(mat > 0.98 && mat < 1.02);
	float leaves   = float(mat > 1.98 && mat < 2.02);
	float candle   = float(mat > 4.98 && mat < 5.02);
	lava     = float(mat > 3.98 && mat < 4.02);

	#if defined SSPT && defined EMISSIVE_CONCRETE
	emissive += isConcrete * 1.5;
	albedo.rgb *= 1.0 + isConcrete * 0.5;
	#endif

	#ifdef INTEGRATED_EMISSION
	getIntegratedEmission(emissive, lightmap, albedo, worldPos, viewPos.xyz);
	#endif

	float metalness      = 0.0;
			emission       = emissive + candle + lava;
	float subsurface     = (foliage + candle) * 0.5 + leaves;
	vec3 baseReflectance = vec3(0.04);

	emission *= dot(albedo.rgb, albedo.rgb) * 0.333;

	#ifdef ADVANCED_MATERIALS
	float f0 = 0.0, porosity = 0.5, ao = 1.0;
	vec3 normalMap = vec3(0.0, 0.0, 1.0);
	GetMaterials(smoothness, metalness, f0, emission, subsurface, porosity, ao, normalMap,
					newCoord, dcdx, dcdy);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
							tangent.z, binormal.z, normal.z);

	if (normalMap.x > -0.999 && normalMap.y > -0.999)
		newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
	#endif
	
	#ifdef DYNAMIC_HANDLIGHT
	float heldLightValue = max(float(heldBlockLightValue), float(heldBlockLightValue2));
	float handlight = clamp((heldLightValue - 2.0 * length(viewPos)) / 15.0, 0.0, 0.9333);
	lightmap.x = max(lightmap.x, handlight);
	#endif

	albedo.rgb = pow(albedo.rgb, vec3(2.2));

	#ifdef WHITE_WORLD
	albedo.rgb = vec3(0.35);
	#endif
	
	vec3 outNormal = newNormal;
	#ifdef NORMAL_PLANTS
	if (foliage > 0.5){
		newNormal = upVec;
		
		#ifdef ADVANCED_MATERIALS
		newNormal = normalize(mix(outNormal, newNormal, normalMap.z * normalMap.z));
		#endif
	}
	#endif
	
	float NoL = clamp(dot(newNormal, lightVec), 0.0, 1.0);
	float NoU = clamp(dot(newNormal, upVec), -1.0, 1.0);
	float NoE = clamp(dot(newNormal, eastVec), -1.0, 1.0);
	float vanillaDiffuse = (0.25 * NoU + 0.75) + (0.667 - abs(NoE)) * (1.0 - abs(NoU)) * 0.15;
			vanillaDiffuse *= vanillaDiffuse;

	#ifndef NORMAL_PLANTS
	if (foliage > 0.5) vanillaDiffuse *= 1.8;
	#endif

	float parallaxShadow = 1.0;
	#ifdef ADVANCED_MATERIALS
	vec3 rawAlbedo = albedo.rgb * 0.999 + 0.001;
	albedo.rgb *= ao * ao;

	#ifdef REFLECTION_SPECULAR
	albedo.rgb *= 1.0 - metalness * smoothness;
	#endif

	float doParallax = 0.0;
	#ifdef SELF_SHADOW
	float pNoL = dot(outNormal, lightVec);

	#ifdef OVERWORLD
	doParallax = float(lightmap.y > 0.0 && pNoL > 0.0);
	#endif
	
	#ifdef END
	doParallax = float(pNoL > 0.0);
	#endif
	
	if (doParallax > 0.5 && skipAdvMat < 0.5) {
		parallaxShadow = GetParallaxShadow(surfaceDepth, parallaxFade, newCoord, lightVec,
											tbnMatrix);
	}
	#endif

	#ifdef DIRECTIONAL_LIGHTMAP
	mat3 lightmapTBN = GetLightmapTBN(viewPos);
	lightmap.x = DirectionalLightmap(lightmap.x, lmCoord.x, outNormal, lightmapTBN);
	lightmap.y = DirectionalLightmap(lightmap.y, lmCoord.y, outNormal, lightmapTBN);
	#endif
	#endif
	
	GetLighting(albedo.rgb, shadow, viewPos, worldPos, lightmap, color.a, NoL, vanillaDiffuse,
				parallaxShadow, emission, subsurface);
				
	#ifdef ADVANCED_MATERIALS
	float puddles = 0.0;

	#ifdef REFLECTION_RAIN
	float pNoU = dot(outNormal, upVec);
	if (wetness > 0.001) {
		puddles = GetPuddles(worldPos, newCoord, wetness) * clamp(pNoU, 0.0, 1.0);
	}
	
	#ifdef WEATHER_PERBIOME
	float weatherweight = isCold + isDesert + isMesa + isSavanna;
	puddles *= 1.0 - weatherweight;
	#endif
	
	puddles *= clamp(lightmap.y * 32.0 - 31.0, 0.0, 1.0) * (1.0 - lava);

	float ps = sqrt(1.0 - 0.75 * porosity);
	float pd = (0.5 * porosity + 0.15);	
	
	smoothness = mix(smoothness, 1.0, puddles * ps);
	f0 = max(f0, puddles * 0.02);

	albedo.rgb *= 1.0 - (puddles * pd);

	if (puddles > 0.001 && rainStrength > 0.001) {
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
							tangent.z, binormal.z, normal.z);

		vec3 puddleNormal = GetPuddleNormal(worldPos, viewPos, tbnMatrix);
		outNormal = normalize(
			mix(outNormal, puddleNormal, puddles * sqrt(1.0 - porosity) * rainStrength)
		);
	}
	#endif

	skyOcclusion = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);
	
	baseReflectance = mix(vec3(f0), rawAlbedo, metalness);
	float fresnel = pow(clamp(1.0 + dot(outNormal, normalize(viewPos.xyz)), 0.0, 1.0), 5.0);

	fresnel3 = mix(baseReflectance, vec3(1.0), fresnel);
	#if MATERIAL_FORMAT == 1
	if (f0 >= 0.9 && f0 < 1.0) {
		baseReflectance = GetMetalCol(f0);
		fresnel3 = ComplexFresnel(pow(fresnel, 0.2), f0);
		#ifdef ALBEDO_METAL
		fresnel3 *= rawAlbedo;
		#endif
	}
	#endif
	
	float aoSquared = ao * ao;
	shadow *= aoSquared; fresnel3 *= aoSquared;
	albedo.rgb = albedo.rgb * (1.0 - fresnel3 * smoothness * smoothness * (1.0 - metalness));
	#endif

	#if (defined OVERWORLD || defined END) && (defined ADVANCED_MATERIALS || defined SPECULAR_HIGHLIGHT_ROUGH)
	vec3 specularColor = GetSpecularColor(lightmap.y, metalness, baseReflectance);
	
	albedo.rgb += GetSpecularHighlight(newNormal, viewPos, smoothness, baseReflectance,
										specularColor, shadow * vanillaDiffuse, color.a);
	#endif
	
	#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR && defined REFLECTION_ROUGH
	newNormal = outNormal;
	if (normalMap.x > -0.999 && normalMap.y > -0.999) {
		normalMap = mix(vec3(0.0, 0.0, 1.0), normalMap, smoothness);
		newNormal = mix(normalMap * tbnMatrix, newNormal, 1.0 - pow(1.0 - puddles, 4.0));
		newNormal = clamp(normalize(newNormal), vec3(-1.0), vec3(1.0));
	}
	#endif

	#if ALPHA_BLEND == 0
	albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
	#endif

	#ifdef TEST
	albedo.a = clamp(albedo.a - float(mat > 195870.9 && mat < 195871.1), 0.0, 1.0);
	#endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0367 */
	gl_FragData[1] = vec4(smoothness, skyOcclusion, 0.0, 1.0);
	gl_FragData[2] = vec4(EncodeNormal(newNormal), float(gl_FragCoord.z < 1.0), 0.0);
	gl_FragData[3] = vec4(fresnel3, 1.0);
	#endif

	#if defined SSPT && (!defined ADVANCED_MATERIALS || !defined REFLECTION_SPECULAR)
	/* RENDERTARGETS:0,6,10 */
	gl_FragData[1] = vec4(EncodeNormal(newNormal), float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[2] = vec4(albedo.rgb, emission);
	#endif

	#if defined SSPT && (defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR)
	/* RENDERTARGETS:0,3,6,7,10 */
	gl_FragData[1] = vec4(smoothness, skyOcclusion, 0.0, 1.0);
	gl_FragData[2] = vec4(EncodeNormal(newNormal), float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[3] = vec4(fresnel3, 0.0);
	gl_FragData[4] = vec4(albedo.rgb, emission);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat, recolor;

#ifdef INTEGRATED_EMISSION
varying float isPlant;
#endif

#ifdef SSPT
varying float isConcrete;
#endif

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
varying float dist;

varying vec3 binormal, tangent;
varying vec3 viewVector;

varying vec4 vTexCoord, vTexCoordAM;
#endif

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

#ifdef TAA
uniform int frameCounter;

uniform float viewWidth, viewHeight;
#endif

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

#ifdef ADVANCED_MATERIALS
attribute vec4 at_tangent;
#endif

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

#ifdef INTEGRATED_EMISSION
#include "/lib/surface/integratedEmissionTerrain.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, vec2(0.0), vec2(0.9333, 1.0));

	normal = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADVANCED_MATERIALS
	binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
								  
	viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
	
	dist = length(gl_ModelViewMatrix * gl_Vertex);

	vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texMinMidCoord = texCoord - midCoord;

	vTexCoordAM.pq  = abs(texMinMidCoord) * 2.0;
	vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);
	
	vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
	color = gl_Color;
	
	mat = 0.0; recolor = 0.0;

	#ifdef SSPT
	isConcrete = 0.0;
	#endif

	if (mc_Entity.x >= 10100 && mc_Entity.x < 10200)
		mat = 1.0;
	if (mc_Entity.x == 10105 || mc_Entity.x == 10106){
		mat = 2.0;
		color.rgb *= 1.225;
	}
	if (mc_Entity.x >= 10200 && mc_Entity.x < 10300)
		mat = 3.0;
	if (mc_Entity.x == 10203)
		mat = 4.0;
	if (mc_Entity.x == 10208)
		mat = 5.0;

	if (mc_Entity.x == 10201 || mc_Entity.x == 10205 || mc_Entity.x == 10206)
		recolor = 1.0;

	if (mc_Entity.x == 10202)
		lmCoord.x -= 0.0667;

	if (mc_Entity.x == 10203)
		lmCoord.x += 0.0667;

	if (mc_Entity.x == 10400)
		color.a = 1.0;

	#ifdef TEST
	if (mc_Entity.x == 0) mat = 195871.0;
	#endif

	#if defined SSPT && defined EMISSIVE_CONCRETE
	if (mc_Entity.x == 29999) isConcrete = 1.0;
	#endif

	#ifdef INTEGRATED_EMISSION
	isPlant = 0.0;
	getIntegratedEmissionMaterials(mat, isPlant);
	#endif

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	eastVec = normalize(gbufferModelView[0].xyz);

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz = WavingBlocks(position.xyz, istopv, lmCoord);

    #ifdef WORLD_CURVATURE
	position.y -= WorldCurvature(position.xz);
    #endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	#ifdef TAA
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif