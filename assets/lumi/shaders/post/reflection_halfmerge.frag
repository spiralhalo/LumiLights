#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/lib/taa.glsl

/******************************************************
  lumi:shaders/post/reflection_halfmerge.frag
******************************************************/
uniform sampler2D u_input;

in vec2 v_invSize;

out vec4 fragColor;

void main()
{
#ifdef HALF_REFLECTION_RESOLUTION
    vec2 deltaRes = v_invSize * 0.5;
    vec2 currentUv = v_texcoord * 0.5 + vec2(.5, .0);

    vec4 current2x2Colors[neighborCount2x2];
    for(int iter = 0; iter < neighborCount2x2; iter++)
    {
        current2x2Colors[iter] = texture(u_input, currentUv + (kOffsets2x2[iter] * deltaRes));
    }
    vec4 min2 = MinColors(current2x2Colors);
    vec4 max2 = MaxColors(current2x2Colors);

    vec4 current = texture(u_input, currentUv);
    vec4 history = texture(u_input, v_texcoord * 0.5 + 0.5);
    
    history = clip_aabb(min2.rgb, max2.rgb, current, history);

    fragColor = mix(current, history, 0.9);
#else
    discard;
#endif
}
