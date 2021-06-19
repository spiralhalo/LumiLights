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
    out float atmosv_celestIntensity;
    out vec3 atmosv_hdrCaveFogRadiance;
    out vec3 atmosv_hdrCloudColorRadiance;
    out vec3 atmosv_hdrSkyColorRadiance;
    out float atmosv_hdrOWTwilightFactor;
    out vec3 atmosv_hdrOWTwilightSkyRadiance;
    #endif

    void atmos_generateAtmosphereModel();

#else

    in vec3 atmosv_hdrCelestialRadiance;
    in vec3 atmosv_hdrSkyAmbientRadiance;

    #ifdef POST_SHADER
    in float atmosv_celestIntensity;
    in vec3 atmosv_hdrCaveFogRadiance;
    in vec3 atmosv_hdrCloudColorRadiance;
    in vec3 atmosv_hdrSkyColorRadiance;
    in float atmosv_hdrOWTwilightFactor;
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
float atmos_celestIntensity()
{
    return atmosv_celestIntensity;
}

vec3 atmos_hdrCaveFogRadiance()
{
    return atmosv_hdrCaveFogRadiance;
}

vec3 atmos_hdrSkyColorRadiance(vec3 world_toSky)
{
    //TODO: test non-overworld has_sky_light custom dimension and broaden if fits
    if (!frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) // this is for nether performance increase mostly
        return atmosv_hdrSkyColorRadiance;

    //NB: only works if sun always rise from dead east instead of north/southeast etc.
    float isTwilight = max(0.0, dot(world_toSky, vec3(sign(frx_skyLightVector().x), 0.0, 0.0)));
    isTwilight *= isTwilight * atmosv_hdrOWTwilightFactor;

    return mix(atmosv_hdrSkyColorRadiance, atmosv_hdrOWTwilightSkyRadiance, isTwilight);
}

vec3 atmos_hdrSkyGradientRadiance(vec3 world_toSky)
{
    //TODO: test non-overworld has_sky_light custom dimension and broaden if fits
    if (!frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) // this is for nether performance increase mostly
        return atmosv_hdrSkyColorRadiance;

    //NB: only works if sun always rise from dead east instead of north/southeast etc.
    float isTwilight = max(0.0, dot(world_toSky, vec3(sign(frx_skyLightVector().x), 0.0, 0.0)));
    isTwilight *= isTwilight * atmosv_hdrOWTwilightFactor;

    // horizonBrightening can't be used on reflections yet due to clamping I think
    float skyDotUp = l2_clampScale(.5, -.1, world_toSky.y);
    float brighteningCancel = min(1., atmosv_hdrOWTwilightFactor * .6 + frx_rainGradient() * .6);
    float brightenFactor = pow(skyDotUp, 5.) * (1. - brighteningCancel);
    float darkenFactor = max(world_toSky.y, 0.);
    float horizonBrightening = 1. + 9. * brightenFactor - darkenFactor * .6;

    return mix(atmosv_hdrSkyColorRadiance, atmosv_hdrOWTwilightSkyRadiance, isTwilight) * horizonBrightening;
}

vec3 atmos_hdrCloudColorRadiance(vec3 world_toSky)
{
    //TODO: test non-overworld has_sky_light custom dimension and broaden if fits
    if (!frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) // this is for nether performance increase mostly
        return atmosv_hdrCloudColorRadiance;

    //NB: only works if sun always rise from dead east instead of north/southeast etc.
    float isTwilight = max(0.0, dot(world_toSky, vec3(sign(frx_skyLightVector().x), 0.0, 0.0)));
    isTwilight *= isTwilight * atmosv_hdrOWTwilightFactor;

    return mix(atmosv_hdrCloudColorRadiance, atmosv_hdrOWTwilightSkyRadiance, isTwilight);
}
#endif



#ifdef VERTEX_SHADER

/** DEFINES **/
#define DEF_VANILLA_DAY_SKY_COLOR hdr_gammaAdjust(vec3(0.52, 0.69, 1.0))
#if SKY_MODE == SKY_MODE_LUMI
    #if LUMI_SKY_COLOR == LUMI_SKY_COLOR_BRIGHT_CYAN
    #define DEF_DAY_SKY_COLOR hdr_gammaAdjust(vec3(0.33, 0.7, 1.0))
    #define DEF_DAY_CLOUD_COLOR hdr_gammaAdjust(vec3(0.40, 0.69, 1.0))
    #else
    #define DEF_DAY_SKY_COLOR hdr_gammaAdjust(vec3(0.3, 0.5, 1.0))
    #define DEF_DAY_CLOUD_COLOR DEF_VANILLA_DAY_SKY_COLOR
    #endif
#define DEF_NIGHT_SKY_COLOR hdr_gammaAdjust(vec3(0.1, 0.1, 0.2))
#else
#define DEF_DAY_SKY_COLOR DEF_VANILLA_DAY_SKY_COLOR
#define DEF_DAY_CLOUD_COLOR DEF_VANILLA_DAY_SKY_COLOR
#define DEF_NIGHT_SKY_COLOR hdr_gammaAdjust(vec3(0.01, 0.01, 0.01))
#endif

#if TONE_PROFILE == TONE_PROFILE_HIGH_CONTRAST_OLD
#define DEF_SUNLIGHT_STR 12.0
#define DEF_MOONLIGHT_STR 0.2
#define DEF_SKY_STR 1.0
#elif defined(HIGH_CONTRAST_ENABLED)
#define DEF_SUNLIGHT_STR 24.0
#define DEF_MOONLIGHT_STR 0.01
#define DEF_SKY_STR 2.0
#else
#define DEF_SUNLIGHT_STR 6.0
#define DEF_MOONLIGHT_STR 0.1
#define DEF_SKY_STR 1.0
#endif

#if defined(SHADOW_MAP_PRESENT) && !defined(HIGH_CONTRAST_ENABLED)
#define DEF_SKY_AMBIENT_STR 0.6
#else
#define DEF_SKY_AMBIENT_STR 1.2
#endif
/*************/



const float SKY_LIGHT_RAINING_MULT = 0.3;
const float SKY_LIGHT_THUNDERING_MULT = 0.1;

const float SUNLIGHT_STR = DEF_SUNLIGHT_STR;
const float MOONLIGHT_STR = DEF_MOONLIGHT_STR;
const float SKY_STR = DEF_SKY_STR;
const float SKY_AMBIENT_STR = DEF_SKY_AMBIENT_STR;

const vec3 DAY_SKY_COLOR = DEF_DAY_SKY_COLOR;
const vec3 NIGHT_SKY_COLOR = DEF_NIGHT_SKY_COLOR * DEF_NIGHT_SKY_MULTIPLIER;
const vec3 DAY_CLOUD_COLOR = DEF_DAY_CLOUD_COLOR;

const vec3 NOON_SUNLIGHT_COLOR = hdr_gammaAdjust(vec3(1.0, 1.0, 1.0));
const vec3 SUNRISE_LIGHT_COLOR = hdr_gammaAdjust(vec3(1.0, 0.7, 0.4));

const vec3 NOON_AMBIENT  = hdr_gammaAdjust(vec3(1.0));
const vec3 NIGHT_AMBIENT = hdr_gammaAdjust(vec3(0.3, 0.3, 0.45)) * DEF_NIGHT_SKY_MULTIPLIER;

const vec3 CAVEFOG_C = DEF_DAY_SKY_COLOR;
const vec3 CAVEFOG_DEEPC = SUNRISE_LIGHT_COLOR;
const float CAVEFOG_MAXY = 16.0;
const float CAVEFOG_MINY = 0.0;
const float CAVEFOG_STR = 0.1;


const int SRISC = 0;
const int SNONC = 1;
const int SMONC = 2;
const vec3[3] CELEST_COLOR =  vec3[](SUNRISE_LIGHT_COLOR, NOON_SUNLIGHT_COLOR, vec3(1.0)    );
     float[3] CELEST_STR   = float[](SUNLIGHT_STR       , SUNLIGHT_STR       , MOONLIGHT_STR);
const float[3] TWG_FACTOR  = float[](1.0, 0.0, 0.0); // maps celest color to twilight factor
const int CELEST_LEN = 8;
const int[CELEST_LEN] CELEST_INDICES = int[]  (SMONC, SRISC, SRISC, SNONC, SNONC, SRISC, SRISC, SMONC);
const float[CELEST_LEN] CELEST_TIMES = float[](-0.04, -0.03, -0.01,  0.02,  0.48,  0.51,  0.53,  0.54);

const int DAYC = 0;
const int NGTC = 1;
const int TWGC = 2;
const int CLDC = 3;
#ifdef POST_SHADER
const vec3[4] SKY_COLOR   = vec3[](DAY_SKY_COLOR, NIGHT_SKY_COLOR, SUNRISE_LIGHT_COLOR, DAY_CLOUD_COLOR);
#endif
      vec3[2] SKY_AMBIENT = vec3[](NOON_AMBIENT,  NIGHT_AMBIENT  );
const int SKY_LEN = 4;
const int[SKY_LEN] SKY_INDICES = int[]  ( NGTC, DAYC, DAYC, NGTC);
const int[SKY_LEN] CLOUD_INDICES = int[]( NGTC, CLDC, CLDC, NGTC);
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

    if (horizonTime <= CELEST_TIMES[0]) {
        atmosv_hdrCelestialRadiance = CELEST_COLOR[CELEST_INDICES[0]] * CELEST_STR[CELEST_INDICES[0]];
        #ifdef POST_SHADER
            atmosv_celestIntensity = CELEST_STR[CELEST_INDICES[0]] / SUNLIGHT_STR;
            atmosv_hdrOWTwilightFactor = TWG_FACTOR[CELEST_INDICES[0]];
        #endif
    } else {
        int sunI = 1;
        while (horizonTime > CELEST_TIMES[sunI] && sunI < CELEST_LEN - 1) sunI++;
        float celestTransition = l2_clampScale(CELEST_TIMES[sunI-1], CELEST_TIMES[sunI], horizonTime);
        atmosv_hdrCelestialRadiance = mix(
            CELEST_COLOR[CELEST_INDICES[sunI-1]] * CELEST_STR[CELEST_INDICES[sunI-1]],
            CELEST_COLOR[CELEST_INDICES[sunI]] * CELEST_STR[CELEST_INDICES[sunI]],
            celestTransition);
            
        #ifdef POST_SHADER
            atmosv_celestIntensity = mix(CELEST_STR[CELEST_INDICES[sunI-1]], CELEST_STR[CELEST_INDICES[sunI]], celestTransition) / SUNLIGHT_STR;
            atmosv_hdrOWTwilightFactor = mix(TWG_FACTOR[CELEST_INDICES[sunI-1]], TWG_FACTOR[CELEST_INDICES[sunI]], celestTransition);
        #endif
    }



    if (horizonTime <= SKY_TIMES[0]) {
        atmosv_hdrSkyAmbientRadiance = SKY_AMBIENT[SKY_INDICES[0]] * SKY_AMBIENT_STR * (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? 1.0 : 0.0);
        #ifdef POST_SHADER
        atmosv_hdrSkyColorRadiance   = SKY_COLOR  [SKY_INDICES[0]] * SKY_STR;
        atmosv_hdrCloudColorRadiance = SKY_COLOR[CLOUD_INDICES[0]] * SKY_STR;
        #endif
    } else {
        int skyI = 1;
        while (horizonTime > SKY_TIMES[skyI] && skyI < SKY_LEN - 1) skyI++;
        float skyTransition = l2_clampScale(SKY_TIMES[skyI-1], SKY_TIMES[skyI], horizonTime);

        atmosv_hdrSkyAmbientRadiance    = mix(SKY_AMBIENT[SKY_INDICES[skyI-1]], SKY_AMBIENT[SKY_INDICES[skyI]], skyTransition)
                                              * SKY_AMBIENT_STR * (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? 1.0 : 0.0);
        #ifdef POST_SHADER
        atmosv_hdrSkyColorRadiance      = mix(SKY_COLOR[SKY_INDICES[skyI-1]], SKY_COLOR[SKY_INDICES[skyI]], skyTransition) * SKY_STR;
        atmosv_hdrCloudColorRadiance    = mix(SKY_COLOR[CLOUD_INDICES[skyI-1]], SKY_COLOR[CLOUD_INDICES[skyI]], skyTransition) * SKY_STR;
        #endif
    }



    #ifdef POST_SHADER
    // TODO: separate fog
    bool customOWFog =
        !frx_viewFlag(FRX_CAMERA_IN_FLUID)
        && frx_worldFlag(FRX_WORLD_IS_OVERWORLD)
        && !frx_playerHasEffect(FRX_EFFECT_BLINDNESS);

    if (!customOWFog) {
        // high saturation non-ow fog
        atmosv_hdrSkyColorRadiance = hdr_gammaAdjust(mix(frx_vanillaClearColor() / l2_max3(frx_vanillaClearColor()), frx_vanillaClearColor(), 0.75));
    }

    atmosv_hdrOWTwilightSkyRadiance = customOWFog ? SKY_COLOR[TWGC] : atmosv_hdrSkyColorRadiance;
    atmosv_hdrCaveFogRadiance       = customOWFog
                                      ? mix(CAVEFOG_C, CAVEFOG_DEEPC, l2_clampScale(CAVEFOG_MAXY, CAVEFOG_MINY, frx_cameraPos().y)) * CAVEFOG_STR
                                      : vec3(0.0);
    #endif



    /** RAIN **/
    float rainBrightness = min(mix(1.0, SKY_LIGHT_RAINING_MULT, frx_rainGradient()), mix(1.0, SKY_LIGHT_THUNDERING_MULT, frx_thunderGradient()));

    vec3 grayCelestial  = vec3(frx_luminance(atmosv_hdrCelestialRadiance));
    vec3 graySkyAmbient = vec3(frx_luminance(atmosv_hdrSkyAmbientRadiance));
    #ifdef POST_SHADER
    vec3 graySky        = vec3(frx_luminance(atmosv_hdrSkyColorRadiance));
    #endif

    float toGray = frx_rainGradient() * 0.6 + frx_thunderGradient() * 0.35;

    atmosv_hdrCelestialRadiance     = mix(atmosv_hdrCelestialRadiance, grayCelestial, toGray) * rainBrightness; // only used for cloud shading during rain
    atmosv_hdrSkyAmbientRadiance    = mix(atmosv_hdrSkyAmbientRadiance, graySkyAmbient, toGray) * mix(1., .5, frx_thunderGradient());
    #ifdef POST_SHADER
    atmosv_celestIntensity *= rainBrightness;
    if (customOWFog) {
        atmosv_hdrSkyColorRadiance      = mix(atmosv_hdrSkyColorRadiance, graySky, toGray) * rainBrightness;
        atmosv_hdrOWTwilightSkyRadiance = mix(atmosv_hdrOWTwilightSkyRadiance, graySky, toGray) * rainBrightness;
        atmosv_hdrCloudColorRadiance    = mix(atmosv_hdrCloudColorRadiance, graySky, toGray) * rainBrightness;
    }
    #endif
    /**********/
}
#endif
