module gfm.sdl2.renderer;

import std.string;

import derelict.sdl2.sdl;

import std.experimental.logger;

import gfm.sdl2.sdl,
       gfm.sdl2.window,
       gfm.sdl2.texture,
       gfm.sdl2.surface;

/// SDL Renderer wrapper.
final class SDL2Renderer
{
    public
    {
        /// Creates a SDL renderer which targets a window.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_CreateRenderer)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2Window window, int flags = 0)
        {
            _sdl2 = window._sdl2;
            _renderer = SDL_CreateRenderer(window._window, -1, flags);
            if (_renderer is null)
                _sdl2.throwSDL2Exception("SDL_CreateRenderer");

            readCapabilities();
        }

        /// Create a software renderer which targets a surface.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_CreateSoftwareRenderer)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2Surface surface)
        {
            _sdl2 = surface._sdl2;
            _renderer = SDL_CreateSoftwareRenderer(surface._surface);
            if (_renderer is null)
                _sdl2.throwSDL2Exception("SDL_CreateSoftwareRenderer");

            readCapabilities();
        }

        /// Releases the SDL ressource.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_DestroyRenderer)
        ~this()
        {
            if (_renderer !is null)
            {
                debug ensureNotInGC("SDL2Renderer");
                SDL_DestroyRenderer(_renderer);
                _renderer = null;
            }
        }

        /// Clear the current rendering target with the drawing color.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderClear)
        /// Throws: $(D SDL2Exception) on error.
        void clear()
        {
            if (0 != SDL_RenderClear(_renderer))
                _sdl2.throwSDL2Exception("SDL_RenderClear");
        }

        /// Update the screen with rendering performed.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderPresent)
        void present()
        {
            SDL_RenderPresent(_renderer);
        }

        /// Sets the color used for drawing operations.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetRenderDrawColor)
        /// Throws: $(D SDL2Exception) on error.
        void setColor(int r, int g, int b, int a = 255)
        {
            if (0 != SDL_SetRenderDrawColor(_renderer, cast(ubyte)r, cast(ubyte)g, cast(ubyte)b, cast(ubyte)a))
                _sdl2.throwSDL2Exception("SDL_SetRenderDrawColor");
        }

        /// Sets the window drawing area.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderSetViewport)
        /// Throws: $(D SDL2Exception) on error.
        void setViewport(int x, int y, int w, int h)
        {
            SDL_Rect r = SDL_Rect(x, y, w, h);
            if (0 != SDL_RenderSetViewport(_renderer, &r))
                _sdl2.throwSDL2Exception("SDL_RenderSetViewport");
        }

        /// Sets the whole window as drawing area.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderSetViewport)
        /// Throws: $(D SDL2Exception) on error.
        void setViewportFull()
        {
            if (0 != SDL_RenderSetViewport(_renderer, null))
                _sdl2.throwSDL2Exception("SDL_RenderSetViewport");
        }

        /// Sets the scale of the renderer.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderSetScale)
        /// Throws: $(D SDL2Exception) on error.
        void setScale(float x, float y)
        {
            if (0 != SDL_RenderSetScale(_renderer, x, y))
                _sdl2.throwSDL2Exception("SDL_RenderSetScale");
        }

        /// Sets a device independent resolution of the renderer.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderSetLogicalSize)
        /// Throws: $(D SDL2Exception) on error.
        void setLogicalSize(int w, int h)
        {
            if (0 != SDL_RenderSetLogicalSize(_renderer, w, h))
                _sdl2.throwSDL2Exception("SDL_RenderSetLogicalSize");
        }

        /// Sets SDL blend mode.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetRenderDrawBlendMode)
        /// Throws: $(D SDL2Exception) on error.
        void setBlend(int blendMode)
        {
            if (0 != SDL_SetRenderDrawBlendMode(_renderer, blendMode))
                _sdl2.throwSDL2Exception("SDL_SetRenderDrawBlendMode");
        }

        /// Draw a line.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderDrawLine)
        /// Throws: $(D SDL2Exception) on error.
        void drawLine(int x1, int y1, int x2, int y2)
        {
            if (0 != SDL_RenderDrawLine(_renderer, x1, y1, x2, y2))
                _sdl2.throwSDL2Exception("SDL_RenderDrawLine");

        }

        /// Draw several lines at once.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderDrawLines)
        /// Throws: $(D SDL2Exception) on error.
        void drawLines(SDL_Point[] points)
        {
            if (0 != SDL_RenderDrawLines(_renderer, points.ptr, cast(int)(points.length)))
                _sdl2.throwSDL2Exception("SDL_RenderDrawLines");
        }

        /// Draw a point.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderDrawPoint)
        /// Throws: $(D SDL2Exception) on error.
        void drawPoint(int x, int y)
        {
            if (0 != SDL_RenderDrawPoint(_renderer, x, y))
                _sdl2.throwSDL2Exception("SDL_RenderDrawPoint");
        }

        /// Draw several point at once.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderDrawPoints)
        /// Throws: $(D SDL2Exception) on error.
        void drawPoints(SDL_Point[] points)
        {
            if (0 != SDL_RenderDrawPoints(_renderer, points.ptr, cast(int)(points.length)))
                _sdl2.throwSDL2Exception("SDL_RenderDrawPoints");
        }

        /// Draw a rectangle outline.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderDrawRect)
        /// Throws: $(D SDL2Exception) on error.
        void drawRect(int x, int y, int width, int height)
        {
            SDL_Rect r = SDL_Rect(x, y, width, height);
            if (0 != SDL_RenderDrawRect(_renderer, &r))
                _sdl2.throwSDL2Exception("SDL_RenderDrawRect");
        }

        /// Draw a filled rectangle.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderFillRect)
        /// Throws: $(D SDL2Exception) on error.
        void fillRect(int x, int y, int width, int height)
        {
            SDL_Rect r = SDL_Rect(x, y, width, height);
            if (0 != SDL_RenderFillRect(_renderer, &r))
                _sdl2.throwSDL2Exception("SDL_RenderFillRect");
        }

        /// Blit a rectangle from a texture.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderCopy)
        /// Throws: $(D SDL2Exception) on error.
        void copy(SDL2Texture texture, SDL_Rect srcRect, SDL_Rect dstRect)
        {
            if (0 != SDL_RenderCopy(_renderer, texture._handle, &srcRect, &dstRect))
                _sdl2.throwSDL2Exception("SDL_RenderCopy");
        }

        /// Draws a whole texture.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderCopy)
        /// Throws: $(D SDL2Exception) on error.
        void copy(SDL2Texture texture, int x, int y)
        {
            int w = texture.width();
            int h = texture.height();
            SDL_Rect source = SDL_Rect(0, 0, w, h);
            SDL_Rect dest = SDL_Rect(x, y, w, h);
            copy(texture, source, dest);
        }

        /// Blits a rectangle from a texture and apply rotation/reflection.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_RenderCopyEx)
        /// Throws: $(D SDL2Exception) on error.
        void copyEx(SDL2Texture texture, SDL_Rect srcRect, SDL_Rect dstRect, double rotangle, SDL_Point* rotcenter, SDL_RendererFlip flip)
        {
            if (0 != SDL_RenderCopyEx(_renderer, texture._handle, &srcRect, &dstRect, rotangle, rotcenter, flip))
                _sdl2.throwSDL2Exception("SDL_RenderCopyEx");
        }

        /// Set a texture as the current rendering target.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetRenderTarget)
        /// Throws: $(D SDL2Exception) on error.
        void setRenderTarget(SDL2Texture texture)
        {
            if (0 != SDL_SetRenderTarget(_renderer, texture is null ? cast(SDL_Texture*)0 : texture._handle))
                _sdl2.throwSDL2Exception("SDL_SetRenderTarget");
        }

        /// Returns: Renderer information.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetRendererInfo)
        /// Throws: $(D SDL2Exception) on error.
        SDL2RendererInfo info()
        {
            return _info;
        }

        /// Returns: SDL handle.
        SDL_Renderer* handle()
        {
            return _renderer;
        }
    }

    package
    {
        SDL2 _sdl2;
        SDL_Renderer* _renderer;
        SDL2RendererInfo _info;
    }

    private
    {
        void readCapabilities()
        {
            SDL_RendererInfo info;
            int res = SDL_GetRendererInfo(_renderer, &info);
            if (res != 0)
                _sdl2.throwSDL2Exception("SDL_GetRendererInfo");
            _info = new SDL2RendererInfo(info);
        }
    }
}

/// SDL Renderer information.
final class SDL2RendererInfo
{
    public
    {
        this(SDL_RendererInfo info)
        {
            _info = info;
        }

        /// Returns: Renderer name.
        const(char)[] name()
        {
            return fromStringz(_info.name);
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

        /// Returns: the maximum supported texture width
        int maxTextureWidth()
        {
            return _info.max_texture_width;
        }

        /// Returns: the maximum supported texture height
        int maxTextureHeight()
        {
            return _info.max_texture_height;
        }

        /// Returns: Pretty string describing the renderer.
        override string toString()
        {
            string res = format("renderer: %s [flags:", name());
            if (isSoftware()) res ~= " software";
            if (isAccelerated()) res ~= " accelerated";
            if (hasRenderToTexture()) res ~= " render-to-texture";
            if (isVsyncEnabled()) res ~= " vsync";
            res ~= "]\n";
            res ~= format("max. supported texture size: %sx%s", maxTextureWidth(), maxTextureHeight());
            return res;
        }
    }

    private
    {
        SDL_RendererInfo _info;
    }
}
