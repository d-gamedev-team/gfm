module gfm.sdl2.surface;

import derelict.sdl2.sdl;

import gfm.math.vector,
       gfm.sdl2.sdl;

/// SDL Surface wrapper.
/// A SDL2Surface might own the SDL_Surface* handle or not.
final class SDL2Surface
{
    public
    {
        /// Whether a SDL Surface is owned by the wrapper or borrowed.
        enum Owned
        {
            NO,  // Not owned.
            YES  // Owned.
        }

        /// Create from an existing SDL_Surface* handle.
        this(SDL2 sdl2, SDL_Surface* surface, Owned owned)
        {
            assert(surface !is null);
            _sdl2 = sdl2;
            _surface = surface;
            _owned = owned;
        }

        /// Create surface from RGBA data
        /// See_also: $WEB(wiki.libsdl.org/SDL_CreateRGBSurfaceFrom,SDL_CreateRGBSurfaceFrom)
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

        /// Releases the SDL resource.
        void close()
        {
            if (_surface !is null)
            {
                if (_owned == Owned.YES)
                    SDL_FreeSurface(_surface);
                _surface = null;
            }
        }

        /// Returns: Width of the surface in pixels.
        @property int width() const
        {
            return _surface.w;
        }

        /// Returns: Height of the surface in pixels.
        @property int height() const
        {
            return _surface.h;
        }

        /// Returns: Pointer to surface data.
        /// You must lock the surface before accessng it.
        ubyte* pixels()
        {
            return cast(ubyte*) _surface.pixels;
        }

        /// Get the surface pitch (number of bytes between lines).
        size_t pitch()
        {
            return _surface.pitch;
        }

        /// Lock the surface, allow to use pixels().
        void lock()
        {
            if (SDL_LockSurface(_surface) != 0)
                _sdl2.throwSDL2Exception("SDL_LockSurface");
        }

        /// Unlock the surface.
        void unlock()
        {
            SDL_UnlockSurface(_surface);
        }

        /// Returns: SDL handle.
        SDL_Surface* handle()
        {
            return _surface;
        }

        /// Returns: SDL_PixelFormat which describe the surface.
        SDL_PixelFormat* pixelFormat()
        {
            return _surface.format;
        }

        /// Get a surface pixel color.
        /// Bugs: must be locked when using this method. Slow!
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
