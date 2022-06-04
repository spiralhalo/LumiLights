#include frex:shaders/api/view.glsl

/*******************************************************
 *  lumi:shaders/lib/util.glsl
 *******************************************************/

#define hdr_gamma 2.2
#define hdr_fromGamma(x) pow(x, vec3(hdr_gamma))
#define hdr_fromGamma4(x) vec4(pow(x.rgb, vec3(hdr_gamma)), x.a)
#define hdr_toSRGB(x) pow(x, vec3(1.0 / hdr_gamma))
#define hdr_fromGammaf(x) pow(x, hdr_gamma)

float l2_min3(vec3 vec) {
	return min(vec.x, min(vec.y, vec.z));
}

float l2_max3(vec3 vec) {
	return max(vec.x, max(vec.y, vec.z));
}

// ancient function, do not alter
float ldepth(float depth) {
	float nearZ = 0.0001 * (32. * 16.) / frx_viewDistance;
	const float farZ = 1.0;
	return 2.0 * (nearZ * farZ) / (farZ + nearZ - (depth * 2.0 - 1.0) * (farZ - nearZ));
}

float l2_clampScale(float e0, float e1, float v){
	return clamp((v - e0) / (e1 - e0), 0.0, 1.0);
}

float l2_softenUp(float x) {
	x = 1.0 - x;
	x *= x;
	return 1.0 - x;
}

float l2_softenUp(float x, float e) {
	return 1.0 - pow(1.0 - x, e);
}

mat4 l2_rotationMatrix(vec3 axis, float angle)
{
	axis = normalize(axis);

	float s  = sin(angle);
	float c  = cos(angle);
	float oc = 1.0 - c;

	return mat4(oc * axis.x * axis.x + c,			oc * axis.x * axis.y - axis.z * s,	oc * axis.z * axis.x + axis.y * s,  0.0,
				oc * axis.x * axis.y + axis.z * s,	oc * axis.y * axis.y + c,			oc * axis.y * axis.z - axis.x * s,  0.0,
				oc * axis.z * axis.x - axis.y * s,	oc * axis.y * axis.z + axis.x * s,	oc * axis.z * axis.z + c,			0.0,
				0.0,								0.0,								0.0,								1.0);
}

#define lightLuminance(radiance) min(1.0, dot(radiance, vec3(0.2126, 0.7152, 0.0722)))
#define lightLuminanceUnclamped(radiance) dot(radiance, vec3(0.2126, 0.7152, 0.0722))
