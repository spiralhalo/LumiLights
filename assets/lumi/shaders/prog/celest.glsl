#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/prog/celest.glsl
 *******************************************************/

#ifdef POST_SHADER

l2_vary vec3 v_celest1;
l2_vary vec3 v_celest2;
l2_vary vec3 v_celest3;

#ifdef VERTEX_SHADER

void celestSetup()
{
	const vec3 o	   = vec3(-1024.0, 0.0,  0.0);
	const vec3 dayAxis = vec3(	  0.0, 0.0, -1.0);

	float size = 250.; // One size fits all; vanilla would be -50 for moon and +50 for sun

	Rect result = Rect(o + vec3(.0, -size, -size), o + vec3(.0, -size,  size), o + vec3(.0,  size, -size));
	
	vec3  zenithAxis  = vec3(-1.0, 0.0, 0.0);
	float zenithAngle = asin(frx_skyLightVector.z);
	float dayAngle	  = frx_skyAngleRadians + PI * 0.5;

	mat4 transformation = l2_rotationMatrix(zenithAxis, zenithAngle);
		transformation *= l2_rotationMatrix(dayAxis, dayAngle);

	rect_applyMatrix(transformation, result, 1.0);

	// jitter celest
	// #ifdef TAA_ENABLED
	// 	vec2 taaJitterValue = taaJitter(v_invSize);
	// 	vec4 celest_clip = frx_projectionMatrix * vec4(v_celest1, 1.0);
	// 	v_celest1.xy += taaJitterValue * celest_clip.w;
	// 	v_celest2.xy += taaJitterValue * celest_clip.w;
	// 	v_celest3.xy += taaJitterValue * celest_clip.w;
	// #endif

	// TODO: wtf
	float flipper = frx_worldIsMoonlit * 2.0 - 1.0;

	// TODO: wtf double facepalm combo
	vec3 correction = flipper * normalize(result.topLeft + result.bottomRight);
	correction = (frx_skyLightVector - correction) * 1024;

	v_celest1 = flipper * result.bottomLeft + correction;
	v_celest2 = flipper * result.bottomRight + correction;
	v_celest3 = flipper * result.topLeft + correction;
}

#endif
#endif
