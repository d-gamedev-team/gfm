module gfm.sdl2.sdlimage;

import std.string;

import derelict.util.exception,
       derelict.sdl2.sdl,
       derelict.sdl2.image;

import gfm.core.log,
       gfm.core.text,
       gfm.sdl2.sdl, 
       gfm.sdl2.surface;

/// Load images using SDL_image, a SDL companion library able to load various image formats.
final class SDLImage
{
    public
    {
        this(SDL2 sdl2, int flags = IMG_INIT_JPG | IMG_INIT_PNG | IMG_INIT_TIF | IMG_INIT_WEBP)
        {
            _sdl2 = sdl2; // force loading of SDL first
            _log = sdl2._log;
            _SDLImageInitialized = false;
            
            try
            {
                DerelictSDL2Image.load();
            }
            catch(DerelictException e)
            {
                throw new SDL2Exception(e.msg);
            }

            int inited = IMG_Init(flags);

            if ((inited & IMG_INIT_JPG) != 0)
                _log.infof("SDL_image: JPG loading enabled.");

            if ((inited & IMG_INIT_PNG) != 0)
                _log.infof("SDL_image: PNG loading enabled.");

            if ((inited & IMG_INIT_TIF) != 0)
                _log.infof("SDL_image: TIF loading enabled.");

            if ((inited & IMG_INIT_WEBP) != 0)
                _log.infof("SDL_image: WebP loading enabled.");

            _SDLImageInitialized = true;

        }

        void close()
        {
            if (_SDLImageInitialized)
            {
                _SDLImageInitialized = false;
                IMG_Quit();
            }

            DerelictSDL2Image.unload();
        }

        ~this()
        {
            close();            
        }

        // load an image
        // throw SDL2ImageException on error
        SDL2Surface load(string path)
        {
            immutable(char)* pathz = toStringz(path);
            SDL_Surface* surface = IMG_Load(pathz);
            if (surface is null)
                throwSDL2ImageException("IMG_Load");

            return new SDL2Surface(_sdl2, surface, SDL2Surface.Owned.YES);
        }
    }

    private
    {
        Log _log;
        SDL2 _sdl2;
        bool _SDLImageInitialized;

        void throwSDL2ImageException(string callThatFailed)
        {
            string message = format("%s failed: %s", callThatFailed, getErrorString());
            throw new SDL2Exception(message);
        }

        string getErrorString()
        {
            return sanitizeUTF8(IMG_GetError(), _log, "SDL_Image error string");
        }
    }
}
