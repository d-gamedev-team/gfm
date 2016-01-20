module gfm.sdl2.timer;

import core.stdc.stdlib;

import derelict.sdl2.sdl;

import gfm.sdl2.sdl;

/// SDL Timer wrapper.
class SDL2Timer
{
    public
    {
        /// Create a new SDL timer.
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_AddTimer)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2 sdl2, uint intervalMs)
        {
            _id = SDL_AddTimer(intervalMs, &timerCallbackSDL, cast(void*)this);
            if (_id == 0)
                sdl2.throwSDL2Exception("SDL_AddTimer");
        }

        /// Returns: Timer ID.
        SDL_TimerID id() pure const nothrow @nogc
        {
            return _id;
        }

        /// Timer clean-up.
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_RemoveTimer)
        ~this()
        {
            if (_id != 0)
            {
                debug ensureNotInGC("SDL2Timer");
                SDL_RemoveTimer(_id);
                _id = 0;
            }
        }
    }

    protected
    {
        /// Override this to implement a SDL timer.
        abstract uint onTimer(uint interval) nothrow;
    }

    private
    {
        SDL_TimerID _id;
    }
}

extern(C) private nothrow
{
    uint timerCallbackSDL(uint interval, void* param)
    {
        try
        {
            SDL2Timer timer = cast(SDL2Timer)param;
            return timer.onTimer(interval);
        }
        catch (Throwable e)
        {
            // No Throwable is supposed to cross C callbacks boundaries
            // Crash immediately
            exit(-1);
            return 0;
        }
    }
}