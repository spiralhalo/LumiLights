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
const vec2 BLOOM_DOWNSAMPLE_DIST_VEC = vec2(BLOOM_SCALE / 10. * 2.); // must be at least one
const vec2 BLOOM_UPSAMPLE_DIST_VEC	 = BLOOM_DOWNSAMPLE_DIST_VEC / 10.; // not sure why this is

void main()
{
	if (frxu_layer == 0) {
		vec4 base = hdr_inverseTonemap(texture(u_input, v_texcoord));
		float luminance = l2_max3(base.rgb); //use max instead of luminance to get some lava action
		const float MIN_LUM = 0.9; // based on semi-comfortable bloom on snowy scapes
		float luminanceGate = smoothstep(MIN_LUM, MIN_LUM + 2.0, luminance);
		fragColor = base * luminanceGate;
	} else if (frxu_layer == 1) {
		fragColor = frx_sample13(u_input, v_texcoord, BLOOM_DOWNSAMPLE_DIST_VEC / frxu_size, max(0, frxu_lod - 1));
	} else {
		vec4 base  = texture(u_input, v_texcoord);
		vec4 bloom = vec4(0.);
		for (int i = 6; i >= 0; i--) {
			bloom += frx_sampleTent(u_blend, v_texcoord, BLOOM_UPSAMPLE_DIST_VEC / frxu_size, i);
		}
		bloom /= 6.0;
		bloom *= BLOOM_INTENSITY_FLOAT;
		vec3 color = hdr_inverseTonemap(base.rgb) + bloom.rgb;
		fragColor = vec4(ldr_tonemap(color), 1.0);
	}
}
