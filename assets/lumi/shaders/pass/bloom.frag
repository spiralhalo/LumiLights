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
		float estimatedExposure = frx_smoothedEyeBrightness.y;
		const float LOWER_BOUND = 0.0; // based on indoor lava
		const float UPPER_BOUND = 0.9; // based on semi-comfortable bloom on snowy scapes
		float minimumLuminance = mix(LOWER_BOUND, UPPER_BOUND, estimatedExposure);
		float luminanceGate = smoothstep(minimumLuminance, 1.0, luminance);
		fragColor = base * luminanceGate;
	} else if (frxu_layer == 1) {
		fragColor = frx_sample13(u_input, v_texcoord, BLOOM_DOWNSAMPLE_DIST_VEC / frxu_size, max(0, frxu_lod - 1));
	} else {
		vec4 base  = texture(u_input, v_texcoord);
		vec4 bloom6 = frx_sampleTent(u_blend, v_texcoord, BLOOM_UPSAMPLE_DIST_VEC / frxu_size, 6);
		vec4 bloom5 = frx_sampleTent(u_blend, v_texcoord, BLOOM_UPSAMPLE_DIST_VEC / frxu_size, 5);
		vec4 bloom4 = frx_sampleTent(u_blend, v_texcoord, BLOOM_UPSAMPLE_DIST_VEC / frxu_size, 4);
		vec4 bloom = (bloom6 + bloom5 + bloom4) / 3.0 * BLOOM_INTENSITY_FLOAT;
		vec3 color = hdr_inverseTonemap(base.rgb) + bloom.rgb;
		fragColor = vec4(ldr_tonemap(color), 1.0);
	}
}
