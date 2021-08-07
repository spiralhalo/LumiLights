/*******************************************************
 *  lumi:shaders/lib/pack_normal.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

float packVec2(in vec2 c) {
    c *= 255.;
    c = floor(c);

    return (c.r * 256. + c.g) / 65536.;
}

vec2 unpackVec2(in float val) {
	val *= 65536.;

    vec2 c;
    c.g = mod(val, 256.);
    val = floor(val / 256.);
    c.r = mod(val, 256.);

    return c / 255.;
}

vec3 packNormal(vec3 normal, vec3 tangent) {
	normal = 0.5 + 0.5 * normal;
	tangent = 0.5 + 0.5 * tangent;

	return vec3(packVec2(normal.rg), packVec2(tangent.rg), packVec2(vec2(normal.b, tangent.b)));
}

/**
 *	Unpacks packed normal and tangent vectors.
 *  Must output without normalization.
 */
void unpackNormal(in vec3 source, out vec3 normal, out vec3 tangent) {
	normal.rg = unpackVec2(source.r);
	tangent.rg = unpackVec2(source.g);

	vec2 bb = unpackVec2(source.b);

	normal.b = bb.r;
	tangent.b = bb.g;

	// Don't normalize
	normal = 2.0 * normal - 1.0;
	tangent = 2.0 * tangent - 1.0;
}
