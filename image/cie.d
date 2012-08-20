module gfm.image.cie;

import gfm.math.vector;
import gfm.math.smallmatrix;

// This module performs various color computation and conversions.
// See: http://www.brucelindbloom.com
// TODO: tag XYZ values with a ReferenceWhite?

// Standard illuminants (or reference whites) provide a basis for comparing colors recorded under different lighting.
enum ReferenceWhite
{
    A,
    B,
    C,
    D50, // 5003 K ("horizon" light), very common
    D55,
    D65, // 6504 K (noon light)
    D75,
    E,   // equal-energy radiator
    F2,
    F7,
    F11
}

// define various RGB spaces, which all have a reference white, 
// a power curve and primary xyY coordinates
enum RGBSpace
{
    sRGB,
    ADOBE_RGB,
    APPLE_RGB,
    BEST_RGB,
    BETA_RGB,
    BRUCE_RGB,
    CIE_RGB,
    COLORMATCH_RGB,
    DON_RGB_4,
    ECI_RGB_V2,
    EKTA_SPACE_PS5,
    NTSC_RGB,
    PAL_SECAM_RGB,
    PROPHOTO_RGB,
    SMPTE_C_RGB,
    WIDE_GAMUT_RGB
}


// A spectral distribution is actual energy, from 360 to 780 nm, by 5 nm increments
alias Vector!(95u, float) SpectralDistribution;

// Holds reflectance values, can only be converted to a SpectralDistribution
// when lit with a ReferenceWhite.
// from 360 to 780 nm, by 5 nm increments
// Reflectances are parameterized by a ReferenceWhite.
alias Vector!(95u, float) SpectralReflectance;

// Converts spectral color into a XYZ space (parameterized by an illuminant)
vec3f spectralToXYZColor(SpectralReflectance c, ReferenceWhite illuminant) pure nothrow
{
    Vector!(95u, float) c_lit = c * refWhiteToSpectralDistribution(illuminant);
    return vec3f(dot(CIE_OBS_X2, c_lit),
                 dot(CIE_OBS_Y2, c_lit),
                 dot(CIE_OBS_Z2, c_lit));
}


// convert from companded RGB to uncompanded RGB
// input and output in [0..1]
vec3f toLinearRGB(RGBSpace space)(vec3f compandedRGB)
{
    alias compandedRGB c;
    final switch (getRGBSettings(space).companding)
    {
        case Companding.GAMMA:
        {
            float gamma = getRGBSettings(space).gamma;
            return c ^^ gamma;
        }

        case Companding.sRGB:
        {
            static s(float x)
            {
                if (x <= 0.04045f)
                    return x / 12.92f;
                else
                    return ((x + 0.055f) / 1.055f) ^^ 2.4f;
            }
            return vec3f(s(c.x), s(c.y), s(c.z));
        }

        case Companding.L_STAR:
        {
            static l(float x)
            {
                const K = 903.3f;
                if (x <= 0.08f)
                    return (x * 100) / K;
                else
                    return ((x + 0.16f) / 1.16f) ^^ 3;
            }
            return vec3f(l(c.x), l(c.y), l(c.z));
        }
    }    
}

// convert from uncompanded RGB to companded RGB
// input and output in [0..1]
vec3f toCompandedRGB(RGBSpace space)(vec3f compandedRGB)
{
    alias compandedRGB c;
    final switch (getRGBSettings(space).companding)
    {
        case Companding.GAMMA:
        {
            float invGamma = 1 / getRGBSettings(space).gamma;
            return c ^^ invGamma;
        }

        case Companding.sRGB:
        {
            static s(float x)
            {
                if (x <= 0.0031308f)
                    return x * 12.92f;
                else
                    return 1.055f * (x ^^ (1 / 2.4f)) - 0.055f;
            }
            return vec3f(s(c.x), s(c.y), s(c.z));
        }

        case Companding.L_STAR:
        {
            static l(float x)
            {
                const K = 903.3f;
                if (x <= 0.008856f)
                    return x * K / 100.0f;
                else
                    return 1.16f * (x ^^ (1 / 3.0f)) - 0.16f;
            }
            return vec3f(l(c.x), l(c.y), l(c.z));
        }
    }
}

// concert linear RGB to XYZ
vec3f linearRGBToXYZ(RGBSpace space)(vec3f rgb)
{
    // TODO: make M compile-time
    auto M = getRGBSettings(space).makeRGBToXYZMatrix();
    return M * rgb;
}

// concert XYZ to linear RGB
vec3f XYZToLinearRGB(RGBSpace space)(vec3f xyz)
{
    // TODO: make M compile-time
    auto M = getRGBSettings(space).makeXYZToRGBMatrix();
    return M * xyz;
}

// Converts from such a XYZ space back to spectral reflectance
// Both spaces parametereized by the same Illuminant.
SpectralReflectance XYZToSpectralColor(vec3f XYZ) pure nothrow
{
    return CIE_OBS_X2 * XYZ.x + CIE_OBS_Y2 * XYZ.y + CIE_OBS_Z2 * XYZ.z;
}

private
{
    // defining spectrum table of CIE 1931 Standard Colorimetric Observer
    // aka 2° observer
    enum SpectralDistribution CIE_OBS_X2 = SpectralDistribution
    ([
        0.0001299f, 0.0002321f, 0.0004149f, 0.0007416f, 0.001368f,
        0.002236f, 0.004243f, 0.00765f, 0.01431f, 0.02319f,
        0.04351f, 0.07763f, 0.13438f, 0.21477f, 0.2839f,
        0.3285f, 0.34828f, 0.34806f, 0.3362f, 0.3187f,
        0.2908f, 0.2511f, 0.19536f, 0.1421f, 0.09564f,
        0.05795001f, 0.03201f, 0.0147f, 0.0049f, 0.0024f,
        0.0093f, 0.0291f, 0.06327f, 0.1096f, 0.1655f,
        0.2257499f, 0.2904f, 0.3597f, 0.4334499f, 0.5120501f,
        0.5945f, 0.6784f, 0.7621f, 0.8425f, 0.9163f,
        0.9786f, 1.0263f, 1.0567f, 1.0622f, 1.0456f,
        1.0026f, 0.9384f, 0.8544499f, 0.7514f, 0.6424f,
        0.5419f, 0.4479f, 0.3608f, 0.2835f, 0.2187f,
        0.1649f, 0.1212f, 0.0874f, 0.0636f, 0.04677f,
        0.0329f, 0.0227f, 0.01584f, 0.01135916f, 0.008110916f,
        0.005790346f, 0.004106457f, 0.002899327f, 0.00204919f, 0.001439971f,
        0.000999949f, 0.000690079f, 0.000476021f, 0.000332301f, 0.000234826f,
        0.000166151f, 0.000117413f, 8.30753e-05f, 5.87065e-05f, 4.15099e-05f,
        2.93533e-05f, 2.06738e-05f, 1.45598e-05f, 1.0254e-05f, 7.22146e-06f,
        5.08587e-06f, 3.58165e-06f, 2.52253e-06f, 1.77651e-06f, 1.25114e-06f
    ]);

    enum SpectralDistribution CIE_OBS_Y2 = SpectralDistribution
    ([
        0.000003917f, 0.000006965f, 0.00001239f, 0.00002202f, 0.000039f,
        0.000064f, 0.00012f, 0.000217f, 0.000396f, 0.00064f,
        0.00121f, 0.00218f, 0.004f, 0.0073f, 0.0116f,
        0.01684f, 0.023f, 0.0298f, 0.038f, 0.048f,
        0.06f, 0.0739f, 0.09098f, 0.1126f, 0.13902f,
        0.1693f, 0.20802f, 0.2586f, 0.323f, 0.4073f,
        0.503f, 0.6082f, 0.71f, 0.7932f, 0.862f,
        0.9148501f, 0.954f, 0.9803f, 0.9949501f, 1.0f,
        0.995f, 0.9786f, 0.952f, 0.9154f, 0.87f,
        0.8163f, 0.757f, 0.6949f, 0.631f, 0.5668f,
        0.503f, 0.4412f, 0.381f, 0.321f, 0.265f,
        0.217f, 0.175f, 0.1382f, 0.107f, 0.0816f,
        0.061f, 0.04458f, 0.032f, 0.0232f, 0.017f,
        0.01192f, 0.00821f, 0.005723f, 0.004102f, 0.002929f,
        0.002091f, 0.001484f, 0.001047f, 0.00074f, 0.00052f,
        0.0003611f, 0.0002492f, 0.0001719f, 0.00012f, 0.0000848f,
        0.00006f, 0.0000424f, 0.00003f, 0.0000212f, 0.00001499f,
        0.0000106f, 7.4657e-06f, 5.2578e-06f, 3.7029e-06f, 2.6078e-06f,
        1.8366e-06f, 1.2934e-06f, 9.1093e-07f, 6.4153e-07f, 4.5181e-07f
    ]);

    enum SpectralDistribution CIE_OBS_Z2 = SpectralDistribution
    ([
        0.0006061f, 0.001086f, 0.001946f, 0.003486f, 0.006450001f,
        0.01054999f, 0.02005001f, 0.03621f, 0.06785001f, 0.1102f,
        0.2074f, 0.3713f, 0.6456f, 1.0390501f, 1.3856f,
        1.62296f, 1.74706f, 1.7826f, 1.77211f, 1.7441f,
        1.6692f, 1.5281f, 1.28764f, 1.0419f, 0.8129501f,
        0.6162f, 0.46518f, 0.3533f, 0.272f, 0.2123f,
        0.1582f, 0.1117f, 0.07824999f, 0.05725001f, 0.04216f,
        0.02984f, 0.0203f, 0.0134f, 0.008749999f, 0.005749999f,
        0.0039f, 0.002749999f, 0.0021f, 0.0018f, 0.001650001f,
        0.0014f, 0.0011f, 0.001f, 0.0008f, 0.0006f,
        0.00034f, 0.00024f, 0.00019f, 0.0001f, 5e-05f,
        0.00003f, 0.00002f, 0.00001f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f
    ]);


    vec3f refWhiteToXYZ(ReferenceWhite white) pure nothrow
    {
        final switch(white)
        {
            case ReferenceWhite.A:   return vec3f( 1.0985f, 1.0f, 0.35585f);
            case ReferenceWhite.B:   return vec3f(0.99072f, 1.0f, 0.85223f);
            case ReferenceWhite.C:   return vec3f(0.98074f, 1.0f, 1.18232f);
            case ReferenceWhite.D50: return vec3f(0.96422f, 1.0f, 0.82521f);
            case ReferenceWhite.D55: return vec3f(0.95682f, 1.0f, 0.92149f);
            case ReferenceWhite.D65: return vec3f(0.95047f, 1.0f, 1.08883f);
            case ReferenceWhite.D75: return vec3f(0.94972f, 1.0f, 1.22638f);
            case ReferenceWhite.E:   return vec3f(    1.0f, 1.0f,     1.0f);
            case ReferenceWhite.F2:  return vec3f(0.99186f, 1.0f, 0.67393f);
            case ReferenceWhite.F7:  return vec3f(0.95041f, 1.0f, 1.08747f);
            case ReferenceWhite.F11: return vec3f(1.00962f, 1.0f, 0.64350f);
        }
    }

    SpectralDistribution refWhiteToSpectralDistribution(ReferenceWhite illuminant) pure nothrow
    {
        // TODO: actual reference white distributions? especially for F*
        // TODO: precalc
        vec3f XYZ = refWhiteToXYZ(illuminant);
        return CIE_OBS_X2 * XYZ.x + CIE_OBS_Y2 * XYZ.y + CIE_OBS_Z2 * XYZ.z;
    }

    // return a (X, Y, Z) triplet from a (x, y, Y) triplet
    vec3f xyYToXYZColor(vec3f xyY) pure nothrow
    {
        assert(xyY.x >= 0 && xyY.x <= 1
               && xyY.y >= 0 && xyY.y <= 1
               && xyY.z >= 0 && xyY.z <= 1);
        if (xyY.y == 0)
        {
            return vec3f(0.0f);
        }
        else
        {
            vec3f res = void;
            res.x = xyY.x * xyY.z / xyY.y;
            res.y = xyY.z;
            res.z = (1 - xyY.x - xyY.y) * xyY.z / xyY.y;
            return res;
        }
    }
}

private
{
    enum Companding
    {
        GAMMA,
        sRGB,
        L_STAR
    }

    struct RGBSpaceConf
    {
        Companding companding;
        float gamma;
        ReferenceWhite refWhite;
        float xRed, yRed, YRed;
        float xGreen, yGreen, YGreen;
        float xBlue, yBlue, YBlue;

        // return the 3x3 matrix to go from a RGB space to a XYZ space
        // parameterized by the same reference white
        mat3f makeXYZToRGBMatrix() pure const nothrow
        {
            // compute XYZ values of primaries
            vec3f r = xyYToXYZColor(vec3f(xRed, yRed, 1.0f));
            vec3f g = xyYToXYZColor(vec3f(xGreen, yGreen, 1.0f));
            vec3f b = xyYToXYZColor(vec3f(xBlue, yBlue, 1.0f));

            vec3f S = mat3f.fromRows(r, g, b).inverse() * refWhiteToXYZ(refWhite);
            return mat3f.fromRows(r * S, g * S, b * S);
        }

        // return the 3x3 matrix to go from a, XYZ space to an RGB space
        // the XYZ space must be parameterized with the RGB reference white
        mat3f makeRGBToXYZMatrix() pure const nothrow 
        {
            return makeXYZToRGBMatrix().inverse();
        }
    }

    // gives characteristics of known RGB space
    RGBSpaceConf getRGBSettings(RGBSpace s)
    {
        final switch(s)
        {
            case RGBSpace.sRGB: return RGBSpaceConf(Companding.sRGB, float.nan, ReferenceWhite.D65, 0.6400f, 0.3300f, 0.212656f, 0.3000f, 0.6000f, 0.715158f, 0.1500f, 0.0600f, 0.072186f);
            case RGBSpace.ADOBE_RGB: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.D65, 0.6400f, 0.3300f, 0.297361f, 0.2100f, 0.7100f, 0.627355f, 0.1500f, 0.0600f, 0.075285f);
            case RGBSpace.APPLE_RGB: return RGBSpaceConf(Companding.GAMMA, 1.8f, ReferenceWhite.D65, 0.6250f, 0.3400f, 0.244634f, 0.2800f, 0.5950f, 0.672034f, 0.1550f, 0.0700f, 0.083332f);
            case RGBSpace.BEST_RGB: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.D50, 0.7347f, 0.2653f, 0.228457f, 0.2150f, 0.7750f, 0.737352f, 0.1300f, 0.0350f, 0.034191f);
            case RGBSpace.BETA_RGB: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.D50, 0.6888f, 0.3112f, 0.303273f, 0.1986f, 0.7551f, 0.663786f, 0.1265f, 0.0352f, 0.032941f);
            case RGBSpace.BRUCE_RGB: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.D65, 0.6400f, 0.3300f, 0.240995f, 0.2800f, 0.6500f, 0.683554f, 0.1500f, 0.0600f, 0.075452f);
            case RGBSpace.CIE_RGB: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.E, 0.7350f, 0.2650f, 0.176204f, 0.2740f, 0.7170f, 0.812985f, 0.1670f, 0.0090f, 0.010811f);
            case RGBSpace.COLORMATCH_RGB: return RGBSpaceConf(Companding.GAMMA, 1.8f, ReferenceWhite.D50, 0.6300f, 0.3400f, 0.274884f, 0.2950f, 0.6050f, 0.658132f, 0.1500f, 0.0750f, 0.066985f);
            case RGBSpace.DON_RGB_4: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.D50, 0.6960f, 0.3000f, 0.278350f, 0.2150f, 0.7650f, 0.687970f, 0.1300f, 0.0350f, 0.033680f);
            case RGBSpace.ECI_RGB_V2: return RGBSpaceConf(Companding.L_STAR, float.nan, ReferenceWhite.D50, 0.6700f, 0.3300f, 0.320250f, 0.2100f, 0.7100f, 0.602071f, 0.1400f, 0.0800f, 0.077679f);
            case RGBSpace.EKTA_SPACE_PS5: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.D50, 0.6950f, 0.3050f, 0.260629f, 0.2600f, 0.7000f, 0.734946f, 0.1100f, 0.0050f, 0.004425f);
            case RGBSpace.NTSC_RGB: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.C, 0.6700f, 0.3300f, 0.298839f, 0.2100f, 0.7100f, 0.586811f, 0.1400f, 0.0800f, 0.114350f);
            case RGBSpace.PAL_SECAM_RGB: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.D65, 0.6400f, 0.3300f, 0.222021f, 0.2900f, 0.6000f, 0.706645f, 0.1500f, 0.0600f, 0.071334f);
            case RGBSpace.PROPHOTO_RGB: return RGBSpaceConf(Companding.GAMMA, 1.8f, ReferenceWhite.D50, 0.7347f, 0.2653f, 0.288040f, 0.1596f, 0.8404f, 0.711874f, 0.0366f, 0.0001f, 0.000086f);
            case RGBSpace.SMPTE_C_RGB: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.D65, 0.6300f, 0.3400f, 0.212395f, 0.3100f, 0.5950f, 0.701049f, 0.1550f, 0.0700f, 0.086556f);
            case RGBSpace.WIDE_GAMUT_RGB: return RGBSpaceConf(Companding.GAMMA, 2.2f, ReferenceWhite.D50, 0.7350f, 0.2650f, 0.258187f, 0.1150f, 0.8260f, 0.724938f, 0.1570f, 0.0180f, 0.016875f);
        }
    }
}

unittest
{
    vec3f white = vec3f(1.0f);
    
    vec3f XYZ = linearRGBToXYZ!(RGBSpace.sRGB)(toLinearRGB!(RGBSpace.sRGB)(white));
    vec3f rgb = toCompandedRGB!(RGBSpace.sRGB)(XYZToLinearRGB!(RGBSpace.sRGB)(XYZ));

    assert(white.distanceTo(rgb) < 1e-3f);


}
