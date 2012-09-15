module gfm.sdl2.glcontext;

import derelict.sdl2.sdl;

import gfm.sdl2.sdl,
       gfm.sdl2.window;


final class SDL2GLContext
{
    public
    {
        this(SDL2Window window)
        {
            _window = window;
            _context = SDL_GL_CreateContext(window._window);
            _initialized = true;
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_initialized)
            {
                SDL_GL_DeleteContext(_context);
                _initialized = false;
            }
        }

        void makeCurrent()
        {
            if (0 != SDL_GL_MakeCurrent(_window._window, _context))
                _window._sdl2.throwSDL2Exception("SDL_GL_MakeCurrent");
        }
    }

    package
    {
        SDL_GLContext _context;
        SDL2Window _window;
    }

    private
    {
        bool _initialized;
    }
}
