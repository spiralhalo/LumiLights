#include lumi:shaders/pass/header.glsl

#include lumi:shaders/lib/taa_jitter.glsl
#include lumi:shaders/prog/clouds.glsl
#include lumi:shaders/prog/fog.glsl
#include lumi:shaders/prog/reflection.glsl
#include lumi:shaders/prog/shading.glsl
#include lumi:shaders/prog/tonemap.glsl

/*******************************************************
 *  lumi:shaders/post/post.frag
 *******************************************************/

uniform sampler2D u_color_result;
uniform sampler2D u_color_depth;
uniform sampler2D u_color_albedo;
uniform sampler2DArray u_color_others;

uniform sampler2D u_vanilla_depth;
uniform sampler2D u_vanilla_clouds_depth;
uniform sampler2D u_vanilla_transl_color;
uniform sampler2D u_vanilla_transl_depth;

uniform sampler2DArray u_gbuffer_main_etc;
uniform sampler2DArray u_gbuffer_lightnormal;
uniform sampler2DArrayShadow u_gbuffer_shadow;

uniform sampler2D u_tex_sun;
uniform sampler2D u_tex_moon;
uniform sampler2D u_tex_nature;
uniform sampler2D u_tex_noise;

out vec4 fragColor;

// ugh
bool endPortalFix()
{
	vec3 A = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_MISC)).xyz;
	vec3 B = texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_TRANS_LIGT)).xyz;
	vec3 C = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_MATS)).xyz;
	vec3 D = texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_TRANS_MNORM)).xyz;

	vec3 test = A + B - C - D;

	return abs(test.x + test.y + test.z) > 1.0 / 255.0;
}

void main()
{
	fragColor = texture(u_color_result, v_texcoord);

	vec4 albedo = texture(u_color_albedo, v_texcoord);

	float idLight = albedo.a == 0.0 ? ID_SOLID_LIGT : (albedo.a < 1.0 ? ID_TRANS_LIGT : ID_PARTS_LIGT);
	float idMaterial = albedo.a == 0.0 ? ID_SOLID_MATS : ID_TRANS_MATS;
	float idNormal = albedo.a == 0.0 ? ID_SOLID_NORM : ID_TRANS_NORM;
	float idMicroNormal = albedo.a == 0.0 ? ID_SOLID_MNORM : ID_TRANS_MNORM;

	if (endPortalFix() || albedo.a == 0.0) {
		fragColor += reflection(albedo.rgb, u_color_result, u_gbuffer_main_etc, u_gbuffer_lightnormal, u_color_depth, u_gbuffer_shadow, u_tex_sun, u_tex_moon, u_tex_noise, idLight, idMaterial, idNormal, idMicroNormal);
	}

	vec4 trans = texture(u_color_others, vec3(v_texcoord, ID_OTHER_TRANS));
	vec4 after = texture(u_color_others, vec3(v_texcoord, ID_OTHER_AFTER));

	fragColor = ldr_tonemap(fragColor);
	fragColor = premultBlend(after, fragColor);

	float dMin   = texture(u_color_depth, v_texcoord).g;
	float dTrans = texture(u_color_depth, v_texcoord).r;
	float dSolid = texture(u_vanilla_depth, v_texcoord).r;
	
	float dVanillaTransl = texture(u_vanilla_transl_depth, v_texcoord).r;
	vec4 cVanillaTrans = texture(u_vanilla_transl_color, v_texcoord);

	if (cVanillaTrans.a > 0.0 && dVanillaTransl < dSolid) {
		cVanillaTrans.rgb = hdr_fromGamma(cVanillaTrans.rgb / cVanillaTrans.a);
		cVanillaTrans = vec4(ldr_tonemap(cVanillaTrans.rgb), cVanillaTrans.a);

		if (dVanillaTransl >= dTrans) {
			cVanillaTrans = max(vec4(0.0), cVanillaTrans * (1.0 - trans)); // ??? trans is alpha premultiplied
		}

		cVanillaTrans.rgb *= cVanillaTrans.a;

		fragColor = premultBlend(cVanillaTrans, fragColor);

		dMin = min(dMin, dVanillaTransl);
	}

	fragColor = hdr_inverseTonemap(fragColor);

	vec4 tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * v_texcoord - 1.0, 2.0 * dMin - 1.0, 1.0);
	vec3 eyePos  = tempPos.xyz / tempPos.w;
	vec3 toFrag  = normalize(eyePos);

	float distToEye = length(eyePos);
	fragColor = dMin < 1.0 ? fog(fragColor, distToEye, toFrag, frx_cameraInWater == 1) : fragColor;

	vec4 clouds = customClouds(u_vanilla_clouds_depth, u_tex_nature, u_tex_noise, dMin, v_texcoord, eyePos, toFrag, NUM_SAMPLE);
	fragColor.rgb = fragColor.rgb * (1.0 - clouds.a) + clouds.rgb * clouds.a;

	fragColor = blindnessFog(fragColor, distToEye);
	fragColor = ldr_tonemap(fragColor);
}
