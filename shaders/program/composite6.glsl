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

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform sampler2D colortex1, colortex9;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Common Functions//
vec3 ToWorld(vec3 pos) {
	return mat3(gbufferModelViewInverse) * pos + gbufferModelViewInverse[3].xyz;
}

//Includes//
#include "/lib/lighting/refraction.glsl"

//Program//
void main() {
    vec3 color = texture2D(colortex1, texCoord).rgb;

	float z0 = texture2D(depthtex0, texCoord).r;

    vec4 waterData = texture2D(colortex9, texCoord);

    if (waterData.a > 0.5){
        vec4 screenPos = vec4(texCoord, z0, 1.0);
        vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
        viewPos /= viewPos.w;

        vec3 worldPos = ToWorld(viewPos.xyz);
        vec3 waterPos = worldPos + cameraPosition;

        vec2 refractCoord = getRefraction(texCoord, waterPos, waterData.b);
        color = texture2D(colortex1, refractCoord).rgb;
    }

    /* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(color, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif