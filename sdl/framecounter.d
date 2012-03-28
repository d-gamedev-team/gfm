module gfm.sdl.framecounter;

import derelict.sdl.sdl;
import gfm.sdl.sdl;
import gfm.math.statistics;
import gfm.common.queue;

// gets intra-frame delta time
class FrameCounter
{
    public
    {
        this(SDL sdl)
        {
            _sdl = sdl;
            _firstFrame = true;
            _elapsedTime = 0;
        }

        /**
         * Mark the beginning of a new frame, get the current delta
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
        SDL _sdl;
        bool _firstFrame;
        uint _lastTime;
        ulong _elapsedTime;

        uint getCurrentTime()
        {
            return SDL_GetTicks();
        }
    }
}

