module gfm.sdl2.surface;

import derelict.sdl2.sdl;

import gfm.sdl2.sdl;
import gfm.sdl2.exception;
import gfm.math.smallvector;


final class SDL2Surface
{
    public
    {
        this(SDL2 sdl2, SDL_Surface* surface)
        {
            _sdl2 = sdl2;
            _surface = surface;
        }      

        ~this()
        {

        }

        int width()
        {
            return _surface.w;
        }

        int height()
        {
            return _surface.h;
        }
    }

    private
    {
        SDL2 _sdl2;
        SDL_Surface* _surface;
    }
}
