/*******************************************************
 *  lumi:shaders/internal/main_vert.glsl               *
 *******************************************************
 *  Copyright (c) 2020 spiralhalo and Contributors.    *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

varying vec3 pbrv_viewPos;

#ifdef LUMI_BUMP
float bump_resolution;
vec2 uvN;
vec2 uvT;
vec2 uvB;

void startBump() {
	bump_resolution = 1.0;
}

void setupBump(frx_VertexData data) {
	float bumpSample = 0.015625 * bump_resolution;

	uvN = clamp(data.spriteUV + vec2(-bumpSample, bumpSample), 0.0, 1.0);
	uvT = clamp(data.spriteUV + vec2(bumpSample, 0), 0.0, 1.0);
	uvB = clamp(data.spriteUV - vec2(0, bumpSample), 0.0, 1.0);
}

void endBump(vec4 spriteBounds) {
    uvN = spriteBounds.xy + uvN * spriteBounds.zw;
    uvT = spriteBounds.xy + uvT * spriteBounds.zw;
    uvB = spriteBounds.xy + uvB * spriteBounds.zw;
}
#endif

#ifdef LUMI_PBR
void setPBRVaryings(vec4 viewCoord) {
    pbrv_viewPos = viewCoord.xyz;
}
#endif
