module gfm.sdl2.window;

import std.string;

import derelict.sdl2.sdl;

import std.experimental.logger;

import gfm.sdl2.sdl,
       gfm.sdl2.surface,
       gfm.sdl2.mouse,
       gfm.sdl2.keyboard;


/// An interface for mouse events.
interface KeyboardListener
{
    /// Called whenever a keyboard button is pressed.
    void onKeyDown(uint timestamp, SDL2Keyboard keyboard, SDL_Keycode key);

    /// Called whenever a keyboard button is released.
    void onKeyUp(uint timestamp, SDL2Keyboard keyboard, SDL_Keycode key);
}

/// An interface for mouse events.
interface MouseListener
{
    /// Called whenever the mouse moves.
    void onMouseMove(uint timestamp, SDL2Mouse mouseState);

    /// Called whenever a mouse button is pressed.
    void onMouseButtonPressed(uint timestamp, SDL2Mouse mouseState, int button, bool isDoubleClick);

    /// Called whenever a mouse button is released.
    void onMouseButtonReleased(uint timestamp, SDL2Mouse mouseState, int button);

    /// Called whenever the mouse wheel is scrolled.
    void onMouseWheel(uint timestamp, SDL2Mouse mouseState, int wheelDeltaX, int wheelDeltaY);
}

/// SDL Window wrapper.
/// There is two ways to receive events, either by polling a SDL2 object, 
/// or by overriding the event callbacks.
class SDL2Window : KeyboardListener, MouseListener
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

            if (OpenGL)
            {
                // put here your desired context profile and version

                //SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
                //SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
                //SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
                //SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_DEBUG_FLAG | SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);

                // force debug OpenGL context creation in debug mode
                debug
                {
                    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_DEBUG_FLAG);
                }
            }

            _window = SDL_CreateWindow(toStringz(""), x, y, width, height, flags);
            if (_window == null)
                throw new SDL2Exception("SDL_CreateWindow failed: " ~ _sdl2.getErrorString());

            _id = SDL_GetWindowID(_window);

            // register window for event dispatch
            _sdl2.registerWindow(this);

            if (OpenGL)
                _glContext = new SDL2GLContext(this);
        }

        /// Releases the SDL resource.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_DestroyWindow)
        final void close()
        {
            if (_glContext !is null)
            {
                _glContext.close();
                _glContext = null;
            }

            if (_window !is null)
            {
                _sdl2.unregisterWindow(this);
                SDL_DestroyWindow(_window);
                _window = null;
            }
        }

        ///
        ~this()
        {
            close();
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

        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetWindowSize)
        /// Returns: Window size in pixels.
        final SDL_Point getSize()
        {
            int w, h;
            SDL_GetWindowSize(_window, &w, &h);
            return SDL_Point(w, h);
        }

        /// See_also: $(LINK https://wiki.libsdl.org/SDL_SetWindowIcon)
        final void setIcon(SDL2Surface icon)
        {
                SDL_SetWindowIcon( _window, icon.handle() );
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

        // override these function, they are event callbacks

        ///
        void onShow()
        {
        }

        ///
        void onHide()
        {
        }

        ///
        void onExposed()
        {
            _surfaceMustBeRenewed = true;
        }

        ///
        void onMove(int x, int y)
        {        
        }
        
        ///
        void onResized(int width, int height)
        {
            _surfaceMustBeRenewed = true;
        }

        ///
        void onSizeChanged()
        {
            _surfaceMustBeRenewed = true;
        }

        ///
        void onMinimized()
        {
            _surfaceMustBeRenewed = true;
        }

        ///
        void onMaximized()
        {
            _surfaceMustBeRenewed = true;
        }

        ///
        void onRestored()
        {            
        }

        ///
        void onEnter()
        {
        }
        
        ///
        void onLeave()
        {
        }

        ///
        void onFocusGained()
        {
        }

        ///
        void onFocusLost()
        {
        }
        
        ///
        void onClose()
        {
        }

        // Mouse event callbacks

        override void onMouseMove(uint timestamp, SDL2Mouse mouseState)
        {
            // do nothing by default
        }

        override void onMouseButtonPressed(uint timestamp, SDL2Mouse mouseState, int button, bool isDoubleClick)
        {
            // do nothing by default
        }

        override void onMouseButtonReleased(uint timestamp, SDL2Mouse mouseState, int button)
        {
            // do nothing by default
        }

        override void onMouseWheel(uint timestamp, SDL2Mouse mouseState, int wheelDeltaX, int wheelDeltaY)
        {
            // do nothing by default
        }

        // Keybard event callbacks

        override void onKeyDown(uint timestamp, SDL2Keyboard keyboard, SDL_Keycode key)
        {
            // do nothing by default
        }

        override void onKeyUp(uint timestamp, SDL2Keyboard keyboard, SDL_Keycode key)
        {
            // do nothing by default
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
        /// Creates for a given SDL window. 
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

