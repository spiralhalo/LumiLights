#include lumi:shaders/post/common/header.glsl

/*******************************************************
 *  lumi:shaders/post/exposure_merge.frag              *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_exposure;

out vec4 fragColor;

#define SMOOTHING_FRAMES 50.

void main() {
    const float a = 1. - exp(-1. / SMOOTHING_FRAMES);

    float new = textureLod(u_exposure, vec2(0.0), 2).r;
    float history = textureLod(u_exposure, vec2(0.0), 0).r;

    fragColor = vec4(history * (1. - a) + a * new);
}
