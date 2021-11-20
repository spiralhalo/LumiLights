#include lumi:shaders/post/common/header.glsl

#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/post/common/bloom.glsl

/*******************************************************
 *  lumi:shaders/post/godrays_composite.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_depth;
uniform sampler2D u_color;
uniform sampler2D u_godrays;

out vec4 fragColor;

void main() {
	vec3 scatterColor = vec3(1.0);

	if (frx_cameraInWater == 1) {
		scatterColor = atmos_hdrFogColorRadiance(vec3(0.0, 0.0, 1.0));
		scatterColor /= l2_max3(scatterColor);
	}

	float scatterLuminance = frx_luminance(scatterColor);

	scatterColor = scatterLuminance == 0.0 ? vec3(1.0) : scatterColor / scatterLuminance;

	vec3 godraysRadiance = atmos_hdrCelestialRadiance() * scatterColor;

	// moonlight is too bright because exposure is low at night
	// TODO: Do better than this
	// TODO: might as well do godrays in HDR space
	godraysRadiance *= 0.1 + atmosv_celestIntensity * 0.9;

	vec3 tmapped = ldr_tonemap(godraysRadiance);

	vec4 a = texture(u_color, v_texcoord);
	vec4 b = vec4(tmapped, texture(u_godrays, v_texcoord).r);

	// vec3 aa = hdr_fromGamma(a.rgb);
	// vec3 bb = hdr_fromGamma(b.rgb);

	// vec3 cc = aa + bb * a.rgb * b.a; // TOO GLITCHY
	// vec3 cc = aa + bb * b.a; // WAY TOO WASHED OUT

	// vec3 c = hdr_toSRGB(cc);
	// vec3 c = a.rgb * (1.0 - b.a) + b.rgb * b.a; // TOO WASHED OUT
	// vec3 c = a.rgb + b.rgb * a.rgb * b.a; // TOO GLITCHY

#if LIGHTRAYS_BLENDING == LIGHTRAYS_BLENDING_BLOOM
	vec3 c = mix(a.rgb, b.rgb, b.a * l2_clampScale(0.0, 0.5, BLOOM_INTENSITY_FLOAT));
#else
	// vec3 c = blendLinearLight(a.rgb, b.rgb, b.a); // linear light is only capable of comprehending turmeric yellow
	vec3 c = a.rgb + b.rgb * b.a;

#if LIGHTRAYS_BLENDING == LIGHTRAYS_BLENDING_LUMI_BLEND_A
	c = min(c, max(a.rgb, b.rgb)); // like linear light but understands the color orange
#endif
#endif

// #if LIGHTRAYS_BLENDING == LIGHTRAYS_BLENDING_LUMI_BLEND_B
// 	vec3 c2  = min(c, max(a.rgb, b.rgb));
// 	float l1 = frx_luminance(c);
// 	float l2 = frx_luminance(c2);
// 	c = mix(c, c2, l1); // BAD: this mixing causes grayish zone
// #endif

	fragColor = vec4(c, a.a);
}
