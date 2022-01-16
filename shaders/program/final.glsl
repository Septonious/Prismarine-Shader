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
uniform sampler2D colortex1;

uniform float viewWidth, viewHeight;
uniform float aspectRatio;

//Optifine Constants//
/*
const int colortex0Format = R11F_G11F_B10F; //main scene
const int colortex1Format = RGB8; //raw translucent, bloom, final scene
const int colortex2Format = RGBA16; //temporal data
const int colortex3Format = RGB8; //specular data
const int gaux1Format = R8; //cloud alpha, ao
const int gaux2Format = RGB10_A2; //reflection image
const int gaux3Format = RGB16; //normals
const int gaux4Format = RGB16; //fresnel
*/

const bool shadowHardwareFiltering = true;
const float shadowDistanceRenderMul = 1.0;

const int noiseTextureResolution = 512;

const float drynessHalflife = 50.0;
const float wetnessHalflife = 300.0;

//Common Functions//
#if defined CAS || defined TAA
void ContrastAdaptiveSharpening(inout vec3 outColor){
    vec2 uv = texCoord * MC_RENDER_QUALITY;
  
    vec3 originalColor = texture2D(colortex1, uv).rgb;
    vec3 modifiedColor = vec3(0.0);

    vec4 uvoff = vec4(1.0, 0.0, 1.0, -1.0) / vec4(vec2(viewWidth, viewWidth), vec2(viewHeight, viewHeight));

    float maxGreen = originalColor.g;
    float minGreen = originalColor.g;
    float adaptiveSharpening = 0.0;

    vec3 newColor = texture2D(colortex1, uv + uvoff.yw).rgb;
    maxGreen = max(maxGreen, newColor.g);
    minGreen = min(minGreen, newColor.g);
        modifiedColor = newColor;
    	 newColor = texture2D(colortex1, uv + uvoff.xy).rgb;
    maxGreen = max(maxGreen, newColor.g);
    minGreen = min(minGreen, newColor.g);
        modifiedColor += newColor;
    	 newColor = texture2D(colortex1, uv + uvoff.yz).rgb;
    maxGreen = max(maxGreen, newColor.g);
    minGreen = min(minGreen, newColor.g);
        modifiedColor += newColor;
    	 newColor = texture2D(colortex1, uv - uvoff.xy).rgb;
    maxGreen = max(maxGreen, newColor.g);
    minGreen = min(minGreen, newColor.g);
        modifiedColor += newColor;

    adaptiveSharpening = minGreen / max(maxGreen, 0.0);

    adaptiveSharpening = sqrt(max(0.0, adaptiveSharpening));
    adaptiveSharpening *= mix(-0.125, -0.2, 0.25);

    outColor = (originalColor + modifiedColor * adaptiveSharpening) / (1.0 + 4.0 * adaptiveSharpening);
}
#endif

/*
#include "/lib/util/dither.glsl"
uniform sampler2D colortex2;
#define dot2( a) dot(a,a)
uniform int frameCounter;
#define RENDERSCALE 0.03125

#define phi2 1.32471795724474602596090885447809734
#define phi2sq phi2*phi2

void mainImage(out vec4 outColor){
    vec2 imageResolution = vec2(viewWidth, viewHeight);
    vec2 coord = imageResolution * gl_FragCoord.xy;

    float k = 80.0;
    int kernell = 1;
    float s = min(3.14 / k * float(frameCounter), 15.0);
    
    outColor = texture2D(colortex2, gl_FragCoord.xy / imageResolution) * s;
    
    for(int x = -kernell; x <= kernell; x++){
        for(int y = -kernell; y <= kernell; y++){
            vec2 offset = vec2(x, y);
            vec2 offsetNew = fract(Bayer16(coord + offset) + float(frameCounter) / vec2(phi2sq, phi2)) + offset;

            float weight = exp2(-(s <= 1e-3 ? 0.25 / RENDERSCALE : k) * dot2(offsetNew - fract(coord)));
            vec4 color = texture2D(colortex1, (coord + offset) / imageResolution);
            
            outColor += color * weight;
            s += weight;
    	}
    }
    outColor /= max(s, 1e-6);
}
*/

//Program//
void main() {
    vec2 newTexCoord = texCoord;

	vec3 color = texture2DLod(colortex1, newTexCoord, 0.0).rgb;

	#if CHROMATIC_ABERRATION > 0
	float caStrength = 0.004 * CHROMATIC_ABERRATION;
	vec2 caScale = vec2(1.0 / aspectRatio, 1.0);
	color *= vec3(0.0,1.0,0.0);
	color += texture2DLod(colortex1, mix(newTexCoord, vec2(0.5), caScale * -caStrength), 0).rgb * vec3(1.0,0.0,0.0);
	color += texture2DLod(colortex1, mix(newTexCoord, vec2(0.5), caScale * -caStrength * 0.5), 0).rgb * vec3(0.5,0.5,0.0);
	color += texture2DLod(colortex1, mix(newTexCoord, vec2(0.5), caScale * caStrength * 0.5), 0).rgb * vec3(0.0,0.5,0.5);
	color += texture2DLod(colortex1, mix(newTexCoord, vec2(0.5), caScale* caStrength), 0).rgb * vec3(0.0,0.0,1.0);

	color /= vec3(1.5, 2.0, 1.5);
	#endif

    #if defined CAS || defined TAA
    ContrastAdaptiveSharpening(color.rgb);
    #endif

	gl_FragColor = vec4(color, 1.0);
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