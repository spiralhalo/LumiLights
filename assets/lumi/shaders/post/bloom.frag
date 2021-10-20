#include lumi:shaders/post/common/header.glsl

#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/sample.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/post/common/bloom.glsl
#include lumi:shaders/lib/bitpack.glsl
#include lumi:shaders/lib/util.glsl

/******************************************************
  lumi:shaders/post/bloom.frag
******************************************************/

uniform sampler2D u_base;
uniform sampler2D u_bloom;
uniform sampler2D u_base_misc;
uniform sampler2D u_blue_noise;

out vec4 fragColor;

// Based on approach described by Jorge Jiminez, 2014
// http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
void main()
{
	vec4 base;

#if HURT_MODE != HURT_MODE_CLASSIC_RED
	vec3 misc = texture(u_base_misc, v_texcoord).xyz;
	float mathurt = bit_unpack(misc.z, 1);

	if (mathurt == 1.0) {
		const vec2 mul = vec2(1.0, 0.0);
#if HURT_MODE == HURT_MODE_GLITCH_CITY
		float t = fract(floor(frx_renderSeconds() * 30.0) * 0.1);
		vec2 noise = texture(u_blue_noise, vec2(t, 0.0)).rg;
		vec4 one = texture(u_base, v_texcoord + noise * vec2(-0.05,  0.05));
		vec4 two = texture(u_base, v_texcoord + noise * vec2( 0.05, -0.05));
#else
		vec4 one = texture(u_base, v_texcoord + vec2(-0.005, 0.0));
		vec4 two = texture(u_base, v_texcoord + vec2( 0.005, 0.0));
#endif
		base = one * mul.yxxx + two * mul.xyxx;
	} else {
		base = texture(u_base, v_texcoord);
	}
#else
	base = texture(u_base, v_texcoord);
#endif

	vec4 bloom = textureLod(u_bloom, v_texcoord, 0) * BLOOM_INTENSITY_FLOAT;

	vec3 color = hdr_fromGamma(base.rgb) + bloom.rgb;

	fragColor = vec4(hdr_toSRGB(color), 1.0);
}
