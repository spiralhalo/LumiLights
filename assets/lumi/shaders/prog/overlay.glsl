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

		return n * GLINT_COLOR * GLINT_COLOR;
	} else {
		return vec3(0.0);
	}
}

vec3 textureGlint(sampler2D glintTexture, vec2 normalizedUV, float glint)
{
	if (glint == 1.0) {
		// vanilla scale factor for entity, works in most scenario
		const float scale = 0.16;

		// vanilla rotation factor
		const float angle = PI * 10. / 180.;
		const vec3  axis = vec3(0.0, 0.0, 1.0);
		const float s = sin(angle);
		const float c = cos(angle);
		const float oc = 1.0 - c;
		const mat4 rotation = mat4(
		oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
		oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
		oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
		0.0,                                0.0,                                0.0,                                1.0);

		// vanilla translation factor
		float time = frx_renderSeconds * 8.;
		float tx = mod(time, 110.) / 110.;
		float ty = mod(time, 30.) / 30.;
		vec2 translation = vec2(-tx, ty);

		vec2 uv = (rotation * vec4(normalizedUV * scale, 0.0, 1.0)).xy + translation;
		vec3 glint = texture(glintTexture, uv).rgb;

		// emulate GL_SRC_COLOR sfactor
		return glint * glint;
	} else {
		return vec3(0.0);
	}
}

vec3 autoGlint(sampler2D glintTexture, vec2 normalizedUV, float glint)
{
#if GLINT_MODE == GLINT_MODE_GLINT_SHADER
	return noiseGlint(normalizedUV, glint);
#else
	return textureGlint(glintTexture, normalizedUV, glint);
#endif
}

#ifdef POST_SHADER
vec4 overlay(vec4 base, sampler2D glintTexture, vec3 misc)
{
	const float GLINT_EMISSIVE_STR = 2.0;
	float flash = bit_unpack(misc.z, 0);
	float hurt = bit_unpack(misc.z, 1);
	float glint = bit_unpack(misc.z, 2);

	vec3 glintColor = hdr_fromGamma(autoGlint(glintTexture, misc.xy, glint));

	vec3 overlay = glintColor * GLINT_EMISSIVE_STR;
	overlay += vec3(flash) + vec3(0.5 * hurt, 0.0, 0.0);

	base.rgb += overlay;

	return base;
}
#endif
