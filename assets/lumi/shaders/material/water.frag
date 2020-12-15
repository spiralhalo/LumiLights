#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/lib/color.glsl
#include lumi:shaders/lib/bump.glsl
#include lumi:shaders/api/water_param.glsl

float ww_noise(vec3 pos, vec3 move, float invScale, float amplitude, float stretch)
{
	vec3 noisePos = vec3(pos.x * invScale * stretch, pos.y * invScale, pos.z * invScale) + move;
    return (snoise(noisePos) * 0.5 + 0.5) * amplitude;
}

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
	
	// normal recalculation
	vec3 up = fragData.vertexNormal.xyz;// * (1.0 + texAmplitude);
	vec3 samplePos = frx_var0.xyz;
	// samplePos = floor(samplePos) + floor(fract(samplePos) * 16) / 16;

	float microSample = 0.01 * scale;
	float invScale = 1 / scale;
	vec3  waveMove = moveSpeed * frx_renderSeconds() * waveSpeed;
		  waveMove.xz *= abs(up.y);

	vec3 tmove = _bump_tangentMove(up);
	vec3 bmove = _bump_bitangentMove(up, tmove) * microSample;
		 tmove *= microSample;
	
	vec3 origin = ww_noise(samplePos, waveMove, invScale, amplitude, stretch) * up;
	vec3 tangent = tmove + ww_noise(samplePos + tmove, waveMove, invScale, amplitude, stretch) * up - origin;
	vec3 bitangent = bmove + ww_noise(samplePos + bmove, waveMove, invScale, amplitude, stretch) * up - origin;

	vec3 noisyNormal = normalize(cross(tangent, bitangent));
	fragData.vertexNormal = noisyNormal;
#endif
}
