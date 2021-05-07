/*******************************************************
 *  lumi:shaders/lib/godrays.glsl                      *
 *******************************************************
 *  Original Work:                                     *
 *  https://github.com/Erkaman/glsl-godrays            *
 *                                                     *
 *  Copyright notice not provided (as of 2021/01/13)   *
 *                                                     *
 *  Please refer to the file `MIT_LICENSE` contained   *
 *  in the same directory as this file for the full    *
 *  license terms of the Original Work.                *
 *                                                     *
 *  The following code is a derivative work of         *
 *  the above Original Work.                           *
 *                                                     *
 *  Copyright (c) 2021 spiralhalo                      *
 *                                                     *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

float godrays(float density, float weight, float decay, float exposure, int numSamples, sampler2D ssoliddepth, sampler2D sclouddepth, vec2 screenSpaceLightPos, vec2 texcoord)
{
    float strength = 0.0;
    vec2 deltaTexcoord = vec2(texcoord - screenSpaceLightPos.xy);
    vec2 currentTexcoord = texcoord.xy ;
    deltaTexcoord *= (1.0 /  float(numSamples)) * density;
    float illuminationDecay = 1.0;
    float samp;
    for (int i=0; i < numSamples; i++) {
        currentTexcoord -= deltaTexcoord;
        #if CLOUD_RENDERING == CLOUD_RENDERING_VANILLA
            samp = step(1.0, texture(ssoliddepth, currentTexcoord).r);
            samp = min(samp, max(0.5, step(1.0, texture(sclouddepth, currentTexcoord).r)));
        #else
            samp = min(texture(ssoliddepth, currentTexcoord).r, texture(sclouddepth, currentTexcoord).r) < 1. ? 0. : 1.;
        #endif
        samp *= illuminationDecay * weight;
        strength += samp;
        illuminationDecay *= decay;
    }
    return strength * exposure;
}
