#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/lib/color.glsl
#include lumi:shaders/lib/bump.glsl

float ww_noise(vec3 aPos, float renderTime, float invScale, float amplitude, float stretch)
{
    return (snoise(vec3(aPos.x * invScale * stretch, aPos.z * invScale, aPos.y * invScale + renderTime)) * 0.5+0.5) * amplitude;
}

// water wavyness parameter
const float speed = 2;
const float scale = 1.5;
const float amplitude = 0.01;
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
    // fragData.spriteColor.rgb *= fragData.spriteColor.rgb * 0.8;
		
	// hack
	// fragData.light.y += 0.077 * smoothstep(1.0, 0.99, fragData.vertexNormal.y);
	fragData.light.y = min(0.96875, fragData.light.y);
	
	vec3 samplePos = frx_var0.xyz;
	// samplePos = floor(samplePos) + floor(fract(samplePos) * 16) / 16;

	// inferred parameter
	float renderTime = frx_renderSeconds() * 0.5 * speed;
	float microSample = 0.01 * scale;
	float invScale = 1 / scale;

	// base noise
	float noise = ww_noise(samplePos, renderTime, invScale, amplitude, stretch);

	// normal recalculation
	vec3 origNormal = fragData.vertexNormal.xyz;

	vec3 tangentMove = _bump_tangentMove(origNormal) * microSample;
	vec3 bitangentMove = _bump_bitangentMove(origNormal, tangentMove) * microSample; 
	
	vec3 origin = noise * origNormal;
	vec3 tangent = tangentMove + ww_noise(samplePos + tangentMove, renderTime, invScale, amplitude, stretch) * origNormal - origin;
	vec3 bitangent = bitangentMove + ww_noise(samplePos + bitangentMove, renderTime, invScale, amplitude, stretch) * origNormal - origin;

	// noisy normal
	vec3 noisyNormal = normalize(cross(tangent, bitangent));
	fragData.vertexNormal = noisyNormal;
#endif
}
