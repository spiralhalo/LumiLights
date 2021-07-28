#include lumi:shaders/post/common/header.glsl

#include lumi:shaders/post/common/shading_includes.glsl

/*******************************************************
 *  lumi:shaders/post/shading.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_solid_color;
uniform sampler2D u_solid_depth;
uniform sampler2D u_light_solid;
uniform sampler2D u_normal_solid;
uniform sampler2D u_material_solid;
uniform sampler2D u_misc_solid;

uniform sampler2D u_translucent_depth;
uniform sampler2D u_translucent_color;
uniform sampler2D u_misc_translucent;

uniform sampler2D u_ao;
uniform sampler2D u_sun;
uniform sampler2D u_moon;

in vec3 v_celest1;
in vec3 v_celest2;
in vec3 v_celest3;

in mat4 v_star_rotator;
in float v_fov;
in float v_night;
in float v_not_in_void;
in float v_near_void_core;

const vec3 VOID_CORE_COLOR = hdr_fromGamma(vec3(1.0, 0.7, 0.5));

out vec4[2] fragColor;

void custom_sky(in vec3 modelPos, in float blindnessFactor, in bool maybeUnderwater, inout vec4 a, inout float bloom_out)
{
	vec3 worldSkyVec = normalize(modelPos);
	float skyDotUp = dot(worldSkyVec, vec3(0.0, 1.0, 0.0));

	bloom_out = 0.0;

	if ((frx_viewFlag(FRX_CAMERA_IN_WATER) && maybeUnderwater) || frx_worldFlag(FRX_WORLD_IS_NETHER)) {
		a.rgb = atmosv_hdrFogColorRadiance;
	} else if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD) && v_not_in_void > 0.0) {
		#if SKY_MODE == SKY_MODE_LUMI
			vec4 celestColor = celestFrag(Rect(v_celest1, v_celest2, v_celest3), u_sun, u_moon, worldSkyVec);
			float starEraser = celestColor.a;
			float celestStr = mix(1.0, STARS_STR, v_night);

			bloom_out += celestColor.a * 2.0;
			a.rgb = atmos_hdrSkyGradientRadiance(worldSkyVec);
			a.rgb += celestColor.rgb * (1. - frx_rainGradient()) * celestStr;
		#else
			// a.rgb = hdr_fromGamma(a.rgb) * 2.0; // Don't gamma-correct vanilla sky
		#endif

		#if SKY_MODE == SKY_MODE_LUMI || SKY_MODE == SKY_MODE_VANILLA_STARRY
			// stars
			const vec3 nonMilkyAxis = vec3(-0.598964, 0.531492, 0.598964);

			float starry = l2_clampScale(0.4, 0.0, frx_luminance(a.rgb)) * v_night;

			starry *= l2_clampScale(-0.6, -0.5, skyDotUp); //prevent star near the void core

			float milkyness = l2_clampScale(0.7, 0.0, abs(dot(nonMilkyAxis, worldSkyVec.xyz)));
			float rainOcclusion = (1.0 - frx_rainGradient());
			vec4  starVec = v_star_rotator * vec4(worldSkyVec, 0.0);
			float zoomFactor = l2_clampScale(90, 30, v_fov); // zoom sharpening
			float milkyHaze = starry * rainOcclusion * milkyness * 0.4 * l2_clampScale(-1.0, 1.0, snoise(starVec.xyz * 2.0));
			float star = starry * l2_clampScale(0.12 + milkyness * milkyness * 0.15, 0.0, cellular2x2x2(starVec.xyz * mix(40, 60, milkyness)).x);

			star = l2_clampScale(0.0, 1.0 - 0.6 * zoomFactor, star) * rainOcclusion;

			#if SKY_MODE == SKY_MODE_LUMI
				star -= star * starEraser;
				milkyHaze -= milkyHaze * starEraser;
				milkyHaze *= milkyHaze;
			#endif

			vec3 starRadiance = vec3(star) * STARS_STR + NEBULAE_COLOR * milkyHaze;

			a.rgb += starRadiance;
			bloom_out += (star + milkyHaze);
		#endif
	}

	//prevent sky in the void for extra immersion
	if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) {
		// VOID CORE
		float voidCore = l2_clampScale(-0.8 + v_near_void_core, -1.0 + v_near_void_core, skyDotUp); 
		vec3 voidColor = mix(vec3(0.0), VOID_CORE_COLOR, voidCore);
		bloom_out += voidCore * (1. - v_not_in_void);
		a.rgb = mix(voidColor, a.rgb, v_not_in_void);
	}

	bloom_out *= blindnessFactor;
}

#include lumi:shaders/post/common/shading.glsl

void main()
{
	float ec = exposureCompensation();

	tileJitter = getRandomFloat(u_blue_noise, v_texcoord, frxu_size); //JITTER_STRENGTH;
	float bloom1;
#ifdef SSAO_ENABLED
	vec4 ssao = texture(u_ao, v_texcoord);
#else
	vec4 ssao = vec4(0.0, 0.0, 0.0, 1.0);
#endif
	float translucentDepth = texture(u_translucent_depth, v_texcoord).r;
	vec4 solidAlbedoAlpha = texture(u_solid_color, v_texcoord);

	bool translucentIsWater = bit_unpack(texture(u_misc_translucent, v_texcoord).z, 7) == 1.;

	vec4 a1 = hdr_shaded_color(
		v_texcoord, u_solid_depth, u_light_solid, u_normal_solid, u_material_solid, u_misc_solid,
		solidAlbedoAlpha, ssao.rgb, ssao.a, false, translucentIsWater, translucentDepth, ec, bloom1);

	fragColor[0] = a1;

	float translucentAlpha = texture(u_translucent_color, v_texcoord).a;
	float bloomTransmittance = translucentDepth < texture(u_solid_depth, v_texcoord).r
		  ? (1.0 - translucentAlpha * translucentAlpha)
		  : 1.0;

	fragColor[1] = vec4(bloom1 * bloomTransmittance, 0.0, 0.0, 1.0);
}


