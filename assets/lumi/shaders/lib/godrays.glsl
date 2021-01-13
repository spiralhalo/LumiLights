/************************************************************************************
 *  lumi:shaders/lib/godrays.glsl
 ************************************************************************************
 *  Original work:
 *  https://github.com/Erkaman/glsl-godrays (MIT License)
 *  
 *  Original work license:
 *  This software is released under the MIT license:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy of
 *  this software and associated documentation files (the "Software"), to deal in
 *  the Software without restriction, including without limitation the rights to
 *  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 *  the Software, and to permit persons to whom the Software is furnished to do so,
 *  subject to the following conditions:
 *  
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *  
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 *  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 *  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 *  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 *  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 *  Copyright notice was not provided in the original work at the time
 *  of writing (January 13, 2021).
 *
 *  The following code is a derivative of the original work as stated above:
 *
 *  Copyright (c) 2021 spiralhalo
 *
 *  The derivative work is further licensed under the GNU Lesser General Public
 *  License version 3 alongside the rest of Lumi Lights source code.
 ************************************************************************************/

vec3 godrays(float density, float weight, float decay, float exposure, int numSamples, sampler2D sdepth1, sampler2D sdepth2, vec2 screenSpaceLightPos, vec2 texcoord)
{
    float strength = 0.0;
    vec2 deltaTexcoord = vec2(texcoord - screenSpaceLightPos.xy);
    vec2 currentTexcoord = texcoord.xy ;
    deltaTexcoord *= (1.0 /  float(numSamples)) * density;
    float illuminationDecay = 1.0;
    float samp;
    for (int i=0; i < numSamples; i++) {
        currentTexcoord -= deltaTexcoord;
        samp = step(1.0, texture2D(sdepth1, currentTexcoord).r);
        samp = min(samp, max(0.5, step(1.0, texture2D(sdepth2, currentTexcoord).r)));
        samp *= illuminationDecay * weight;
        strength += samp;
        illuminationDecay *= decay;
    }
    return vec3(strength * exposure);
}
