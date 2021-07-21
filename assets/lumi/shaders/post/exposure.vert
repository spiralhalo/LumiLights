#include lumi:shaders/post/common/header.glsl

#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/exposure.vert                    *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_color;

out float v_exposure;

void main()
{
    basicFrameSetup();

    v_exposure = 0.;

    int x = 0;
    for (int i = 0; i < 100; i ++) {
        for (int j = 0; j < 100; j ++) {
            x ++;
            vec2 coord = vec2(i, j) / 100.;

            // scale down in center (fovea)
            // coord -= 0.5;

            // vec2 scaling = 0.25 + smoothstep(0.0, 0.5, abs(coord)) * 0.75; // more scaling down the closer to center

            // coord *= scaling;
            // coord += 0.5;

            v_exposure += frx_luminance(texture(u_color, coord).rgb);
        }
    }

    v_exposure /= float(x);

    float brightnessPadding = frx_viewBrightness() * 0.1;

    // a bunch of magic based on experiment
    v_exposure = l2_clampScale(0.0, 0.4 + brightnessPadding, v_exposure);
    v_exposure = pow(v_exposure, 1. / 2.2);
}
