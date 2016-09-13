module gfm.sdl2.surface;

import derelict.sdl2.sdl;

import gfm.sdl2.sdl;

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
            _handleOwned = owned;
        }

        /// Create a new RGBA surface. Both pixels data and handle are owned.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_CreateRGBSurface)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2 sdl2, int width, int height, int depth,
             uint Rmask, uint Gmask, uint Bmask, uint Amask)
        {
            _sdl2 = sdl2;
            _surface = SDL_CreateRGBSurface(0, width, height, depth, Rmask, Gmask, Bmask, Amask);
            if (_surface is null)
                _sdl2.throwSDL2Exception("SDL_CreateRGBSurface");
            _handleOwned = Owned.YES;
        }

        /// Create surface from RGBA data. Pixels data is <b>not</b> and not owned.
        /// See_also: clone, $(WEB wiki.libsdl.org/SDL_CreateRGBSurfaceFrom,SDL_CreateRGBSurfaceFrom)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2 sdl2, void* pixels, int width, int height, int depth, int pitch,
             uint Rmask, uint Gmask, uint Bmask, uint Amask)
        {
            _sdl2 = sdl2;
            _surface = SDL_CreateRGBSurfaceFrom(pixels, width, height, depth, pitch, Rmask, Gmask, Bmask, Amask);
            if (_surface is null)
                _sdl2.throwSDL2Exception("SDL_CreateRGBSurfaceFrom");
            _handleOwned = Owned.YES;
        }

        /// Releases the SDL resource.
        ~this()
        {
            if (_surface !is null)
            {
                debug ensureNotInGC("SDL2Surface");
                if (_handleOwned == Owned.YES)
                    SDL_FreeSurface(_surface);
                _surface = null;
            }
        }

        /// Converts the surface to another format.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_ConvertSurface)
        /// Returns: A new surface.
        SDL2Surface convert(const(SDL_PixelFormat)* newFormat)
        {
            SDL_Surface* surface = SDL_ConvertSurface(_surface, newFormat, 0);
            if (surface is null)
                _sdl2.throwSDL2Exception("SDL_ConvertSurface");
            assert(surface != _surface); // should not be the same handle
            return new SDL2Surface(_sdl2, surface, Owned.YES);
        }

        /// Returns: A copy of the surface, useful for taking ownership of not-owned pixel data.
        /// See_also: $WEB(wiki.libsdl.org/SDL_CreateRGBSurfaceFrom,SDL_CreateRGBSurfaceFrom)
        SDL2Surface clone()
        {
            return convert(pixelFormat());
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
        /// Throws: $(D SDL2Exception) on error.
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

        ///
        struct RGBA
        {
            ubyte r, g, b, a;
        }

        /// Get a surface pixel color.
        /// Bugs: must be locked when using this method. Slow!
        RGBA getRGBA(int x, int y)
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
            return RGBA(r, g, b, a);
        }

        /// Enable the key color as the transparent key.
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_SetColorKey)
        /// Throws: $(D SDL2Exception) on error.
        void setColorKey(bool enable, uint key)
        {
            if (0 != SDL_SetColorKey(this._surface, enable ? SDL_TRUE : SDL_FALSE, key))
                _sdl2.throwSDL2Exception("SDL_SetColorKey");
        }

        /// Enable the (r, g, b, a) key color as the transparent key.
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_SetColorKey) $(https://wiki.libsdl.org/SDL_MapRGBA)
        /// Throws: $(D SDL2Exception) on error.
        void setColorKey(bool enable, ubyte r, ubyte g, ubyte b, ubyte a = 0)
        {
            uint key = SDL_MapRGBA(cast(const)this._surface.format, r, g, b, a);
            this.setColorKey(enable, key);
        }

        /// Perform a fast surface copy of given source surface to this destination surface.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_BlitSurface)
        /// Throws: $(D SDL2Exception) on error.
        void blit(SDL2Surface source, SDL_Rect srcRect, SDL_Rect dstRect)
        {
            if (0 != SDL_BlitSurface(source._surface, &srcRect, _surface, &dstRect))
                _sdl2.throwSDL2Exception("SDL_BlitSurface");
        }

        /// Perform a scaled surface copy of given source surface to this destination surface.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_BlitScaled)
        /// Throws: $(D SDL2Exception) on error.
        void blitScaled(SDL2Surface source, SDL_Rect srcRect, SDL_Rect dstRect)
        {
            if (0 != SDL_BlitScaled(source._surface, &srcRect, _surface, &dstRect))
                _sdl2.throwSDL2Exception("SDL_BlitScaled");
        }
    }

    package
    {
        SDL2 _sdl2;
        SDL_Surface* _surface;
        Owned _handleOwned;
    }
}
