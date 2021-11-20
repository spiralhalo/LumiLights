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
const vec2 BLOOM_DOWNSAMPLE_DIST_VEC = vec2(BLOOM_SCALE / 25.0);
const vec2 BLOOM_UPSAMPLE_DIST_VEC	 = max(vec2(0.1), BLOOM_DOWNSAMPLE_DIST_VEC * 0.1);

void main()
{
	if (frxu_layer == 0) {
		vec4 base = hdr_inverseTonemap(texture(u_input, v_texcoord));
		float luminance = l2_max3(base.rgb); //use max instead of luminance to get some lava action
		float luminanceGate = l2_clampScale(0.7, 1.0, luminance); //TODO: configurable
		fragColor = base * luminanceGate;
	} else if (frxu_layer == 1) {
		fragColor = frx_sample13(u_input, v_texcoord, BLOOM_DOWNSAMPLE_DIST_VEC / frxu_size, max(0, frxu_lod - 1));
	} else if (frxu_layer == 2) {
		fragColor = textureLod(u_input, v_texcoord, frxu_lod);
	} else if (frxu_layer == 3) {
		vec4 prior = frx_sampleTent(u_blend, v_texcoord, BLOOM_UPSAMPLE_DIST_VEC / frxu_size, frxu_lod + 1);
		fragColor = textureLod(u_input, v_texcoord, frxu_lod) + prior;
	} else {
		vec4 base  = texture(u_input, v_texcoord);
		vec4 bloom = textureLod(u_blend, v_texcoord, 0) * BLOOM_INTENSITY_FLOAT;
		vec3 color = hdr_inverseTonemap(base.rgb) + bloom.rgb;
		fragColor = vec4(ldr_tonemap(color), 1.0);
	}
}
