module gfm.sdl2.renderer;

import std.string;

import derelict.sdl2.sdl;
import gfm.common.log;
import gfm.common.text;
import gfm.math.vector;
import gfm.math.box;

import gfm.sdl2.sdl;
import gfm.sdl2.window; 
import gfm.sdl2.surface;

enum Blend
{
    NONE = SDL_BLENDMODE_NONE,
    MUL = SDL_BLENDMODE_MOD,
    ADD = SDL_BLENDMODE_ADD,
    BLEND = SDL_BLENDMODE_BLEND
}

final class SDL2RendererInfo
{
    public
    {
        this(int index, SDL_RendererInfo info)
        {
            _index = index;
            _info = info;
        }

        string name()
        {
            return sanitizeUTF8(_info.name);
        }

        bool isSoftware()
        {
            return (_info.flags & SDL_RENDERER_SOFTWARE) != 0;
        }

        bool isAccelerated()
        {
            return (_info.flags & SDL_RENDERER_ACCELERATED) != 0;
        }

        bool hasRenderToTexture()
        {
            return (_info.flags & SDL_RENDERER_TARGETTEXTURE) != 0;
        }

        bool isVsyncEnabled()
        {
            return (_info.flags & SDL_RENDERER_PRESENTVSYNC) != 0;
        }

        override string toString()
        {
            string res = format("renderer #%d: %s [flags:", _index, name());
            if (isSoftware()) res ~= " software";
            if (isAccelerated()) res ~= " accelerated";
            if (hasRenderToTexture()) res ~= " render-to-texture";
            if (isVsyncEnabled()) res ~= " vsync";
            res ~= "]\n";
            res ~= format("max. texture: %sx%s", _info.max_texture_width, _info.max_texture_height);
            return res;
        }
    }

    private
    {
        int _index;
        SDL_RendererInfo _info;
    }
}


final class SDL2Renderer
{
    public
    {
        // renderer for a window
        this(SDL2Window window)
        {
            _sdl2 = window._sdl2;
            _window = window;
            _surface = null;
            _renderer = SDL_CreateRenderer(window._window, -1, 0);
            if (_renderer is null)
                _sdl2.throwSDL2Exception("SDL_CreateRenderer");
        }

        // create a software renderer for a surface
        this(SDL2Surface surface)
        {
            _sdl2 = surface._sdl2;
            _window = null;
            _surface = surface;
            _renderer = SDL_CreateSoftwareRenderer(surface._surface);
            if (_renderer is null)
                _sdl2.throwSDL2Exception("SDL_CreateSoftwareRenderer");
        }

        void close()
        {
            if (_renderer !is null)
            {
                SDL_DestroyRenderer(_renderer);
                _renderer = null;
            }
        }

        ~this()
        {
            close();
        }


        void clear()
        {
            SDL_RenderClear(_renderer);
        }

        void present()
        {
            SDL_RenderPresent(_renderer);
        }

        void setColor(ubyte r, ubyte g, ubyte b, ubyte a)
        {
            SDL_SetRenderDrawColor(_renderer, r, g, b, a);
        }

        void setViewport(box2i b)
        {
            SDL_Rect r = box2i_to_SDL_Rect(b);
            SDL_RenderSetViewport(_renderer, &r);
        }

        void setBlend(Blend b)
        {
            SDL_SetRenderDrawBlendMode(_renderer, b);
        }

        void drawLine(vec2i a, vec2i b)
        {
            SDL_RenderDrawLine(_renderer, a.x, a.y, b.x, b.y);
        }

        void drawLines(vec2i[] points)
        {
            SDL_RenderDrawLines(_renderer, cast(SDL_Point*)(points.ptr), cast(int)(points.length));
        }

        void drawPoint(vec2i point)
        {
            SDL_RenderDrawPoint(_renderer, point.x, point.y);
        }

        void drawPoints(vec2i[] points)
        {
            SDL_RenderDrawPoints(_renderer, cast(SDL_Point*)(points.ptr), cast(int)(points.length));
        }
    }

    private
    {
        SDL2 _sdl2;
        SDL2Window _window; // not null if renderer to window
        SDL2Surface _surface; // not null if renderer to surface
        SDL_Renderer* _renderer;

        static SDL_Rect box2i_to_SDL_Rect(box2i b) pure
        {
            SDL_Rect res = void;
            res.x = b.a.x;
            res.y = b.a.y;
            res.w = b.width;
            res.h = b.height;
            return res;
        }
    }
}
