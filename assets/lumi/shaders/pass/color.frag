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

uniform sampler2D u_translucent_depth;
uniform sampler2D u_particles_depth;

uniform sampler2DArray u_gbuffer_trans;
uniform sampler2DArray u_gbuffer_main_etc;
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
layout(location = 3) out vec4 fragTrans;
layout(location = 4) out vec4 fragAfter;

void main()
{
	float dVanilla = texture(u_vanilla_depth, v_texcoord).r;
	float dTrans = texture(u_translucent_depth, v_texcoord).r;

	vec2 uvSolid = refractSolidUV(u_gbuffer_lightnormal, u_vanilla_depth, dVanilla, dTrans);

	float dSolid = texture(u_vanilla_depth, uvSolid).r;

	vec4  cSolid = texture(u_vanilla_color, uvSolid);
	vec4  lTrans = texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_TRANS_LIGT));
	vec4  cTrans = texture(u_gbuffer_trans, vec3(v_texcoord, ID_TRANS_COLR));
	float dParts = texture(u_particles_depth, v_texcoord).r;
	vec4  cParts = texture(u_gbuffer_trans, vec3(v_texcoord, ID_PARTS_COLR));
	float dRains = texture(u_weather_depth, v_texcoord).r;
	vec4  cRains = texture(u_weather_color, v_texcoord);

	cParts.rgb /= cParts.a == 0.0 ? 1.0 : cParts.a;
	cRains.rgb /= cRains.a == 0.0 ? 1.0 : cRains.a;
	// cRains.rgb = frx_worldIsOverworld == 1 ? vec3(lightLuminance(cRains.rgb)) : cRains.rgb;
	cTrans = dSolid < dTrans ? vec4(0.0) : cTrans;
	cParts = dSolid < dParts ? vec4(0.0) : cParts;
	cRains = dSolid < dRains ? vec4(0.0) : cRains;
	cRains.a *= 0.7; // thinner rains and snow

	vec4 tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * uvSolid - 1.0, 2.0 * dSolid - 1.0, 1.0);
	vec3 eyePos  = tempPos.xyz / tempPos.w;

	vec4 light	= texture(u_gbuffer_lightnormal, vec3(uvSolid, ID_SOLID_LIGT));
	vec3 rawMat	= texture(u_gbuffer_main_etc, vec3(uvSolid, ID_SOLID_MATS)).xyz;
	vec3 normal	= normalize(texture(u_gbuffer_lightnormal, vec3(uvSolid, ID_SOLID_MNORM)).xyz);
	vec3 vertexNormal = normalize(texture(u_gbuffer_lightnormal, vec3(uvSolid, ID_SOLID_NORM)).xyz);

	bool solidIsManaged = light.x > 0.0;
	vec3 solidPos = eyePos;
	float solidNormaly = vertexNormal.y;

	light.w = denoisedShadowFactor(u_gbuffer_shadow, uvSolid, eyePos, dSolid, light.y, vertexNormal);

	vec3 miscSolid = texture(u_gbuffer_main_etc, vec3(uvSolid, ID_SOLID_MISC)).xyz;
	vec3 miscTrans = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_MISC)).xyz;
	bool transIsWater = bit_unpack(miscTrans.z, 7) == 1.;
	bool solidIsUnderwater = decideUnderwater(dSolid, dTrans, transIsWater, false);
	vec3 toFrag = normalize(eyePos);
	float disableDiffuse = bit_unpack(miscSolid.z, 4);

	vec4 base;
	vec4 sky = customSky(u_tex_sun, u_tex_moon, toFrag, dSolid == 1.0 ? cSolid.rgb : frx_vanillaClearColor, solidIsUnderwater);

	if (dSolid == 1.0) {
		base = sky;
	} else {
		base = shading(cSolid, u_tex_nature, light, rawMat, eyePos, normal, vertexNormal, solidIsUnderwater, disableDiffuse);
		base = overlay(base, u_tex_glint, miscSolid);
	}

	float dMin = min(dSolid, min(dTrans, min(dParts, dRains)));

	// reflection doesn't include other translucent stuff
	if (dSolid > dTrans) {
		base += skyReflection(u_tex_sun, u_tex_moon, u_tex_noise, cSolid.rgb, rawMat.xy, toFrag, normal, light.yw);
	}

	if (dSolid > dMin) {
		vec4 clouds = customClouds(u_vanilla_clouds_depth, u_tex_nature, u_tex_noise, dSolid, uvSolid, eyePos, toFrag, NUM_SAMPLE, ldepth(dMin) * frx_viewDistance * 4.);
		base.rgb = base.rgb * (1.0 - clouds.a) + clouds.rgb * clouds.a;
	}

	vec4 foggedColor = base;
	vec3 foggedToFrag = toFrag;
	// float foggedLightY = light.y;
	float foggedDist = length(eyePos);
	// float tileJitter = getRandomFloat(u_tex_noise, v_texcoord, frxu_size);
	// float foggedDepth = dSolid;
	bool foggedIsUnderwater = solidIsUnderwater;
	float edgeBlend = edgeBlendFactor(foggedDist);


	tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * v_texcoord - 1.0, 2.0 * dParts - 1.0, 1.0);
	eyePos  = tempPos.xyz / tempPos.w;
	light = texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_PARTS_LIGT));
	light.w = denoisedShadowFactor(u_gbuffer_shadow, v_texcoord, eyePos, dParts, light.y, -frx_cameraView);
	vec4 nextParts = particleShading(cParts, u_tex_nature, light, eyePos, decideUnderwater(dParts, dTrans, transIsWater, false));

	vec4 nextTrans;
	bool transIsManaged = cTrans.a > 0.0 && notEndPortal(u_gbuffer_lightnormal) && lTrans.x > 0.0;

	// will be used for fog outside of shading
	tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * v_texcoord - 1.0, 2.0 * dTrans - 1.0, 1.0);
	eyePos  = tempPos.xyz / tempPos.w;
	light   = lTrans;
	vertexNormal = normalize(texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_TRANS_NORM)).xyz);
	light.w = denoisedShadowFactor(u_gbuffer_shadow, v_texcoord, eyePos, dTrans, light.y, vertexNormal);

	if (transIsManaged) {
		cTrans.rgb = cTrans.rgb / (fastLight(lTrans.xy, vertexNormal) * cTrans.a);
		rawMat = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_TRANS_MATS)).xyz;
		normal = normalize(texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_TRANS_MNORM)).xyz);
		disableDiffuse = bit_unpack(miscTrans.z, 4);

		#ifdef WATER_FOAM
		if (transIsWater && solidIsManaged) {
			foamPreprocess(cTrans, u_tex_nature, eyePos + frx_cameraPos, vertexNormal.y, solidNormaly, eyePos, solidPos);
		}
		#endif

		nextTrans = shading(cTrans, u_tex_nature, light, rawMat, eyePos, normal, vertexNormal, decideUnderwater(dTrans, dTrans, transIsWater, true), disableDiffuse);
		nextTrans = overlay(nextTrans, u_tex_glint, miscTrans);
	} else {
		cTrans.rgb = cTrans.rgb / (cTrans.a == 0.0 ? 1.0 : cTrans.a);
		nextTrans = vec4(hdr_fromGamma(cTrans.rgb), cTrans.a);
	}

	// fog behind rain or trans but only if it's not water (why are you like this)
	if ((cRains.a > 0 && dSolid > dRains) || (dSolid > dMin && !solidIsUnderwater)) {
		bool foggedIsTrans = dTrans < dSolid && dTrans > dRains;

		if (foggedIsTrans) {
			foggedColor = nextTrans;
			////// foggedToFrag = normalize(eyePos); // should be the same
			// foggedLightY = light.y;
			foggedDist = length(eyePos);
			// foggedDepth = dTrans;
			foggedIsUnderwater = frx_cameraInWater == 1;
		}

		// use normal fog for optimization because vol fog isn't applied during rain
		vec4 fogged = fog(foggedColor, foggedDist, foggedToFrag, foggedIsUnderwater);
		// vec4 fogged = volumetricFog(u_gbuffer_shadow, u_tex_nature, foggedColor, foggedDist, foggedToFrag, foggedLightY, tileJitter, foggedDepth, foggedIsUnderwater);

		if (foggedIsTrans) {
			nextTrans = mix(nextTrans, fogged, frx_rainGradient);
			nextTrans = mix(nextTrans, sky, edgeBlendFactor(foggedDist));
		}

		// do this mix to fill gaps
		base = mix(base, fogged, 1.0 - nextTrans.a);
	}

	base = mix(base, sky, edgeBlend);

	vec4 nextRains = vec4(hdr_fromGamma(cRains.rgb), cRains.a);

	vec4 next0, next1, next, after0, after1;

	// try alpha compositing in HDR and you will go bald
	nextParts = vec4(ldr_tonemap(nextParts.rgb) * nextParts.a, nextParts.a); // premultiply α
	nextRains = vec4(ldr_tonemap(nextRains.rgb) * nextRains.a, nextRains.a);
	base = ldr_tonemap(base);

	// TODO: is this slower than insert sort?
	if (dRains > dTrans && dParts > dTrans) {
		next0 = (dRains > dParts ? nextRains : nextParts);
		next1 = (dRains > dParts ? nextParts : nextRains);
		after0 = after1 = vec4(0.0);
	} else if (dParts > dTrans) {
		next1 = nextParts;
		after0 = vec4(0.0);
		after1 = nextRains;
	} else if (dRains > dTrans) {
		next1 = nextRains;
		after0 = vec4(0.0);
		after1 = nextParts;
	} else {
		next0 = next1 = vec4(0.0);
		after0 = (dRains > dParts ? nextRains : nextParts);
		after1 = (dRains > dParts ? nextParts : nextRains);
	}

	nextTrans = vec4(ldr_tonemap(nextTrans.rgb) * nextTrans.a, nextTrans.a);

	next1 = premultBlend(next1, next0);
	next  = premultBlend(nextTrans, next1);
	after1 = premultBlend(after1, after0);
	base  = premultBlend(next, base);

	fragColor = hdr_inverseTonemap(base);
	fragDepth = dMin;
	fragTrans = next;
	fragAfter = after1;

	if (dTrans == dSolid) {
		fragAlbedo = vec4(hdrAlbedo(cSolid), 0.0);
	} else {
		fragAlbedo = vec4(hdrAlbedo(cTrans), 0.5);
	}
}
