#include lumi:shaders/common/contrast.glsl
#include lumi:shaders/lib/tmo.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/func/tonemap.glsl                     *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_exposure;

float exposureCompensation() {
    return texture(u_exposure, vec2(0.5)).r;
}

#ifdef POST_SHADER

vec3 ldr_tonemap3noGamma(vec3 a)
{
    vec3 c = a.rgb;
    float exposure = 1.0;

#ifdef HIGH_CONTRAST_ENABLED
    float eyeBrightness = exposureCompensation();
    exposure = getExposure(eyeBrightness);
#endif

    c = acesNarkowicz(c * exposure);

    // In the past ACES requires clamping for some reason
    c = clamp(c, 0.0, 1.0);
    return c;
}

vec3 ldr_tonemap3(vec3 a)
{
    vec3 c = ldr_tonemap3noGamma(a);
    float capBrightness = min(1.5, frx_viewBrightness());
    float viewGamma = hdr_gamma + capBrightness;

    c = pow(c, vec3(1.0 / viewGamma));
    return c;
}

vec4 ldr_tonemap(vec4 a)
{
    vec3 c = ldr_tonemap3(a.rgb);

    return vec4(c, a.a);
}

#endif
