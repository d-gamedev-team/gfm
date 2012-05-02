module gfm.sdl2.eventqueue;

import std.string;

import derelict.sdl2.sdl;

import gfm.common.log;
import gfm.sdl2.sdl;
import gfm.sdl2.exception;
import gfm.sdl2.window;


final class SDL2EventQueue
{
    public
    {
        bool quit = false;
        this(SDL2 sdl2, Log log)
        {
            _sdl2 = sdl2;
            _log = log;
        }

        void registerWindow(SDL2Window window)
        {
            _knownWindows ~= window;
        }

        void processEvents()
        {
            SDL_Event event;

            while(SDL_PollEvent(&event) != 0)
            {
                switch(event.type)
                {
                    case SDL_QUIT: 
                        quit = true;
                        _log.info("quit");
                        break;
                    default:
                        break;
                }
            }
        }
    }

    private
    {
        SDL2 _sdl2;
        Log _log;
        SDL2Window[] _knownWindows;

    }
}