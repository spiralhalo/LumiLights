#include lumi:shaders/lib/bump.glsl

float ww_noise(vec3 pos, vec3 move, float invScale, float amplitude, float stretch)
{
	vec3 noisePos = vec3(pos.x * invScale * stretch, pos.y * invScale, pos.z * invScale) + move;
    return (snoise(noisePos) * 0.5 + 0.5) * amplitude;
}

vec3 ww_normals(vec3 up, vec3 samplePos, float waveSpeed, float scale, float amplitude, float stretch, vec3 moveSpeed)
{
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
	return noisyNormal;
}
