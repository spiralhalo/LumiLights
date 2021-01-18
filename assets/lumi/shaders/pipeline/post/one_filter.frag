#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
// #include lumi:shaders/lib/fast_gaussian_blur.glsl

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

// #define MAX_SIZE        5
// #define MAX_KERNEL_SIZE ((MAX_SIZE * 2 + 1) * (MAX_SIZE * 2 + 1))

// int i = 0;
// int j = 0;
// int count = 0;
// float values[MAX_KERNEL_SIZE];
// float val = 0.0;
// float val_accum = 0.0;
// float mean = 0.0;
// float variance = 0;
// float min_variance = -1;

// void search(int i0, int i1, int j0, int j1)
// {
//     val_accum = 0.0;
//     count = 0;
//     for (i = i0; i <= i1; ++i) {
//         for (j = j0; j <= j1; ++j) {
//             val = texture2D(u_source, v_texcoord + vec2(i, j) * inv_size).r;
//             val_accum += val;
//             values[count] = val;
//             count += 1;
//         }
//     }

//     val_accum /= count;
//     for (i = 0; i < count; ++i) {
//         variance += pow(values[i] - val_accum, 2);
//     }
//     variance /= count;
//     if (variance < min_variance || min_variance <= -1) {
//         mean = val_accum;
//         min_variance = variance;
//     }
// }

const int size = 4;
const float depth_threshold = 0.0001;
void main()
{
    // search(-size, 0, -size, 0);
    // search(0, size, 0, size);
    // search(-size, 0, 0, size);
    // search(0, size, -size, 0);
    // gl_FragData[0] = vec4(mean, 0.0, 0.0, 1.0);
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
    // gl_FragData[0] = blur13(u_source, v_texcoord, frxu_size, vec2(1.0, 1.0));
    // gl_FragData[0] = texture2D(u_source, v_texcoord);
}
