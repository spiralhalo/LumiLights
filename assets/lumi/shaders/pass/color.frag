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
uniform sampler2D u_vanilla_clouds;
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
layout(location = 1) out vec3 fragDepth;
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

	vec4 tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * uvSolid - 1.0, 2.0 * dSolid - 1.0, 1.0);
	vec3 eyePos  = tempPos.xyz / tempPos.w;

	vec4 light    = texture(u_gbuffer_light, vec3(uvSolid, ID_SOLID_LIGT));
	vec3 material = texture(u_gbuffer_main_etc, vec3(uvSolid, ID_SOLID_MATS)).xyz;
	vec3 normal   = texture(u_gbuffer_normal, vec3(uvSolid, ID_SOLID_MNORM)).xyz * 2.0 - 1.0;

	// vec3 normalMin = normal;

	light.w = denoisedShadowFactor(u_gbuffer_shadow, uvSolid, eyePos, dSolid, light.y);

	vec3 miscTrans = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_MISC)).xyz;
	bool transIsWater = bit_unpack(miscTrans.z, 7) == 1.;
	bool solidIsUnderwater = decideUnderwater(dSolid, dTrans, transIsWater, false);
	vec3 toFrag = normalize(eyePos);

	// TODO: end portal glitch?

	vec4 base = dSolid == 1.0 ? customSky(u_tex_sun, u_tex_moon, toFrag, solidIsUnderwater) : shading(cSolid, u_tex_nature, light, material, eyePos, normal, solidIsUnderwater);
	vec4 next = (dSolid < dTrans && dSolid < dParts) ? vec4(0.0) : (dParts > dTrans ? cParts : cTrans);
	vec4 last = (dSolid < dTrans && dSolid < dParts) ? vec4(0.0) : (dParts > dTrans ? cTrans : cParts);

	float dMin = min(dSolid, min(dTrans, min(dParts, dRains)));

	if (dSolid > dMin) {
		if (dSolid < 1.0) {
			base += skyReflection(u_tex_sun, u_tex_moon, cSolid.rgb, material, toFrag, normal, light.yw);
			base = fog(base, eyePos, toFrag);
		}

		vec4 clouds = customClouds(u_vanilla_clouds, u_vanilla_clouds_depth, u_tex_nature, u_tex_noise, dSolid, uvSolid, eyePos, toFrag, NUM_SAMPLE, ldepth(dMin) * frx_viewDistance * 4.);
		base.rgb = base.rgb * (1.0 - clouds.a) + clouds.rgb * clouds.a;
	}

	if (dRains <= dSolid && dRains > dMin) {
		next = vec4(next.rgb * (1.0 - cRains.a) + cRains.rgb * cRains.a, min(1.0, next.a + cRains.a));
	}

	next = vec4(next.rgb * (1.0 - last.a) + last.rgb * last.a, min(1.0, next.a + last.a));

	tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * v_texcoord - 1.0, 2.0 * dMin - 1.0, 1.0);
	eyePos  = tempPos.xyz / tempPos.w;

	light	 = vec4(0.0, 1.0, 0.0, 0.0);
	material = vec3(1.0, 0.0, 0.04);
	normal	 = -frx_cameraView;

	if (dMin == dTrans) {
		light    = texture(u_gbuffer_light, vec3(v_texcoord, ID_TRANS_LIGT));
		material = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_MATS)).xyz;
		normal   = texture(u_gbuffer_normal, vec3(v_texcoord, ID_TRANS_MNORM)).xyz * 2.0 - 1.0;

		// normalMin = normal;

		#ifdef WATER_FOAM
		if (transIsWater) {
			// vec3 viewVertexNormal = frx_normalModelMatrix * (texture(u_gbuffer_normal, vec3(v_texcoord, ID_TRANS_NORM)).xyz * 2.0 - 1.0);
			vec3 vertexNormal = texture(u_gbuffer_normal, vec3(v_texcoord, ID_TRANS_NORM)).xyz * 2.0 - 1.0;
			foamPreprocess(next, material, u_tex_nature, eyePos + frx_cameraPos, vertexNormal.y, cSolid.rgb, dVanilla, dTrans);
		}
		#endif
	} else if (dMin == dParts) {
		light    = texture(u_gbuffer_light, vec3(v_texcoord, ID_PARTS_LIGT));
	}

	bool nextIsUnderwater = decideUnderwater(dMin, dTrans, transIsWater, true);

	light.w = transIsWater ? lightmapRemap (light.y) : denoisedShadowFactor(u_gbuffer_shadow, v_texcoord, eyePos, dMin, light.y);

	if (next.a != 0.0) {
		next = shading(next, u_tex_nature, light, material, eyePos, normal, nextIsUnderwater);
	}
	next.a = sqrt(next.a);

	if (dRains == dMin) {
		cRains.rgb = hdr_fromGamma(cRains.rgb);
		next = vec4(next.rgb * (1.0 - cRains.a) + cRains.rgb * cRains.a, max(next.a, cRains.a));
	}

	base.rgb = base.rgb * (1.0 - next.a) + next.rgb * next.a;

	int idMisc = dMin == dSolid ? ID_SOLID_MISC : (dMin == dTrans ? ID_TRANS_MISC : -1);

	if (idMisc > -1) {
		vec2 uvAuto = idMisc == ID_SOLID_MISC ? uvSolid : v_texcoord;
		vec4 miscAuto = texture(u_gbuffer_main_etc, vec3(uvAuto, idMisc));
		base = overlay(base, u_tex_glint, miscAuto);
	}

	fragColor = base;

	// float MIN_THICKNESS = 2. / frx_viewDistance;
	// float MAX_THICKNESS = 10. / frx_viewDistance;
	// float dotNC = abs((frx_normalModelMatrix * normalMin).z);
	// float thickness = mix(MIN_THICKNESS, MAX_THICKNESS, dotNC);

	// float dBoxMin = dMin;
	// float dBoxMax = dMin;
	// for (int i=-1; i<=1; i++) {
	// 	for (int j=-1; j<=1; j++){
	// 		float dBox = texture(u_gbuffer_depth, vec3(v_texcoord + v_invSize * vec2(i, j), 0.)).r;
	// 		dBoxMax = max(dBoxMax, dBox);
	// 		dBoxMin = min(dBoxMin, dBox);
	// 	}
	// }

	float ldMin = l2_getLdepth(dMin);
	// thomas et al
	float thickness = -l2_getZ(dMin) * (1.0/frx_projectionMatrix[1][1]) / (frxu_size.x * frxu_size.y);

	fragDepth = vec3(dMin, ldMin, thickness);

	if (dMin == dSolid) {
		fragAlbedo = vec4(cSolid.rgb, 0.0);
	} else if (dMin == dTrans) {
		fragAlbedo = vec4(cTrans.rgb, 0.5);
	} else {
		fragAlbedo = vec4(cParts.rgb, 1.0);
	}
}
