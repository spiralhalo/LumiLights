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
uniform sampler2DArray u_color_others;

uniform sampler2D u_vanilla_depth;
uniform sampler2D u_vanilla_clouds_depth;
uniform sampler2D u_vanilla_transl_color;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_entity_hitbox;
uniform sampler2D u_entity_hitbox_depth;

uniform sampler2DArray u_gbuffer_main_etc;
uniform sampler2DArray u_gbuffer_lightnormal;
uniform sampler2DArrayShadow u_gbuffer_shadow;

uniform sampler2DArray u_resources;
uniform sampler2D u_tex_nature;
uniform sampler3D u_light_data;

out vec4 fragColor;

vec3 lightColor(vec3 toFrag, float distToEye, vec3 fallback) {
	int steps = 10;
	float range = min(distToEye, 128.0);

	vec3 lerp = (toFrag * range) / float(steps);
	vec3 jitt = getRandomFloat(u_resources, v_texcoord, frxu_size) * lerp;

	int i = 0;

	vec3 size = vec3(textureSize(u_light_data, 0));
	vec3 totalLight = vec3(0.0);
	vec3 visiblity = vec3(1.0);
	float alpha = 0.01 * range / float(steps);
	alpha *= mix(1.0, 0.01, atmosv_eyeAdaptation);

	while (i < steps) {	
		vec3 light = vec3(0.0);
		vec3 pos = mod(lerp * float(i) + jitt + frx_cameraPos, size);

		vec3 tex = texture(u_light_data, pos / size).rgb;
		// vec4 texA = vec4(0.0);
		// texA += vec4(texture(u_light_data, pos / size).rgb, 1.0);
		// tex = texture(u_light_data, (pos + vec3(0.0, 0.0, 1.0)) / size).rgb;
		// if (tex != vec3(0.0)) texA += vec4(tex, 1.0);
		// tex = texture(u_light_data, (pos + vec3(0.0, 0.0, -1.0)) / size).rgb;
		// if (tex != vec3(0.0)) texA += vec4(tex, 1.0);
		// tex = texture(u_light_data, (pos + vec3(0.0, 1.0, 0.0)) / size).rgb;
		// if (tex != vec3(0.0)) texA += vec4(tex, 1.0);
		// tex = texture(u_light_data, (pos + vec3(0.0, -1.0, 0.0)) / size).rgb;
		// if (tex != vec3(0.0)) texA += vec4(tex, 1.0);
		// tex = texture(u_light_data, (pos + vec3(1.0, 0.0, 0.0)) / size).rgb;
		// if (tex != vec3(0.0)) texA += vec4(tex, 1.0);
		// tex = texture(u_light_data, (pos + vec3(-1.0, 0.0, 0.0)) / size).rgb;
		// if (tex != vec3(0.0)) texA += vec4(tex, 1.0);
		// tex = texA.rgb / texA.a;
		light = tex.rgb * tex.rgb;// * tex.a;
		// float l = lightLuminance(light);
		// light *= l;
		light *= visiblity * alpha;
		visiblity = clamp(visiblity - light, 0.0, 1.0);
		// light = pos / size;

		totalLight += light;
		i++;
	}

	totalLight += fallback * visiblity;

	return totalLight;
}

void main()
{
	fragColor = texture(u_color_result, v_texcoord);

	vec4 albedo = texture(u_color_others, vec3(v_texcoord, ID_OTHER_ALBEDO));

	float idLight = albedo.a == 0.0 ? ID_SOLID_LIGT : (albedo.a < 1.0 ? ID_TRANS_LIGT : ID_PARTS_LIGT);
	float idMaterial = albedo.a == 0.0 ? ID_SOLID_MATS : ID_TRANS_MATS;
	float idNormal = albedo.a == 0.0 ? ID_SOLID_NORM : ID_TRANS_NORM;
	float idMicroNormal = albedo.a == 0.0 ? ID_SOLID_MNORM : ID_TRANS_MNORM;

	if (notEndPortal(u_gbuffer_lightnormal) || albedo.a == 0.0) {
		fragColor += reflection(albedo.rgb, u_color_result, u_gbuffer_main_etc, u_gbuffer_lightnormal, u_translucent_depth, u_gbuffer_shadow, u_resources, idLight, idMaterial, idNormal, idMicroNormal);
	}

	vec4 trans = texture(u_color_others, vec3(v_texcoord, ID_OTHER_TRANS));
	vec4 after = texture(u_color_others, vec3(v_texcoord, ID_OTHER_AFTER));

	fragColor = ldr_tonemap(fragColor);
	fragColor = premultBlend(after, fragColor);

	float dMin = texture(u_color_depth, v_texcoord).r;

	fragColor = hdr_inverseTonemap(fragColor);

	vec4 tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * v_texcoord - 1.0, 2.0 * dMin - 1.0, 1.0);
	vec3 eyePos  = tempPos.xyz / tempPos.w;
	vec3 toFrag  = normalize(eyePos);

	float distToEye = length(eyePos);
	vec4 skyBasic = basicSky(toFrag, skyBase(toFrag, frx_vanillaClearColor));
	if (dMin < 1) {
		fragColor = mix(
			volumetricFog(u_gbuffer_shadow, u_tex_nature, fragColor, distToEye, toFrag, texture(u_gbuffer_lightnormal, vec3(v_texcoord, idLight)).y, getRandomFloat(u_resources, v_texcoord, frxu_size), dMin, frx_cameraInWater == 1),
			skyBasic,
			edgeBlendFactor(distToEye));
	}

	vec4 clouds = customClouds(u_vanilla_clouds_depth, u_tex_nature, u_resources, dMin, v_texcoord, eyePos, toFrag, NUM_SAMPLE, skyBasic);
	fragColor.rgb = fragColor.rgb * (1.0 - clouds.a) + clouds.rgb * clouds.a;

	fragColor.rgb = lightColor(toFrag, distToEye, fragColor.rgb);

	fragColor = blindnessFog(fragColor, distToEye);
	fragColor = ldr_tonemap(fragColor);

	float dTrans = texture(u_translucent_depth, v_texcoord).r;
	float dSolid = texture(u_vanilla_depth, v_texcoord).r;
	vec4 cVanillaTrans = texture(u_vanilla_transl_color, v_texcoord);

	if (cVanillaTrans.a > 0.0 && dTrans <= dSolid) {
		cVanillaTrans.rgb = hdr_fromGamma(cVanillaTrans.rgb / cVanillaTrans.a);
		cVanillaTrans = vec4(ldr_tonemap(cVanillaTrans.rgb), sqrt(cVanillaTrans.a)); // dunno about the sqrt really

		if (trans.a > 0.0) cVanillaTrans = max(vec4(0.0), cVanillaTrans * (1.0 - trans));
		if (after.a > 0.0) cVanillaTrans = max(vec4(0.0), cVanillaTrans * (1.0 - after));

		cVanillaTrans.rgb *= cVanillaTrans.a;

		fragColor = premultBlend(cVanillaTrans, fragColor);
	}

	vec4 cHitbox = texture(u_entity_hitbox, v_texcoord);
	float dHitbox = texture(u_entity_hitbox_depth, v_texcoord).r;

	if (cHitbox.a > 0.0 && dHitbox <= dSolid) {
		cHitbox = vec4(ldr_tonemap(hdr_fromGamma(cHitbox.rgb / cHitbox.a)), cHitbox.a);

		if (dHitbox > dTrans && trans.a > 0.0) cHitbox = max(vec4(0.0), cHitbox * (1.0 - trans));
		if (dHitbox > dMin && after.a > 0.0) cHitbox = max(vec4(0.0), cHitbox * (1.0 - after));

		cHitbox.rgb *= cHitbox.a;
		fragColor = premultBlend(cHitbox, fragColor);
	}
}
