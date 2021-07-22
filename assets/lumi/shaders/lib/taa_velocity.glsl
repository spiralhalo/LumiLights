#include frex:shaders/api/view.glsl
#include lumi:shaders/lib/taa.glsl

/*******************************************************
 *  lumi:shaders/lib/taa_velocity.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

vec2 calcVelocity(sampler2D depthTex, vec2 currentUv, vec2 sizeRcp) {
	float closestDepth = texture(depthTex, GetClosestUV(depthTex, currentUv, sizeRcp)).r;
	vec4 currentModelPos = frx_inverseViewProjectionMatrix() * vec4(currentUv * 2.0 - 1.0, closestDepth * 2.0 - 1.0, 1.0);
	currentModelPos.xyz /= currentModelPos.w;
	currentModelPos.w = 1.0;

	// This produces correct velocity?
	vec4 cameraToLastCamera = vec4(frx_cameraPos() - frx_lastCameraPos(), 0.0);
	vec4 prevModelPos = currentModelPos + cameraToLastCamera;

	prevModelPos = frx_lastViewProjectionMatrix() * prevModelPos;
	prevModelPos.xy /= prevModelPos.w;
	vec2 prevPos = (prevModelPos.xy * 0.5 + 0.5);

	return vec2(currentUv - prevPos);
}

// Optimized velocity for SSAO / local use case
vec2 fastVelocity(sampler2D depthTex, vec2 currentUv) {
	float depth = texture(depthTex, currentUv).r;
	vec4 currentModelPos = frx_inverseViewProjectionMatrix() * vec4(currentUv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	currentModelPos.xyz /= currentModelPos.w;
	currentModelPos.w = 1.0;

	// This produces correct velocity?
	vec4 cameraToLastCamera = vec4(frx_cameraPos() - frx_lastCameraPos(), 0.0);
	vec4 prevModelPos = currentModelPos + cameraToLastCamera;

	prevModelPos = frx_lastViewProjectionMatrix() * prevModelPos;
	prevModelPos.xy /= prevModelPos.w;
	vec2 prevPos = (prevModelPos.xy * 0.5 + 0.5);

	if (prevPos != clamp(prevPos, 0., 1.)) return vec2(0.); // out of bounds

	return vec2(currentUv - prevPos);
}
