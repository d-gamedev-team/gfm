module gfm.sdl2.renderer;

import std.string;

import derelict.sdl2.sdl;

import gfm.core.log,
       gfm.core.text,
       gfm.math.vector,
       gfm.math.box,
       gfm.sdl2.sdl,
       gfm.sdl2.window,
       gfm.sdl2.texture,
       gfm.sdl2.surface;

/// SDL Renderer wrapper.
final class SDL2Renderer
{
    public
    {
        /// Creates a SDL renderer which targets a window.
        this(SDL2Window window, int flags)
        {
            _sdl2 = window._sdl2;
            _renderer = SDL_CreateRenderer(window._window, -1, flags);
            if (_renderer is null)
                _sdl2.throwSDL2Exception("SDL_CreateRenderer");
        }

        /// Create a software renderer which targets a surface.
        this(SDL2Surface surface)
        {
            _sdl2 = surface._sdl2;
            _renderer = SDL_CreateSoftwareRenderer(surface._surface);
            if (_renderer is null)
                _sdl2.throwSDL2Exception("SDL_CreateSoftwareRenderer");
        }

        /// Releases the SDL ressource.
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
            if (0 != SDL_SetRenderDrawColor(_renderer, r, g, b, a))
                _sdl2.throwSDL2Exception("SDL_RenderSetViewport");
        }

        void setViewport(box2i b)
        {
            SDL_Rect r = box2i_to_SDL_Rect(b);
            if (0 != SDL_RenderSetViewport(_renderer, &r))
                _sdl2.throwSDL2Exception("SDL_RenderSetViewport");
        }

        void setViewportFull()
        {
            if (0 != SDL_RenderSetViewport(_renderer, null))
                _sdl2.throwSDL2Exception("SDL_RenderSetViewport");
        }

        /// Sets SDL blend mode.
        void setBlend(int blendMode)
        {
            if (0 != SDL_SetRenderDrawBlendMode(_renderer, blendMode))
                _sdl2.throwSDL2Exception("SDL_SetRenderDrawBlendMode");
        }

        void drawLine(vec2i a, vec2i b)
        {
            if (0 != SDL_RenderDrawLine(_renderer, a.x, a.y, b.x, b.y))
                _sdl2.throwSDL2Exception("SDL_RenderDrawLine");

        }

        void drawLines(vec2i[] points)
        {
            if (0 != SDL_RenderDrawLines(_renderer, cast(SDL_Point*)(points.ptr), cast(int)(points.length)))
                _sdl2.throwSDL2Exception("SDL_RenderDrawLines");
        }

        void drawPoint(vec2i point)
        {
            if (0 != SDL_RenderDrawPoint(_renderer, point.x, point.y))
                _sdl2.throwSDL2Exception("SDL_RenderDrawPoint");
        }

        void drawPoints(vec2i[] points)
        {
            if (0 != SDL_RenderDrawPoints(_renderer, cast(SDL_Point*)(points.ptr), cast(int)(points.length)))
                _sdl2.throwSDL2Exception("SDL_RenderDrawPoints");
        }

        void drawRect(box2i rect)
        {
            SDL_Rect r = box2i_to_SDL_Rect(rect);
            if (0 != SDL_RenderDrawRect(_renderer, &r))
                _sdl2.throwSDL2Exception("SDL_RenderDrawRect");
        }

        void fillRect(box2i rect)
        {
            SDL_Rect r = box2i_to_SDL_Rect(rect);
            if (0 != SDL_RenderFillRect(_renderer, &r))
                _sdl2.throwSDL2Exception("SDL_RenderFillRect");
        }

        void copy(SDL2Texture texture, box2i srcRect, box2i dstRect)
        {
            auto f = texture.format();
            SDL_Rect src = box2i_to_SDL_Rect(srcRect);
            SDL_Rect dst = box2i_to_SDL_Rect(dstRect);
            if (0 != SDL_RenderCopy(_renderer, texture._handle, &src, &dst))
                _sdl2.throwSDL2Exception("SDL_RenderCopy");
        }
    }

    package
    {
        SDL2 _sdl2;
        SDL_Renderer* _renderer;
    }

    private
    {
        static SDL_Rect box2i_to_SDL_Rect(box2i b) pure
        {
            SDL_Rect res = void;
            res.x = b.min.x;
            res.y = b.min.y;
            res.w = b.width;
            res.h = b.height;
            return res;
        }
    }
}

/// SDL Renderer information.
final class SDL2RendererInfo
{
    public
    {
        this(Log log, int index, SDL_RendererInfo info)
        {
            _log = log;
            _index = index;
            _info = info;
        }

        /// Returns: Renderer name.
        string name()
        {
            return sanitizeUTF8(_info.name, _log, "SDL2 renderer name");
        }

        /// Returns: true if this renderer is software.
        bool isSoftware()
        {
            return (_info.flags & SDL_RENDERER_SOFTWARE) != 0;
        }

        /// Returns: true if this renderer is accelerated.
        bool isAccelerated()
        {
            return (_info.flags & SDL_RENDERER_ACCELERATED) != 0;
        }

        /// Returns: true if this renderer can render to a texture.
        bool hasRenderToTexture()
        {
            return (_info.flags & SDL_RENDERER_TARGETTEXTURE) != 0;
        }

        /// Returns: true if this renderer support vertical synchronization.
        bool isVsyncEnabled()
        {
            return (_info.flags & SDL_RENDERER_PRESENTVSYNC) != 0;
        }

        /// Returns: Pretty string describing the renderer.
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
        Log _log;
        int _index;
        SDL_RendererInfo _info;
    }
}
