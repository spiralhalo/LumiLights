#include frex:shaders/lib/noise/cellular2x2x2.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include lumi:shaders/lib/rectangle.glsl
#include lumi:shaders/prog/shading.glsl

/*******************************************************
 *  lumi:shaders/prog/sky.glsl
 *******************************************************/

l2_vary vec3 v_celest1;
l2_vary vec3 v_celest2;
l2_vary vec3 v_celest3;

l2_vary mat4 v_star_rotator;
l2_vary float v_night; //what
l2_vary float v_not_in_void;
l2_vary float v_near_void_core;

#ifdef VERTEX_SHADER

void celestSetup()
{
	const vec3 o	   = vec3(-1024., 0.,  0.);
	const vec3 dayAxis = vec3(	0., 0., -1.);

	float size = 250.; // One size fits all; vanilla would be -50 for moon and +50 for sun

	Rect result = Rect(o + vec3(.0, -size, -size), o + vec3(.0, -size,  size), o + vec3(.0,  size, -size));
	
	vec3  zenithAxis  = cross(frx_skyLightVector, vec3( 0.,  0., -1.));
	float zenithAngle = asin(frx_skyLightVector.z);
	float dayAngle	  = frx_skyAngleRadians + PI * 0.5;

	mat4 transformation = l2_rotationMatrix(zenithAxis, zenithAngle);
		transformation *= l2_rotationMatrix(dayAxis, dayAngle);

	rect_applyMatrix(transformation, result, 1.0);

	// jitter celest
	// #ifdef TAA_ENABLED
	// 	vec2 taa_jitterValue = taa_jitter(v_invSize);
	// 	vec4 celest_clip = frx_projectionMatrix * vec4(v_celest1, 1.0);
	// 	v_celest1.xy += taa_jitterValue * celest_clip.w;
	// 	v_celest2.xy += taa_jitterValue * celest_clip.w;
	// 	v_celest3.xy += taa_jitterValue * celest_clip.w;
	// #endif

	v_celest1 = result.bottomLeft;
	v_celest2 = result.bottomRight;
	v_celest3 = result.topLeft;
}

void skySetup()
{
	v_star_rotator = l2_rotationMatrix(vec3(1.0, 0.0, 1.0), frx_worldTime * PI);
	v_night		   = min(smoothstep(0.50, 0.54, frx_worldTime), smoothstep(1.0, 0.96, frx_worldTime));

	v_not_in_void	 = l2_clampScale(-1.0,   0.0, frx_cameraPos.y);
	v_near_void_core = l2_clampScale(10.0, -90.0, frx_cameraPos.y) * 1.8;
}

#else

const vec3 VOID_CORE_COLOR = hdr_fromGamma(vec3(1.0, 0.7, 0.5));

vec4 celestFrag(in Rect celestRect, sampler2D ssun, sampler2D smoon, vec3 worldVec)
{
	if (dot(worldVec, frx_skyLightVector) < 0.) return vec4(0.); // no more both at opposites, sorry

	vec2 celestUV  = rect_innerUV(celestRect, worldVec * 1024.);
	vec3 celestCol = vec3(0.);
	vec3 celestTex = vec3(0.);
	float opacity  = 0.0;

	bool isMoon = frx_worldIsMoonlit == 1;

	if (celestUV == clamp(celestUV, 0.0, 1.0)) {
		if (isMoon){
			vec2 moonUv = clamp(celestUV, 0.25, 0.75);

			if (celestUV == moonUv) {
				celestUV = 2.0 * moonUv - 0.5;
				vec2 fullMoonUV	   = celestUV * vec2(0.25, 0.5);
				vec3 fullMoonColor = texture(smoon, fullMoonUV).rgb;

				opacity = l2_max3(fullMoonColor);
				opacity = min(1.0, opacity * 3.0);

				celestUV.x *= 0.25;
				celestUV.y *= 0.5;
				celestUV.x += mod(frx_worldDay, 4.) * 0.25;
				celestUV.y += (mod(frx_worldDay, 8.) >= 4.) ? 0.5 : 0.0;

				celestTex = hdr_fromGamma(texture(smoon, celestUV).rgb);
				celestCol = celestTex + vec3(0.01) * hdr_fromGamma(fullMoonColor);
				celestCol *= EMISSIVE_LIGHT_STR;
			}
		} else {
			celestTex = texture(ssun, celestUV).rgb;
			celestCol = hdr_fromGamma(celestTex) * atmosv_hdrCelestialRadiance * EMISSIVE_LIGHT_STR;
		}

		opacity = max(opacity, frx_luminance(clamp(celestTex, 0.0, 1.0)));
	}

	return vec4(celestCol, opacity);
}

vec4 customSky(sampler2D sunTexture, sampler2D moonTexture, vec3 toSky, bool isUnderwater, float skyVisible, float celestVisible)
{
	vec4 result = vec4(0.0, 0.0, 0.0, 1.0);
	float skyDotUp = dot(toSky, vec3(0.0, 1.0, 0.0));

	if (frx_cameraInWater == 1 && isUnderwater || isUnderwater || frx_worldIsNether == 1) {
		result.rgb = atmosv_hdrFogColorRadiance;
	} else if (frx_worldIsOverworld == 1 && v_not_in_void > 0.0) {
		// Sky, sun and moon
		#if SKY_MODE == SKY_MODE_LUMI
		vec4 celestColor = celestFrag(Rect(v_celest1, v_celest2, v_celest3), sunTexture, moonTexture, toSky);
		float starEraser = celestColor.a;
		float celestStr  = mix(1.0, STARS_STR, v_night);

		result.rgb  = atmos_hdrSkyGradientRadiance(toSky) * skyVisible;
		result.rgb += celestColor.rgb * (1. - frx_rainGradient) * celestStr * celestVisible;
		#endif

		#if SKY_MODE == SKY_MODE_LUMI || SKY_MODE == SKY_MODE_VANILLA_STARRY
		// Stars
		const vec3 NON_MILKY_AXIS = vec3(-0.598964, 0.531492, 0.598964);

		float starry = l2_clampScale(0.4, 0.0, frx_luminance(result.rgb)) * v_night;
			 starry *= l2_clampScale(-0.6, -0.5, skyDotUp); //prevent star near the void core

		float milkyness   = l2_clampScale(0.7, 0.0, abs(dot(NON_MILKY_AXIS, toSky.xyz)));
		float rainOcclude = (1.0 - frx_rainGradient);
		vec4  starVec     = v_star_rotator * vec4(toSky, 0.0);
		float milkyHaze   = starry * rainOcclude * milkyness * 0.4 * l2_clampScale(-1.0, 1.0, snoise(starVec.xyz * 2.0));
		float starNoise   = cellular2x2x2(starVec.xyz * mix(20 + 2 * LUMI_STAR_DENSITY, 40 + 2 * LUMI_STAR_DENSITY, milkyness)).x;
		float star        = starry * l2_clampScale(0.025 + 0.0095 * LUMI_STAR_SIZE + milkyness * milkyness * 0.15, 0.0, starNoise);

		star = l2_clampScale(0.0, 1.0 - 0.6, star) * rainOcclude;

		#if SKY_MODE == SKY_MODE_LUMI
		star -= star * starEraser;

		milkyHaze -= milkyHaze * starEraser;
		milkyHaze *= milkyHaze;
		#endif

		vec3 starRadiance = vec3(star) * STARS_STR * 0.1 * LUMI_STAR_BRIGHTNESS + NEBULAE_COLOR * milkyHaze;

		result.rgb += starRadiance * skyVisible;
		#endif
	}

	if (frx_worldIsOverworld == 1) {
		// VOID CORE
		float voidCore = l2_clampScale(-0.8 + v_near_void_core, -1.0 + v_near_void_core, skyDotUp); 
		vec3 voidColor = mix(vec3(0.0), VOID_CORE_COLOR, voidCore);

		result.rgb = mix(voidColor, result.rgb, v_not_in_void) * skyVisible;
	}

	return result;
}

vec4 customSky(sampler2D sunTexture, sampler2D moonTexture, vec3 toSky, bool isUnderwater) {
	return customSky(sunTexture, moonTexture, toSky, isUnderwater, 1.0, 1.0);
}

vec4 skyReflection(sampler2D sunTexture, sampler2D moonTexture, vec3 albedo, vec3 material, vec3 toFrag, vec3 toSky, vec3 normal, vec2 lightyw) {
	vec3 radiance = customSky(sunTexture, moonTexture, toSky, false, lightmapRemap(lightyw.x), lightyw.y).rgb;
	return vec4(reflectionPbr(albedo, material, radiance, toSky, -toFrag), 0.0);
}

vec4 skyReflection(sampler2D sunTexture, sampler2D moonTexture, vec3 albedo, vec3 material, vec3 toFrag, vec3 normal, vec2 lightyw) {
	vec3 toSky = reflect(toFrag, normalize(normal));
	return skyReflection(sunTexture, moonTexture, albedo, material, toFrag, toSky, normal, lightyw);
}

#endif