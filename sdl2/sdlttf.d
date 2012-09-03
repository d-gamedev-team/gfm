module gfm.sdl2.sdlttf;

import derelict.sdl2.sdl;
import derelict.sdl2.ttf;
import derelict.util.exception;

import gfm.common.log;
import gfm.common.text;

import gfm.sdl2.sdl;

class SDL2TTFException : SDL2Exception
{
    public
    {
        this(string msg)
        {
            super(msg);
        }
    }
}

final class SDLTTF
{
    public
    {
        this(SDL2 sdl2)
        {
            _sdl2 = sdl2; // force loading of SDL first
            _log = sdl2._log;
            _SDLTTFInitialized = false;

            try
            {
                DerelictSDL2ttf.load();
            }
            catch(DerelictException e)
            {
                throw new SDL2TTFException(e.msg);
            }

            int res = TTF_Init();
            if (res != 0)
                throwSDL2TTFException("TTF_Init");

             _log.infof("SDL_ttf: initialized.");
            _SDLTTFInitialized = true;
        }

        void close()
        {
            if (_SDLTTFInitialized)
            {
                _SDLTTFInitialized = false;
                TTF_Quit();
            }

            DerelictSDL2ttf.unload();
        }

        ~this()
        {
            close();
        }   
    }

    private
    {
        Log _log;
        SDL2 _sdl2;
        bool _SDLTTFInitialized;

        void throwSDL2TTFException(string callThatFailed)
        {
            string message = format("%s failed: %s", callThatFailed, getErrorString());
            throw new SDL2TTFException(message);
        }

        string getErrorString()
        {
            return sanitizeUTF8(TTF_GetError());
        }
    }
}
