#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/pipeline/post/one_filter.frag         *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_source;
uniform sampler2D u_depth;

vec2 inv_size = 1.0 / frxu_size;

const int size = 4;
const float depth_threshold = 0.0001;
void main()
{
    float accum = 0.0;
    float origin_depth = ldepth(texture2D(u_depth, v_texcoord).r);
    float target_depth;
    float diff;
    vec2 target_uv;
    int count = 0;
    for (int i = -size; i <= size; i++) {
        for (int j = -size; j <= size; j++) {
            target_uv = v_texcoord + vec2(i, j) * inv_size;
            target_depth = ldepth(texture2D(u_depth, target_uv).r);
            diff = abs(target_depth - origin_depth);
            accum += diff <= depth_threshold ? texture2D(u_source, target_uv).r : 0.0;
            count += diff <= depth_threshold ? 1 : 0;
        }   
    }
    gl_FragData[0] = vec4(accum/float(count), 0.0, 0.0, 1.0);
}
