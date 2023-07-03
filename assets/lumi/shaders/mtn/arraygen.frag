#include lumi:shaders/pass/header.glsl

uniform sampler2D u_tex_0;
uniform sampler2D u_tex_1;
uniform sampler2D u_tex_2;
uniform sampler2D u_tex_3;
// uniform sampler2D u_tex_4;
// uniform sampler2D u_tex_5;
// uniform sampler2D u_tex_6;
// uniform sampler2D u_tex_7;

out vec4[4] outColor;

void main() {
	outColor[0] = texture(u_tex_0, v_texcoord);
	outColor[1] = texture(u_tex_1, v_texcoord);
	outColor[2] = texture(u_tex_2, v_texcoord);
	outColor[3] = texture(u_tex_3, v_texcoord);
}
