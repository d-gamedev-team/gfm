module gfm.sdl2.sdlttf;

import std.string;

import derelict.sdl2.sdl,
       derelict.sdl2.ttf,
       derelict.util.exception;

import gfm.core.log,
       gfm.core.text,
       gfm.math.vector,
       gfm.sdl2.sdl,
       gfm.sdl2.surface;

/// SDL_ttf library wrapper.
final class SDLTTF
{
    public
    {
        /// Loads the SDL_ttf library.
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2 sdl2)
        {
            _sdl2 = sdl2; // force loading of SDL first
            _log = sdl2._log;
            _SDLTTFInitialized = false;

            try
            {
                DerelictSDL2ttf.load();
            }
            catch(DerelictException e)
            {
                throw new SDL2Exception(e.msg);
            }

            int res = TTF_Init();
            if (res != 0)
                throwSDL2TTFException("TTF_Init");

             _log.infof("SDL_ttf: initialized.");
            _SDLTTFInitialized = true;
        }

        /// Releases the SDL_ttf library.
        void close()
        {
            if (_SDLTTFInitialized)
            {
                _SDLTTFInitialized = false;
                TTF_Quit();
            }

            DerelictSDL2ttf.unload();
        }

        ~this()
        {
            close();
        }   
    }

    private
    {
        Log _log;
        SDL2 _sdl2;
        bool _SDLTTFInitialized;

        void throwSDL2TTFException(string callThatFailed)
        {
            string message = format("%s failed: %s", callThatFailed, getErrorString());
            throw new SDL2Exception(message);
        }

        string getErrorString()
        {
            return sanitizeUTF8(TTF_GetError(), _log, "SDL_TTF error string");
        }
    }
}

/// SDL_ttf loaded font wrapper.
final class SDLFont
{
    public
    {
        /// Loads a font from a file.
        /// Params:
        ///     ptSize = font size in 72 dpi ("This basically translates to pixel height" says the doc).
        /// Throws: $(D SDL2Exception) on error.
        this(SDLTTF sdlttf, string filename, int ptSize)
        {
            _sdlttf = sdlttf;
            _font = TTF_OpenFont(toStringz(filename), ptSize);
            if (_font is null)
                _sdlttf.throwSDL2TTFException("TTF_OpenFont");
        }

        ~this()
        {
            close();
        }

        /// Releases the SDL resource.
        void close()
        {
            if (_font !is null)
            {
                TTF_CloseFont(_font);
                _font = null;
            }
        }

        /// Returns: Font style.
        int style()
        {
            return TTF_GetFontStyle(_font);
        }

        /// Set font style.
        int setStyle(int newStyle)
        {
            if (newStyle != TTF_GetFontStyle(_font))
                TTF_SetFontStyle(_font, newStyle);
            return newStyle;
        }

        /// Returns: Font hinting.
        int hinting()
        {
            return TTF_GetFontHinting(_font);
        }

        /// Set font hinting.
        int setHinting(int newHinting)
        {
            if (newHinting != TTF_GetFontHinting(_font))
                TTF_SetFontHinting(_font, newHinting);
            return newHinting;
        }

        /// Returns: Font outline.
        int outline()
        {
            return TTF_GetFontOutline(_font);
        }

        /// Set font outline.
        int setOutline(int newOutline)
        {
            if (newOutline != TTF_GetFontOutline(_font))
                TTF_SetFontOutline(_font, newOutline);
            return newOutline;
        }

        /// Returns: true if kerning is enabled.
        bool getKerning()
        {
            return TTF_GetFontKerning(_font) != 0;
        }

        /// Enables/Disables font kerning.
        bool setKerning(bool enabled)
        {
            TTF_SetFontKerning(_font, enabled ? 1 : 0);
            return enabled;
        }

        /// Returns: Maximum height of a glyph in pixels.
        int height()
        {
            return TTF_FontAscent(_font);
        }

        /// Returns: Height above baseline in pixels.
        int ascent()
        {
            return TTF_FontAscent(_font);
        }

        /// Returns: Height below baseline.
        int descent()
        {
            return TTF_FontDescent(_font);
        }

        /// Returns: Line skip, the recommended pixel interval between two lines.
        int lineSkip()
        {
            return TTF_FontLineSkip(_font);
        }

        /// Returns: Size of text in pixels if rendered with this font.
        vec2i measureText(string text)
        {
            int w, h;
            TTF_SizeUTF8(_font, toStringz(text), &w, &h);
            return vec2i(w, h);
        }

        /// Create a 32-bit ARGB surface and render the given text at high quality, 
        /// using alpha blending to dither the font with the given color.
        /// Throws: $(D SDL2Exception) on error.
        SDL2Surface renderTextBlended(string text, SDL_Color color)
        {
            return checkedSurface(TTF_RenderUTF8_Blended(_font, toStringz(text), color));
        }

        /// Create an 8-bit palettized surface and render the given text at fast 
        /// quality with the given font and color.
        /// Throws: $(D SDL2Exception) on error.
        SDL2Surface renderTextSolid(string text, SDL_Color color)
        {
            return checkedSurface(TTF_RenderUTF8_Solid(_font, toStringz(text), color));
        }

        /// Create an 8-bit palettized surface and render the given text at high 
        /// quality with the given font and colors.
        /// Throws: $(D SDL2Exception) on error.
        SDL2Surface renderTextShaded(string text, SDL_Color fg, SDL_Color bg)
        {
            return checkedSurface(TTF_RenderUTF8_Shaded(_font, toStringz(text), fg, bg));
        }
    }

    private
    {
        SDLTTF _sdlttf;
        TTF_Font *_font;

        SDL2Surface checkedSurface(SDL_Surface* s)
        {
            if (s is null)
                _sdlttf.throwSDL2TTFException("TTF_Render");
            return new SDL2Surface(_sdlttf._sdl2, s, SDL2Surface.Owned.YES);
        }
    }
}
