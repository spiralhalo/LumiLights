#include frex:shaders/api/fragment.glsl

void frx_materialFragment() {
#ifndef SHADOW_MAP_PRESENT
	frx_fragEnableDiffuse = true;
#endif
}
