#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/common/atmosphere.glsl                *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#ifdef VERTEX_SHADER

    out vec3 atmosv_hdrCelestialRadiance;
    out vec3 atmosv_hdrSkyAmbientRadiance;

    #ifdef POST_SHADER
    out vec3 atmosv_hdrSkyColorRadiance;
    out vec3 atmosv_hdrOWTwilightSkyRadiance;
    #endif

    void atmos_generateAtmosphereModel();

#else

    in vec3 atmosv_hdrCelestialRadiance;
    in vec3 atmosv_hdrSkyAmbientRadiance;

    #ifdef POST_SHADER
    in vec3 atmosv_hdrSkyColorRadiance;
    in vec3 atmosv_hdrOWTwilightSkyRadiance;
    #endif

#endif

vec3 atmos_hdrCelestialRadiance()
{
    return atmosv_hdrCelestialRadiance;
}

vec3 atmos_hdrSkyAmbientRadiance()
{
    return atmosv_hdrSkyAmbientRadiance;
}

#ifdef POST_SHADER
vec3 atmos_hdrSkyColorRadiance(vec3 world_toSky)
{
    //TODO: test non-overworld has_sky_light custom dimension and broaden if fits
    if (!frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) // this is for nether performance increase mostly
        return atmosv_hdrSkyColorRadiance;

    //NB: only works if sun always rise from dead east instead of north/southeast etc.
    float isTwilight = max(0.0, dot(world_toSky, vec3(sign(frx_skyLightVector().x), 0.0, 0.0)));
    isTwilight *= isTwilight;

    return mix(atmosv_hdrSkyColorRadiance, atmosv_hdrOWTwilightSkyRadiance, isTwilight);
}
#endif



#ifdef VERTEX_SHADER

/** DEFINES **/
#if SKY_MODE == SKY_MODE_LUMI
#if LUMI_SKY_COLOR == LUMI_SKY_COLOR_BRIGHT_CYAN
#define DEF_DAY_SKY_COLOR hdr_gammaAdjust(vec3(0.33, 0.7, 1.0))
#else
#define DEF_DAY_SKY_COLOR hdr_gammaAdjust(vec3(0.3, 0.5, 1.0))
#endif
#define DEF_NIGHT_SKY_COLOR hdr_gammaAdjust(vec3(0.1, 0.1, 0.2))
#else
#define DEF_DAY_SKY_COLOR hdr_gammaAdjust(vec3(0.52, 0.69, 1.0))
#define DEF_NIGHT_SKY_COLOR hdr_gammaAdjust(vec3(0.01, 0.01, 0.01))
#endif
#ifdef HIGH_CONTRAST
#define DEF_SUNLIGHT_STR 12.0
#define DEF_MOONLIGHT_STR 0.2
#else
#define DEF_SUNLIGHT_STR 6.0
#define DEF_MOONLIGHT_STR 0.1
#endif
#define DEF_SKY_AMBIENT_STR 1.2
/*************/



const float SKY_LIGHT_RAINING_MULT = 0.3;
const float SKY_LIGHT_THUNDERING_MULT = 0.1;

const float SUNLIGHT_STR = DEF_SUNLIGHT_STR;
const float MOONLIGHT_STR = DEF_MOONLIGHT_STR;
const float SKY_STR = 1.0;
const float SKY_AMBIENT_STR = DEF_SKY_AMBIENT_STR;

const vec3 DAY_SKY_COLOR = DEF_DAY_SKY_COLOR;
const vec3 NIGHT_SKY_COLOR = DEF_NIGHT_SKY_COLOR;

const vec3 NOON_SUNLIGHT_COLOR = vec3(1.0, 1.0, 1.0);
const vec3 SUNRISE_LIGHT_COLOR = vec3(1.0, 0.7, 0.4);

const vec3 NOON_AMBIENT  = hdr_gammaAdjust(vec3(1.0));
const vec3 NIGHT_AMBIENT = hdr_gammaAdjust(vec3(0.3, 0.3, 0.45));



const int SRISC = 0;
const int SNONC = 1;
const int SMONC = 2;
const vec3[3] CELEST_COLOR =  vec3[](SUNRISE_LIGHT_COLOR, NOON_SUNLIGHT_COLOR, vec3(1.0)    );
     float[3] CELEST_STR   = float[](SUNLIGHT_STR       , SUNLIGHT_STR       , MOONLIGHT_STR);
const int CELEST_LEN = 8;
const int[CELEST_LEN] CELEST_INDICES = int[]  (SMONC, SRISC, SRISC, SNONC, SNONC, SRISC, SRISC, SMONC);
const float[CELEST_LEN] CELEST_TIMES = float[](-0.04, -0.03, -0.01,  0.02,  0.48,  0.51,  0.53,  0.54);

const int DAYC = 0;
const int NGTC = 1;
const int TWGC = 2;
#ifdef POST_SHADER
const vec3[3] SKY_COLOR   = vec3[](DAY_SKY_COLOR, NIGHT_SKY_COLOR, SUNRISE_LIGHT_COLOR);
const int[3] TWG_MAPPER   = int[] (TWGC, DAYC, NGTC); // maps celest color to sky color
#endif
      vec3[2] SKY_AMBIENT = vec3[](NOON_AMBIENT,  NIGHT_AMBIENT  );
const int SKY_LEN = 4;
const int[SKY_LEN] SKY_INDICES = int[]  ( NGTC, DAYC, DAYC, NGTC);
const float[SKY_LEN] SKY_TIMES = float[](-0.04, -0.01, 0.51, 0.54);

void atmos_generateAtmosphereModel()
{
    /** TRUE DARKNESS **/
    #ifdef TRUE_DARKNESS_MOONLIGHT
        CELEST_STR[SMONC] = 0.0;
        SKY_AMBIENT[NGTC] = vec3(0.0);
    #endif
    /*******************/


    CELEST_STR[SMONC] *= 0.4 + 0.6 * frx_moonSize();
    SKY_AMBIENT[NGTC] *= 0.4 + 0.6 * frx_moonSize();
    

    float horizonTime = frx_worldTime() < 0.75 ? frx_worldTime():frx_worldTime() - 1.0; // [-0.25, 0.75)


    #ifdef POST_SHADER
        int twgMappedA;
        int twgMappedB;
        float twgTransition;
    #endif

    if (horizonTime <= CELEST_TIMES[0]) {
        atmosv_hdrCelestialRadiance = CELEST_COLOR[CELEST_INDICES[0]] * CELEST_STR[CELEST_INDICES[0]];
        #ifdef POST_SHADER
            twgMappedA = twgMappedB = TWG_MAPPER[CELEST_INDICES[0]];
            twgTransition = 0.;
        #endif
    } else {
        int sunI = 1;
        while (horizonTime > CELEST_TIMES[sunI] && sunI < CELEST_LEN) sunI++;
        float celestTransition = l2_clampScale(CELEST_TIMES[sunI-1], CELEST_TIMES[sunI], horizonTime);
        atmosv_hdrCelestialRadiance = mix(
            CELEST_COLOR[CELEST_INDICES[sunI-1]] * CELEST_STR[CELEST_INDICES[sunI-1]],
            CELEST_COLOR[CELEST_INDICES[sunI]] * CELEST_STR[CELEST_INDICES[sunI]],
            celestTransition);
            
        #ifdef POST_SHADER
            twgMappedA = TWG_MAPPER[CELEST_INDICES[sunI-1]];
            twgMappedB = TWG_MAPPER[CELEST_INDICES[sunI]];
            twgTransition = celestTransition;
        #endif
    }



    if (horizonTime <= SKY_TIMES[0]) {
        atmosv_hdrSkyAmbientRadiance = SKY_AMBIENT[SKY_INDICES[0]] * SKY_AMBIENT_STR * (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? 1.0 : 0.0);
        #ifdef POST_SHADER
        atmosv_hdrSkyColorRadiance   = SKY_COLOR  [SKY_INDICES[0]] * SKY_STR;
        #endif
    } else {
        int skyI = 1;
        while (horizonTime > SKY_TIMES[skyI] && skyI < SKY_LEN) skyI++;
        float skyTransition = l2_clampScale(SKY_TIMES[skyI-1], SKY_TIMES[skyI], horizonTime);

        atmosv_hdrSkyAmbientRadiance    = mix(SKY_AMBIENT[SKY_INDICES[skyI-1]], SKY_AMBIENT[SKY_INDICES[skyI]], skyTransition)
                                              * SKY_AMBIENT_STR * (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? 1.0 : 0.0);
        #ifdef POST_SHADER
        atmosv_hdrSkyColorRadiance      = mix(SKY_COLOR[SKY_INDICES[skyI-1]], SKY_COLOR[SKY_INDICES[skyI]], skyTransition) * SKY_STR;
        #endif
    }



    #ifdef POST_SHADER
    // TODO: separate fog
    bool customOWFog =
        !frx_viewFlag(FRX_CAMERA_IN_FLUID)
        && frx_worldFlag(FRX_WORLD_IS_OVERWORLD)
        && !frx_playerHasEffect(FRX_EFFECT_BLINDNESS);

    atmosv_hdrSkyColorRadiance = customOWFog ? atmosv_hdrSkyColorRadiance : hdr_gammaAdjust(frx_vanillaClearColor());
    atmosv_hdrOWTwilightSkyRadiance = customOWFog
                                    ? mix(SKY_COLOR[twgMappedA], SKY_COLOR[twgMappedB], twgTransition) * SKY_STR
                                    : atmosv_hdrSkyColorRadiance;
    #endif



    /** RAIN **/
    float rainBrightness = min(mix(1.0, SKY_LIGHT_RAINING_MULT, frx_rainGradient()), mix(1.0, SKY_LIGHT_THUNDERING_MULT, frx_thunderGradient()));

    vec3 grayCelestial  = vec3(frx_luminance(atmosv_hdrCelestialRadiance));
    vec3 graySkyAmbient = vec3(frx_luminance(atmosv_hdrSkyAmbientRadiance));
    #ifdef POST_SHADER
    vec3 graySky        = vec3(frx_luminance(atmosv_hdrSkyColorRadiance));
    #endif

    float toGray = frx_rainGradient() * 0.6 + frx_thunderGradient() * 0.35;

    atmosv_hdrCelestialRadiance     = mix(atmosv_hdrCelestialRadiance, grayCelestial, toGray) * rainBrightness; 
    atmosv_hdrSkyAmbientRadiance    = mix(atmosv_hdrSkyAmbientRadiance, graySkyAmbient, toGray)* rainBrightness;
    #ifdef POST_SHADER
    if (customOWFog) {
        atmosv_hdrSkyColorRadiance      = mix(atmosv_hdrSkyColorRadiance, graySky, toGray) * rainBrightness;
        atmosv_hdrOWTwilightSkyRadiance = mix(atmosv_hdrOWTwilightSkyRadiance, graySky, toGray) * rainBrightness;
    }
    #endif
    /**********/
}
#endif
