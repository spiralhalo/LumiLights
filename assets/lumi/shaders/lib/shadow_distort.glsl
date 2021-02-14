/*******************************************************
*  lumi:shaders/lib/shadow_distort.glsl               *
*******************************************************
*  Copyright (c) 2020-2021 spiralhalo                 *
*  Released WITHOUT WARRANTY under the terms of the   *
*  GNU Lesser General Public License version 3 as     *
*  published by the Free Software Foundation, Inc.    *
*******************************************************/

vec4 distortedShadowPos(vec4 shadowVertex, int cascade)
{
    vec4 shadow_ndc = frx_shadowViewProjectionMatrix(0) * shadowVertex;
    vec4 center = frx_shadowViewProjectionMatrix(0) * vec4(0.0, 0.0, 0.0, 1.0);
    vec2 translator = vec2(0.0, 0.0) - center.xy;
    shadow_ndc.xy += translator;
    float distortion_rate = 0.01 + length(shadow_ndc.xy) * 0.99;
    shadow_ndc.xy /= distortion_rate;
    shadow_ndc.xy -= translator;
    return shadow_ndc;
}
