#include lumi:shaders/lib/rectangle.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/lib/celest_adapter.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

#ifdef VERTEX_SHADER

Rect celestSetup()
{
	const vec3 o	   = vec3(-1024., 0.,  0.);
	const vec3 dayAxis = vec3(	0., 0., -1.);

	float size = 250.; // One size fits all; vanilla would be -50 for moon and +50 for sun

	Rect result = Rect(o + vec3(.0, -size, -size), o + vec3(.0, -size,  size), o + vec3(.0,  size, -size));
	
	vec3  zenithAxis  = cross(frx_skyLightVector(), vec3( 0.,  0., -1.));
	float zenithAngle = asin(frx_skyLightVector().z);
	float dayAngle	= frx_skyAngleRadians() + PI * 0.5;

	mat4 transformation = l2_rotationMatrix(zenithAxis, zenithAngle);
		transformation *= l2_rotationMatrix(dayAxis, dayAngle);

	rect_applyMatrix(transformation, result, 1.0);

	return result;
}

#else

vec4 celestFrag(in Rect celestRect, sampler2D ssun, sampler2D smoon, vec3 worldVec) {
	vec2 celestUV = rect_innerUV(celestRect, worldVec * 1024.);
	vec3 celestialObjectColor = vec3(0.);
	float opacity = 0.0;
	bool isMoon = dot(worldVec, frx_skyLightVector()) < 0. ? !frx_worldFlag(FRX_WORLD_IS_MOONLIT) : frx_worldFlag(FRX_WORLD_IS_MOONLIT);

	if (celestUV == clamp(celestUV, 0.0, 1.0)) {
		if (isMoon){
			vec2 moonUv = clamp(celestUV, 0.25, 0.75);

			if (celestUV == moonUv) {
				celestUV = 2.0 * moonUv - 0.5;
				vec2 fullMoonUV = celestUV * vec2(0.25, 0.5);
				vec3 fullMoonColor = texture(smoon, fullMoonUV).rgb;
				opacity = l2_max3(fullMoonColor);
				opacity = min(1.0, opacity * 3.0);
				celestUV.x *= 0.25;
				celestUV.y *= 0.5;
				celestUV.x += mod(frx_worldDay(), 4.) * 0.25;
				celestUV.y += (mod(frx_worldDay(), 8.) >= 4.) ? 0.5 : 0.0;
				celestialObjectColor = hdr_fromGamma(texture(smoon, celestUV).rgb) * 3.0;
				celestialObjectColor += vec3(0.01) * hdr_fromGamma(fullMoonColor);
			}
		} else {
			celestialObjectColor = hdr_fromGamma(texture(ssun, celestUV).rgb) * 2.0;
		}

		opacity = max(opacity, frx_luminance(clamp(celestialObjectColor, 0.0, 1.0)) * 0.25);
	}

	return vec4(celestialObjectColor, opacity);
}

vec2 celestSpecular(in Rect celestRect, sampler2D ssun, sampler2D smoon, vec3 worldVec) {
	float top = max(0.0, worldVec.y);
	// float size = frx_worldFlag(FRX_WORLD_IS_MOONLIT) ? 0.0025 : 0.005;
	
	if (top <= 0.) return vec2(0.0);

	top = smoothstep(0.0, 0.01, top);

	vec4 celestialObjectColor = celestFrag(celestRect, ssun, smoon, worldVec);

	celestialObjectColor.rgb = smoothstep(0.0, 1.0, celestialObjectColor.rgb);

	float specular = frx_luminance(clamp(celestialObjectColor.rgb, 0.0, 1.0)) * top;
	float opacity = max(celestialObjectColor.a, specular) * top;

	// float specular = max(0.0, dot(worldVec, frx_skyLightVector()));

	// specular = smoothstep(1.0 - size, 1.0, specular) * top;

	// float opacity = specular;

	return vec2(specular, opacity);
}

#endif
