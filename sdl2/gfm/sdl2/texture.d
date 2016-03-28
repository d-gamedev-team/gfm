module gfm.sdl2.texture;

import std.string;

import derelict.sdl2.sdl;

import gfm.sdl2.sdl,
       gfm.sdl2.surface,
       gfm.sdl2.renderer;

/// SDL Texture wrapper.
final class SDL2Texture
{
    public
    {
        /// Creates a SDL Texture for a specific renderer.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_CreateTexture)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2Renderer renderer, uint format, uint access, int width, int height)
        {
            _sdl2 = renderer._sdl2;
            _renderer = renderer;
            _handle = SDL_CreateTexture(renderer._renderer, format, access, width, height);
            if (_handle is null)
                _sdl2.throwSDL2Exception("SDL_CreateTexture");
        }

        /// Creates a SDL Texture for a specific renderer, from an existing surface.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_CreateTextureFromSurface)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2Renderer renderer, SDL2Surface surface)
        {
            _handle = SDL_CreateTextureFromSurface(renderer._renderer, surface._surface);
            _renderer = renderer;
            if (_handle is null)
                _sdl2.throwSDL2Exception("SDL_CreateTextureFromSurface");
        }

        /// Releases the SDL resource.
        ~this()
        {
            if (_handle !is null)
            {
                debug ensureNotInGC("SDL2Texture");
                SDL_DestroyTexture(_handle);
                _handle = null;
            }
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetTextureBlendMode)
        /// Throws: $(D SDL2Exception) on error.
        void setBlendMode(SDL_BlendMode blendMode)
        {
            if (SDL_SetTextureBlendMode(_handle, blendMode) != 0)
                _sdl2.throwSDL2Exception("SDL_SetTextureBlendMode");
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetTextureColorMod)
        /// Throws: $(D SDL2Exception) on error.
        void setColorMod(int r, int g, int b)
        {
            if (SDL_SetTextureColorMod(_handle, cast(ubyte)r, cast(ubyte)g, cast(ubyte)b) != 0)
                _sdl2.throwSDL2Exception("SDL_SetTextureColorMod");
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetTextureAlphaMod)
        /// Throws: $(D SDL2Exception) on error.
        void setAlphaMod(int a)
        {

            // #Workaround SDL software renderer bug with alpha = 255
            if (_renderer.info().isSoftware())
            {
                if (a >= 255)
                    a = 254;
            }

            if (SDL_SetTextureAlphaMod(_handle, cast(ubyte)a) != 0)
                _sdl2.throwSDL2Exception("SDL_SetTextureAlphaMod");
        }

        /// Returns: Texture format.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_QueryTexture)
        /// Throws: $(D SDL2Exception) on error.
        uint format()
        {
            uint res;
            int err = SDL_QueryTexture(_handle, &res, null, null, null);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_QueryTexture");

            return res;
        }

        /// Returns: Texture access.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_QueryTexture)
        /// Throws: $(D SDL2Exception) on error.
        int access()
        {
            int res;
            int err = SDL_QueryTexture(_handle, null, &res, null, null);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_QueryTexture");

            return res;
        }

        /// Returns: Width of texture.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_QueryTexture)
        /// Throws: $(D SDL2Exception) on error.
        int width()
        {
            int res;
            int err = SDL_QueryTexture(_handle, null, null, &res, null);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_QueryTexture");
            return res;
        }

        /// Returns: Height of texture.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_QueryTexture)
        /// Throws: $(D SDL2Exception) on error.
        int height()
        {
            int res;
            int err = SDL_QueryTexture(_handle, null, null, null, &res);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_QueryTexture");
            return res;
        }

        /// Updates the whole texture with new pixel data.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_UpdateTexture)
        /// Throws: $(D SDL2Exception) on error.
        void updateTexture(const(void)* pixels, int pitch)
        {
            int err = SDL_UpdateTexture(_handle, null, pixels, pitch);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_UpdateTexture");
        }

        /// Updates a part of a texture with new pixel data.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_UpdateTexture)
        /// Throws: $(D SDL2Exception) on error.
        void updateTexture(const(SDL_Rect)* rect, const(void)* pixels, int pitch)
        {
            int err = SDL_UpdateTexture(_handle, rect, pixels, pitch);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_UpdateTexture");
        }

        /// Update a planar YV12 or IYUV texture with new pixel data.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_UpdateYUVTexture)
        /// Throws: $(D SDL2Exception) on error.
        void updateYUVTexture(const(ubyte)* Yplane, int Ypitch, const(ubyte)* Uplane, int Upitch, const Uint8* Vplane, int Vpitch)
        {
            int err = SDL_UpdateYUVTexture(_handle, null, Yplane, Ypitch, Uplane, Upitch, Vplane, Vpitch);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_UpdateYUVTexture");
        }

        /// Update a part of a planar YV12 or IYUV texture with new pixel data.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_UpdateYUVTexture)
        /// Throws: $(D SDL2Exception) on error.
        void updateYUVTexture(const(SDL_Rect)* rect, const(ubyte)* Yplane, int Ypitch, const(ubyte)* Uplane, int Upitch, const Uint8* Vplane, int Vpitch)
        {
            int err = SDL_UpdateYUVTexture(_handle, rect, Yplane, Ypitch, Uplane, Upitch, Vplane, Vpitch);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_UpdateYUVTexture");
        }

        /// Returns: SDL handle.
        SDL_Texture* handle()
        {
            return _handle;
        }

    }

    package
    {
        SDL_Texture* _handle;
    }

    private
    {
        SDL2 _sdl2;
        SDL2Renderer _renderer;
    }
}

