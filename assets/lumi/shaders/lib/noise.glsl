#include frex:shaders/lib/noise/noise3d.glsl

float l2_noise(vec3 aPos, float renderTime, float scale, float amplitude)
{
	float invScale = 1/scale;
    return (snoise(vec3(aPos.x*invScale, aPos.z*invScale, renderTime)) * 0.5+0.5) * amplitude;
}
