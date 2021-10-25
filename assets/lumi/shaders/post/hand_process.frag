#include lumi:shaders/post/common/header.glsl

#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/shadow.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/func/glintify2.glsl
#include lumi:shaders/func/pbr_shading.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/lib/bitpack.glsl
#include lumi:shaders/lib/taa_jitter.glsl
#include lumi:shaders/lib/util.glsl

#ifdef REFLECTION_ON_HAND
	#define PASS_REFLECTION_PROFILE REFLECTION_PROFILE
	#ifdef REFLECT_CLOUDS
		#define PASS_REFLECT_CLOUDS
	#endif
#else
	#define PASS_REFLECTION_PROFILE REFLECTION_PROFILE_NONE
#endif

#include lumi:shaders/post/common/reflection.glsl

/******************************************************
 * lumi:shaders/post/hand_process.frag
 ******************************************************/

uniform sampler2D u_color;
uniform sampler2D u_depth;
uniform sampler2D u_light;
uniform sampler2D u_normal;
uniform sampler2D u_normal_micro;
uniform sampler2D u_material;
uniform sampler2D u_misc;
				
uniform sampler2D u_translucent_depth;

uniform sampler2D u_glint;
uniform sampler2DArrayShadow u_shadow;

in vec2 v_invSize;
in float v_blindness;

out vec4 fragColor[3];

void main()
{
	float depth		  = texture(u_depth, v_texcoord).r;
	float topMidDepth = texture(u_depth, vec2(0.5, 1.0)).r; // skip if hand render is disabled (F1)

	if (depth == 1.0 || topMidDepth != 1.0) {
		discard;
	}

	vec4  a = texture(u_color, v_texcoord);

	vec4 temp = frx_inverseViewProjectionMatrix() * vec4(2.0 * v_texcoord - 1.0, 2.0 * depth - 1.0, 1.0);
	vec3 modelPos = temp.xyz / temp.w;

	vec3 light  = texture(u_light, v_texcoord).xyz;
	vec3 normal = normalize(2.0 * texture(u_normal_micro, v_texcoord).xyz - 1.0);
	vec3 mat	= texture(u_material, v_texcoord).xyz;

	float roughness = mat.x == 0.0 ? 1.0 : min(1.0, 1.0203 * mat.x - 0.01);
	float bloom_out = light.z;

#if defined(SHADOW_MAP_PRESENT)
	#ifdef TAA_ENABLED
	vec2 uvJitter	   = taa_jitter(v_invSize);
	vec4 unjitteredPos = frx_inverseViewProjectionMatrix() * vec4(2.0 * v_texcoord - uvJitter - 1.0, 2.0 * depth - 1.0, 1.0);
	vec4 shadowViewPos = frx_shadowViewMatrix() * vec4(unjitteredPos.xyz / unjitteredPos.w, 1.0);
	#else
	vec4 shadowViewPos = frx_shadowViewMatrix() * vec4(modelPos, 1.0);
	#endif

	float shadowFactor = calcShadowFactor(u_shadow, shadowViewPos);
	// workaround for janky shadow on edges of things (hardly perfect, better than nothing)
	shadowFactor = mix(shadowFactor, simpleShadowFactor(u_shadow, shadowViewPos), step(0.99, shadowFactor));
	light.z = shadowFactor;

	#ifdef SHADOW_WORKAROUND
	// Workaround to fix patches in shadow map until it's FLAWLESS
	light.z *= l2_clampScale(0.03125, 0.04, light.y);
	#endif
#else
	light.z = lightmapRemap(light.y);
#endif

	pbr_shading(a, bloom_out, modelPos, light, normal, roughness, mat.y, mat.z, /*diffuse=*/true, true);

	vec3 misc = texture(u_misc, v_texcoord).xyz;

	#if GLINT_MODE == GLINT_MODE_GLINT_SHADER
	a.rgb += hdr_fromGamma(noise_glint(misc.xy, bit_unpack(misc.z, 2)));
	#else
	a.rgb += hdr_fromGamma(texture_glint(u_glint, misc.xy, bit_unpack(misc.z, 2)));
	#endif

	vec4 source_base = a;
	vec3 source_albedo = texture(u_color, v_texcoord).rgb;
	float source_roughness = mat.x;
	rt_ColorDepthBloom source_source = work_on_pair(
		source_base,
		source_albedo,
		u_depth,
		u_light,
		u_normal,
		u_normal_micro,
		u_material,
		u_color,
		u_translucent_depth,
		u_light,
		u_normal,
		1.0,
		false);
	a.rgb += source_source.color.rgb;

	fragColor[0] = ldr_tonemap(a);
	fragColor[1] = vec4(bloom_out, 0.0, 0.0, 1.0);
	fragColor[2] = vec4(depth, 0.0, 0.0, 1.0);
}
