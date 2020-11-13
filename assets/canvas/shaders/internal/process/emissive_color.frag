#include canvas:shaders/internal/process/header.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/sample.glsl
#include frex:shaders/lib/math.glsl

/******************************************************
  canvas:shaders/internal/process/emissive_color.frag
******************************************************/
uniform sampler2D _cvu_base;
uniform sampler2D _cvu_emissive;
uniform ivec2 _cvu_size;

varying vec2 _cvv_texcoord;

void main() {
	vec4 e = texture2D(_cvu_emissive, _cvv_texcoord);

	bool sky = e.g == 0.0;
	float bloom = sky ? 0.25 : e.r;

	vec4 c = frx_fromGamma(texture2D(_cvu_base, _cvv_texcoord));
	
	gl_FragData[0] = vec4(c.rgb * bloom, e.r);
}
