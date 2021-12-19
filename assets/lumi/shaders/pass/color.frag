#include lumi:shaders/pass/header.glsl

#include lumi:shaders/lib/bitpack.glsl
#include lumi:shaders/lib/pack_normal.glsl
#include lumi:shaders/prog/clouds.glsl
#include lumi:shaders/prog/fog.glsl
#include lumi:shaders/prog/overlay.glsl
#include lumi:shaders/prog/shading.glsl
#include lumi:shaders/prog/sky.glsl
#include lumi:shaders/prog/tonemap.glsl
#include lumi:shaders/prog/water.glsl

/*******************************************************
 *  lumi:shaders/post/color.frag
 *******************************************************/

uniform sampler2D u_vanilla_color;
uniform sampler2D u_vanilla_depth;
uniform sampler2D u_weather_color;
uniform sampler2D u_weather_depth;
uniform sampler2D u_vanilla_clouds_depth;

uniform sampler2DArray u_gbuffer_main_etc;
uniform sampler2DArray u_gbuffer_depth;
uniform sampler2DArray u_gbuffer_light;
uniform sampler2DArray u_gbuffer_normal;
uniform sampler2DArrayShadow u_gbuffer_shadow;

uniform sampler2D u_tex_sun;
uniform sampler2D u_tex_moon;
uniform sampler2D u_tex_nature;
uniform sampler2D u_tex_glint;
uniform sampler2D u_tex_noise;

layout(location = 0) out vec4 fragColor;
layout(location = 1) out float fragDepth;
layout(location = 2) out vec4 fragAlbedo;

void main()
{
	float dVanilla = texture(u_vanilla_depth, v_texcoord).r;
	float dTrans = texture(u_gbuffer_depth, vec3(v_texcoord, 0.)).r;

	vec2 uvSolid = refractSolidUV(u_gbuffer_normal, u_vanilla_depth, dVanilla, dTrans);

	float dSolid = texture(u_vanilla_depth, uvSolid).r;

	vec4  cSolid = texture(u_vanilla_color, uvSolid);
	vec4  cTrans = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_COLR));
		  cTrans = vec4(cTrans.a == 0.0 ? vec3(0.0) : (cTrans.rgb / cTrans.a), sqrt(cTrans.a));
	float dParts = texture(u_gbuffer_depth, vec3(v_texcoord, 1.)).r;
	vec4  cParts = dParts > dSolid ? vec4(0.0) : texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_PARTS_COLR));
	float dRains = texture(u_weather_depth, v_texcoord).r;
	vec4  cRains = texture(u_weather_color, v_texcoord);

	cParts.rgb /= cParts.a == 0.0 ? 1.0 : cParts.a;
	cRains.rgb /= cRains.a == 0.0 ? 1.0 : cRains.a;
	cRains = dSolid < dRains ? vec4(0.0) : cRains;

	vec4 tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * uvSolid - 1.0, 2.0 * dSolid - 1.0, 1.0);
	vec3 eyePos  = tempPos.xyz / tempPos.w;

	vec4 light    = texture(u_gbuffer_light, vec3(uvSolid, ID_SOLID_LIGT));
	vec3 material = texture(u_gbuffer_main_etc, vec3(uvSolid, ID_SOLID_MATS)).xyz;
	vec3 normal   = texture(u_gbuffer_normal, vec3(uvSolid, ID_SOLID_MNORM)).xyz * 2.0 - 1.0;

	light.w = denoisedShadowFactor(u_gbuffer_shadow, uvSolid, eyePos, dSolid, light.y);

	vec3 miscSolid = texture(u_gbuffer_main_etc, vec3(uvSolid, ID_SOLID_MISC)).xyz;
	vec3 miscTrans = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_MISC)).xyz;
	bool transIsWater = bit_unpack(miscTrans.z, 7) == 1.;
	bool solidIsUnderwater = decideUnderwater(dSolid, dTrans, transIsWater, false);
	vec3 toFrag = normalize(eyePos);
	float disableDiffuse = bit_unpack(miscSolid.z, 4);

	// TODO: end portal glitch?

	vec4 base = dSolid == 1.0 ? customSky(u_tex_sun, u_tex_moon, toFrag, cSolid.rgb, solidIsUnderwater) : shading(cSolid, u_tex_nature, light, material, eyePos, normal, solidIsUnderwater, disableDiffuse);
	float dMin = min(dSolid, min(dTrans, min(dParts, dRains)));

	if (dSolid > dMin) {
		if (dSolid < 1.0) {
			base += skyReflection(u_tex_sun, u_tex_moon, u_tex_noise, cSolid.rgb, material, toFrag, normal, light.yw);
			base = fog(base, eyePos, toFrag, solidIsUnderwater);
		}

		vec4 clouds = customClouds(u_vanilla_clouds_depth, u_tex_nature, u_tex_noise, dSolid, uvSolid, eyePos, toFrag, NUM_SAMPLE, ldepth(dMin) * frx_viewDistance * 4.);
		base.rgb = base.rgb * (1.0 - clouds.a) + clouds.rgb * clouds.a;
	}

	vec4 next0, next1, next;

	// TODO: is this slower than insert sort?
	if (dMin == dRains) {
		next0 = (dParts > dTrans ? cParts : cTrans);
		next1 = (dParts > dTrans ? cTrans : cParts);
		next  = cRains;
	} else if (dMin == dParts) {
		next0 = (dRains > dTrans ? cRains : cTrans);
		next1 = (dRains > dTrans ? cTrans : cRains);
		next  = cParts;
	} else {
		next0 = (dRains > dParts ? cRains : cParts);
		next1 = (dRains > dParts ? cParts : cRains);
		next  = cTrans;
	}

	next0 = vec4(next0.rgb * (1.0 - next1.a) + next1.rgb * next1.a, max(next0.a, next1.a));
	next  = vec4(next0.rgb * (1.0 - next.a) + next.rgb * next.a, max(next0.a, next.a));

	tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * v_texcoord - 1.0, 2.0 * dMin - 1.0, 1.0);
	eyePos  = tempPos.xyz / tempPos.w;

	light	 = vec4(1.0);
	material = vec3(1.0, 0.0, 0.04);
	normal	 = -frx_cameraView;
	disableDiffuse = 0.0;

	if (dMin == dTrans) {
		light    = texture(u_gbuffer_light, vec3(v_texcoord, ID_TRANS_LIGT));
		material = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_MATS)).xyz;
		normal   = texture(u_gbuffer_normal, vec3(v_texcoord, ID_TRANS_MNORM)).xyz * 2.0 - 1.0;
		disableDiffuse = bit_unpack(miscTrans.z, 4);

		#ifdef WATER_FOAM
		if (transIsWater) {
			// vec3 viewVertexNormal = frx_normalModelMatrix * (texture(u_gbuffer_normal, vec3(v_texcoord, ID_TRANS_NORM)).xyz * 2.0 - 1.0);
			vec3 vertexNormal = texture(u_gbuffer_normal, vec3(v_texcoord, ID_TRANS_NORM)).xyz * 2.0 - 1.0;
			foamPreprocess(next, material, u_tex_nature, eyePos + frx_cameraPos, vertexNormal.y, base.rgb, dVanilla, dTrans);
		}
		#endif
	} else if (dMin == dParts) {
		light = texture(u_gbuffer_light, vec3(v_texcoord, ID_PARTS_LIGT));
	}

	bool nextIsUnderwater = decideUnderwater(dMin, dTrans, transIsWater, true);

	light.w = transIsWater ? lightmapRemap (light.y) : denoisedShadowFactor(u_gbuffer_shadow, v_texcoord, eyePos, dMin, light.y);

	if (next.a != 0.0) {
		next = shading(next, u_tex_nature, light, material, eyePos, normal, nextIsUnderwater, disableDiffuse);
	}
	next.a = sqrt(next.a);

	base.rgb = base.rgb * (1.0 - next.a) + next.rgb * next.a;

	if (dMin == dSolid || dMin == dTrans) {
		base = overlay(base, u_tex_glint, dMin == dSolid ? miscSolid : miscTrans);
	}

	fragColor = base;
	fragDepth = dMin;

	if (dMin == dSolid) {
		fragAlbedo = vec4(cSolid.rgb, 0.0);
	} else if (dMin == dTrans) {
		fragAlbedo = vec4(cTrans.rgb, 0.5);
	} else {
		fragAlbedo = vec4(cParts.rgb, 1.0);
	}
}
