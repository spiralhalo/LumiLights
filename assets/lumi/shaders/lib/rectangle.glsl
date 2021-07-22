/*******************************************************
 *  lumi:shaders/lib/rectangle.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

struct Rect {
	vec3 bottomLeft;
	vec3 bottomRight;
	vec3 topLeft;
};

void rect_applyMatrix(mat4 matrix, inout Rect rectangle, float w)
{
	vec4 botL = matrix * vec4(rectangle.bottomLeft, w);
	vec4 botR = matrix * vec4(rectangle.bottomRight, w);
	vec4 topL = matrix * vec4(rectangle.topLeft, w);

	rectangle.bottomLeft = botL.xyz / botL.w;
	rectangle.bottomRight = botR.xyz / botR.w;
	rectangle.topLeft = topL.xyz / topL.w;
}

vec2 rect_innerUV(in Rect rectangle, vec3 point)
{
	vec3 bLP = point - rectangle.bottomLeft;
	vec3 bLbR = rectangle.bottomRight - rectangle.bottomLeft;
	vec3 bLtL = rectangle.topLeft - rectangle.bottomLeft;
	
	float normbRrcp = 1. / length(bLbR);
	float normtLrcp = 1. / length(bLtL);

	// project a to b, then normalize to b's length
	// a.b̂/||b|| = a.(b/||b||)/||b|| = a.b*||b||^-2

	return vec2(dot(bLP, bLbR) * normbRrcp * normbRrcp, dot(bLP, bLtL) * normtLrcp * normtLrcp);
}
