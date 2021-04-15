#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/util.glsl

/******************************************************
 *    lumi:shaders/post/outline.frag                  *
 ******************************************************/

uniform sampler2D u_color;
uniform sampler2D u_depth;

in vec2 v_invSize;
out vec4 fragColor;

void main()
{
    float d1 = ldepth(texture(u_depth, v_texcoord).x);
    float d2 = /*(n1!=n2)?(d1+1.0):*/ldepth(texture(u_depth, v_texcoord + v_invSize * vec2( 1.,  1.)).x);
    float d3 = /*(n1!=n3)?(d1+1.0):*/ldepth(texture(u_depth, v_texcoord + v_invSize * vec2( 1., -1.)).x);
    float d4 = /*(n1!=n4)?(d1+1.0):*/ldepth(texture(u_depth, v_texcoord + v_invSize * vec2(-1.,  1.)).x);
    float d5 = /*(n1!=n5)?(d1+1.0):*/ldepth(texture(u_depth, v_texcoord + v_invSize * vec2(-1., -1.)).x);
    float threshold = mix(.000001, .3, d1);
    float lineness = l2_clampScale(threshold, threshold * .5, max(max(d1 - d2, d1 - d3), max(d1 - d4, d1 - d5)));
    lineness += (1.0 - lineness) * d1 * 0.5;
    fragColor = texture(u_color, v_texcoord) * lineness;
}
