/*******************************************************
 *  lumi:shaders/internal/main_frag.glsl               *
 *******************************************************
 *  Copyright (c) 2020 spiralhalo and Contributors.    *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

const float hdr_finalMult = 1;
const float hdr_gamma = 2.2;

float hdr_gammaAdjust(float x){
	return pow(x, hdr_gamma);
}

vec3 hdr_gammaAdjust(vec3 x){
	return pow(x, vec3(hdr_gamma));
}

float l2_clampScale(float e0, float e1, float v){
    return clamp((v-e0)/(e1-e0), 0.0, 1.0);
}

float l2_max3(vec3 vec){
	return max(vec.x, max(vec.y, vec.z));
}

float l2_ao(frx_FragmentData fragData) {
#if AO_SHADING_MODE != AO_MODE_NONE
#if LUMI_LightMode == LUMI_LightMode_SystemUnused
	float aoInv = 1.0 - (fragData.ao ? _cvv_ao : 1.0);
	return 1.0 - 0.8 * smoothstep(0.0, 0.3, aoInv * (0.5 + 0.5 * abs((_cvv_normal * frx_normalModelMatrix()).y)));
#else
	float ao = fragData.ao ? _cvv_ao : 1.0;
	return hdr_gammaAdjust(min(1.0, ao + fragData.emissivity));
#endif
#else
	return 1.0;
#endif
}
