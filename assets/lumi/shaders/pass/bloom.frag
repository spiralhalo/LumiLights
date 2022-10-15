#include lumi:shaders/pass/header.glsl

#include frex:shaders/lib/sample.glsl
#include lumi:shaders/prog/tonemap.glsl

/******************************************************
  lumi:shaders/pass/bloom.frag
******************************************************/

uniform sampler2D u_input;
uniform sampler2D u_blend;

out vec4 fragColor;

const vec2 BLOOM_DOWNSAMPLE_DIST_VEC = vec2(BLOOM_SCALE);
const vec2 BLOOM_UPSAMPLE_DIST_VEC	 = BLOOM_DOWNSAMPLE_DIST_VEC / 10.; // not sure why this is

#ifdef HIGH_QUALITY_BLOOM
// https://stackoverflow.com/questions/13501081/efficient-bicubic-filtering-code-in-glsl
vec4 cubic(float v)
{
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0/6.0);
}

vec4 textureBicubic(sampler2D sampler, vec2 texCoords, float lod)
{
	vec2 texSize = textureSize(sampler, int(lod));
	vec2 invTexSize = 1.0 / texSize;

	texCoords = texCoords * texSize - 0.5;


	vec2 fxy = fract(texCoords);
	texCoords -= fxy;

	vec4 xcubic = cubic(fxy.x);
	vec4 ycubic = cubic(fxy.y);

	vec4 c = texCoords.xxyy + vec2 (-0.5, +1.5).xyxy;

	vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
	vec4 offset = c + vec4 (xcubic.yw, ycubic.yw) / s;

	offset *= invTexSize.xxyy;

	vec4 sample0 = textureLod(sampler, offset.xz, lod);
	vec4 sample1 = textureLod(sampler, offset.yz, lod);
	vec4 sample2 = textureLod(sampler, offset.xw, lod);
	vec4 sample3 = textureLod(sampler, offset.yw, lod);

	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);

	return mix(
		mix(sample3, sample2, sx),
		mix(sample1, sample0, sx),
		sy);
}
#endif

void main()
{
	if (frxu_layer == 1) { // downsample
		// fragColor = textureBicubic(u_input, v_texcoord, max(0, frxu_lod - 1));
		fragColor = frx_sample13(u_input, v_texcoord, BLOOM_DOWNSAMPLE_DIST_VEC / frxu_size, max(0, frxu_lod - 1));
	} else if (frxu_layer == 2) { // upsample
		#ifdef HIGH_QUALITY_BLOOM
		vec4 prior = frxu_lod == 5 ? vec4(0.0) : textureBicubic(u_input, v_texcoord, frxu_lod + 1);
		#else
		vec4 prior = frxu_lod == 5 ? vec4(0.0) : textureLod(u_input, v_texcoord, frxu_lod + 1);
		#endif
		vec4 bloom = frx_sampleTent(u_blend, v_texcoord, BLOOM_UPSAMPLE_DIST_VEC / frxu_size, frxu_lod + 1);
		fragColor = prior + bloom;
	} else {
		vec4 base  = texture(u_input, v_texcoord);
		vec4 bloom = texture(u_blend, v_texcoord);
		bloom /= 6.0;
		bloom *= BLOOM_INTENSITY;

		vec3 color = hdr_inverseTonemap(base.rgb) + bloom.rgb;
		fragColor = vec4(ldr_tonemap(color), 1.0);

		#if TONEMAP_OPERATOR != TMO_DEFAULT
		fragColor = brightness(POST_TMO_BRIGHTNESS, contrast(POST_TMO_CONTRAST, saturation(POST_TMO_SATURATION, fragColor)));
		#endif
	}
}
