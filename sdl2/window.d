module gfm.sdl2.window;

import std.string;

import derelict.sdl2.sdl;

import gfm.sdl2.sdl;
import gfm.sdl2.surface;
import gfm.sdl2.exception;
import gfm.math.smallvector;
import gfm.common.log;
import gfm.sdl2.eventqueue;

class SDL2Window
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
        this(SDL2 sdl2, string title, vec2i dimension, bool OpenGL, bool resizable)
        {
            _sdl2 = sdl2;
            _log = sdl2._log;
            _surface = null;
            _surfaceMustBeRenewed = false;
            int flags = 0;
            if (OpenGL)
                flags |= SDL_WINDOW_OPENGL;

            if (resizable)
                flags |= SDL_WINDOW_RESIZABLE;

            _window = SDL_CreateWindow(toStringz(title), 
                                       SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                       dimension.x, dimension.y,
                                       flags);
            if (_window == null)
                throw new SDL2Exception("SDL_CreateWindow failed: " ~ _sdl2.getErrorString());

            _id = SDL_GetWindowID(_window);
        }

        final void close()
        {
            if (_window !is null)
            {
                SDL_DestroyWindow(_window);
                _window = null;
            }
        }

        ~this()
        {
            close();
        }

        final void setPosition(vec2i position)
        {
            SDL_SetWindowPosition(_window, position.x, position.y);
        }

        final void setSize(vec2i size)
        {
            SDL_SetWindowSize(_window, size.x, size.y);
        }

        final void show()
        {
            SDL_ShowWindow(_window);
        }

        final void hide()
        {
            SDL_HideWindow(_window);
        }

        final void minimize()
        {
            SDL_MinimizeWindow(_window);
        }

        final void maximize()
        {
            SDL_MaximizeWindow(_window);
        }

        final SDL2Surface surface()
        {
            if (!hasValidSurface())
            {
                SDL_Surface* internalSurface = SDL_GetWindowSurface(_window);
                if (internalSurface is null)
                    _sdl2.throwSDL2Exception("SDL_GetWindowSurface");

                // renews surface as needed
                _surfaceMustBeRenewed = false;
                _surface = new SDL2Surface(_sdl2, internalSurface);
            }
            return _surface;
        }

        final void updateSurface()
        {
            if (!hasValidSurface())
                surface();

            int res = SDL_UpdateWindowSurface(_window);
            if (res != 0)
                _sdl2.throwSDL2Exception("SDL_UpdateWindowSurface");
            
        }

        final int id()
        {
            return _id;
        }

        void onShow()
        {
            _log.info("onShow");
        }

        void onHide()
        {
            _log.info("onHide");
        }

        void onExposed()
        {
            _surfaceMustBeRenewed = true;
        }

        void onMove(int x, int y)
        {        
        }
        
        void onResized(int width, int height)
        {
            _surfaceMustBeRenewed = true;
        }

        void onSizeChanged()
        {
            _surfaceMustBeRenewed = true;
        }

        void onMinimized()
        {
            _surfaceMustBeRenewed = true;
        }

        void onMaximized()
        {
            _surfaceMustBeRenewed = true;
        }

        void onRestored()
        {            
        }

        void onEnter()
        {
        }
        
        void onLeave()
        {
        }
        
        void onFocusGained()
        {
        }

        void onFocusLost()
        {
        }
        
        void onClose()
        {
        }
    }

    private
    {
        SDL2 _sdl2;
        Log _log;
        SDL_Window* _window;
        SDL2Surface _surface;
        uint _id;

        bool _surfaceMustBeRenewed;

        bool hasValidSurface()
        {
            return (!_surfaceMustBeRenewed) && (_surface !is null);
        }
    }
}
