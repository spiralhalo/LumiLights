/*******************************************************
 *  lumi:shaders/lib/godrays.glsl
 *******************************************************
 *  Original Work:
 *  https://github.com/Erkaman/glsl-godrays
 *
 *  Copyright notice not provided (as of 2021/01/13)
 *
 *  Please refer to the file `MIT_LICENSE` contained
 *  in the same directory as this file for the full
 *  license terms of the Original Work.
 *
 *  The following code is a derivative work of
 *  the above Original Work.
 *
 *  Copyright (c) 2021 spiralhalo
 *
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

float godrays(int numSamples, sampler2D ssoliddepth, float tileJitter, vec2 screenSpaceLightPos, vec2 texcoord, vec2 texSize)
{
	float weight = (1.0 /  float(numSamples));
	vec2 deltaTexcoord = (texcoord - screenSpaceLightPos) * weight;
	vec2 currentTexcoord = texcoord.xy + deltaTexcoord * (2.0 * tileJitter - 1.0);

	float strength = 0.0;
	float samp;

	for (int i=0; i < numSamples; i++) {
		currentTexcoord -= deltaTexcoord;
		samp = texture(ssoliddepth, currentTexcoord).r == 1.0 ? 1.0 : 0.0;
		strength += samp;
	}

	return strength * weight;
}
