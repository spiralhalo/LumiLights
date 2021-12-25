#include lumi:shaders/pass/header.glsl

#include frex:shaders/lib/sample.glsl
#include lumi:shaders/prog/tonemap.glsl

/******************************************************
  lumi:shaders/pass/bloom.frag
******************************************************/

uniform sampler2D u_input;
uniform sampler2D u_blend;

uniform sampler2D u_color_albedo;
uniform sampler2DArray u_gbuffer_light;

out vec4 fragColor;

void main()
{
	vec4  albedo   = texture(u_color_albedo, v_texcoord);
	float idLight  = albedo.a == 0.0 ? ID_SOLID_LIGT : (albedo.a < 1.0 ? ID_TRANS_LIGT : ID_PARTS_LIGT);
	float lightz   = texture(u_gbuffer_light, vec3(v_texcoord, idLight)).z;
	float emissive = lightz;

	vec4 base = hdr_inverseTonemap(texture(u_input, v_texcoord));
	float luminance = l2_max3(base.rgb); //use max instead of luminance to get some lava action
	const float MIN_LUM = 0.9; // based on semi-comfortable bloom on snowy scapes

	// NOTE: multiplying the gate only makes sense with additive bloom
	float luminanceGate = smoothstep(MIN_LUM, MIN_LUM + 1.0, luminance) * 0.5;

	luminanceGate = max(luminanceGate, emissive);

	fragColor = base * luminanceGate;
}
