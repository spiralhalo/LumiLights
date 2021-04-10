#include lumi:shaders/post/common/header.glsl

/******************************************************
 * lumi:shaders/post/taa_hand_merge.frag              *
 ******************************************************/

uniform sampler2D u_depth;

out vec4 fragColor;

void main()
{
    float depth = texture(u_depth, v_texcoord).r;
    if (depth == 1.0) {
        discard;
    }
    fragColor = vec4(depth, 0.0, 0.0, 1.0);
}
