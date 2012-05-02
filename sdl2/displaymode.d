module gfm.sdl2.displaymode;

import std.string;
import derelict.sdl2.sdl;
import gfm.math.box;

final class SDL2DisplayMode
{
    public
    {
        this(int modeIndex, SDL_DisplayMode mode)
        {
            _modeIndex = modeIndex;
            _mode = mode;
        }

        override string toString()
        {
            return format("mode #%s (width = %spx, height = %spx, rate = %shz, format = %s)", 
                          _modeIndex, _mode.w, _mode.h, _mode.refresh_rate, _mode.format);
        }
    }

    private
    {
        int _modeIndex;
        SDL_DisplayMode _mode;
    }
}

final class SDL2VideoDisplay
{
    public
    {
        this(int displayindex, box2i bounds, SDL2DisplayMode[] availableModes)
        {
            _displayindex = displayindex;
            _bounds = bounds;
            _availableModes = availableModes;
        }

        const(SDL2DisplayMode[]) availableModes() pure const nothrow
        {
            return _availableModes;
        }

        const(box2i) bounds() pure const nothrow
        {
            return _bounds;
        }

        override string toString()
        {
            string res = format("display #%s (bounds = %s,%s - %s,%s)\n", _displayindex, 
                                _bounds.a.x, _bounds.a.y, _bounds.b.x, _bounds.b.y);
            foreach (mode; _availableModes)
                res ~= format("  - %s\n", mode);
            return res;
        }
    }

    private
    {
        int _displayindex;
        SDL2DisplayMode[] _availableModes;        
        box2i _bounds;
    }
}

