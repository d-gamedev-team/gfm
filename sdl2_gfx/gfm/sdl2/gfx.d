module gfm.sdl2.gfx;

import std.conv,
       std.string;

import derelict.sdl2.sdl,
       derelict.util.exception;

import derelict.sdl2.gfx.gfx,
       derelict.sdl2.gfx.primitives,
       derelict.sdl2.gfx.rotozoom;

import gfm.sdl2.sdl,
       gfm.sdl2.renderer,
       gfm.sdl2.surface,
       gfm.math.vector;

union ColorAndRGBA {
    uint rgba;
    struct { ubyte r, g, b, a; };
}

/// Collection of graphic primitives rendering functions that can be applied onto the assigned SDL2Renderer.
final class SDL2Graphics
{
    public
    {
        /// Creates a SDL2_gfx function call wrapper which targets a renderer.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2Renderer renderer)
        {
            _renderer = renderer;
            try
            {
                DerelictSDL2Gfx.load();
            }
            catch(DerelictException e)
            {
                throw new SDL2Exception(e.msg);
            }
        }

        /// Gets the color used by the renderer for drawing operations and stores it for graphics operations.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetRenderDrawColor)
        /// Throws: $(D SDL2Exception) on error.
        uint getColor()
        {
            if (0 != SDL_GetRenderDrawColor(_renderer._renderer, &color.r, &color.g, &color.b, &color.a))
                _renderer._sdl2.throwSDL2Exception("SDL_GetRenderDrawColor");

            return color.rgba;
        }

        /// Sets the color used for graphics operations.
        void setColor(int r, int g, int b, int a = 255)
        {
            color.r = to!ubyte(r);
            color.g = to!ubyte(g);
            color.b = to!ubyte(b);
            color.a = to!ubyte(a);
        }

        /// Draw a line.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawLine(int x1, int y1, int x2, int y2, bool antialias)
        {
            if (antialias) {
                if (0 != aalineColor(_renderer._renderer, to!short(x1), to!short(y1), to!short(x2), to!short(y2), color.rgba))
                    _renderer._sdl2.throwSDL2Exception("aalineColor");
            } else {
                _renderer.drawLine(x1, y1, x2, y2);
            }
        }

        /// Draw rounded-corner rectangle.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawRoundedRect(int x, int y, int width, int height, int cornerArc)
        {
            if (0 != roundedRectangleColor(_renderer._renderer, to!short(x), to!short(y), to!short(x + width), to!short(y + height), to!short(cornerArc), color.rgba))
                _renderer._sdl2.throwSDL2Exception("roundedRectangleColor");
        }

        /// Draw a filled rounded-corner rectangle.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void fillRoundedRect(int x, int y, int width, int height, int cornerArc)
        {
            if (0 != roundedBoxColor(_renderer._renderer, to!short(x), to!short(y), to!short(x + width), to!short(y + height), to!short(cornerArc), color.rgba))
                _renderer._sdl2.throwSDL2Exception("roundedBoxColor");
        }

        /// Draw pie.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawPie(int x, int y, int radius, int startDegree, int endDegree)
        {
            if (0 != pieColor(_renderer._renderer, to!short(x), to!short(y), to!short(radius), to!short(startDegree), to!short(endDegree), color.rgba))
                _renderer._sdl2.throwSDL2Exception("pieColor");
        }

        /// Draw filled pie.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void fillPie(int x, int y, int radius, int startDegree, int endDegree)
        {
            if (0 != filledPieColor(_renderer._renderer, to!short(x), to!short(y), to!short(radius), to!short(startDegree), to!short(endDegree), color.rgba))
                _renderer._sdl2.throwSDL2Exception("filledPieColor");
        }

        /// Draw a circle.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawCircle(int x, int y, int radius, bool antialias)
        {
            if (antialias) {
                if (0 != aacircleColor(_renderer._renderer, to!short(x), to!short(y), to!short(radius), color.rgba))
                    _renderer._sdl2.throwSDL2Exception("aacircleColor");
            } else {
                if (0 != circleColor(_renderer._renderer, to!short(x), to!short(y), to!short(radius), color.rgba))
                    _renderer._sdl2.throwSDL2Exception("circleColor");
            }
        }

        /// Draw a filled circle.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void fillCircle(int x, int y, int radius)
        {
            if (0 != filledCircleColor(_renderer._renderer, to!short(x), to!short(y), to!short(radius), color.rgba))
                _renderer._sdl2.throwSDL2Exception("circleColor");
        }

        /// Draw a ellipse.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawEllipse(int x, int y, int radiusx, int radiusy, bool antialias)
        {
            if (antialias) {
                if (0 != aaellipseColor(_renderer._renderer, to!short(x), to!short(y), to!short(radiusx), to!short(radiusy), color.rgba))
                    _renderer._sdl2.throwSDL2Exception("aaellipseColor");
            } else {
                if (0 != ellipseColor(_renderer._renderer, to!short(x), to!short(y), to!short(radiusx), to!short(radiusy), color.rgba))
                    _renderer._sdl2.throwSDL2Exception("ellipseColor");
            }
        }

        /// Draw a filled ellipse.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void fillEllipse(int x, int y, int radiusx, int radiusy)
        {
            if (0 != filledEllipseColor(_renderer._renderer, to!short(x), to!short(y), to!short(radiusx), to!short(radiusy), color.rgba))
                _renderer._sdl2.throwSDL2Exception("filledEllipseColor");
        }

        /// Draw a trigon.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawTrigon(int x1, int y1, int x2, int y2, int x3, int y3, bool antialias)
        {
            if (antialias) {
                if (0 != aatrigonColor(_renderer._renderer, to!short(x1), to!short(y1), to!short(x2), to!short(y2), to!short(x3), to!short(y3), color.rgba))
                    _renderer._sdl2.throwSDL2Exception("aatrigonColor");
            } else {
                if (0 != trigonColor(_renderer._renderer, to!short(x1), to!short(y1), to!short(x2), to!short(y2), to!short(x3), to!short(y3), color.rgba))
                    _renderer._sdl2.throwSDL2Exception("trigonColor");
            }
        }

        /// Draw a filled trigon.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void fillTrigon(int x1, int y1, int x2, int y2, int x3, int y3)
        {
            if (0 != filledTrigonColor(_renderer._renderer, to!short(x1), to!short(y1), to!short(x2), to!short(y2), to!short(x3), to!short(y3), color.rgba))
                _renderer._sdl2.throwSDL2Exception("filledTrigonColor");
        }

        /// Draw arc.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawArc(int x, int y, int radius, int startDegree, int endDegree)
        {
            if (0 != arcColor(_renderer._renderer, to!short(x), to!short(y), to!short(radius), to!short(startDegree), to!short(endDegree), color.rgba))
                _renderer._sdl2.throwSDL2Exception("arcColor");
        }

        /// Draw polygon.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawPolygon(vec2i[] vertexes, bool antialias)
        {
            short[] vx, vy;
            foreach (v; vertexes) {
                vx ~= to!short(v.x);
                vy ~= to!short(v.y);
            }
            if (antialias) {
                if (0 != aapolygonColor(_renderer._renderer, vx.ptr, vy.ptr, vx.length, color.rgba))
                    _renderer._sdl2.throwSDL2Exception("aapolygonColor");
            } else {
                if (0 != polygonColor(_renderer._renderer, vx.ptr, vy.ptr, vx.length, color.rgba))
                    _renderer._sdl2.throwSDL2Exception("polygonColor");
            }
        }

        /// Draw a filled polygon.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void fillPolygon(vec2i[] vertexes)
        {
            short[] vx, vy;
            foreach (v; vertexes) {
                vx ~= to!short(v.x);
                vy ~= to!short(v.y);
            }
            if (0 != filledPolygonColor(_renderer._renderer, vx.ptr, vy.ptr, vx.length, color.rgba))
                _renderer._sdl2.throwSDL2Exception("filledPolygonColor");
        }

        /// Draw a textured polygon.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawTexturedPolygon(vec2i[] vertexes, SDL2Surface* surface, int offsetx, int offsety)
        {
            short[] vx, vy;
            foreach (v; vertexes) {
                vx ~= to!short(v.x);
                vy ~= to!short(v.y);
            }
            if (texturedPolygon(_renderer._renderer, vx.ptr, vy.ptr, vx.length, surface._surface, offsetx, offsety) < 0)
                _renderer._sdl2.throwSDL2Exception("texturedPolygon");
        }

        /// Draw a bezier curve with alpha blending.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawBezier(vec2i[] vertexes, int interpolationSteps = 2)
        {
            short[] vx, vy;
            foreach (v; vertexes) {
                vx ~= to!short(v.x);
                vy ~= to!short(v.y);
            }
            if (0 != bezierColor(_renderer._renderer, vx.ptr, vy.ptr, vx.length, to!uint(interpolationSteps), color.rgba))
                _renderer._sdl2.throwSDL2Exception("bezierColor");
        }

        /// Draw a thick line with alpha blending.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawThickLine(int x1, int y1, int x2, int y2, int width)
        {
            if (0 != thickLineColor(_renderer._renderer, to!short(x1), to!short(y1), to!short(x2), to!short(y2), to!uint(width), color.rgba))
                _renderer._sdl2.throwSDL2Exception("circleColor");
        }

        /+
         +  These should not be used in favor of SDL2_ttf but are here for reference.
         + 
        /// Set the current font.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void setFont(void* fontdata, int cw, int ch)
        {
            if (0 != gfxPrimitivesSetFont(fontdata, cw, ch))
                _renderer._sdl2.throwSDL2Exception("gfxPrimitivesSetFont");
            if (0 != gfxPrimitivesSetFontRotation(rotation))
                _renderer._sdl2.throwSDL2Exception("gfxPrimitivesSetFontRotation");
        }

        /// Draw a character in the current font.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawCharacter(int x, int y, char character)
        {
            if (0 != characterColor(_renderer._renderer, to!short(x), to!short(y), character, color.rgba))
                _renderer._sdl2.throwSDL2Exception("characterColor");
        }

        /// Draw a text with the current font.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawText(int x, int y, string text)
        {
            if (0 != stringColor(_renderer._renderer, to!short(x), to!short(y), text.toStringz(), color.rgba))
                _renderer._sdl2.throwSDL2Exception("stringColor");
        }
        +/

        ColorAndRGBA color;
    }

    private
    {
        SDL2Renderer _renderer;
    }
}

/// Collection of rotate and zoom functions that can be applied onto the assigned SDL2Surface.
final class SDL2Rotozoomer
{
    public
    {
        /// Creates a SDL2_gfx function call wrapper which targets a surface.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2Surface surface)
        {
            _surface = surface;
            try
            {
                DerelictSDL2Gfx.load();
            }
            catch(DerelictException e)
            {
                throw new SDL2Exception(e.msg);
            }
        }

        /// Rotate the surface.
        /// Automatically uses the faster rotateSurface90Degrees if applicable.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__rotozoom_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void rotate(double angle, int smooth)
        {
            if (angle % 90.0 == 0) {
                auto s = rotateSurface90Degrees(_surface._surface, to!int(angle / 90.0));
                if (s is null)
                    _surface._sdl2.throwSDL2Exception("rotateSurface90Degrees");
                replaceSurfaceHandle(s);
            } else {
                rotozoom(angle, 1.0, 1.0, smooth);
            }
        }

        /// Rotate and zoom the surface.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__rotozoom_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void rotozoom(double angle, double zoomx, double zoomy, int smooth)
        {
            auto s = rotozoomSurfaceXY(_surface._surface, angle, zoomx, zoomy, smooth);
            if (s is null)
                _surface._sdl2.throwSDL2Exception("rotozoomSurfaceXY");
            replaceSurfaceHandle(s);
        }

        /// Zoom the surface.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__rotozoom_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void zoom(double zoomx, double zoomy, int smooth)
        {
            auto s = zoomSurface(_surface._surface, zoomx, zoomy, smooth);
            if (s is null)
                _surface._sdl2.throwSDL2Exception("zoomSurface");
            replaceSurfaceHandle(s);
        }

        /// Shrink the surface.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__rotozoom_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void shrink(int factorx, int factory)
        {
            auto s = shrinkSurface(_surface._surface, factorx, factory);
            if (s is null)
                _surface._sdl2.throwSDL2Exception("shrinkSurface");
            replaceSurfaceHandle(s);
        }
    }
    
    private
    {
        void replaceSurfaceHandle(SDL_Surface* handle)
        {
            if (_surface._handleOwned == SDL2Surface.Owned.YES)
                SDL_FreeSurface(_surface._surface);
            _surface._surface = handle;
            _surface._handleOwned = SDL2Surface.Owned.YES;
        }

        SDL2Surface _surface;
    }
}
