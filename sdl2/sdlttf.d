module gfm.sdl2.sdlttf;

import derelict.sdl2.sdl;
import derelict.sdl2.ttf;
import derelict.util.exception;

import gfm.common.log;
import gfm.common.text;
import gfm.math.vector;

import gfm.sdl2.sdl;

/// SDL_ttf library resource
final class SDLTTF
{
    public
    {
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
            return sanitizeUTF8(TTF_GetError());
        }
    }
}

/// SDL_ttf loaded font wrapper
final class SDLFont
{
    public
    {
        /**
         * Load a font from a file.
         * ptSize is in 72 dpi ("This basically translates to pixel height" says the doc).
         */
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

        void close()
        {
            if (_font !is null)
            {
                TTF_CloseFont(_font);
                _font = null;
            }
        }

        // style set/get properties
        int style() @property
        {
            return TTF_GetFontStyle(_font);
        }

        int style(int newStyle) @property
        {
            if (newStyle != TTF_GetFontStyle(_font))
                TTF_SetFontStyle(_font, newStyle);
            return newStyle;
        }

        // hinting set/get properties
        int hinting() @property
        {
            return TTF_GetFontHinting(_font);
        }

        int hinting(int newHinting) @property
        {
            if (newHinting != TTF_GetFontHinting(_font))
                TTF_SetFontHinting(_font, newHinting);
            return newHinting;
        }

        // outline set/get properties
        int outline() @property
        {
            return TTF_GetFontOutline(_font);
        }

        int outline(int newOutline) @property
        {
            if (newOutline != TTF_GetFontOutline(_font))
                TTF_SetFontOutline(_font, newOutline);
            return newOutline;
        }

        // kerning set/get properties
        bool kerning() @property
        {
            return TTF_GetFontKerning(_font) != 0;
        }

        bool kerning(bool enabled) @property
        {
            TTF_SetFontKerning(_font, enabled ? 1 : 0);
            return enabled;
        }

        /// the maximum height of a glyph in pixels
        int height() @property
        {
            return TTF_FontAscent(_font);
        }

        /// height above baseline in pixels
        int ascent() @property
        {
            return TTF_FontAscent(_font);
        }

        /// height below baseline
        int descent() @property
        {
            return TTF_FontDescent(_font);
        }

        /// line skip is the recommended pixel interval between two lines
        int lineSlip() @property
        {
            return TTF_FontLineSkip(_font);
        }

        /// return size in pixels of text if rendered with this font
        vec2i measureText(string text)
        {
            int w, h;
            TTF_SizeUTF8(_font, toStringz(text), &w, &h);
            return vec2i(w, h);
        }
    }

    private
    {
        SDLTTF _sdlttf;
        TTF_Font *_font;
    }
}