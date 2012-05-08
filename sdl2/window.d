module gfm.sdl2.window;

import std.string;

import derelict.sdl2.sdl;

import gfm.sdl2.sdl;
import gfm.sdl2.surface;
import gfm.sdl2.exception;
import gfm.math.smallvector;


final class SDL2Window
{
    public
    {
        enum Flags
        {
            FULLSCREEN,
            SHOWN,
            OPENGL
        }

        // initially invisible
        this(SDL2 sdl2, string title, vec2i dimension, bool OpenGL)
        {
            _sdl2 = sdl2;
            _surface = null;
            int flags = 0;
            if (OpenGL)
                flags |= SDL_WINDOW_OPENGL;

            _window = SDL_CreateWindow(toStringz(title), 
                                       SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                       dimension.x, dimension.y,
                                       flags);
            if (_window == null)
                throw new SDL2Exception("SDL_CreateWindow failed: " ~ _sdl2.getErrorString());

            _id = SDL_GetWindowID(_window);
        }

        ~this()
        {           
            assert(SDL_DestroyWindow !is null);
            SDL_DestroyWindow(_window);
        }

        void setPosition(vec2i position)
        {
            SDL_SetWindowPosition(_window, position.x, position.y);
        }

        void setSize(vec2i size)
        {
            SDL_SetWindowSize(_window, size.x, size.y);
        }

        void show()
        {
            SDL_ShowWindow(_window);
        }

        void hide()
        {
            SDL_HideWindow(_window);
        }

        void minimize()
        {
            SDL_MinimizeWindow(_window);
        }

        void maximize()
        {
            SDL_MaximizeWindow(_window);
        }

        SDL2Surface surface()
        {
            if (_surface is null)
            {
                SDL_Surface* internalSurface = SDL_GetWindowSurface(_window);
                if (internalSurface is null)
                    _sdl2.throwSDL2Exception("SDL_GetWindowSurface");

                _surface = new SDL2Surface(_sdl2, internalSurface);
            }
            return _surface;
        }

        void updateSurface()
        {
            surface();
            int res = SDL_UpdateWindowSurface(_window);
            if (res != 0)
                _sdl2.throwSDL2Exception("SDL_UpdateWindowSurface");
            
        }

        int id()
        {
            return _id;
        }
    }

    private
    {
        SDL2 _sdl2;
        SDL_Window* _window;
        SDL2Surface _surface;
        uint _id;
    }
}
