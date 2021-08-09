#include lumi:shaders/post/common/header.glsl

#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/exposure.vert
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_color;

#if EXPOSURE_FUNC == EXPOSURE_FUNC_MEDIAN

const int BIN_SIZE = 64;

int bin[BIN_SIZE];

#endif

out float v_exposure;

void main()
{
#ifdef COMPUTE_EXPOSURE
	basicFrameSetup();

	v_exposure = 0.;

	vec2 onePixel = pow(2.0, max(0.0, float(frxu_lod) - 1.0)) / frxu_size;

	// Calculate exposure in one OR two vertexes and precisely one pixel
	if (v_texcoord == vec2(0.0)) {
		gl_Position.xy += onePixel * 0.5;

		const int limit = 50;

#if EXPOSURE_FUNC == EXPOSURE_FUNC_MEDIAN
		for (int i = 0; i < BIN_SIZE; i ++) {
			bin[i] = 0;
		}
#endif

		for (int i = 0; i < limit; i ++) {
			for (int j = 0; j < limit; j ++) {
				vec2 coord = vec2(i, j) / limit;

 				// scale down in center (fovea)
				coord -= 0.5;
				// vec2 scaling = 0.25 + smoothstep(0.0, 0.5, abs(coord)) * 0.75; // more scaling down the closer to center
				coord *= 0.5; //scaling;
				coord += 0.5;

				float luminance = frx_luminance(texture(u_color, coord).rgb);

				// clamp luminance to half
				luminance = clamp(luminance, 0.0, 0.5) * 2.0;

#if EXPOSURE_FUNC == EXPOSURE_FUNC_MEDIAN
				int index = int(floor(luminance * BIN_SIZE));

				bin[index] ++;
#else
				v_exposure += luminance;
#endif
			}
		}

		const int total = (limit * limit);

#if EXPOSURE_FUNC == EXPOSURE_FUNC_MEDIAN
		const int medianIndex = total / 2;

		int count = 0;
		int k;
		for (k = 0; k < BIN_SIZE; k ++) {
			count += bin[k];

			if (count >= medianIndex) {
				break;
			}
		}

		v_exposure = float(k) / float(BIN_SIZE);
#else
		v_exposure /= float(total);
#endif

		// a bunch of magic based on experiment
		// v_exposure = smoothstep(0.0, 0.5, v_exposure); // not required since luminance are clamped to half already
		// v_exposure = pow(v_exposure, 0.5);
	} else {
		gl_Position.xy += 1.0;
		gl_Position.xy *= onePixel;
		gl_Position.xy -= 1.0;
	}
#else
	gl_Position = vec4(0.0);
#endif
}
