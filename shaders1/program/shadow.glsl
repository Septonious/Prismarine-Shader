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
varying vec2 texCoord;
varying vec4 color;

//Uniforms//
uniform int blockEntityId, worldTime;

uniform sampler2D tex;

#ifdef WATER_CAUSTICS
uniform int isEyeInWater;

uniform float frameTimeCounter, timeBrightness;

varying vec4 position;

uniform vec3 cameraPosition;

uniform sampler2D noisetex;

#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

#include "/lib/color/waterColor.glsl"
#include "/lib/lighting/caustics.glsl"
#endif

//Program//
void main() {
    #if MC_VERSION >= 11300
	if (blockEntityId == 10205) discard;
	#endif

    vec4 albedo = texture2D(tex, texCoord.xy);
	albedo.rgb *= color.rgb;

    float premult = float(mat > 0.98 && mat < 1.02);
	float disable = float(mat > 1.98 && mat < 2.02);
	if (disable > 0.5 || albedo.a < 0.01) discard;

    #ifdef SHADOW_COLOR
	albedo.rgb = mix(vec3(1.0), albedo.rgb, pow(albedo.a, (1.0 - albedo.a) * 0.5));
	albedo.rgb *= 1.0 - pow(albedo.a, 64.0);
	#else
	if ((premult > 0.5 && albedo.a < 0.98)) albedo.a = 0.0;
	#endif

	#ifdef WATER_CAUSTICS
	if (mat > 2.98 && mat < 3.02){
		float caustics = getCaustics(position.xyz + cameraPosition.xyz);
		if (isEyeInWater == 0) albedo.rgb = mix(waterColor.rgb, waterColor.rgb * WATER_CAUSTICS_STRENGTH, caustics);
		else albedo.rgb *= caustics * waterColor.rgb * WATER_CAUSTICS_STRENGTH;
	}
	#endif
	
	gl_FragData[0] = albedo;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat;

varying vec2 texCoord;

varying vec4 color, position;

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;

	vec2 lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, vec2(0.0), vec2(0.9333, 1.0));

	color = gl_Color;
	
	mat = 0.0;
	if (mc_Entity.x == 10301 || mc_Entity.x == 10302) mat = 1.0;
	if (mc_Entity.x == 10204) mat = 2.0;
	#ifdef WATER_CAUSTICS
	if (mc_Entity.x == 10300 || mc_Entity.x == 10303) mat = 3.0;
	#else
	if (mc_Entity.x == 10300 || mc_Entity.x == 10303) mat = 2.0;
	#endif
	
	position = shadowModelViewInverse * shadowProjectionInverse * ftransform();
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz = WavingBlocks(position.xyz, istopv, lmCoord);

	#ifdef WORLD_CURVATURE
	position.y -= WorldCurvature(position.xz);
	#endif
	
	gl_Position = shadowProjection * shadowModelView * position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);
	
	gl_Position.xy *= 1.0 / distortFactor;
	gl_Position.z = gl_Position.z * 0.2;
}

#endif