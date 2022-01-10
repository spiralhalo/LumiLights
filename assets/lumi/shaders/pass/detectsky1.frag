#include lumi:shaders/pass/header.glsl

#include frex:shaders/lib/sample.glsl

uniform sampler2D u_input;

out vec4 fragColor;

/*******************************************************
 *  lumi:shaders/pass/detectsky1.frag
 *******************************************************/

void main() {
	if (frxu_layer == 1) {
		// sky detect utility downscaler
		fragColor.r = max(textureLod(u_input, v_texcoord, frxu_lod - 1.0).r,
					  max(textureLod(u_input, v_texcoord + vec2(1.0, 0.0) * v_invSize, frxu_lod - 1.0).r,
					  max(textureLod(u_input, v_texcoord + vec2(-1.0,0.0) * v_invSize, frxu_lod - 1.0).r,
					  max(textureLod(u_input, v_texcoord + vec2(0.0, 1.0) * v_invSize, frxu_lod - 1.0).r,
						  textureLod(u_input, v_texcoord + vec2(0.0,-1.0) * v_invSize, frxu_lod - 1.0).r))));
	} else {
		// sky detect utility finisher
		float sky = frx_sample13(u_input, v_texcoord, v_invSize * 16., 4).r;
		fragColor = vec4(sky);
	}
}
