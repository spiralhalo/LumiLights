#include frex:shaders/api/world.glsl

/*******************************************************
 *  lumi:shaders/lib/water.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

float ww_noise(vec3 pos, vec3 move, float invScale, float amplitude, float stretch)
{
	vec3 hh = vec3(pos.x * invScale, pos.y * invScale, pos.z * invScale * stretch);
	vec3 pp1 = hh + move;
	vec3 pp2 = hh * 5.0 + move;
	// vec3 pp3 = hh * 10.0 + move;
	float xx1 = (snoise(pp1) * 0.5 + 0.5) * 0.9;
	float xx2 = (snoise(pp2) * 0.5 + 0.5) * 0.1;
	// float xx3 = (snoise(pp3) * 0.5 + 0.5) * 0.05;
	return (xx1 + xx2) * amplitude;
}

vec3 ww_normals(vec3 up, vec3 tgt, vec3 btgt, vec3 samplePos, float waveSpeed, float scale, float amplitude, float stretch, vec3 moveSpeed)
{
	float microSample = 0.01 * scale;
	float invScale = 1 / scale;
	float upFactor = abs(up.y);
	vec3  waveMove = moveSpeed * frx_renderSeconds() * waveSpeed;
		  waveMove.xz *= upFactor;
		  waveMove.y *= 1.0 - upFactor * 0.8;

	vec3 tmove = tgt * microSample;
	vec3 bmove = btgt * microSample;
	
	vec3 origin = ww_noise(samplePos, waveMove, invScale, amplitude, stretch) * up;
	vec3 tangent = tmove + ww_noise(samplePos + tmove, waveMove, invScale, amplitude, stretch) * up - origin;
	vec3 bitangent = bmove + ww_noise(samplePos + bmove, waveMove, invScale, amplitude, stretch) * up - origin;

	vec3 noisyNormal = normalize(cross(tangent, bitangent));

	return noisyNormal;
}
