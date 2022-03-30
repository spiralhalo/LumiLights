#include lumi:shaders/pass/header.glsl

#include frex:shaders/lib/sample.glsl
#include lumi:shaders/prog/tonemap.glsl

/******************************************************
  lumi:shaders/pass/bloom.frag
******************************************************/

uniform sampler2D u_input;
uniform sampler2D u_blend;

out vec4 fragColor;

const float BLOOM_INTENSITY_FLOAT	 = BLOOM_INTENSITY / 50.0;
const vec2 BLOOM_DOWNSAMPLE_DIST_VEC = vec2(clamp(BLOOM_SCALE / 10., 0.1, 2.0));
const vec2 BLOOM_UPSAMPLE_DIST_VEC	 = BLOOM_DOWNSAMPLE_DIST_VEC / 10.; // not sure why this is

void main()
{
	if (frxu_layer == 1) {
		fragColor = frx_sample13(u_input, v_texcoord, BLOOM_DOWNSAMPLE_DIST_VEC / frxu_size, max(0, frxu_lod - 1));
	} else if (frxu_layer == 2) {
		vec4 prior = frxu_lod == 5 ? vec4(0.0) : textureLod(u_input, v_texcoord, frxu_lod + 1);
		vec4 bloom = frx_sampleTent(u_blend, v_texcoord, BLOOM_UPSAMPLE_DIST_VEC / frxu_size, frxu_lod + 1);
		fragColor = prior + bloom;
	} else {
		vec4 base  = texture(u_input, v_texcoord);
		vec4 bloom = texture(u_blend, v_texcoord);
		bloom /= 6.0;
		bloom *= BLOOM_INTENSITY_FLOAT;

		vec3 color = hdr_inverseTonemap(base.rgb) + bloom.rgb;
		fragColor = vec4(ldr_tonemap(color), 1.0);

		#if TONEMAP_OPERATOR != TMO_DEFAULT
		fragColor = brightness(POST_TMO_BRIGHTNESS, contrast(POST_TMO_CONTRAST, saturation(POST_TMO_SATURATION, fragColor)));
		#endif
	}
}
