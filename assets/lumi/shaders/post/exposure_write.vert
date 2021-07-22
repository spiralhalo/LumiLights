#include lumi:shaders/post/common/header.glsl

/*******************************************************
 *  lumi:shaders/post/exposure_write.vert              *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

void main()
{
    basicFrameSetup();

    vec2 onePixel = pow(2.0, max(0.0, float(frxu_lod) - 1.0)) / frxu_size;

    if (v_texcoord == vec2(0.0)) {
        gl_Position.xy += onePixel * 0.5;
    } else {
        gl_Position.xy += 1.0;
        gl_Position.xy *= onePixel;
        gl_Position.xy -= 1.0;
    }
}
