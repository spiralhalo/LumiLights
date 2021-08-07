/*******************************************************
 *  lumi:shaders/post/common/shading.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_glint;
uniform sampler2DArrayShadow u_shadow;
uniform sampler2D u_blue_noise;

/*******************************************************
	vertexShader: lumi:shaders/post/hdr.vert
 *******************************************************/

in vec2 v_invSize;
in float v_blindness;

// const float JITTER_STRENGTH = 0.4;
float tileJitter;

vec3 coords_view(vec2 uv, mat4 inv_projection, float depth)
{
	vec4 view = inv_projection * vec4(2.0 * uv - 1.0, 2.0 * depth - 1.0, 1.0);
	return view.xyz / view.w;
}

vec2 coords_uv(vec3 view, mat4 projection)
{
	vec4 clip = projection * vec4(view, 1.0);
	clip.xyz /= clip.w;
	return clip.xy * 0.5 + 0.5;
}

vec4 unmanaged(in vec4 a, out float bloom_out, bool translucent) {
	// bypass unmanaged translucent draw (LITEMATICA WORKAROUND)
	// bypass unmanaged solid sky draw (fix debug rendering color)
	// rationale: light.x is always at least 0.03125 for managed draws
	//			this might not always hold up in the future.
	#if OVERLAY_DEBUG == OVERLAY_DEBUG_NEON || OVERLAY_DEBUG == OVERLAY_DEBUG_DISCO
		bloom_out = step(0.01, a.a);
		a.r += a.g * 0.25;
		a.b += a.g * 0.5;
		a.g *= 0.25;
	#endif
	#if OVERLAY_DEBUG == OVERLAY_DEBUG_DISCO
		a.rgb *= 0.25 + 0.75 * fract(frx_renderSeconds()*2.0);
	#endif
	// marker for unmanaged draw
	a.a = translucent ? a.a : 0.0;
	return a;
}

const float RADIUS = 0.4;
const float BIAS = 0.4;
const float INTENSITY = 10.0;

vec4 hdr_shaded_color(
	vec2 uv, sampler2D sdepth, sampler2D slight, sampler2D snormal, sampler2D smaterial, sampler2D smisc,
	vec4 albedo_alpha, vec3 emissionRadiance, float aoval, bool translucent, bool translucentIsWater, float translucentDepth,
	float exposureCompensation, out float bloom_out)
{
	vec4  a = albedo_alpha;

	if (translucent && a.a == 0.) return vec4(0.);

	float depth   = texture(sdepth, uv).r;
	vec3  viewPos = coords_view(uv, frx_inverseProjectionMatrix(), depth);
	vec3  modelPos = coords_view(uv, frx_inverseViewProjectionMatrix(), depth);
	vec3  worldPos  = frx_cameraPos() + modelPos;
	bool maybeUnderwater = false;
	bool mostlikelyUnderwater = false;
	
	if (frx_viewFlag(FRX_CAMERA_IN_WATER)) {
		if (translucent) {
			maybeUnderwater = true;
		} else {
			maybeUnderwater = translucentDepth >= depth;
		}
		mostlikelyUnderwater = maybeUnderwater;
	} else {
		maybeUnderwater = translucentDepth < depth;
		mostlikelyUnderwater = maybeUnderwater && translucentIsWater;
	}

	if (depth == 1.0 && !translucent) {
		// the sky
		if (v_blindness == 1.0) return vec4(0.0);
		custom_sky(modelPos, 1.0 - v_blindness, maybeUnderwater, a, bloom_out);
		// mark as managed draw, vanilla sky is an exception
		return vec4(a.rgb * 1.0 - v_blindness, 1.0);
	}

	vec4  light = texture(slight, uv);

	if (light.x == 0.0) {
		return unmanaged(a, bloom_out, translucent);
	}

	vec3  normal	= texture(snormal, uv).xyz * 2.0 - 1.0;
	vec3  material  = texture(smaterial, uv).xyz;
	float roughness = material.x == 0.0 ? 1.0 : min(1.0, 1.0203 * material.x - 0.01);
	float metallic  = material.y;
	float f0		= material.z;
	float bloom_raw = light.z * 2.0 - 1.0;
	bool  diffuse   = material.x < 1.0;
	vec3  misc	  = texture(smisc, uv).xyz;
	float matflash  = bit_unpack(misc.z, 0);
	float mathurt   = bit_unpack(misc.z, 1);
	// return vec4(coords_view(uv, frx_inverseProjectionMatrix(), depth), 1.0);

	// Support vanilla emissive
	if (light.x > 0.93625) {
		light.x = 0.93625;
		bloom_raw = 1.0;
	}

	light.y = lightmapRemap(light.y);

	#ifdef SHADOW_MAP_PRESENT
		#ifdef TAA_ENABLED
			vec2 uvJitter = taa_jitter(v_invSize);
			vec4 unjitteredModelPos = frx_inverseViewProjectionMatrix() * vec4(2.0 * uv - uvJitter - 1.0, 2.0 * depth - 1.0, 1.0);
			vec4 shadowViewPos = frx_shadowViewMatrix() * vec4(unjitteredModelPos.xyz/unjitteredModelPos.w, 1.0);
		#else
			vec4 shadowViewPos = frx_shadowViewMatrix() * vec4(worldPos - frx_cameraPos(), 1.0);
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
		light.z = hdr_fromGammaf(light.y);
	#endif

	float causticLight = 0.0;

	#ifdef WATER_CAUSTICS
		if (mostlikelyUnderwater && frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
			causticLight = caustics(worldPos);
			causticLight = pow(causticLight, 15.0);
			causticLight *= smoothstep(0.0, 1.0, light.y);
		}
	#endif

	#ifdef SHADOW_MAP_PRESENT
		causticLight *= light.z;

		if (maybeUnderwater || frx_viewFlag(FRX_CAMERA_IN_WATER)) {
			light.z *= hdr_fromGammaf(light.y);
		}
	#endif

	light.z += causticLight;

	bloom_out = max(0.0, bloom_raw);
	#ifdef RAIN_PUDDLES
		ww_puddle_pbr(a, roughness, light.y, normal, worldPos);
	#endif
	#if BLOCKLIGHT_SPECULAR_MODE == BLOCKLIGHT_SPECULAR_MODE_FANTASTIC
		preCalc_blockDir = calcBlockDir(slight, uv, v_invSize, normal, viewPos, sdepth);
	#endif
	pbr_shading(a, bloom_out, modelPos, light.xyz, normal, roughness, metallic, f0, diffuse, translucent);


#if AMBIENT_OCCLUSION != AMBIENT_OCCLUSION_NO_AO
	#if AMBIENT_OCCLUSION != AMBIENT_OCCLUSION_PURE_SSAO
		float ao_shaded = 1.0 + min(0.0, bloom_raw);
	#else
		float ao_shaded = 1.0;
	#endif
#ifdef SSAO_ENABLED
	float ssao = mix(aoval, 1.0, min(bloom_out, 1.0));
#else
	float ssao = 1.;
#endif
	a.rgb += emissionRadiance * EMISSIVE_LIGHT_STR;
	a.rgb *= ao_shaded * ssao;
#endif
	if (matflash == 1.0) a.rgb += 1.0;
	if (mathurt == 1.0) a.r += 0.5;

	a.a = min(1.0, a.a);

	#if GLINT_MODE == GLINT_MODE_GLINT_SHADER
		a.rgb += hdr_fromGamma(noise_glint(misc.xy, bit_unpack(misc.z, 2)));
	#else
		a.rgb += hdr_fromGamma(texture_glint(u_glint, misc.xy, bit_unpack(misc.z, 2)));
	#endif

	if (a.a != 0.0 && depth != 1.0) {
		a = fog(light.y, exposureCompensation, v_blindness, a, modelPos, bloom_out);
	}

	return a;
}
