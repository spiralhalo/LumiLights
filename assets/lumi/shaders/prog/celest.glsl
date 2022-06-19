#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/prog/celest.glsl
 *******************************************************/

#ifdef POST_SHADER

l2_vary vec3 v_celestVec;
l2_vary vec3 v_celest1;
l2_vary vec3 v_celest2;
l2_vary vec3 v_celest3;

#ifdef VERTEX_SHADER

void celestSetup()
{
	const vec3 o	   = vec3(-1024., 0.,  0.);
	const vec3 dayAxis = vec3(	0., 0., -1.);

	float size = 250.; // One size fits all; vanilla would be -50 for moon and +50 for sun

	Rect result = Rect(o + vec3(.0, -size, -size), o + vec3(.0, -size,  size), o + vec3(.0,  size, -size));
	
	vec3  zenithAxis  = cross(frx_skyLightVector, vec3( 0.,  0., -1.));
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

	// TODO: change the entire setup routine so this becomes unnecessary
	v_celestVec = (frx_worldIsMoonlit * 2.0 - 1.0) * normalize(result.topLeft + result.bottomRight);
	v_celest1 = result.bottomLeft;
	v_celest2 = result.bottomRight;
	v_celest3 = result.topLeft;
}

#endif
#endif
