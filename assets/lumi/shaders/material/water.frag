#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/lib/color.glsl

float ww_noise(vec3 aPos, float renderTime, float scale, float amplitude, float stretch)
{
	float invScale = 1/scale;
    return (snoise(vec3(aPos.x * invScale * stretch, aPos.z*invScale, renderTime)) * 0.5+0.5) * amplitude;
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

    if(fragData.vertexNormal.y > 0.01) {
		
		// hack
    	fragData.light.y += 0.077 * smoothstep(1.0, 0.99, fragData.vertexNormal.y);
    	fragData.light.y = min(0.96875, fragData.light.y);
		
		vec3 samplePos = frx_var0.xyz;
		// samplePos = floor(samplePos) + floor(fract(samplePos) * 16) / 16;

		// inferred parameter
		float renderTime = frx_renderSeconds() * 0.5 * speed;
		float microSample = 0.01 * scale;

		// base noise
		float noise = ww_noise(samplePos, renderTime, scale, amplitude, stretch);

		// normal recalculation
		vec3 noiseOrigin = vec3(0, noise, 0);
		vec3 noiseTangent = vec3(microSample, ww_noise(samplePos + vec3(microSample,0,0), renderTime, scale, amplitude, stretch), 0) - noiseOrigin;
		vec3 noiseBitangent = vec3(0, ww_noise(samplePos + vec3(0,0,microSample), renderTime, scale, amplitude, stretch), microSample) - noiseOrigin;

		// noisy normal
		vec3 noisyNormal = normalize(cross(noiseBitangent, noiseTangent));
		fragData.vertexNormal = noisyNormal;
	}
#endif
}
