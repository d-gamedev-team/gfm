module gfm.sdl2.framecounter;

import std.string;

import derelict.sdl2.sdl;
import gfm.sdl2.sdl;
import gfm.math.statistics;

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
            _stats = new Statistics!ulong(10, 1);
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
                _stats.eat(0);
                return 0; // no advance for first frame
            }
            else
            {
                uint now = getCurrentTime();
                uint delta = now - _lastTime;
                _elapsedTime += delta;
                _lastTime = now;
                _stats.eat(delta);
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

        string getFPSString()
        {
            double avg = _stats.computeAverage();
            int avgFPS = cast(int)(0.5 + ( avg != 0 ? 1000 / avg : 0 ) );
            int avgdt = cast(int)(0.5 + avg);

            return format("FPS: %s dt: avg %sms min %sms max %sms stddev %s",
                          avgFPS,
                          avgdt,
                          _stats.computeMinimum(),
                          _stats.computeMaximum(),
                          _stats.computeStdDeviation());

        }
    }

    private
    {
        SDL2 _sdl;
        Statistics!ulong _stats;
        bool _firstFrame;
        uint _lastTime;
        ulong _elapsedTime;

        uint getCurrentTime()
        {
            return SDL_GetTicks();
        }
    }
}

