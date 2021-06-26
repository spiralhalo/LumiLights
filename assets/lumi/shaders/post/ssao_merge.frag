#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/lib/taa.glsl
#include lumi:shaders/lib/taa_velocity.glsl

/*******************************************************
 *  lumi:shaders/post/ssao_merge.frag                  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_input;
uniform sampler2D u_depth;
uniform sampler2D u_history;

frag_in vec2 v_invSize;

#ifndef USING_OLD_OPENGL
out vec4[1] fragColor;
#endif

void main()
{
#ifdef SSAO_ENABLED
    vec2 deltaRes = v_invSize;
    vec2 currentUv = v_texcoord;
    vec2 velocity = fastVelocity(u_depth, v_texcoord);

    vec4 min2 = vec4(1.0);
    vec4 max2 = vec4(0.0);
    for(int iter = 0; iter < neighborCount2x2; iter++)
    {
        vec4 currentIter = texture(u_input, currentUv + (kOffsets2x2[iter] * deltaRes * 3.0));
        min2 = min(min2, currentIter);
        max2 = max(max2, currentIter);
    }

    vec4 current = texture(u_input, currentUv);
    vec4 history = texture(u_history, currentUv - velocity);

    history = clip_aabb_rgba(min2, max2, current, history);

    fragColor[0] = mix(current, history, 0.9);
#else
    fragColor[0] = vec4(0.0, 0.0, 0.0, 1.0);
#endif
}
