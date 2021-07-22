#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl

/*******************************************************
 *  lumi:shaders/lib/glintify.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

const vec3 GLINT_COLOR = vec3(0.655, 0.333, 1.0);

vec3 noise_glint(vec2 normalizedUV, float glint)
{
	const float zoom = 0.5;
	const vec2 skew = vec2(0.0, 0.4);
	const vec2 speed = vec2(0.4, -1.0);
	const vec2 detail = vec2(5.0, 4.0);
	if (glint == 1.0) {
		normalizedUV += normalizedUV.yx * skew;
		normalizedUV *= zoom;
		vec2 t = mod(normalizedUV + speed * frx_renderSeconds(), 1.0);
		t *= detail;
		vec2 f = fract(t);
		t -= f;
		t /= detail;
		f -= 0.5;
		f = abs(f);
		f = 1.0 - 2.0 * f;
		float n = smoothstep(0.5, 1.0, frx_noise2d(t.xx) * f.x) + smoothstep(0.5, 1.0, frx_noise2d(t.yy) * f.y);
		return n * GLINT_COLOR;
	} else {
		return vec3(0.0);
	}
}

vec3 texture_glint(sampler2D glint_sampler, vec2 normalizedUV, float glint)
{
	if (glint == 1.0) {
		vec4 glint_tex_c = texture(glint_sampler, mod(normalizedUV * 0.5 + frx_renderSeconds() * 0.4, 1.0));
		return glint_tex_c.rgb * glint_tex_c.a;
	} else {
		return vec3(0.0);
	}
}
