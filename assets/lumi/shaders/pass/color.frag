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

uniform sampler2DArray u_gbuffer_trans;
uniform sampler2DArray u_gbuffer_main_etc;
uniform sampler2DArray u_gbuffer_depth;
uniform sampler2DArray u_gbuffer_lightnormal;
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

	vec2 uvSolid = refractSolidUV(u_gbuffer_lightnormal, u_vanilla_depth, dVanilla, dTrans);

	float dSolid = texture(u_vanilla_depth, uvSolid).r;

	vec4  cSolid = texture(u_vanilla_color, uvSolid);
	vec4  lTrans = texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_TRANS_LIGT));
	vec4  cTrans = texture(u_gbuffer_trans, vec3(v_texcoord, ID_TRANS_COLR));
	vec3  rawTrans = cTrans.rgb;

	cTrans = dSolid < dTrans ? vec4(0.0) : cTrans;
	if (cTrans.a != 0) {
		cTrans.rgb = cTrans.rgb / (fastLight(lTrans.xy) * cTrans.a);
	}

	float dParts = texture(u_gbuffer_depth, vec3(v_texcoord, 1.)).r;
	vec4  cParts = dParts > dSolid ? vec4(0.0) : texture(u_gbuffer_trans, vec3(v_texcoord, ID_PARTS_COLR));
	float dRains = texture(u_weather_depth, v_texcoord).r;
	vec4  cRains = texture(u_weather_color, v_texcoord);

	cParts.rgb /= cParts.a == 0.0 ? 1.0 : cParts.a;
	cRains.rgb /= cRains.a == 0.0 ? 1.0 : cRains.a;
	cRains = dSolid < dRains ? vec4(0.0) : cRains;

	vec4 tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * uvSolid - 1.0, 2.0 * dSolid - 1.0, 1.0);
	vec3 eyePos  = tempPos.xyz / tempPos.w;

	vec4 light	= texture(u_gbuffer_lightnormal, vec3(uvSolid, ID_SOLID_LIGT));
	vec3 rawMat	= texture(u_gbuffer_main_etc, vec3(uvSolid, ID_SOLID_MATS)).xyz;
	vec3 normal	= texture(u_gbuffer_lightnormal, vec3(uvSolid, ID_SOLID_MNORM)).xyz * 2.0 - 1.0;
	float vertexNormaly = texture(u_gbuffer_lightnormal, vec3(uvSolid, ID_SOLID_NORM)).y * 2.0 - 1.0;

	light.w = denoisedShadowFactor(u_gbuffer_shadow, uvSolid, eyePos, dSolid, light.y);

	vec3 miscSolid = texture(u_gbuffer_main_etc, vec3(uvSolid, ID_SOLID_MISC)).xyz;
	vec3 miscTrans = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_MISC)).xyz;
	bool transIsWater = bit_unpack(miscTrans.z, 7) == 1.;
	bool solidIsUnderwater = decideUnderwater(dSolid, dTrans, transIsWater, false);
	vec3 toFrag = normalize(eyePos);
	float disableDiffuse = bit_unpack(miscSolid.z, 4);

	vec4 base;

	if (dSolid == 1.0) {
		base = customSky(u_tex_sun, u_tex_moon, toFrag, cSolid.rgb, solidIsUnderwater);
	} else {
		base = shading(cSolid, u_tex_nature, light, rawMat, eyePos, normal, vertexNormaly, solidIsUnderwater, disableDiffuse);
		base = overlay(base, u_tex_glint, miscSolid);
	}

	float dMin = min(dSolid, min(dTrans, min(dParts, dRains)));

	if (dSolid > dMin) {
		if (dSolid < 1.0) {
			base += skyReflection(u_tex_sun, u_tex_moon, u_tex_noise, cSolid.rgb, rawMat.xy, toFrag, normal, light.yw);
			base = fog(base, eyePos, toFrag, solidIsUnderwater);
		}

		vec4 clouds = customClouds(u_vanilla_clouds_depth, u_tex_nature, u_tex_noise, dSolid, uvSolid, eyePos, toFrag, NUM_SAMPLE, ldepth(dMin) * frx_viewDistance * 4.);
		base.rgb = base.rgb * (1.0 - clouds.a) + clouds.rgb * clouds.a;
	}


	tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * v_texcoord - 1.0, 2.0 * dParts - 1.0, 1.0);
	eyePos  = tempPos.xyz / tempPos.w;
	light = texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_PARTS_LIGT));
	light.w = denoisedShadowFactor(u_gbuffer_shadow, v_texcoord, eyePos, dParts, light.y);
	vec4 nextParts = particleShading(cParts, u_tex_nature, light, eyePos, decideUnderwater(dParts, dTrans, transIsWater, false));


	tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * v_texcoord - 1.0, 2.0 * dTrans - 1.0, 1.0);
	eyePos  = tempPos.xyz / tempPos.w;
	light  = lTrans;
	rawMat = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_MATS)).xyz;
	normal = texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_TRANS_MNORM)).xyz * 2.0 - 1.0;
	vertexNormaly = texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_TRANS_NORM)).y * 2.0 - 1.0;
	disableDiffuse = bit_unpack(miscTrans.z, 4);

	#ifdef WATER_FOAM
	if (transIsWater) {
		foamPreprocess(cTrans, u_tex_nature, eyePos + frx_cameraPos, vertexNormaly, base.rgb, dVanilla, dTrans);
	}
	#endif

	if (miscTrans == rawMat && rawMat == rawTrans) light.x = 0.0; // end portal fix

	light.w = transIsWater ? lightmapRemap (light.y) : denoisedShadowFactor(u_gbuffer_shadow, v_texcoord, eyePos, dTrans, light.y);

	vec4 nextTrans = shading(cTrans, u_tex_nature, light, rawMat, eyePos, normal, vertexNormaly, decideUnderwater(dTrans, dTrans, transIsWater, true), disableDiffuse);
	nextTrans = overlay(nextTrans, u_tex_glint, miscTrans);


	vec4 nextRains = vec4(hdr_fromGamma(cRains.rgb), cRains.a);

	vec4 next0, next1, next;

	// try alpha compositing in HDR and you will go bald
	nextParts = vec4(ldr_tonemap(nextParts.rgb) * nextParts.a, nextParts.a); // premultiply α
	nextTrans = vec4(ldr_tonemap(nextTrans.rgb) * nextTrans.a, nextTrans.a);
	nextRains = vec4(ldr_tonemap(nextRains.rgb) * nextRains.a, nextRains.a);
	base = ldr_tonemap(base);

	// TODO: is this slower than insert sort?
	if (dMin == dRains) {
		next0 = (dParts > dTrans ? nextParts : nextTrans);
		next1 = (dParts > dTrans ? nextTrans : nextParts);
		next  = nextRains;
	} else if (dMin == dParts) {
		next0 = (dRains > dTrans ? nextRains : nextTrans);
		next1 = (dRains > dTrans ? nextTrans : nextRains);
		next  = nextParts;
	} else {
		next0 = (dRains > dParts ? nextRains : nextParts);
		next1 = (dRains > dParts ? nextParts : nextRains);
		next  = nextTrans;
	}

	next1 = premultBlend(next1, next0);
	next  = premultBlend(next, next1);
	base  = premultBlend(next, base);

	fragColor = hdr_inverseTonemap(base);
	fragDepth = dMin;

	if (dMin == dSolid) {
		fragAlbedo = vec4(cSolid.rgb, 0.0);
	} else if (dMin == dTrans) {
		fragAlbedo = vec4(cTrans.rgb, 0.5);
	} else {
		fragAlbedo = vec4(cParts.rgb, 1.0);
	}
}
