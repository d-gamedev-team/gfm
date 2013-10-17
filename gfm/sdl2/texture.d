module gfm.sdl2.texture;

import std.string;

import derelict.sdl2.sdl;

import gfm.core.log;

import gfm.sdl2.sdl,
       gfm.sdl2.surface,
       gfm.sdl2.renderer;

final class SDL2Texture
{
    public
    {
        this(SDL2Renderer renderer, uint format, uint access, int width, int height)
        {
            _sdl2 = renderer._sdl2;
            _handle = SDL_CreateTexture(renderer._renderer, format, access, width, height);
            if (_handle is null)
                _sdl2.throwSDL2Exception("SDL_CreateTexture");
        }

        // create texture from a surface
        this(SDL2Renderer renderer, SDL2Surface surface)
        {
            _handle = SDL_CreateTextureFromSurface(renderer._renderer, surface._surface);
            if (_handle is null)
                _sdl2.throwSDL2Exception("SDL_CreateTextureFromSurface");
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_handle !is null)
            {
                SDL_DestroyTexture(_handle);
                _handle = null;
            }
        }

        uint format()
        {
            uint res;
            int err = SDL_QueryTexture(_handle, &res, null, null, null);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_QueryTexture");

            return res;
        }

        int width()
        {
            int res;
            int err = SDL_QueryTexture(_handle, null, null, &res, null);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_QueryTexture");
            return res;
        }

        int height()
        {
            int res;
            int err = SDL_QueryTexture(_handle, null, null, null, &res);
            if (err != 0)
                _sdl2.throwSDL2Exception("SDL_QueryTexture");
            return res;
        }
    }      

    private
    {
        SDL2 _sdl2;
        SDL_Texture* _handle;
    }
}

