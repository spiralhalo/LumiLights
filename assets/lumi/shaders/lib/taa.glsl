#include frex:shaders/api/view.glsl

/*******************************************************
 *  lumi:shaders/lib/taa.glsl
 *******************************************************
 *  Original Work (MIT License):
 *  https://github.com/ziacko/Temporal-AA
 *
 *  The following code is a derivative work licensed
 *  under the LGPL-3.0.
 *
 *  Copyright (c) 2019 Ziyad Barakat
 *  Copyright (c) 2021 spiralhalo
 *
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

#define feedbackFactor 0.9
#define minimumFeedbackFactor 0.5
#define maxDepthFalloff 1.0

const vec2 kOffsets3x3[9] =
vec2[](
	vec2(-1, -1), //upper left
	vec2( 0, -1), //up
	vec2( 1, -1), //upper right
	vec2(-1,  0), //left
	vec2( 0,  0), // K
	vec2( 1,  0), //right
	vec2(-1,  1), //lower left
	vec2( 0,  1), //down
	vec2( 1,  1) //lower right
); //k is index 4

// Number of neighbors.
const int neighborCount3x3 = 9;

//we can cut this down to 4
const vec2 kOffsets2x2[5] =
vec2[](
	vec2(-1, 0), //left
	vec2(0, -1), //up
	vec2( 0,  0), // K
	vec2(1, 0), //right
	vec2(0, 1) //down
); //k is index 3

const int neighborCount2x2 = 5;

vec2 GetClosestUV(in sampler2D depths, vec2 texcoord, vec2 deltaRes)
{
	vec2 closestUV = texcoord;
	float closestDepth = 1.0f;
	for(int iter = 0; iter < neighborCount3x3; iter++)
	{
		vec2 newUV = texcoord + (kOffsets3x3[iter] * deltaRes);
		float depth = texture(depths, newUV).x;
		if(depth < closestDepth)
		{
			closestDepth = depth;
			closestUV = newUV;
		}
	}
	return closestUV;
}

// vec2 MinMaxDepths(in float neighborDepths[neighborCount3x3])
// {
//	 float minDepth = neighborDepths[0];
//	 float maxDepth = neighborDepths[0];
//	 for(int iter = 1; iter < neighborCount3x3; iter++)
//	 {
//		 minDepth = min(minDepth, neighborDepths[iter]);
//		 minDepth = max(maxDepth, neighborDepths[iter]);
//	 }
//	 return vec2(minDepth, maxDepth);
// }

vec4 MinColors(in vec4 neighborColors[neighborCount2x2])
{
	vec4 minColor = neighborColors[0];
	for(int iter = 1; iter < neighborCount2x2; iter++)
	{
		minColor = min(minColor, neighborColors[iter]);
	}
	return minColor;
}

vec4 MaxColors(in vec4 neighborColors[neighborCount2x2])
{
	vec4 maxColor = neighborColors[0];
	for(int iter = 1; iter < neighborCount2x2; iter++)
	{
		maxColor = max(maxColor, neighborColors[iter]);
	}
	return maxColor;
}

vec4 MinColors2(in vec4 neighborColors[neighborCount3x3])
{
	vec4 minColor = neighborColors[0];
	for(int iter = 1; iter < neighborCount2x2; iter++)
	{
		minColor = min(minColor, neighborColors[iter]);
	}
	return minColor;
}

vec4 MaxColors2(in vec4 neighborColors[neighborCount3x3])
{
	vec4 maxColor = neighborColors[0];
	for(int iter = 1; iter < neighborCount2x2; iter++)
	{
		maxColor = max(maxColor, neighborColors[iter]);
	}
	return maxColor;
}

// like clamping but advanced
vec4 clip_aabb(vec3 colorMin, vec3 colorMax, vec4 currentColor, vec4 previousColor)
{
	vec3 p_clip = 0.5 * (colorMax + colorMin);
	vec3 e_clip = 0.5 * (colorMax - colorMin);
	vec4 v_clip = previousColor - vec4(p_clip, currentColor.a);
	vec3 v_unit = v_clip.rgb / e_clip;
	vec3 a_unit = abs(v_unit);
	float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

	if (ma_unit > 1.0)
	{
		return vec4(p_clip, currentColor.a) + v_clip / ma_unit;
	}
	else
	{
		return previousColor;// point inside aabb
	}
}

vec4 clip_aabb_rgba(vec4 colorMin, vec4 colorMax, vec4 currentColor, vec4 previousColor)
{
	vec4 p_clip = 0.5 * (colorMax + colorMin);
	vec4 e_clip = 0.5 * (colorMax - colorMin);
	vec4 v_clip = previousColor - p_clip;
	vec4 v_unit = v_clip / e_clip;
	vec4 a_unit = abs(v_unit);
	float ma_unit = max(a_unit.x, max(a_unit.y, max(a_unit.z, a_unit.w)));

	if (ma_unit > 1.0)
	{
		return p_clip + v_clip / ma_unit;
	}
	else
	{
		return previousColor;// point inside aabb
	}
}

vec4 Inside2Resolve(sampler2D currColorTex, sampler2D prevColorTex, vec2 texcoord, vec2 velocity, vec2 deltaRes, float cameraMove)
{
	vec4 current3x3Colors[neighborCount3x3];
	for(int iter = 0; iter < neighborCount3x3; iter++)
	{
		current3x3Colors[iter] = texture(currColorTex, texcoord + (kOffsets3x3[iter] * deltaRes));
	}
	vec4 rounded3x3Min = MinColors2(current3x3Colors);
	vec4 rounded3x3Max = MaxColors2(current3x3Colors);

	vec4 current2x2Colors[neighborCount2x2];
	for(int iter = 0; iter < neighborCount2x2; iter++)
	{
		current2x2Colors[iter] = texture(currColorTex, texcoord + (kOffsets2x2[iter] * deltaRes));
	}
	vec4 min2 = MinColors(current2x2Colors);
	vec4 max2 = MaxColors(current2x2Colors);

	//mix the 3x3 and 2x2 min maxes together -> Rounded ?
	vec4 mixedMin = mix(rounded3x3Min, min2, 0.5);
	vec4 mixedMax = mix(rounded3x3Max, max2, 0.5);

	float adjustedFeedback = cameraMove == 0.0 ? feedbackFactor : minimumFeedbackFactor;
	vec4 clippedHistoryColor = clip_aabb(mixedMin.rgb, mixedMax.rgb, current2x2Colors[2], texture(prevColorTex, texcoord - velocity));
	return mix(current2x2Colors[2], clippedHistoryColor, adjustedFeedback);
}

vec4 TAA(in sampler2D currentColorTex, in sampler2D previousColorTex, in sampler2D currentDepthTex, vec2 texcoord, vec2 velocity, vec2 invRes, float cameraMove)
{
	return Inside2Resolve(currentColorTex, previousColorTex, texcoord, velocity, invRes, cameraMove);//vec4(1, 0, 0, 1);
}
