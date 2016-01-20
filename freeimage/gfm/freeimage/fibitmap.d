module gfm.freeimage.fibitmap;

import std.string;

import derelict.freeimage.freeimage;

import gfm.freeimage.freeimage;

/// FreeImage bitmap wrapper.
final class FIBitmap
{
    public
    {
        /// Load an image from file.
        /// Throws: FreeImage on error.
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

        /// Loads from existing bitmap handle.
        /// Throws: FreeImage on error.
        this(FreeImage lib, FIBITMAP* bitmap)
        {
            _lib = lib;

            if (bitmap is null)
                throw new FreeImageException("Cannot make FIBitmap from null handle");

            _bitmap = bitmap;
        }

        /// Creates an image from from existing memory data.
        /// Throws: FreeImage on error.
        this(FreeImage lib, ubyte* data, int width, int height, int pitch, uint bpp,
             uint redMask, uint blueMask, uint greenMask, bool topDown = false)
        {
            _lib = lib;
            _bitmap = FreeImage_ConvertFromRawBits(data, width, height, pitch, bpp,
                                                   redMask, greenMask, blueMask, FALSE);

            if (_bitmap is null)
                throw new FreeImageException("Cannot make FIBitmap from raw data");
        }

        /// Releases the FreeImage bitmap resource.
        ~this()
        {
            if (_bitmap !is null)
            {
                debug ensureNotInGC("FIBitmap");
                FreeImage_Unload(_bitmap);
                _bitmap = null;
            }
        }

        /// Saves an image to a file.
        /// Throws: FreeImage on error.
        void save(string filename, int flags = 0)
        {
            const(char)* filenameZ = toStringz(filename);
            FREE_IMAGE_FORMAT fif = FreeImage_GetFIFFromFilename(filenameZ);
            if (fif == FIF_UNKNOWN)
                throw new FreeImageException(format("Coudln't guess format for filename %s", filename));
            FreeImage_Save(fif, _bitmap, filenameZ, flags);
        }

        /// Returns: Width of the image.
        uint width()
        {
            return FreeImage_GetWidth(_bitmap);
        }

        /// Returns: Height of the image.
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

        /// Returns: Red channel bit mask.
        uint redMask()
        {
            return FreeImage_GetRedMask(_bitmap);
        }

        /// Returns: Green channel bit mask.
        uint greenMask()
        {
            return FreeImage_GetGreenMask(_bitmap);
        }

        /// Returns: Blue channel bit mask.
        uint blueMask()
        {
            return FreeImage_GetBlueMask(_bitmap);
        }

        /// Returns: Bits per pixels.
        uint BPP()
        {
            return FreeImage_GetBPP(_bitmap);
        }

        /// Returns: A pointer to pixels data.
        void* data()
        {
            return FreeImage_GetBits(_bitmap);
        }

        /// Returns: Pitch between scanlines in bytes.
        uint pitch()
        {
            return FreeImage_GetPitch(_bitmap);
        }

        /// Returns: A pointer to scanline y.
        void* scanLine(int y)
        {
            return FreeImage_GetScanLine(_bitmap, y);
        }

        /// Converts an image to 4-bits.
        /// Returns: Converted image.
        FIBitmap convertTo4Bits()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo4Bits(_bitmap));
        }

        /// Converts an image to 8-bits.
        /// Returns: Converted image.
        FIBitmap convertTo8Bits()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo8Bits(_bitmap));
        }

        /// Converts an image to greyscale.
        /// Returns: Converted image.
        FIBitmap convertToGreyscale()
        {
            return new FIBitmap(_lib, FreeImage_ConvertToGreyscale(_bitmap));
        }

        /// Converts an image to 16-bits 555.
        /// Returns: Converted image.
        FIBitmap convertTo16Bits555()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo16Bits555(_bitmap));
        }

        /// Converts an image to 16-bits 565.
        /// Returns: Converted image.
        FIBitmap convertTo16Bits565()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo16Bits565(_bitmap));
        }

        /// Converts an image to 24-bits.
        /// Returns: Converted image.
        FIBitmap convertTo24Bits()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo24Bits(_bitmap));
        }

        /// Converts an image to 32-bits.
        /// Throws: FreeImageException on error.
        /// Returns: Converted image.
        FIBitmap convertTo32Bits()
        {
            return new FIBitmap(_lib, FreeImage_ConvertTo32Bits(_bitmap));
        }

        /// Converts an image to another format.
        /// Throws: FreeImageException on error.
        /// Returns: Converted image.
        FIBitmap convertToType(FREE_IMAGE_TYPE dstType, bool scaleLinear = true)
        {
            FIBITMAP* converted = FreeImage_ConvertToType(_bitmap, dstType, scaleLinear);
            if (converted is null)
                throw new FreeImageException("disallowed conversion");
            return new FIBitmap(_lib, converted);
        }

        /// Converts an image to float format.
        /// Returns: Converted image.
        FIBitmap convertToFloat()
        {
            return new FIBitmap(_lib, FreeImage_ConvertToFloat(_bitmap));
        }

        /// Converts an image to RGBF format.
        /// Returns: Converted image.
        FIBitmap convertToRGBF()
        {
            return new FIBitmap(_lib, FreeImage_ConvertToRGBF(_bitmap));
        }

        /// Converts an image to UINT16 format.
        /// Returns: Converted image.
        FIBitmap convertToUINT16()
        {
            return new FIBitmap(_lib, FreeImage_ConvertToUINT16(_bitmap));
        }

        /// Converts an image to RGB16 format.
        /// Returns: Converted image.
        FIBitmap convertToRGB16()
        {
            return new FIBitmap(_lib, FreeImage_ConvertToRGB16(_bitmap));
        }

        /// Clones an image.
        /// Returns: Cloned image.
        FIBitmap clone()
        {
            return new FIBitmap(_lib, FreeImage_Clone(_bitmap));
        }

        /// Applies color quantization.
        FIBitmap colorQuantize(FREE_IMAGE_QUANTIZE quantize)
        {
            return new FIBitmap(_lib, FreeImage_ColorQuantize(_bitmap, quantize));
        }

        /// Applies tone-mapping operator.
        FIBitmap toneMapDrago03(double gamma = 2.2, double exposure = 0.0)
        {
            return new FIBitmap(_lib, FreeImage_TmoDrago03(_bitmap, gamma, exposure));
        }

        /// Rescales the image.
        FIBitmap rescale(int dstWidth, int dstHeight, FREE_IMAGE_FILTER filter)
        {
            return new FIBitmap(_lib, FreeImage_Rescale(_bitmap, dstWidth, dstHeight, filter));
        }

        /// Flips the image vertically.
        /// Throws: FreeImageException on error.
        void horizontalFlip()
        {
            BOOL res = FreeImage_FlipHorizontal(_bitmap);
            if (res == FALSE)
                throw new FreeImageException("cannot flip image horizontally");
        }

        /// Flips the image horizontally.
        /// Throws: FreeImageException on error.
        void verticalFlip()
        {
            BOOL res = FreeImage_FlipVertical(_bitmap);
            if (res == FALSE)
                throw new FreeImageException("cannot flip image horizontally");
        }

        /// Rotates the image.
        /// Returns: Rotated image.
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
