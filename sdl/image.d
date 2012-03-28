module gfm.sdl.image;

import std.conv, std.string;
import derelict.sdl.sdl, derelict.sdl.image, derelict.util.exception;
import gfm.sdl.sdl, gfm.sdl.exception, gfm.sdl.surface;

final class SDLImage
{
    public
    {
        this(SDL sdl)
        {
            _sdl = sdl; // force loading of SDL first

            try
            {
                DerelictSDLImage.load();
            }
            catch(DerelictException e)
            {
                throw new SDLException(e.msg);
            }

            int flags = IMG_INIT_JPG | IMG_INIT_PNG | IMG_INIT_TIF;
            int inited = IMG_Init(flags);

            if (inited != flags)
                throw new SDLException(getErrorString());
        }

        ~this()
        {
            IMG_Quit();
        }

        // load an image
        // throw SDLException on error
        SDLSurface load(string path)
        {
            immutable(char)* pathz = toStringz(path);
            SDL_Surface* surface = IMG_Load(pathz);
            if (surface is null)
                throw new SDLException(getErrorString());

            return new SDLSurface(_sdl, surface, true);
        }
    }

    private
    {
        SDL _sdl;

        string getErrorString()
        {
            return to!string(IMG_GetError());
        }
    }
}
