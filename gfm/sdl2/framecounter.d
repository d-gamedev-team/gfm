module gfm.sdl2.framecounter;

import std.string;

import derelict.sdl2.sdl;

import gfm.core.queue,
       gfm.math.statistics,
       gfm.sdl2.sdl;


/// Utility class which gives time delta between frames, and 
/// logs some framerate statistics.
final class FrameCounter
{
    public
    {
        this(SDL2 sdl)
        {
            _sdl = sdl;
            _firstFrame = true;
            _elapsedTime = 0;
            _stats = new RingBuffer!ulong(10);
        }

        /// Mark the beginning of a new frame.
        /// Returns: current timle difference since last frame, in milliseconds.
        ulong tickMs()
        {
            if (_firstFrame)
            {
                _lastTime = getCurrentTime();
                _firstFrame = false;
                _stats.pushBack(0);
                return 0; // no advance for first frame
            }
            else
            {
                uint now = getCurrentTime();
                uint delta = now - _lastTime;
                _elapsedTime += delta;
                _lastTime = now;
                _stats.pushBack(delta);
                return delta;
            }
        }

        /// Mark the beginning of a new frame.
        /// Returns: current timle difference since last frame, in seconds.
        double tick()
        {
            return tickMs() * 0.001;
        }

        /// Returns: Number of elapsed milliseconds, in milliseconds.
        ulong elapsedTimeMs() const
        {
            return _elapsedTime;
        }

        /// Returns: Number of elapsed milliseconds, in seconds.
        double elapsedTime() const
        {
            return _elapsedTime * 0.001;
        }

        /// Returns displayable framerate statistics.
        string getFPSString()
        {
            double avg = average(_stats[]);
            int avgFPS = cast(int)(0.5 + ( avg != 0 ? 1000 / avg : 0 ) );
            int avgdt = cast(int)(0.5 + avg);

            return format("FPS: %s dt: avg %sms min %sms max %sms",
                          avgFPS,
                          avgdt,
                          minElement(_stats[]),
                          maxElement(_stats[]));
        }
    }

    private
    {
        SDL2 _sdl;
        RingBuffer!ulong _stats;
        bool _firstFrame;
        uint _lastTime;
        ulong _elapsedTime;

        uint getCurrentTime()
        {
            return SDL_GetTicks();
        }
    }
}

