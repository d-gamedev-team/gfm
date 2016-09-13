module gfm.sdl2.window;

import std.string;

import derelict.sdl2.sdl;

import std.experimental.logger;

import gfm.sdl2.sdl,
       gfm.sdl2.surface,
       gfm.sdl2.mouse,
       gfm.sdl2.keyboard;


/// SDL Window wrapper.
/// There is two ways to receive events, either by polling a SDL2 object,
/// or by overriding the event callbacks.
final class SDL2Window
{
    public
    {
        /// Creates a SDL window which targets a window.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_CreateWindow)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2 sdl2, int x, int y, int width, int height, int flags)
        {
            _sdl2 = sdl2;
            _logger = sdl2._logger;
            _surface = null;
            _glContext = null;
            _surfaceMustBeRenewed = false;

            bool OpenGL = (flags & SDL_WINDOW_OPENGL) != 0;
            _window = SDL_CreateWindow(toStringz(""), x, y, width, height, flags);
            if (_window == null)
			{
				string message = "SDL_CreateWindow failed: " ~ _sdl2.getErrorString().idup;
                throw new SDL2Exception(message);
			}

            _id = SDL_GetWindowID(_window);

            if (OpenGL)
                _glContext = new SDL2GLContext(this);
        }

        /// Creates a SDL window from anexisting handle.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_CreateWindowFrom)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2 sdl2, void* windowData)
        {
            _sdl2 = sdl2;
            _logger = sdl2._logger;
            _surface = null;
            _glContext = null;
            _surfaceMustBeRenewed = false;
             _window = SDL_CreateWindowFrom(windowData);
             if (_window == null)
             {
                 string message = "SDL_CreateWindowFrom failed: " ~ _sdl2.getErrorString().idup;
                 throw new SDL2Exception(message);
             }

            _id = SDL_GetWindowID(_window);
        }


        /// Releases the SDL resource.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_DestroyWindow)
        ~this()
        {
            if (_glContext !is null)
            {
                debug ensureNotInGC("SDL2Window");
                _glContext.destroy();
                _glContext = null;
            }

            if (_window !is null)
            {
                debug ensureNotInGC("SDL2Window");
                SDL_DestroyWindow(_window);
                _window = null;
            }
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetWindowFullscreen)
        /// Throws: $(D SDL2Exception) on error.
        final void setFullscreenSetting(uint flags)
        {
            if (SDL_SetWindowFullscreen(_window, flags) != 0)
                _sdl2.throwSDL2Exception("SDL_SetWindowFullscreen");
        }

        /// Returns: X window coordinate.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetWindowPosition)
        final int getX()
        {
            return getPosition().x;
        }

        /// Returns: Y window coordinate.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetWindowPosition)
        final int getY()
        {
            return getPosition().y;
        }

        /// Gets information about the window's display mode
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_GetWindowDisplayMode)
        final SDL_DisplayMode getWindowDisplayMode()
        {
            SDL_DisplayMode mode;
            if (0 != SDL_GetWindowDisplayMode(_window, &mode))
                _sdl2.throwSDL2Exception("SDL_GetWindowDisplayMode");
            return mode;
        }

        /// Returns: Window coordinates.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetWindowPosition)
        final SDL_Point getPosition()
        {
            int x, y;
            SDL_GetWindowPosition(_window, &x, &y);
            return SDL_Point(x, y);
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetWindowPosition)
        final void setPosition(int positionX, int positionY)
        {
            SDL_SetWindowPosition(_window, positionX, positionY);
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetWindowSize)
        final void setSize(int width, int height)
        {
            SDL_SetWindowSize(_window, width, height);
        }

        /// Get the minimum size setting for the window
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_GetWindowMinimumSize)
        final SDL_Point getMinimumSize()
        {
            SDL_Point p;
            SDL_GetWindowMinimumSize(_window, &p.x, &p.y);
            return p;
        }

        /// Get the minimum size setting for the window
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_SetWindowMinimumSize)
        final void setMinimumSize(int width, int height)
        {
            SDL_SetWindowMinimumSize(_window, width, height);
        }

        /// Get the minimum size setting for the window
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_GetWindowMaximumSize)
        final SDL_Point getMaximumSize()
        {
            SDL_Point p;
            SDL_GetWindowMaximumSize(_window, &p.x, &p.y);
            return p;
        }

        /// Get the minimum size setting for the window
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_SetWindowMaximumSize)
        final void setMaximumSize(int width, int height)
        {
            SDL_SetWindowMaximumSize(_window, width, height);
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetWindowSize)
        /// Returns: Window size in pixels.
        final SDL_Point getSize()
        {
            int w, h;
            SDL_GetWindowSize(_window, &w, &h);
            return SDL_Point(w, h);
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetWindowIcon)
        final void setIcon(SDL2Surface icon)
        {
            SDL_SetWindowIcon(_window, icon.handle());
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetWindowBordered)
        final void setBordered(bool bordered)
        {
            SDL_SetWindowBordered(_window, bordered ? SDL_TRUE : SDL_FALSE);
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetWindowSize)
        /// Returns: Window width in pixels.
        final int getWidth()
        {
            int w, h;
            SDL_GetWindowSize(_window, &w, &h);
            return w;
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetWindowSize)
        /// Returns: Window height in pixels.
        final int getHeight()
        {
            int w, h;
            SDL_GetWindowSize(_window, &w, &h);
            return h;
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_SetWindowTitle)
        final void setTitle(string title)
        {
            SDL_SetWindowTitle(_window, toStringz(title));
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_ShowWindow)
        final void show()
        {
            SDL_ShowWindow(_window);
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_HideWindow)
        final void hide()
        {
            SDL_HideWindow(_window);
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_MinimizeWindow)
        final void minimize()
        {
            SDL_MinimizeWindow(_window);
        }

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_MaximizeWindow)
        final void maximize()
        {
            SDL_MaximizeWindow(_window);
        }

        /// Returns: Window surface.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetWindowSurface)
        /// Throws: $(D SDL2Exception) on error.
        final SDL2Surface surface()
        {
            if (!hasValidSurface())
            {
                SDL_Surface* internalSurface = SDL_GetWindowSurface(_window);
                if (internalSurface is null)
                    _sdl2.throwSDL2Exception("SDL_GetWindowSurface");

                // renews surface as needed
                _surfaceMustBeRenewed = false;
                _surface = new SDL2Surface(_sdl2, internalSurface,  SDL2Surface.Owned.NO);
            }
            return _surface;
        }

        /// Submit changes to the window surface.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_UpdateWindowSurface)
        /// Throws: $(D SDL2Exception) on error.
        final void updateSurface()
        {
            if (!hasValidSurface())
                surface();

            int res = SDL_UpdateWindowSurface(_window);
            if (res != 0)
                _sdl2.throwSDL2Exception("SDL_UpdateWindowSurface");

        }

        /// Returns: Window ID.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetWindowID)
        final int id()
        {
            return _id;
        }

        /// Returns: System-specific window information, useful to use a third-party rendering library.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetWindowWMInfo)
        /// Throws: $(D SDL2Exception) on error.
        SDL_SysWMinfo getWindowInfo()
        {
            SDL_SysWMinfo info;
            SDL_VERSION(&info.version_);
            int res = SDL_GetWindowWMInfo(_window, &info);
            if (res != SDL_TRUE)
                _sdl2.throwSDL2Exception("SDL_GetWindowWMInfo");
            return info;
        }

        /// Swap OpenGL buffers.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GL_SwapWindow)
        /// Throws: $(D SDL2Exception) on error.
        void swapBuffers()
        {
            if (_glContext is null)
                throw new SDL2Exception("swapBuffers failed: not an OpenGL window");
            SDL_GL_SwapWindow(_window);
        }
    }

    package
    {
        SDL2 _sdl2;
        SDL_Window* _window;
    }

    private
    {
        Logger _logger;
        SDL2Surface _surface;
        SDL2GLContext _glContext;
        uint _id;

        bool _surfaceMustBeRenewed;

        bool hasValidSurface()
        {
            return (!_surfaceMustBeRenewed) && (_surface !is null);
        }
    }
}

/// SDL OpenGL context wrapper. You probably don't need to use it directly.
final class SDL2GLContext
{
    public
    {
        /// Creates an OpenGL context for a given SDL window.
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

        /// Release the associated SDL ressource.
        void close()
        {
            if (_initialized)
            {
                // work-around Issue #19
                // SDL complains with log message "wglMakeCurrent(): The handle is invalid."
                // in the SDL_DestroyWindow() call if we destroy the OpenGL context before-hand
                //
                // SDL_GL_DeleteContext(_context);
                _initialized = false;
            }
        }

        /// Makes this OpenGL context current.
        /// Throws: $(D SDL2Exception) on error.
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

