module gfm.sdl.overlay;

import std.string;
import std.conv;

import derelict.sdl.sdl;

import gfm.sdl.sdl;
import gfm.sdl.surface;
import gfm.sdl.exception;
import gfm.math.box;
import gfm.common.log;
import gfm.math.smallvector;


final class SDLOverlay
{
    public
    {
        enum Format : uint
        {
            YV12 = 0x32315659,
            IYUV = 0x56555949,
            YUY2 = 0x32595559,
            UYVY = 0x59565955,
            YVYU = 0x55595659
        }

        this(Log log, int width, int height, Format format, SDLSurface display)
        {
            assert(display !is null);

            _overlay = SDL_CreateYUVOverlay(width, height, format, display.internal);

            if (_overlay is null)
                throw new SDLException("Failed to create an overlay");

            log.infof("overlay created %sx%s, format = %s, flags = %s",
                            width, height, to!string(format), flags());
        }

        ~this()
        {
            SDL_FreeYUVOverlay(_overlay);
        }

        @property int width() const
        {
            return _overlay.w;
        }

        @property int height() const
        {
            return _overlay.h;
        }

        @property vec2i dimension() const
        {
            return vec2i(_overlay.w, _overlay.h);
        }

        @property uint numPlanes() const
        {
            return _overlay.planes;
        }

        // lock the overlay
        // pixels and pitches should point to arrays with size numPlanes()
        void lock(ubyte*[] pixels, ptrdiff_t[] pitches)
        {
            uint n = numPlanes();
            assert(pixels.length == _overlay.planes);
            assert(pitches.length == _overlay.planes);

            SDL_LockYUVOverlay(_overlay);

            for (int i = 0; i < n; ++i)
            {
                pixels[i] = _overlay.pixels[i];
                pitches[i] = _overlay.pitches[i];
            }
        }

        void unlock()
        {
            SDL_UnlockYUVOverlay(_overlay);
        }

        // display to screen
        void display(box2i rect)
        {
            SDL_Rect r;
            r.x = cast(ushort)(rect.a.x);
            r.y = cast(ushort)(rect.a.y);
            r.w = cast(ushort)(rect.width);
            r.h = cast(ushort)(rect.height);
            SDL_DisplayYUVOverlay(_overlay, &r);
        }

        int flags() const
        {
            return _overlay.flags;
        }
    }

    private
    {
        SDLSurface _screen; // should be the surface created by an SDLApplication
        SDL_Overlay* _overlay; // pointer to SDL struct
    }
}
