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

varying vec4 color;

//Uniforms//
uniform sampler2D texture;

#ifdef CUSTOM_BEACON_BEAM
uniform sampler2D noisetex;
#endif

//Program//
void main() {
	vec4 albedo = texture2D(texture, texCoord) * color;
	albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 4.0;
	
	#ifdef WHITE_WORLD
	albedo.rgb = vec3(2.0);
	#endif

	#if ALPHA_BLEND == 0
	albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
	#endif

	#ifdef CUSTOM_BEACON_BEAM
	float noise = texture2D(noisetex, texCoord * 0.03).r * 0.1;
		  noise+= texture2D(noisetex, texCoord * 0.02).r * 0.2;
		  noise+= texture2D(noisetex, texCoord * 0.01).r * 0.3;
		
	noise = min(max(0.0, noise * noise), 1.0);

	albedo.a -= noise;
	albedo.rgb += noise;
	#endif
    
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;

	#ifdef ADVANCED_MATERIALS
	/* DRAWBUFFERS:0367 */
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[2] = vec4(0.0, 0.0, float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif

	#if defined SSGI && !defined ADVANCED_MATERIALS
	/* RENDERTARGETS:0,9,10*/
	gl_FragData[1] = vec4(0.25);
	gl_FragData[2] = albedo;
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec4 color;

//Uniforms//
#ifdef TAA
uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;
#include "/lib/util/jitter.glsl"
#endif

#ifdef WORLD_CURVATURE
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
#endif

//Includes//
#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	color = gl_Color;

	#ifdef WORLD_CURVATURE
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	if (gl_ProjectionMatrix[2][2] < -0.5) position.y -= WorldCurvature(position.xz);
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
	gl_Position = ftransform();
	#endif
	
	#ifdef TAA
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif