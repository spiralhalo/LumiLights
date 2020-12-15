#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/lib/color.glsl
#include lumi:shaders/lib/bump.glsl

float ww_noise(vec3 pos, float time, float invScale, float amplitude, float stretch)
{
    return (snoise(vec3(pos.x * invScale * stretch, pos.z * invScale, pos.y * invScale + time)) * 0.5 + 0.5) * amplitude;
}

// water wavyness parameter
const float speed = 2;
const float scale = 1.5;
const float amplitude = 0.01;
// const float texAmplitude = 0.005;
const float stretch = 2;

void frx_startFragment(inout frx_FragmentData fragData) {
#ifdef LUMI_PBR
	pbr_f0 = vec3(0.02);
    pbr_roughness = 0.05;
	
	vec3 desat = vec3(frx_luminance(fragData.vertexColor.rgb));
	fragData.vertexColor.rgb = mix(fragData.vertexColor.rgb, desat, 0.7);

	float maxc = max(fragData.spriteColor.r, max(fragData.spriteColor.g, fragData.spriteColor.b)); 
	fragData.spriteColor.rgb *= fragData.spriteColor.rgb * fragData.spriteColor.rgb * 2.0;

	float l = frx_luminance(fragData.spriteColor.rgb);
	pbr_f0 = mix(pbr_f0, vec3(0.2), l * l);
	
	vec3 samplePos = frx_var0.xyz;
	// samplePos = floor(samplePos) + floor(fract(samplePos) * 16) / 16;

	// inferred parameter
	float time = frx_renderSeconds() * 0.5 * speed;
	float microSample = 0.01 * scale;
	float invScale = 1 / scale;

	// base noise
	float noise = ww_noise(samplePos, time, invScale, amplitude, stretch);

	// normal recalculation
	vec3 up = fragData.vertexNormal.xyz;// * (1.0 + texAmplitude);

	vec3 tmove = _bump_tangentMove(up) * microSample;
	vec3 bmove = _bump_bitangentMove(up, tmove) * microSample; 
	
	vec3 origin = noise * up;
	vec3 tangent = tmove + ww_noise(samplePos + tmove, time, invScale, amplitude, stretch) * up - origin;
	vec3 bitangent = bmove + ww_noise(samplePos + bmove, time, invScale, amplitude, stretch) * up - origin;

	// noisy normal
	vec3 noisyNormal = normalize(cross(tangent, bitangent));
	fragData.vertexNormal = noisyNormal;
#endif
}
