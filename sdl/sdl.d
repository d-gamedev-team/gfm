module gfm.sdl.sdl;

import std.conv;

import derelict.sdl.sdl;
import derelict.util.exception;
import derelict.sdl.image;

import gfm.sdl.exception;
import gfm.sdl.joystick;
import gfm.sdl.keyboard;
import gfm.common.log;

final class SDL
{
    public
    {
        string keyName(int key)
        {
            return to!string(SDL_GetKeyName(key));
        }

        string getErrorString()
        {
            return to!string(SDL_GetError());
        }

        this(Log log)
        {
            _log = log;
            try
            {
                DerelictSDL.load();
                DerelictSDL.disableAutoUnload();
            }
            catch(DerelictException e)
            {
                throw new SDLException(e.msg);
            }

            if (0 != SDL_Init(0))
                throw new SDLException("Unable to initialize SDL");

            subSystemInit(SDL_INIT_TIMER);
            subSystemInit(SDL_INIT_VIDEO);
        //    subSystemInit(SDL_INIT_JOYSTICK);

            SDL_EnableUNICODE(1);
        }

        ~this()
        {
            SDL_Quit();
        }

        void enableAllEvents()
        {
            SDL_EventState(cast(ubyte) SDL_ALLEVENTS, SDL_ENABLE);
        }
    }

    private
    {
        Log _log;

        bool subSystemInitialized(int subSystem)
        {
            int inited = SDL_WasInit(SDL_INIT_EVERYTHING);
            return 0 != ( inited & subSystem );
        }

        void subSystemInit(int flag)
        {
            if (! subSystemInitialized(flag))
            {
                int res = SDL_InitSubSystem(flag);
                if (0 != res)
                    throw new SDLException("Unable to initialize SDL subsystem.");
            }
        }
    }
}

