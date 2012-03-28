module gfm.sdl.surface;

import derelict.sdl.sdl;

import gfm.sdl.sdl;
import gfm.sdl.exception;

final class SDLSurface
{
    public
    {
        this(SDL sdl, SDL_Surface* surface, bool owned)
        {
            assert(surface !is null);

            if (surface is null)
                throw new SDLException("Trying to create a null SDLSurface");

            _sdl = sdl;
            _surface = surface;
            _owned = owned;
        }

        ~this()
        {
            if (_owned)
                SDL_FreeSurface(_surface);

        }

        @property int width() const
        {
            return _surface.w;
        }

        @property int height() const
        {
            return _surface.h;
        }

        @property uint flags() const
        {
            return _surface.flags;
        }

        ubyte* lock()
        {
            if (SDL_MUSTLOCK(_surface) == 0)
                return cast(ubyte*)(_surface.pixels);

            int res = SDL_LockSurface(_surface);
            if (res != 0)
                throw new SDLException(_sdl.getErrorString());

            return cast(ubyte*)(_surface.pixels);
        }

        void unlock()
        {
            if (SDL_MUSTLOCK(_surface) == 0)
                return;

            SDL_UnlockSurface(_surface);
        }

        // only for screen surface
        void flip()
        {
            int err = SDL_Flip(_surface);

            if (err != 0)
                throw new SDLException(_sdl.getErrorString());
        }

        @property SDL_Surface* internal()
        {
            return _surface;
        }
    }

    private
    {
        SDL _sdl;
        bool _owned;
        SDL_Surface* _surface; // pointer to SDL struct
    }
}
