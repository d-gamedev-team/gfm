module gfm.sdl2.sdl;

import std.conv;

import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.util.exception;

import gfm.sdl2.exception;
import gfm.common.log;

final class SDL2
{
    public
    {
    /*    string keyName(int key)
        {
            return to!string(SDL_GetKeyName(key));
        }

        string getErrorString()
        {
            return to!string(SDL_GetError());
        }*/

        this(Log log)
        {
            _log = log;
            try
            {
                // in debug builds, use a debgu version of SDL2
                debug
                    DerelictSDL2.load("SDL2d.dll");
                else
                    DerelictSDL2.load();
                DerelictSDL2.disableAutoUnload();
            }
            catch(DerelictException e)
            {
                throw new SDL2Exception(e.msg);
            }

            // enable all logging
            SDL_LogSetAllPriority(SDL_LOG_PRIORITY_VERBOSE);

            if (0 != SDL_Init(0))
                throw new SDL2Exception("Unable to initialize SDL");

            subSystemInit(SDL_INIT_TIMER);
            subSystemInit(SDL_INIT_VIDEO);
            subSystemInit(SDL_INIT_JOYSTICK);
            subSystemInit(SDL_INIT_AUDIO);
            subSystemInit(SDL_INIT_HAPTIC);
        }

        ~this()
        {
            SDL_Quit();
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
                    throw new SDL2Exception("Unable to initialize SDL subsystem.");
            }
        }
    }
}

