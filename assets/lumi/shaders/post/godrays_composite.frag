#include lumi:shaders/post/common/header.glsl

#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/godrays.frag
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
	// underwater rays are already kind of thin
	float blurAdj = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? 2.0 : 0.0;

	vec3 scatterColor = vec3(1.0);

	if (frx_viewFlag(FRX_CAMERA_IN_WATER)) {
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

	float d = texture(u_depth, v_texcoord).r;
	vec4 a = texture(u_color, v_texcoord);
	vec4 b = textureLod(u_godrays, v_texcoord, (1.0 - ldepth(d)) * (3. - blurAdj));

	b.a = b.r;
	b.rgb = ldr_tonemap3(godraysRadiance);

	// vec3 aa = hdr_fromGamma(a.rgb);
	// vec3 bb = hdr_fromGamma(b.rgb);

	// vec3 cc = aa + bb * a.rgb * b.a; // TOO GLITCHY
	// vec3 cc = aa + bb * b.a; // WAY TOO WASHED OUT

	// vec3 c = hdr_toSRGB(cc);
	// vec3 c = a.rgb * (1.0 - b.a) + b.rgb * b.a; // TOO WASHED OUT
	// vec3 c = a.rgb + b.rgb * a.rgb * b.a; // TOO GLITCHY
	vec3 c = a.rgb + b.rgb * b.a; // ORIGINAL BLENDING

	fragColor = vec4(c, a.a);
}
