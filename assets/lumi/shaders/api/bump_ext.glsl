/*******************************************************
 *  lumi:shaders/api/bump_ext.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

/*** API ***/

/** GENERAL INFORMATION **
 * 
 * The Lumi Lights Bump Extension API is a set of functions that allows you to generate bump maps on the fly
 * to enhance the visuals of your blocks in PBR-enabled pipelines without the requirement of PBR textures.
 *
 * This "API" is more of a library. It is made into an api to ease development of bump based shader pack.
 * This API does come with the limitation of requiring Lumi Lights to be present, although at the moment of
 * writing, Lumi Lights is the prevailing custom pipeline pack for Canvas so this API was made with that in mind.
 *
 * Since the content of this API works like a library, you might copy its content into your own shaders
 * in order to implement it independently from Lumi Lights. HOWEVER, do make sure to NOT overwrite or use the
 * "lumi" namespace and the "bumpExt_" prefix as it will break implementations that relies on this API directly.
 *
 * USAGE
 * Import this API in your vertex and fragment shaders.
 * Guard every calls to the API functions using `#ifdef LUMI_BUMP_API >= {version of the function}` to ensure
 * forward compatibility and fail-safety.
 */

#define LUMI_BUMP_API 1

#ifdef VERTEX_SHADER

/*** VERTEX FUNCTIONS ***/

/**
 * Compute the required inputs for the bump map generators.
 *
 * @param	spriteUV	Normalized sprite UV of the block.
 * @param	resolution	Resolution of the texture.
 * @param	uvn			Outputs texture coordinate of the base texel.
 * @param	uvt			Outputs texture coordinate of the neighboring texel at the direction of the tangent.
 * @param	uvb			Outputs texture coordinate of the neighboring texel at the direction of the bitangent.
 * @param	topRight	Outputs texture coordinate at the top right of the sprite minus 1 sample in U and V axes.
 */
void bumpExt_computeTexCoords_v1(in vec2 spriteUV, in vec2 resolution, out vec2 uvn, out vec2 uvt, out vec2 uvb, out vec2 topRight);

/**
 * Compute the tangent vector from normal. Note: this is an innacurate approximation
 *
 * @param	normal		Original vertex normal.
 *
 * @return				The computed tangent vector.
 */
vec3 bumpExt_computeTangent_v1(vec3 normal);

#else

/*** FRAGMENT FUNCTIONS ***/

/**
 * Generate bumps based on texel luminance.
 * 
 * @param	tex			Base color texture sampler.
 * @param	normal		Original vertex normal.
 * @param	uvn			Texture coordinate of the base texel.
 * @param	uvt			Texture coordinate of the neighboring texel at the direction of the tangent.
 * @param	uvb			Texture coordinate of the neighboring texel at the direction of the bitangent.
 * @param	topRight	Texture coordinate at the top right of the sprite minus 1 sample in U and V axes.
 * @param	tangentVec	The tangent vector.
 * @param	reverse		If true, brighter texel will create deboss instead of emboss.
 *
 * @return				The computed normal vector.
 */
vec3 bumpExt_luminance_v1(sampler2D tex, vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb, vec2 topRight, vec3 tangentVec, bool reverse);

/**
 * Generate a bevel effect on the edges of a block or in a brick shape.
 * 
 * @param	vertNormal	Original vertex normal.
 * @param	tangentVec	The tangent vector.
 * @param	spriteUV	Normalized sprite UV of the block.
 * @param	regionPos	Block coordinate relative to its render region.
 * @param	isBrick		Should be true for stone brick-like textured blocks.
 *
 * @return				The computed normal vector.
 */
vec3 bumpExt_bevel_v1(vec3 vertNormal, vec3 tangentVec, vec2 spriteUV, vec3 regionPos, bool isBrick);

/* Generate random bumps using a white noise.
 *
 * @param	normal		Original vertex normal.
 * @param	uvn			Texture coordinate of the base texel.
 * @param	uvt			Texture coordinate of the neighboring texel at the direction of the tangent.
 * @param	uvb			Texture coordinate of the neighboring texel at the direction of the bitangent.
 * @param	tangentVec	The tangent vector.
 * @param	coarseness	Amount of deviation from original normal in a range of [0, 1]
 * @return				The computed normal vector.
 */
vec3 bumpExt_coarse_v1(vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb, vec3 tangentVec, float coarseness);

/**
 * Generate a binary bump map based on texel saturation.
 * 
 * @param	tex			Base color texture sampler.
 * @param	normal		Original vertex normal.
 * @param	uvn			Texture coordinate of the base texel.
 * @param	uvt			Texture coordinate of the neighboring texel at the direction of the tangent.
 * @param	uvb			Texture coordinate of the neighboring texel at the direction of the bitangent.
 * @param	topRight	Texture coordinate at the top right of the sprite minus 1 sample in U and V axes.
 * @param	tangentVec	The tangent vector.
 * @param	step_		Saturation value that divides between deboss and emboss texels.
 * @param	strength	Steepness of the bump in [0, 1] range.
 * @param	reverse		If true, higher saturation texel will create deboss instead of emboss.
 *
 * @return				The computed normal vector.
 */
vec3 bumpExt_stepSaturation_v1(sampler2D tex, vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb, vec2 topRight, vec3 tangentVec, float step_, float strength, bool reverse);

/**
 * Generate a binary bump map based on texel luminance.
 * 
 * @param	tex			Base color texture sampler.
 * @param	normal		Original vertex normal.
 * @param	uvn			Texture coordinate of the base texel.
 * @param	uvt			Texture coordinate of the neighboring texel at the direction of the tangent.
 * @param	uvb			Texture coordinate of the neighboring texel at the direction of the bitangent.
 * @param	topRight	Texture coordinate at the top right of the sprite minus 1 sample in U and V axes.
 * @param	tangentVec	The tangent vector.
 * @param	step_		Luminance value that divides between deboss and emboss texels.
 * @param	strength	Steepness of the bump in [0, 1] range.
 * @param	reverse		If true, higher luminance texel will create deboss instead of emboss.
 *
 * @return				The computed normal vector.
 */
vec3 bumpExt_stepLuminance_v1(sampler2D tex, vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb, vec2 topRight, vec3 tangentVec, float step_, float strength, bool reverse);

/* Generate bumpy edge between solid and transparent texels.
 * 
 * @param	tex			Base color texture sampler.
 * @param	normal		Original vertex normal.
 * @param	uvn			Texture coordinate of the base texel.
 * @param	uvt			Texture coordinate of the neighboring texel at the direction of the tangent.
 * @param	uvb			Texture coordinate of the neighboring texel at the direction of the bitangent.
 * @param	topRight	Texture coordinate at the top right of the sprite minus 1 sample in U and V axes.
 * @param	tangentVec	The tangent vector.
 * @param	reverse		If true, solid texel will create deboss instead of emboss.
 *
 * @return				The computed normal vector.
 */
vec3 bumpExt_alpha_v1(sampler2D tex, vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb, vec2 topRight, vec3 tangentVec, bool reverse);

#endif



/*** IMPLEMENTATION ***/

#if __VERSION__ <= 120
#define _bumpExt_texture texture2D
#else
#define _bumpExt_texture texture
#endif

#ifdef VERTEX_SHADER

void bumpExt_computeTexCoords_v1(in vec2 spriteUV, in vec2 resolution, out vec2 uvn, out vec2 uvt, out vec2 uvb, out vec2 topRight) {
	vec2 bumpSample = 1.0 / resolution;

	uvn = frx_mapNormalizedUV(spriteUV);
	uvt = frx_mapNormalizedUV(spriteUV + vec2(bumpSample.x, 0.0));
	uvb = frx_mapNormalizedUV(spriteUV + vec2(0.0, -bumpSample.y));
	topRight = frx_mapNormalizedUV(vec2(1.0, 0.0) + vec2(-bumpSample.x, bumpSample.y));
}

const mat4 _bumpExt_rotm = mat4(
	0,  0, -1,  0,
	0,  1,  0,  0,
	1,  0,  0,  0,
	0,  0,  0,  1 );

vec3 bumpExt_computeTangent_v1(vec3 normal)
{
	vec3 aaNormal = vec3(normal.x + 0.01, 0, normal.z + 0.01);

	aaNormal = normalize(aaNormal);

	return (_bumpExt_rotm * vec4(aaNormal, 0.0)).xyz;
}

#else

/* Derived from Hash without Sine by David Hoskins, MIT License.
 * https://www.shadertoy.com/view/4djSRW */
float _bumpExt_hash12(vec2 p)
{
	vec3 p3 = fract(vec3(p.xyx) * 10.1313);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

#define _bumpExt_height1(raw) frx_smootherstep(0, 1, pow(raw, 1 + raw * raw))
#define _bumpExt_height2(x) sqrt((x.r + x.g + x.b) * 0.33333 * 2.0)

vec3 bumpExt_luminance_v1(sampler2D tex, vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb, vec2 topRight, vec3 tangentVec, bool reverse)
{
	vec3 tangentMove = tangentVec * (reverse ? -1.0 : 1.0);
	vec3 bitangentMove = cross(normal, tangentVec) * (reverse ? -1.0 : 1.0);

	if (uvn.x > topRight.x) { uvt = uvn; }
	if (uvn.y < topRight.y) { uvb = uvn; }

	vec3 texel = _bumpExt_texture(tex, uvn, frx_matUnmipped * -4.0).rgb;
	float hn = _bumpExt_height2(texel);
	vec3 origin = hn * normal;
	texel = _bumpExt_texture(tex, uvt, frx_matUnmipped * -4.0).rgb;
	float ht = _bumpExt_height2(texel);
	vec3 tangent = tangentMove + ht * normal - origin;
	texel = _bumpExt_texture(tex, uvb, frx_matUnmipped * -4.0).rgb;
	float hb = _bumpExt_height2(texel);
	vec3 bitangent = bitangentMove + hb * normal - origin;

	return normalize(cross(tangent, bitangent));
}

vec3 bumpExt_bevel_v1(vec3 vertNormal, vec3 tangentVec, vec2 spriteUV, vec3 regionPos, bool isBrick) 
{
	// COMPUTE MASK
	vec2 e1 = smoothstep(0.0725, 0.0525, spriteUV);
	vec2 e2 = smoothstep(1.0-0.0725, 1.0-0.0525, spriteUV);
	vec2 e = max(e1, e2);
	float mask = max(e.s, e.t); // edge mask

	if (isBrick) {
		float bottom = step(0.5-0.0525, spriteUV.t);
		vec2 m = smoothstep(0.0725, 0.0525, abs(spriteUV - vec2(0.5))); // middle + shaped mask
		m.s *= bottom;                                                  // cut top part of + to get ㅜ
		mask = max(mask * max(1.0 - bottom, e2.t), max(m.s, m.t));      // selective combine with edge mask = brick mask
	}

	if (mask <= 0) { // premature culling
		return vertNormal;
	}

	// COMPUTE BEVEL CENTER
	//nb: unlike world pos, region pos is always positive
	vec3 model = fract(regionPos - vertNormal * 0.1); // position roughly within a 1x1 cube
	vec3 center = vec3(0.5, 0.5, 0.5); // center of the bevel

	if (isBrick) {
		// 0.0725 < magic number < 0.5 - 0.0725. 0.15 gives smoothest result
		#define _BRICK_FALLBACK_MAGICN 0.15
		
		bool fallback = spriteUV.t < 0.5 && abs(spriteUV.s - 0.5) < _BRICK_FALLBACK_MAGICN; 
		fallback = fallback || spriteUV.t > 0.5 && abs(spriteUV.s - 0.5) > 0.5 - _BRICK_FALLBACK_MAGICN; // use ALG A where ALG B fails
		if (fallback) { // ALG A: nicely brick shaped, but stretched at the sides
			vec3 bitangent = cross(vertNormal, tangentVec);
			center += spriteUV.t < 0.5 ? vec3(0.0) : tangentVec * (-0.5 + floor(spriteUV.s * 2.0));
			center -= bitangent * (-0.25 + 0.5 * floor(spriteUV.t * 2.0));
			model -= center;
			center = vec3(0.);
			model *= 1.0 - abs(tangentVec) * 0.5;
		} else {        // ALG B: divide one cube into four small cubes, no stretching but has triangle marks
			center = vec3(0.25) + vec3(0.5) * floor(model * 2.0);
		}
	}

	// COMPUTE BEVEL
	center -= vertNormal * 1.;
	vec3 a = (model - center);
	vec3 b = abs(a);                        // compute in positive space
	float minVal = min(b.x, min(b.y, b.z));
	b -= minVal;                            // make the normal favor one cardinal direction within the texture
	b = pow(normalize(b), vec3(.15));       // make the division between directions sharper, adjustable
	a = sign(a) * b;                        // return to real space
	a = mix(vertNormal, normalize(a), mask); // apply mask

	return normalize(a + vertNormal);
}

/* Generate random bump map by using a noise function. */
vec3 bumpExt_coarse_v1(vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb, vec3 tangentVec, float coarseness)
{
	vec3 tangentMove = tangentVec;
	vec3 bitangentMove = cross(normal, tangentVec);

	vec3 origin = _bumpExt_height1(coarseness * _bumpExt_hash12(uvn)) * normal;
	vec3 tangent = tangentMove + _bumpExt_height1(coarseness * _bumpExt_hash12(uvt)) * normal - origin;
	vec3 bitangent = bitangentMove + _bumpExt_height1(coarseness * _bumpExt_hash12(uvb)) * normal - origin;

	return normalize(cross(tangent, bitangent));
}

/* Generate binary bump map based on texel saturation. */
vec3 bumpExt_stepSaturation_v1(sampler2D tex, vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb, vec2 topRight, vec3 tangentVec, float step_, float strength, bool reverse)
{
	vec3 tangentMove = tangentVec * (reverse ? -1.0 : 1.0);
	vec3 bitangentMove = cross(normal, tangentVec) * (reverse ? -1.0 : 1.0);

	if (uvn.x > topRight.x) { uvt = uvn; }
	if (uvn.y < topRight.y) { uvb = uvn; }
	
	vec4  c         = _bumpExt_texture(tex, uvn, frx_matUnmipped * -4.0);
	float min_      = min( min(c.r, c.g), c.b );
	float max_      = max( max(c.r, c.g), c.b );
	float s         = (max_ > 0 ? (max_ - min_) / max_ : 0) + (1 - c.a);
	vec3  origin    = (s > step_ ? strength : 0.0) * normal;
	
		  c         = _bumpExt_texture(tex, uvt, frx_matUnmipped * -4.0);
		  min_      = min( min(c.r, c.g), c.b );
		  max_      = max( max(c.r, c.g), c.b );
		  s         = (max_ > 0 ? (max_ - min_) / max_ : 0) + (1 - c.a);
	vec3  tangent   = tangentMove + (s > step_ ? strength : 0.0) * normal - origin;
	
		  c         = _bumpExt_texture(tex, uvb, frx_matUnmipped * -4.0);
		  min_      = min( min(c.r, c.g), c.b );
		  max_      = max( max(c.r, c.g), c.b );
		  s         = (max_ > 0 ? (max_ - min_) / max_ : 0) + (1 - c.a);
	vec3  bitangent = bitangentMove + (s > step_ ? strength : 0.0) * normal - origin;

	return normalize(cross(tangent, bitangent));
}

/* Generate binary bump map based on texel luminance. */
vec3 bumpExt_stepLuminance_v1(sampler2D tex, vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb, vec2 topRight, vec3 tangentVec, float step_, float strength, bool reverse)
{
	vec3 tangentMove = tangentVec * (reverse ? -1.0 : 1.0);
	vec3 bitangentMove = cross(normal, tangentVec) * (reverse ? -1.0 : 1.0);

	if (uvn.x > topRight.x) { uvt = uvn; }
	if (uvn.y < topRight.y) { uvb = uvn; }

	vec3 origin = _bumpExt_height1(frx_luminance(_bumpExt_texture(tex, uvn, frx_matUnmipped * -4.0).rgb) > step_ ? strength : 0.0) * normal;
	vec3 tangent = tangentMove + _bumpExt_height1(frx_luminance(_bumpExt_texture(tex, uvt, frx_matUnmipped * -4.0).rgb) > step_ ? strength : 0.0) * normal - origin;
	vec3 bitangent = bitangentMove + _bumpExt_height1(frx_luminance(_bumpExt_texture(tex, uvb, frx_matUnmipped * -4.0).rgb) > step_ ? strength : 0.0) * normal - origin;

	return normalize(cross(tangent, bitangent));
}

/* Generate bumpy edge between solid and transparent texels. */
vec3 bumpExt_alpha_v1(sampler2D tex, vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb, vec2 topRight, vec3 tangentVec, bool reverse)
{
	vec3 tangentMove = tangentVec * (reverse ? -1.0 : 1.0);
	vec3 bitangentMove = cross(normal, tangentVec) * (reverse ? -1.0 : 1.0);

	if (uvn.x > topRight.x) { uvt = uvn; }
	if (uvn.y < topRight.y) { uvb = uvn; }

	vec3 origin = _bumpExt_height1(_bumpExt_texture(tex, uvn, frx_matUnmipped * -4.0).a) * normal;
	vec3 tangent = tangentMove + _bumpExt_height1(_bumpExt_texture(tex, uvt, frx_matUnmipped * -4.0).a) * normal - origin;
	vec3 bitangent = bitangentMove + _bumpExt_height1(_bumpExt_texture(tex, uvb, frx_matUnmipped * -4.0).a) * normal - origin;

	return normalize(cross(tangent, bitangent));
}

#endif
