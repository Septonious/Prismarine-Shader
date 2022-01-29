/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float mat;
varying float dist;

varying vec2 texCoord, lmCoord;

varying vec3 normal, binormal, tangent;
varying vec3 sunVec, upVec, eastVec;
varying vec3 viewVector;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
varying vec4 vTexCoord, vTexCoordAM;
#endif

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor, nightVision;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float shadowFade, voidFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferProjection, gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;
uniform sampler2D gaux2;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;

#ifdef ADVANCED_MATERIALS
uniform ivec2 atlasSize;

uniform sampler2D specular;
uniform sampler2D normals;

#ifdef REFLECTION_RAIN
uniform float wetness;
#endif
#endif

#ifdef DYNAMIC_HANDLIGHT
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
#endif

//Optifine Constants//

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

float GetWaterHeightMap(vec3 worldPos, vec3 viewPos, vec2 lightmap){
    float noise = 0.0;

    float mult = clamp(-dot(normalize(normal), normalize(viewPos)) * 8.0, 0.0, 1.0) / 
                 sqrt(sqrt(max(dist, 4.0)));
    
    vec2 wind = vec2(frametime);
    float verticalOffset = worldPos.y * 0.2;

    if (mult > 0.01){
        #if WATER_NORMALS == 1
		noise = texture2D(noisetex, (worldPos.xz + wind - verticalOffset) * 0.002).r * 1.0;
		noise+= texture2D(noisetex, (worldPos.xz - wind - verticalOffset) * 0.003).r * 0.8;
		noise-= texture2D(noisetex, (worldPos.xz + wind + verticalOffset) * 0.005).r * 0.6;
		noise+= texture2D(noisetex, (worldPos.xz - wind - verticalOffset) * 0.010).r * 0.4;
		noise-= texture2D(noisetex, (worldPos.xz + wind + verticalOffset) * 0.015).r * 0.2;

		noise *= mult * lightmap.y;
		#elif WATER_NORMALS == 2
        float lacunarity = 1.0 / WATER_SIZE, persistance = 1.0, weight = 0.0;

        mult *= WATER_BUMP * lightmap.y * WATER_SIZE / 450.0;
        wind *= WATER_SPEED;

        for(int i = 0; i < WATER_OCTAVE; i++){
            float windSign = mod(i, 2) * 2.0 - 1.0;
			vec2 noiseCoord = worldPos.xz + wind * windSign - verticalOffset;
            noise += texture2D(noisetex, noiseCoord * lacunarity).r * persistance;
            if (i == 0) noise = -noise;

            weight += persistance;
            lacunarity *= WATER_LACUNARITY;
            persistance *= WATER_PERSISTANCE;
        }
        noise *= mult / weight;
		#endif
    }

    return noise;
}


vec3 GetParallaxWaves(vec3 worldPos, vec3 viewPos, vec3 viewVector, vec2 lightmap) {
	vec3 parallaxPos = worldPos;
	
	for(int i = 0; i < 4; i++){
		float height = (GetWaterHeightMap(parallaxPos, viewPos, lightmap) - 0.5) * 0.2;
		parallaxPos.xz += height * viewVector.xy / dist;
	}
	return parallaxPos;
}

vec3 GetWaterNormal(vec3 worldPos, vec3 viewPos, vec3 viewVector, vec2 lightmap){
	vec3 waterPos = worldPos + cameraPosition;

	#ifdef WATER_PARALLAX
	waterPos = GetParallaxWaves(waterPos, viewPos, viewVector, lightmap);
	#endif

	#if WATER_NORMALS == 2
	float normalOffset = WATER_SHARPNESS;
	#else
	float normalOffset = 0.1;
	#endif

	float h0 = GetWaterHeightMap(waterPos, viewPos, lightmap);
	float h1 = GetWaterHeightMap(waterPos + vec3( normalOffset, 0.0, 0.0), viewPos, lightmap);
	float h2 = GetWaterHeightMap(waterPos + vec3(-normalOffset, 0.0, 0.0), viewPos, lightmap);
	float h3 = GetWaterHeightMap(waterPos + vec3(0.0, 0.0,  normalOffset), viewPos, lightmap);
	float h4 = GetWaterHeightMap(waterPos + vec3(0.0, 0.0, -normalOffset), viewPos, lightmap);

	float xDelta = (h1 - h2) / normalOffset;
	float yDelta = (h3 - h4) / normalOffset;

	vec3 normalMap = vec3(xDelta, yDelta, 1.0 - (xDelta * xDelta + yDelta * yDelta));
	return normalMap * 0.03 + vec3(0.0, 0.0, 0.97);
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/specularColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/reflections/raytrace.glsl"
#include "/lib/reflections/simpleReflections.glsl"
#include "/lib/surface/ggx.glsl"

#ifdef OVERWORLD
#include "/lib/atmospherics/clouds.glsl"
#endif

#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#ifdef SSGI
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
	float smoothness = 0.0;
	
	#ifdef ADVANCED_MATERIALS
	vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
	float surfaceDepth = 1.0;
	float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
	float skipAdvMat = float(mat > 0.98 && mat < 1.02);
	
	#ifdef PARALLAX
	if(skipAdvMat < 0.5) {
		newCoord = GetParallaxCoord(parallaxFade, surfaceDepth);
		albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * vec4(color.rgb, 1.0);
	}
	#endif
	#endif

	vec3 vlAlbedo = vec3(1.0);

	float water = float(mat > 0.98 && mat < 1.02);
	float glass = float(mat > 1.98 && mat < 2.02);

	vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
	
	if (albedo.a > 0.001) {
		float translucent = float(mat > 2.98 && mat < 3.02) + float(mat > 3.98 && mat < 4.02);
		
		float metalness      = 0.0;
		float emission       = 0.0;
		float subsurface     = 0.0;
		vec3 baseReflectance = vec3(0.04);

		#ifndef REFLECTION_TRANSLUCENT
		glass = 0.0;
		translucent = 0.0;
		#endif

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#ifdef TAA
		vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
		vec3 viewPos = ToNDC(screenPos);
		#endif
		vec3 worldPos = ToWorld(viewPos);

		float dither = Bayer64(gl_FragCoord.xy);

		vec3 normalMap = vec3(0.0, 0.0, 1.0);
		
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);

		#if WATER_NORMALS == 1 || WATER_NORMALS == 2
		if (water > 0.5) {
			normalMap = GetWaterNormal(worldPos, viewPos, viewVector, lightmap);
			newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
		}
		#endif

		#ifdef ADVANCED_MATERIALS
		float f0 = 0.0, porosity = 0.5, ao = 1.0, skyOcclusion = 0.0;
		GetMaterials(smoothness, metalness, f0, emission, subsurface, porosity, ao, normalMap,
						newCoord, dcdx, dcdy);
		if (water < 0.5) {		
			if (normalMap.x > -0.999 && normalMap.y > -0.999)
				newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
		}
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
		
		if (water > 0.5) {
			waterColor.g *= 0.85;

			#if WATER_MODE == 0
			albedo.rgb = waterColor.rgb * clamp(waterColor.a, 0.0, 0.75); //high values overbrighten it
			#elif WATER_MODE == 1
			albedo.rgb *= albedo.a;
			#elif WATER_MODE == 2
			float waterLuma = length(albedo.rgb / pow(color.rgb, vec3(2.2))) * 2.0;
			albedo.rgb = waterLuma * waterColor.rgb * waterColor.a * albedo.a;
			#elif WATER_MODE == 3
			albedo.rgb = color.rgb * color.rgb * 0.35;
			#endif
			#if WATER_ALPHA_MODE == 0
			albedo.a = waterAlpha;
			#endif
			baseReflectance = vec3(0.02);
		}

		vlAlbedo = mix(vec3(1.0), albedo.rgb, sqrt(albedo.a)) * (1.0 - pow(albedo.a, 64.0));
		
		float NoL = clamp(dot(newNormal, lightVec), 0.0, 1.0);

		float NoU = clamp(dot(newNormal, upVec), -1.0, 1.0);
		float NoE = clamp(dot(newNormal, eastVec), -1.0, 1.0);
		float vanillaDiffuse = (0.25 * NoU + 0.75) + (0.667 - abs(NoE)) * (1.0 - abs(NoU)) * 0.15;
			  vanillaDiffuse*= vanillaDiffuse;

		float parallaxShadow = 1.0;
		#ifdef ADVANCED_MATERIALS
		vec3 rawAlbedo = albedo.rgb * 0.999 + 0.001;
		albedo.rgb *= ao;

		#ifdef REFLECTION_SPECULAR
		albedo.rgb *= 1.0 - metalness * smoothness;
		#endif
		
		#ifdef SELF_SHADOW
		if (lightmap.y > 0.0 && NoL > 0.0 && water < 0.5) {
			parallaxShadow = GetParallaxShadow(surfaceDepth, parallaxFade, newCoord, lightVec,
											   tbnMatrix);
		}
		#endif

		#ifdef DIRECTIONAL_LIGHTMAP
		mat3 lightmapTBN = GetLightmapTBN(viewPos);
		lightmap.x = DirectionalLightmap(lightmap.x, lmCoord.x, newNormal, lightmapTBN);
		lightmap.y = DirectionalLightmap(lightmap.y, lmCoord.y, newNormal, lightmapTBN);
		#endif
		#endif
		
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, viewPos, worldPos, lightmap, color.a, NoL, vanillaDiffuse,
				    parallaxShadow, emission, subsurface);

		#ifdef ADVANCED_MATERIALS
		float puddles = 0.0;
		#ifdef REFLECTION_RAIN	
		if (water < 0.5 && wetness > 0.001) {
			puddles = GetPuddles(worldPos, newCoord, wetness) * clamp(NoU, 0.0, 1.0);
		}
		
		#ifdef WEATHER_PERBIOME
		float weatherweight = isCold + isDesert + isMesa + isSavanna;
		puddles *= 1.0 - weatherweight;
		#endif
		
		puddles *= clamp(lightmap.y * 32.0 - 31.0, 0.0, 1.0);

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
			newNormal = normalize(
				mix(newNormal, puddleNormal, puddles * sqrt(1.0 - porosity) * rainStrength)
			);
		}
		#endif
		#endif
		
		float fresnel = pow(clamp(1.0 + dot(newNormal, normalize(viewPos)), 0.0, 1.0), 5.0);

		#ifdef CUSTOM_NETHER_PORTAL
		if (mat > 3.98 && mat < 4.02) {
			vec2 portalCoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
			portalCoord = (portalCoord - 0.5) * vec2(aspectRatio, 1.0);

			vec2 wind = vec2(0.0, frametime * 0.1);

			float portal = texture2D(noisetex, portalCoord * 0.25 + wind * 0.03).r * 0.1;
				portal+= texture2D(noisetex, portalCoord * 0.15 + wind * 0.02).r * 0.2;
				portal+= texture2D(noisetex, portalCoord * 0.05 + wind * 0.01).r * 0.3;
			
			albedo.rgb = portal * portal * vec3(0.75, 0.25, 1.5);
			albedo.a = 0.25;
		}
		#endif

		if (water > 0.5 || ((translucent + glass) > 0.5 && albedo.a < 0.95)) {
			#if REFLECTION > 0
			vec4 reflection = vec4(0.0);
			vec3 skyReflection = vec3(0.0);
	
			fresnel = fresnel * 0.98 + 0.02;
			fresnel*= max(1.0 - isEyeInWater * 0.5 * water, 0.5);
			
			#if REFLECTION == 2
			reflection = SimpleReflection(viewPos, newNormal, dither);
			reflection.rgb = pow(reflection.rgb * 2.0, vec3(8.0));
			#endif
			
			if (reflection.a < 1.0) {
				vec3 skyRefPos = reflect(normalize(viewPos), newNormal);
				vec3 specularColor = GetSpecularColor(lightmap.y, 0.0, vec3(1.0));

				#ifdef OVERWORLD
				skyReflection = GetSkyColor(skyRefPos, true);
				#endif

				#ifdef NETHER
				skyReflection = netherCol.rgb * 0.04;
				#endif

				#ifdef END
				skyReflection = endCol.rgb * 0.01;
				#endif

				#if defined OVERWORLD || defined END
				vec3 specular = GetSpecularHighlight(newNormal, viewPos,  0.9, vec3(0.02),
													 specularColor, shadow, color.a);
				#if ALPHA_BLEND == 0
				float specularAlpha = pow(mix(albedo.a, 1.0, fresnel), 2.2) * fresnel;
				#else
				float specularAlpha = mix(albedo.a , 1.0, fresnel) * fresnel;
				#endif

				skyReflection += specular / ((4.0 - 3.0 * eBS) * specularAlpha);
				#endif

				#ifdef OVERWORLD
				#ifdef AURORA
				skyReflection += DrawAurora(skyRefPos * 100.0, dither, 6);
				#endif

				#ifdef OVERWORLD_NEBULA
				skyReflection.rgb += DrawNebula(skyRefPos.xyz * 100.0);
				#endif

				#if defined PLANAR_CLOUDS
				vec4 cloud = DrawCloud(skyRefPos * 100.0, dither, lightCol, ambientCol);
				skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
				#endif

				skyReflection *= (4.0 - 3.0 * eBS) * lightmap.y;
				#endif

				skyReflection *= clamp(1.0 - isEyeInWater, 0.0, 1.0);
			}
			
			reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));
			
			albedo.rgb = mix(albedo.rgb, reflection.rgb, fresnel);
			albedo.a = mix(albedo.a, 1.0, fresnel);
			#endif
		}else{
			#ifdef ADVANCED_MATERIALS
			skyOcclusion = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);

			baseReflectance = mix(vec3(f0), rawAlbedo, metalness);

			#ifdef REFLECTION_SPECULAR
			vec3 fresnel3 = mix(baseReflectance, vec3(1.0), fresnel);
			#if MATERIAL_FORMAT == 0
			if (f0 >= 0.9 && f0 < 1.0) {
				baseReflectance = GetMetalCol(f0);
				fresnel3 = ComplexFresnel(pow(fresnel, 0.2), f0);
				#ifdef ALBEDO_METAL
				fresnel3 *= rawAlbedo;
				#endif
			}
			#endif
			
			float aoSquared = ao * ao;
			shadow *= aoSquared; fresnel3 *= aoSquared * smoothness * smoothness;

			if (smoothness > 0.0) {
				vec4 reflection = vec4(0.0);
				vec3 skyReflection = vec3(0.0);
				
				float ssrMask = clamp(length(fresnel3) * 400.0 - 1.0, 0.0, 1.0);
				if(ssrMask > 0.0) reflection = SimpleReflection(viewPos, newNormal, dither);
				reflection.rgb = pow(reflection.rgb * 2.0, vec3(8.0));
				reflection.a *= ssrMask;

				if (reflection.a < 1.0) {
					#ifdef OVERWORLD
					vec3 skyRefPos = reflect(normalize(viewPos.xyz), newNormal);
					skyReflection = GetSkyColor(skyRefPos, true);
					
					#ifdef AURORA
					skyReflection += DrawAurora(skyRefPos * 100.0, dither, 6);
					#endif

					#ifdef OVERWORLD_NEBULA
					skyReflection.rgb += DrawNebula(skyRefPos.xyz * 100.0);
					#endif

					#if defined PLANAR_CLOUDS
					vec4 cloud = DrawCloud(skyRefPos * 100.0, dither, lightCol, ambientCol);
					skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
					#endif

					skyReflection = mix(
						vanillaDiffuse * minLightCol,
						skyReflection * (4.0 - 3.0 * eBS),
						skyOcclusion
					);
					#endif

					#ifdef NETHER
					skyReflection = netherCol.rgb * 0.04;
					#endif

					#ifdef END
					skyReflection = endCol.rgb * 0.01;
					#endif
				}

				reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));

				albedo.rgb = albedo.rgb * (1.0 - fresnel3 * (1.0 - metalness)) +
							 reflection.rgb * fresnel3;
				albedo.a = mix(albedo.a, 1.0, GetLuminance(fresnel3));
			}
			#endif
			#endif

			#if defined OVERWORLD || defined END
			vec3 specularColor = GetSpecularColor(lightmap.y, metalness, baseReflectance);

			albedo.rgb += GetSpecularHighlight(newNormal, viewPos, smoothness, baseReflectance,
										   	   specularColor, shadow * vanillaDiffuse, color.a);
			#endif
		}

		#if defined OVERWORLD && defined TRANSLUCENCY_BLENDING
		glass = float(mat > 1.98 && mat < 2.02);
		if ((isEyeInWater == 0 && water > 0.5) || glass > 0.5) {
			vec3 terrainColor = texture2D(gaux2, gl_FragCoord.xy / vec2(viewWidth, viewHeight)).rgb;
		 	float oDepth = texture2D(depthtex1, screenPos.xy).r;
		 	vec3 oScreenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), oDepth);
			
		 	#ifdef TAA
		 	vec3 oViewPos = ToNDC(vec3(TAAJitter(oScreenPos.xy, -0.5), oScreenPos.z));
		 	#else
		 	vec3 oViewPos = ToNDC(oScreenPos);
		 	#endif

			float rainFactor = 1.00 - rainStrength * 0.5;
			float difT = length(oViewPos - viewPos.xyz);
					
			vec3 absorbColor = vec3(0.0);
			float absorbDist = 0.0;

			if (isEyeInWater == 0 && water > 0.5){
				albedo.a *= 0.75;
				absorbColor = normalize(waterColor.rgb * WATER_I) * rainFactor * terrainColor * (1.0 + timeBrightness);
				absorbDist = 1.0 - clamp(difT / 8.0, 0.0, 1.0);
			}

			if (glass > 0.5){
				albedo.a += albedo.a * 0.75;
				albedo.a = clamp(albedo.a, 0.5, 0.95);
				absorbColor = normalize(albedo.rgb * albedo.rgb) * terrainColor * 1.25;
				absorbDist = 1.0 - clamp(difT * 32.0, 0.0, 1.0);
			}
			
			vec3 newAlbedo = mix(absorbColor * absorbColor, terrainColor * terrainColor, absorbDist * absorbDist);

			float lightmapFactor = 0.0 + lightmap.y;
			float absorb = sqrt(clamp(lightmap.y + glass, 0.0, 1.0) * (1.0 - WATER_A) * lightmap.y);
 
			albedo.rgb = mix(albedo.rgb, newAlbedo, absorb * (1.0 - moonVisibility * 0.85));
		}
		#endif

		albedo.a *= 0.75 + lightmap.y * 0.25;

		Fog(albedo.rgb, viewPos);

		#if ALPHA_BLEND == 0
		albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
		#endif
	}

    /* DRAWBUFFERS:01 */
    gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(vlAlbedo, 1.0);

	#if defined WATER_REFRACTION || defined WATER_LIGHTSHAFTS
	/* RENDERTARGETS:0,1,12 */
	gl_FragData[2] = vec4(0.0, lightmap.y, dist, water);
	#endif

	#ifdef SSGI
	/* RENDERTARGETS:0,1,12,3,6,10 */
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, float(mat > 3.98 && mat < 4.02) * 0.25);
	gl_FragData[4] = vec4(EncodeNormal(newNormal), float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[5] = albedo * 0.25 * pow16(1.0 - lightmap.y);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat;
varying float dist;

varying vec2 texCoord, lmCoord;

varying vec3 normal, binormal, tangent;
varying vec3 sunVec, upVec, eastVec;
varying vec3 viewVector;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
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
attribute vec4 at_tangent;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Common Functions//
#ifdef WAVING_LIQUID
float WavingWater(vec3 worldPos, vec2 lmCoord) {
	vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));

	float fractY = fract(worldPos.y + cameraPosition.y + 0.005);
		
	float wave = sin(6.28 * (frametime * 0.7 + worldPos.x * 0.14 + worldPos.z * 0.07)) +
				 sin(6.28 * (frametime * 0.5 + worldPos.x * 0.10 + worldPos.z * 0.20));
	if (fractY > 0.01) return wave * 0.0125 * lightmap.y;
	
	return 0.0;
}
#endif

//Includes//
#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, vec2(0.0), vec2(0.9333, 1.0));

	normal   = normalize(gl_NormalMatrix * gl_Normal);
	binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
								  
	viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
	
	dist = length(gl_ModelViewMatrix * gl_Vertex);

	#ifdef ADVANCED_MATERIALS
	vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texMinMidCoord = texCoord - midCoord;

	vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
	vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);
	
	vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
	color = gl_Color;
	
	mat = 0.0;
	
	if (mc_Entity.x == 10300 || mc_Entity.x == 10303) mat = 1.0;
	if (mc_Entity.x == 10301) mat = 2.0;
	if (mc_Entity.x == 10302) mat = 3.0;
	if (mc_Entity.x == 10304) mat = 4.0;
	if (mc_Entity.x == 10303) color.a = 1.0;

	const vec2 sunRotationData = vec2(
		 cos(sunPathRotation * 0.01745329251994),
		-sin(sunPathRotation * 0.01745329251994)
	);
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	eastVec = normalize(gbufferModelView[0].xyz);

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	#ifdef WAVING_LIQUID
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	if (mc_Entity.x == 10300 || mc_Entity.x == 10302) position.y += WavingWater(position.xyz, lmCoord);
	#endif

    #ifdef WORLD_CURVATURE
	position.y -= WorldCurvature(position.xz);
    #endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	if (mat == 0.0) gl_Position.z -= 0.00001;
	
	#ifdef TAA
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif