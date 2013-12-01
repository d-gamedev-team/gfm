module gfm.sdl2.surface;

import derelict.sdl2.sdl;

import gfm.math.vector,
       gfm.sdl2.sdl;


final class SDL2Surface
{
    public
    {
        enum Owned
        {
            NO, YES
        }

        /// Create from exisint SDL_Surface* handle.
        this(SDL2 sdl2, SDL_Surface* surface, Owned owned)
        {
            assert(surface !is null);
            _sdl2 = sdl2;
            _surface = surface;
            _owned = owned;
        }

        /// Create surface from RGBA data
        /// See: SDL_CreateRGBSurfaceFrom
        this(SDL2 sdl2, void* pixels, int width, int height, int depth, int pitch, 
             uint Rmask, uint Gmask, uint Bmask, uint Amask)
        {
            _sdl2 = sdl2;
            _surface = SDL_CreateRGBSurfaceFrom(pixels, width, height, depth, pitch, Rmask, Gmask, Bmask, Amask);
            if (_surface is null)
                _sdl2.throwSDL2Exception("SDL_CreateRGBSurfaceFrom");
            _owned = Owned.YES;
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_surface !is null)
            {
                if (_owned == Owned.YES)
                    SDL_FreeSurface(_surface);
                _surface = null;
            }
        }

        @property int width() const
        {
            return _surface.w;
        }

        @property int height() const
        {
            return _surface.h;
        }

        ubyte* pixels()
        {
            return cast(ubyte*) _surface.pixels;
        }

        size_t pitch()
        {
            return _surface.pitch;
        }

        void lock()
        {
            if (SDL_LockSurface(_surface) != 0)
                _sdl2.throwSDL2Exception("SDL_LockSurface");
        }

        void unlock()
        {
            SDL_UnlockSurface(_surface);
        }

        SDL_Surface* handle()
        {
            return _surface;
        }

        SDL_PixelFormat* pixelFormat()
        {
            return _surface.format;
        }

        // Warning: must be locked when using this method.
        // Slow!
        vec4ub getRGBA(int x, int y)
        {
            // crash if out of image
            if (x < 0 || x >= width())
                assert(0);

            if (y < 0 || y >= height())
                assert(0);
            
            SDL_PixelFormat* fmt = _surface.format;

            ubyte* pixels = cast(ubyte*)_surface.pixels;
            int pitch = _surface.pitch;

            uint* pixel = cast(uint*)(pixels + y * pitch + x * fmt.BytesPerPixel);
            ubyte r, g, b, a;
            SDL_GetRGBA(*pixel, fmt, &r, &g, &b, &a);
            return vec4ub(r, g, b, a);
        }
    }

    package
    {
        SDL2 _sdl2;
        SDL_Surface* _surface;
        Owned _owned;
    }
}
