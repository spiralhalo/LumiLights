#include lumi:shaders/post/common/header.glsl

/*******************************************************
 *  lumi:shaders/post/exposure_copy.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_exposure;

out vec4 fragColor;

void main() {
	fragColor = textureLod(u_exposure, vec2(0.0), 1);
}
