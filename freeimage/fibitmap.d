module gfm.freeimage.fibitmap;

import std.string;
import derelict.freeimage.freeimage;
import gfm.freeimage.exception;
import gfm.freeimage.freeimage;

final class FIBitmap
{
    public
    {
        // load an image from file
        this(FreeImage lib, string filename, int flags = 0)
        {
            _lib = lib;
            _bitmap = null;
            const(char)* filenameZ = toStringz(filename);

            FREE_IMAGE_FORMAT fif = FIF_UNKNOWN;

            fif = FreeImage_GetFileType(filenameZ, 0);
            if(fif == FIF_UNKNOWN)
            {
                fif = FreeImage_GetFIFFromFilename(filenameZ);
            }

            if((fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif))
            {
                _bitmap = FreeImage_Load(fif, filenameZ, flags);
            }
            if (_bitmap is null)
                throw new FreeImageException(format("Coudln't load image %s", filename));
        }

        // load from existing bitmap handle
        this(FreeImage lib, FIBITMAP* bitmap)
        {
            _lib = lib;

            if (bitmap is null)
                throw new FreeImageException("Cannot make FIBitmap from null handle");

            _bitmap = bitmap;
        }

        this(FreeImage lib, ubyte* data, int width, int height, int pitch, uint bpp,
             uint redMask, uint blueMask, uint greenMask, bool topDown = false)
        {
            _lib = lib;
            _bitmap = FreeImage_ConvertFromRawBits(data, width, height, pitch, bpp,
                                                   redMask, greenMask, blueMask);
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_bitmap !is null)
            {
                FreeImage_Unload(_bitmap);
                _bitmap = null;
            }
        }

        // save image
        void save(string filename, int flags = 0)
        {
            const(char)* filenameZ = toStringz(filename);
            FREE_IMAGE_FORMAT fif = FreeImage_GetFIFFromFilename(filenameZ);
            if (fif == FIF_UNKNOWN)
                throw new FreeImageException(format("Coudln't guess format for filename %s", filename));
            FreeImage_Save(fif, _bitmap, filenameZ, flags);
        }

        uint width()
        {
            return FreeImage_GetWidth(_bitmap);
        }

        uint height()
        {
            return FreeImage_GetHeight(_bitmap);
        }

        FREE_IMAGE_TYPE getImageType()
        {
            return FreeImage_GetImageType(_bitmap);
        }



        uint dotsPerMeterX()
        {
            return FreeImage_GetDotsPerMeterX(_bitmap);
        }

        uint dotsPerMeterY()
        {
            return FreeImage_GetDotsPerMeterY(_bitmap);
        }

        FREE_IMAGE_COLOR_TYPE colorType()
        {
            return FreeImage_GetColorType(_bitmap);
        }

        // pixels access

        uint redMask()
        {
            return FreeImage_GetRedMask(_bitmap);
        }

        uint greenMask()
        {
            return FreeImage_GetGreenMask(_bitmap);
        }

        uint blueMask()
        {
            return FreeImage_GetBlueMask(_bitmap);
        }

        uint BPP()
        {
            return FreeImage_GetBPP(_bitmap);
        }

        uint pitch()
        {
            return FreeImage_GetPitch(_bitmap);
        }

        void* data()
        {
            return FreeImage_GetBits(_bitmap);
        }

        void* scanLine(int y)
        {
            return FreeImage_GetScanLine(_bitmap, y);
        }

        // tone-mapping

        FIBitmap convertTo4Bits()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo4Bits(_bitmap));
        }

        FIBitmap convertTo8Bits()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo8Bits(_bitmap));
        }

        FIBitmap convertToGreyscale()
        {
            return new FIBitmap(_lib, FreeImage_ConvertToGreyscale(_bitmap));
        }

        FIBitmap convertTo16Bits555()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo16Bits555(_bitmap));
        }

        FIBitmap convertTo16Bits565()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo16Bits565(_bitmap));
        }

        FIBitmap convertTo24Bits()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo24Bits(_bitmap));
        }

        FIBitmap convertTo32Bits()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo32Bits(_bitmap));
        }

        FIBitmap convertToType(FREE_IMAGE_TYPE dstType, bool scaleLinear = true)
        {
            FIBITMAP* converted = FreeImage_ConvertToType(_bitmap, dstType, scaleLinear);
            if (converted is null)
                throw new FreeImageException("disallowed conversion");
            return new FIBitmap(_lib, converted);
        }

        FIBitmap convertToFloat()
        {
            return new FIBitmap(_lib, FreeImage_ConvertToFloat(_bitmap));
        }

        FIBitmap convertToRGBF()
        {
            return new FIBitmap(_lib, FreeImage_ConvertToRGBF(_bitmap));
        }

        FIBitmap convertToUINT16()
        {
            return new FIBitmap(_lib, FreeImage_ConvertToUINT16(_bitmap));
        }

        FIBitmap convertToRGB16()
        {
            return new FIBitmap(_lib, FreeImage_ConvertToRGB16(_bitmap));
        }

        // cloning
        FIBitmap clone()
        {
            return new FIBitmap(_lib, FreeImage_Clone(_bitmap));
        }

        // color quantization

        FIBitmap colorQuantize(FREE_IMAGE_QUANTIZE quantize)
        {
            return new FIBitmap(_lib, FreeImage_ColorQuantize(_bitmap, quantize));
        }

        // tone-mapping

        FIBitmap toneMapDrago03(double gamma = 2.2, double exposure = 0.0)
        {
            return new FIBitmap(_lib, FreeImage_TmoDrago03(_bitmap, gamma, exposure));
        }

        // transformation

        FIBitmap rescale(int dstWidth, int dstHeight, FREE_IMAGE_FILTER filter)
        {
            return new FIBitmap(_lib, FreeImage_Rescale(_bitmap, dstWidth, dstHeight, filter));
        }

        void horizontalFlip()
        {
            BOOL res = FreeImage_FlipHorizontal(_bitmap);
            if (res == FALSE)
                throw new FreeImageException("cannot flip image horizontally");
        }

        void verticalFlip()
        {
            BOOL res = FreeImage_FlipVertical(_bitmap);
            if (res == FALSE)
                throw new FreeImageException("cannot flip image horizontally");
        }

        FIBitmap rotate(double angle, void* bkColor = null)
        {
            return new FIBitmap(_lib, FreeImage_Rotate(_bitmap, angle, bkColor));
        }
    }

    private
    {
        FreeImage _lib;
        FIBITMAP* _bitmap;
    }
}
