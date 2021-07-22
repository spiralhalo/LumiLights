#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/lib/fast_gaussian_blur.glsl
 *******************************************************
 *  Original Work:
 *  https://github.com/Jam3/glsl-fast-gaussian-blur
 *
 *  Copyright (c) 2015 Jam3
 *
 *  Please refer to the file `MIT_LICENSE` contained
 *  in the same directory as this file for the full
 *  license terms of the Original Work.
 *******************************************************/

vec4 blur13(sampler2D image, vec2 uv, vec2 resolution, vec2 direction)
{
	vec4 color = vec4(0.0);
	vec2 off1 = vec2(1.411764705882353) * direction;
	vec2 off2 = vec2(3.2941176470588234) * direction;
	vec2 off3 = vec2(5.176470588235294) * direction;
	color += texture(image, uv) * 0.1964825501511404;
	color += texture(image, uv + (off1 / resolution)) * 0.2969069646728344;
	color += texture(image, uv - (off1 / resolution)) * 0.2969069646728344;
	color += texture(image, uv + (off2 / resolution)) * 0.09447039785044732;
	color += texture(image, uv - (off2 / resolution)) * 0.09447039785044732;
	color += texture(image, uv + (off3 / resolution)) * 0.010381362401148057;
	color += texture(image, uv - (off3 / resolution)) * 0.010381362401148057;
	return color;
}

/*******************************************************
 *  The following code is a derivative work of
 *  the above Original Work.
 *
 *  Copyright (c) 2015 Jam3
 *  Copyright (c) 2021 spiralhalo
 *
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

#define blur13depthOf(s, uv) ldepth(texture(s, uv).r)
#define blur13depthDiffFac(f, s, uv, t) (abs(blur13depthOf(s, uv) - f) < t ? 1.0 : 0.0)
vec4 blur13withDepth(sampler2D image, sampler2D depth, float depthThreshold, vec2 uv, vec2 resolution, vec2 direction)
{
	float d = blur13depthOf(depth, uv);
	vec2 invRes = 1/resolution;
	vec4 color = vec4(0.0);
	vec2 off1 = vec2(1.411764705882353) * direction;
	vec2 off2 = vec2(3.2941176470588234) * direction;
	vec2 off3 = vec2(5.176470588235294) * direction;
	color += texture(image, uv) * 0.1964825501511404;
	color += texture(image, uv + (off1 * invRes)) * 0.2969069646728344 * blur13depthDiffFac(d, depth, uv + (off1 * invRes), depthThreshold);
	color += texture(image, uv - (off1 * invRes)) * 0.2969069646728344 * blur13depthDiffFac(d, depth, uv - (off1 * invRes), depthThreshold);
	color += texture(image, uv + (off2 * invRes)) * 0.09447039785044732 * blur13depthDiffFac(d, depth, uv + (off2 * invRes), depthThreshold);
	color += texture(image, uv - (off2 * invRes)) * 0.09447039785044732 * blur13depthDiffFac(d, depth, uv - (off2 * invRes), depthThreshold);
	color += texture(image, uv + (off3 * invRes)) * 0.010381362401148057 * blur13depthDiffFac(d, depth, uv + (off3 * invRes), depthThreshold);
	color += texture(image, uv - (off3 * invRes)) * 0.010381362401148057 * blur13depthDiffFac(d, depth, uv - (off3 * invRes), depthThreshold);
	return color;
}

vec4 blur13sameAlpha(in vec4 x, in float original_a, in vec4 original_color) {
	return x.a == original_a ? x : original_color;
}
vec4 blur13withDepthSameAlpha(sampler2D image, sampler2D depth, float depthThreshold, vec2 uv, vec2 resolution, vec2 direction)
{
	vec4 origin = texture(image, uv);
	float alpha = origin.a;
	float d = blur13depthOf(depth, uv);
	vec2 invRes = 1/resolution;
	vec4 color = vec4(0.0);
	vec2 off1 = vec2(1.411764705882353) * direction;
	vec2 off2 = vec2(3.2941176470588234) * direction;
	vec2 off3 = vec2(5.176470588235294) * direction;
	color += blur13sameAlpha(texture(image, uv), alpha, origin) * 0.1964825501511404;
	color += blur13sameAlpha(texture(image, uv + (off1 * invRes)), alpha, origin) * 0.2969069646728344 * blur13depthDiffFac(d, depth, uv + (off1 * invRes), depthThreshold);
	color += blur13sameAlpha(texture(image, uv - (off1 * invRes)), alpha, origin) * 0.2969069646728344 * blur13depthDiffFac(d, depth, uv - (off1 * invRes), depthThreshold);
	color += blur13sameAlpha(texture(image, uv + (off2 * invRes)), alpha, origin) * 0.09447039785044732 * blur13depthDiffFac(d, depth, uv + (off2 * invRes), depthThreshold);
	color += blur13sameAlpha(texture(image, uv - (off2 * invRes)), alpha, origin) * 0.09447039785044732 * blur13depthDiffFac(d, depth, uv - (off2 * invRes), depthThreshold);
	color += blur13sameAlpha(texture(image, uv + (off3 * invRes)), alpha, origin) * 0.010381362401148057 * blur13depthDiffFac(d, depth, uv + (off3 * invRes), depthThreshold);
	color += blur13sameAlpha(texture(image, uv - (off3 * invRes)), alpha, origin) * 0.010381362401148057 * blur13depthDiffFac(d, depth, uv - (off3 * invRes), depthThreshold);
	return color;
}
