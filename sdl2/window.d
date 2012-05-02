module gfm.sdl2.window;

import std.string;

import derelict.sdl2.sdl;

import gfm.sdl2.sdl;
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

        void updateSurface()
        {
            int res = SDL_UpdateWindowSurface(_window);
            if (res != 0)
                throw new SDL2Exception("SDL_UpdateWindowSurface failed: " ~ _sdl2.getErrorString());
        }

        uint getId();
    }

    private
    {
        SDL2 _sdl2;
        SDL_Window* _window;
        uint _id;
    }
}
