#include lumi:shaders/common/contrast.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/bitpack.glsl

/*******************************************************
 *  lumi:shaders/prog/overlay.glsl
 *******************************************************/

const vec3 GLINT_COLOR = vec3(GLINT_RED, GLINT_GREEN, GLINT_BLUE);

float glintNoise(vec2 uv, float zoom, vec2 skew, vec2 speed, vec2 detail, vec2 taper) {
	uv += uv.yx * skew;
	uv *= zoom;
	vec2 t = mod(uv + speed * frx_renderSeconds, 1.0);
	t *= detail;
	vec2 f = fract(t);
	t -= f;
	t /= detail;
	f -= 0.5;
	f = abs(f);
	f = 1.0 - 2.0 * f;
	float x = smoothstep(taper.x, taper.y, frx_noise2d(t.xx) * f.x);
	float y = smoothstep(taper.x, taper.y, frx_noise2d(t.yy) * f.y);
	// float x = sqrt(l2_clampScale(taper.x, taper.y, frx_noise2d(t.xx) * f.x));
	// float y = sqrt(l2_clampScale(taper.x, taper.y, frx_noise2d(t.yy) * f.y));
	return x * (1.0-y*0.5) + y * (1.0-x*0.5);
}

vec3 noiseGlint(vec2 normalizedUV, float glint)
{
#if GLINT_STYLE == GLINT_STYLE_GLINT_A
	const float zoom  = 0.5;
	const vec2 skew   = vec2(0.0, 0.4);
	const vec2 speed  = vec2(0.4, -1.0);
	const vec2 detail = vec2(10.0, 8.0);
	const vec2 taper  = vec2(0.4, 0.9);
#elif GLINT_STYLE == GLINT_STYLE_GLINT_B
	const float zoom  = 0.5;
	const vec2 skew   = vec2(0.0, 0.4);
	const vec2 speed  = vec2(0.2, -0.5);
	const vec2 detail = vec2(5.0, 4.0);
	const vec2 taper  = vec2(0.0, 0.9);
#else
	const float zoom  = 2.0;
	const vec2 skew   = vec2(0.4, 0.0);
	const vec2 speed  = vec2(0.8, 0.8);
	const vec2 detail = vec2(10.0, 8.0);
	const vec2 taper  = vec2(0.3, 0.9);
	normalizedUV.x = normalizedUV.x * 2.0;
#endif

	if (glint == 1.0) {
		float n = glintNoise(normalizedUV, zoom, skew, speed, detail, taper);

		#if GLINT_STYLE == GLINT_STYLE_GLINT_B
		float o = 0.5 - n * 0.2;
		o *= glintNoise(normalizedUV + 0.5, zoom, skew, speed * 0.5, detail * 10.0, vec2(0.2, 0.7));
		n += o;
		#endif

		return n * GLINT_COLOR;
	} else {
		return vec3(0.0);
	}
}

vec3 textureGlint(sampler2D glintTexture, vec2 normalizedUV, float glint)
{
	if (glint == 1.0) {
		vec4 glint_tex_c = texture(glintTexture, mod(normalizedUV * 0.5 + frx_renderSeconds * 0.4, 1.0));
		return glint_tex_c.rgb * glint_tex_c.a;
	} else {
		return vec3(0.0);
	}
}

vec3 autoGlint(sampler2D glintTexture, vec2 normalizedUV, float glint)
{
#if GLINT_MODE == GLINT_MODE_GLINT_SHADER
	return hdr_fromGamma(noiseGlint(normalizedUV, glint));
#else
	return hdr_fromGamma(textureGlint(glintTexture, normalizedUV, glint));
#endif
}

vec4 overlay(vec4 base, sampler2D glintTexture, vec4 misc)
{
	const float GLINT_EMISSIVE_STR = 2.0;
	float flash = bit_unpack(misc.z, 0);
	float hurt = bit_unpack(misc.z, 1);
	float glint = bit_unpack(misc.z, 2);

	vec3 overlay = autoGlint(glintTexture, misc.xy, glint) * GLINT_EMISSIVE_STR;
	overlay += vec3(flash) + vec3(0.5 * hurt, 0.0, 0.0);

	base.rgb += overlay;

	return base;
}
