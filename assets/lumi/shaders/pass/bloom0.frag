#include lumi:shaders/pass/header.glsl

#include frex:shaders/lib/sample.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/prog/tonemap.glsl

/******************************************************
  lumi:shaders/pass/bloom.frag
******************************************************/

uniform sampler2D u_input;
uniform sampler2D u_vanilla_depth;

uniform sampler2DArray u_color_others;
uniform sampler2DArray u_gbuffer_lightnormal;

out vec4 fragColor;

void main()
{
	vec4  albedo   = texture(u_color_others, vec3(v_texcoord, ID_OTHER_ALBEDO));
	float idLight  = texture(u_vanilla_depth, v_texcoord).r == 1.0
		? (albedo.a == 0.0 ? ID_SOLID_LIGT : (albedo.a < 1.0 ? ID_TRANS_LIGT : ID_PARTS_LIGT))
		: ID_SOLID_LIGT;
	float lightz   = texture(u_gbuffer_lightnormal, vec3(v_texcoord, idLight)).z;
	float emissive = lightz;

	vec4 base = hdr_inverseTonemap(texture(u_input, v_texcoord));
	float luminance = l2_max3(base.rgb); //use max instead of luminance to get some lava action
	
	const float MIN_LUM = 1.0;
	const float MAX_LUM = max(10.0, DEF_SUNLIGHT_STR); //if your screen is already bright by sunlight you probably don't want bloom anyway
	float alpha = max(1.0, min(MAX_LUM, luminance) - MIN_LUM);

	// NOTE: multiplying the gate only makes sense with additive bloom
	float luminanceGate = smoothstep(MIN_LUM, MAX_LUM, luminance) * 0.25 * alpha;

	// luminanceGate = max(luminanceGate, emissive);
	luminanceGate -= min(1.0, luminanceGate) * 0.5 * atmosv_eyeAdaptation;

	fragColor = base * luminanceGate;

	float clipping_point = 12.5 * BLOOM_SCALE;
	if (any(greaterThan(fragColor, vec4(clipping_point)))) {
		fragColor *= clipping_point / l2_max3(fragColor.rgb);	
	}
}
