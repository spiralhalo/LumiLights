#include lumi:shaders/post/common/header.glsl

/*******************************************************
 *  lumi:shaders/post/exposure.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_color;

in float v_exposure;

out vec4 fragColor;

void main() {
#ifdef COMPUTE_EXPOSURE
	fragColor = vec4(v_exposure, v_exposure, v_exposure, 1.0);
#else
	discard;
#endif
}
