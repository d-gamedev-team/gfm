module gfm.sdl2.framecounter;

import derelict.sdl2.sdl;
import gfm.sdl2.sdl;

// gets intra-frame delta time
final class FrameCounter
{
    public
    {
        this(SDL2 sdl)
        {
            _sdl = sdl;
            _firstFrame = true;
            _elapsedTime = 0;
        }

        /**
         * Mark the beginning of a new frame, and get the current delta
         * time in milliseconds.
         */
        ulong tickMs()
        {
            if (_firstFrame)
            {
                _lastTime = getCurrentTime();
                _firstFrame = false;
                return 0; // no advance for first frame
            }
            else
            {
                uint now = getCurrentTime();
                uint delta = now - _lastTime;
                _elapsedTime += delta;
                _lastTime = now;
                return delta;
            }
        }

        /**
         * Same in seconds.
         */
        double tick()
        {
            return tickMs() * 0.001;
        }

        /**
         * Number of elapsed milliseconds.
         */
        ulong elapsedTimeMs() const
        {
            return _elapsedTime;
        }

        /**
         * Same in seconds.
         */
        double elapsedTime() const
        {
            return _elapsedTime * 0.001;
        }
    }

    private
    {
        SDL2 _sdl;
        bool _firstFrame;
        uint _lastTime;
        ulong _elapsedTime;

        uint getCurrentTime()
        {
            return SDL_GetTicks();
        }
    }
}

