module gfm.sdl2.gfx;

import std.conv;

import derelict.sdl2.sdl,
       derelict.util.exception;

import derelict.sdl2.gfx.gfx,
       derelict.sdl2.gfx.primitives;

import gfm.sdl2.sdl,
       gfm.sdl2.renderer,
       gfm.math.vector;

/// Collection of graphics primitives and surface functions that can be called onto the specified SDL2Renderer.
final class SDL2Graphics
{
    public
    {
        /// Creates a SDL2_gfx wrapper which targets a renderer.
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

        /// Gets the current color set for drawing operations.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetRenderDrawColor)
        /// Throws: $(D SDL2Exception) on error.
        uint getColor()
        {
            union U {
                struct { ubyte r, g, b, a; };
                uint rgba;
            }
            U u;

            if (0 != SDL_GetRenderDrawColor(_renderer._renderer, &u.r, &u.g, &u.b, &u.a))
                _renderer._sdl2.throwSDL2Exception("SDL_GetRenderDrawColor");

            return u.rgba;
        }

        /+
int     roundedRectangleColor (SDL_Renderer *renderer, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 rad, Uint32 color)
    Draw rounded-corner rectangle with blending.
int     roundedBoxColor (SDL_Renderer *renderer, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 rad, Uint32 color)
    Draw rounded-corner box (filled rectangle) with blending.
int     boxColor (SDL_Renderer *renderer, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 color)
    Draw box (filled rectangle) with blending.
int     aalineColor (SDL_Renderer *renderer, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 color)
    Draw anti-aliased line with alpha blending.
int     arcColor (SDL_Renderer *renderer, Sint16 x, Sint16 y, Sint16 rad, Sint16 start, Sint16 end, Uint32 color)
    Arc with blending.
int     aacircleColor (SDL_Renderer *renderer, Sint16 x, Sint16 y, Sint16 rad, Uint32 color)
    Draw anti-aliased circle with blending.
int     ellipseColor (SDL_Renderer *renderer, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 color)
    Draw ellipse with blending.
int     aaellipseColor (SDL_Renderer *renderer, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 color)
    Draw anti-aliased ellipse with blending.
int     filledEllipseColor (SDL_Renderer *renderer, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 color)
    Draw filled ellipse with blending.
int     pieColor (SDL_Renderer *renderer, Sint16 x, Sint16 y, Sint16 rad, Sint16 start, Sint16 end, Uint32 color)
    Draw pie (outline) with alpha blending.
int     filledPieColor (SDL_Renderer *renderer, Sint16 x, Sint16 y, Sint16 rad, Sint16 start, Sint16 end, Uint32 color)
    Draw filled pie with alpha blending.
int     trigonColor (SDL_Renderer *renderer, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 color)
    Draw trigon (triangle outline) with alpha blending.
int     aatrigonColor (SDL_Renderer *renderer, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 color)
    Draw anti-aliased trigon (triangle outline) with alpha blending.
int     filledTrigonColor (SDL_Renderer *renderer, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 color)
    Draw filled trigon (triangle) with alpha blending.
int     polygon (SDL_Renderer *renderer, const Sint16 *vx, const Sint16 *vy, int n)
    Draw polygon with the currently set color and blend mode.
int     aapolygonColor (SDL_Renderer *renderer, const Sint16 *vx, const Sint16 *vy, int n, Uint32 color)
    Draw anti-aliased polygon with alpha blending.

int     filledPolygonRGBAMT (SDL_Renderer *renderer, const Sint16 *vx, const Sint16 *vy, int n, Uint8 r, Uint8 g, Uint8 b, Uint8 a, int **polyInts, int *polyAllocated)
    Draw filled polygon with alpha blending (multi-threaded capable).
int     filledPolygonColor (SDL_Renderer *renderer, const Sint16 *vx, const Sint16 *vy, int n, Uint32 color)
    Draw filled polygon with alpha blending.

int     texturedPolygonMT (SDL_Renderer *renderer, const Sint16 *vx, const Sint16 *vy, int n, SDL_Surface *texture, int texture_dx, int texture_dy, int **polyInts, int *polyAllocated)
    Draws a polygon filled with the given texture (Multi-Threading Capable).
int     texturedPolygon (SDL_Renderer *renderer, const Sint16 *vx, const Sint16 *vy, int n, SDL_Surface *texture, int texture_dx, int texture_dy)
    Draws a polygon filled with the given texture.

void    gfxPrimitivesSetFont (const void *fontdata, Uint32 cw, Uint32 ch)
    Sets or resets the current global font data.
void    gfxPrimitivesSetFontRotation (Uint32 rotation)
    Sets current global font character rotation steps.
int     characterColor (SDL_Renderer *renderer, Sint16 x, Sint16 y, char c, Uint32 color)
    Draw a character of the currently set font.
int     stringColor (SDL_Renderer *renderer, Sint16 x, Sint16 y, const char *s, Uint32 color)
    Draw a string in the currently set font.
+/

        /// Draw a circle.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void drawCircle(int x, int y, int radius)
        {
            if (0 != circleColor(_renderer._renderer, to!short(x), to!short(y), to!short(radius), getColor()))
                _renderer._sdl2.throwSDL2Exception("circleColor");
        }

        /// Draw a filled circle.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void fillCircle(int x, int y, int radius)
        {
            if (0 != filledCircleColor(_renderer._renderer, to!short(x), to!short(y), to!short(radius), getColor()))
                _renderer._sdl2.throwSDL2Exception("circleColor");
        }

        /// Draw a bezier curve with alpha blending.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void bezier(vec2i[] vectors, int interpolationSteps = 2)
        {
            short[] vx, vy;
            foreach (v; vectors) {
                vx ~= to!short(v.x);
                vy ~= to!short(v.y);
            }
            if (0 != bezierColor(_renderer._renderer, vx.ptr, vy.ptr, to!uint(vx.length), to!uint(interpolationSteps), getColor()))
                _renderer._sdl2.throwSDL2Exception("bezierColor");
        }

        /// Draw a thick line with alpha blending.
        /// See_also: $(LINK http://www.ferzkopp.net/Software/SDL2_gfx/Docs/html/_s_d_l2__gfx_primitives_8c.html)
        /// Throws: $(D SDL2Exception) on error.
        void thickLine(int x1, int y1, int x2, int y2, int width)
        {
            if (0 != thickLineColor(_renderer._renderer, to!short(x1), to!short(y1), to!short(x2), to!short(y2), to!uint(width), getColor()))
                _renderer._sdl2.throwSDL2Exception("circleColor");
        }
    }

    private
    {
        SDL2Renderer _renderer;
    }
}
