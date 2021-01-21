#include lumi:reflection_config

/*******************************************************
 *  lumi:shaders/context/post/reflection.glsl          *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#if REFLECTION_PROFILE == REFLECTION_PROFILE_EXTREME
    const float HITBOX = 0.0375;
    const int MAXSTEPS = 109;
    const int PERIOD = 18;
    const int REFINE = 16;
#endif

#if REFLECTION_PROFILE == REFLECTION_PROFILE_HIGH
    const float HITBOX = 0.125;
    const int MAXSTEPS = 50;
    const int PERIOD = 9;
    const int REFINE = 16;
#endif

#if REFLECTION_PROFILE == REFLECTION_PROFILE_MEDIUM
    const float HITBOX = 0.125;
    const int MAXSTEPS = 36;
    const int PERIOD = 5;
    const int REFINE = 8;
#endif

#if REFLECTION_PROFILE == REFLECTION_PROFILE_LOW
    const float HITBOX = 0.25;
    const int MAXSTEPS = 19;
    const int PERIOD = 3;
    const int REFINE = 8;
#endif

const float REFLECTION_MINIMUM_ROUGHNESS = REFLECTION_MINIMUM_ROUGHNESS_RELATIVE / 10.0;
