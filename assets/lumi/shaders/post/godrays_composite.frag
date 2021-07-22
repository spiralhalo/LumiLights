#include lumi:shaders/post/common/header.glsl

#include frex:shaders/api/view.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/godrays.frag                     *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_depth;
uniform sampler2D u_color;
uniform sampler2D u_godrays;

out vec4 fragColor;

void main() {
    // underwater rays are already kind of thin
    float blurAdj = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? 2.0 : 0.0;

    float d = texture(u_depth, v_texcoord).r;
    vec4 a = texture(u_color, v_texcoord);
    vec4 b = textureLod(u_godrays, v_texcoord, (1.0 - ldepth(d)) * (3. - blurAdj));

    fragColor = vec4(a.rgb * (1.0 - b.a) + b.rgb * b.a, a.a);
}
