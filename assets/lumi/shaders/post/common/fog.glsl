#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/post/common/fog.glsl                  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

/* DEVNOTE: on high skyscrapers, high fog look good
 * on low forests however, the high fog looks atrocious.
 * the ideal solution would be a fog that is "highest block-conscious"
 * but how is that possible? Make sky bloom cancel out the fog, perhaps?
 *
 * There is also the idea of making the fog depend on where
 * you look vertically, but that would be NAUSEATINGLY BAD.
 */

#define SEA_LEVEL 62.0

// #define FOG_NOISE_SCALE 0.125
// #define FOG_NOISE_SPEED 0.25
// #define FOG_NOISE_HEIGHT 4.0

const float FOG_TOP = SEA_LEVEL + 64.0;
const float FOG_TOP_THICK = SEA_LEVEL + 128.0;
const float FOG_FAR = FOG_FAR_CHUNKS * 16.0;
const float FOG_DENSITY = FOG_DENSITY_RELATIVE / 20.0;
const float UNDERWATER_FOG_FAR = UNDERWATER_FOG_FAR_CHUNKS * 16.0;
const float UNDERWATER_FOG_DENSITY = UNDERWATER_FOG_DENSITY_RELATIVE / 20.0;
