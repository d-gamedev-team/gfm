module gfm.sdl2.mouse;

import derelict.sdl2.sdl;
import gfm.sdl2.sdl;
import gfm.sdl2.surface;

/// Holds SDL mouse state.
final class SDL2Mouse
{
    public
    {
        /// Returns: true if a specific mouse button defined by mask is pressed
        /// Example:
        /// --------------------
        /// // Check if the left mouse button is pressed
        /// if(_sdl2.mouse.isButtonPressed(SDL_BUTTON_LMASK))
        ///     ...
        /// --------------------
        bool isButtonPressed(int mask) pure const nothrow
        {
            return (_buttonState & mask) != 0;
        }

        /// Returns: X coordinate of mouse pointer.
        int x() pure const nothrow
        {
            return _x;
        }

        /// Returns: Y coordinate of mouse pointer.
        int y() pure const nothrow
        {
            return _y;
        }

        /// Returns: X relative movement on last motion event.
        int lastDeltaX() pure const nothrow
        {
            return _lastDeltaX;
        }

        /// Returns: Y relative movement on last motion event.
        int lastDeltaY() pure const nothrow
        {
            return _lastDeltaY;
        }

        /// Returns: Coordinates of mouse pointer.
        SDL_Point position() pure const nothrow
        {
            return SDL_Point(_x, _y);
        }

        /// Returns: Previous coordinates of mouse pointer. Useful in onMouseMove event callback.
        SDL_Point previousPosition() pure const nothrow
        {
            return SDL_Point(_x - _lastDeltaX, _y - _lastDeltaY);
        }

        /// Returns: How much was scrolled by X coordinate since the last call.
        int wheelDeltaX() nothrow
        {
            int value = _wheelX;
            _wheelX = 0;
            return value;
        }

        /// Returns: How much was scrolled by Y coordinate since the last call.
        int wheelDeltaY() nothrow
        {
            int value = _wheelY;
            _wheelY = 0;
            return value;
        }

        /// Use this function to capture the mouse and to track input outside an SDL window.
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_CaptureMouse)
        /// Throws: $(D SDL2Exception) on error.
        void startCapture()
        {
            if (SDL_CaptureMouse(SDL_TRUE) != 0)
                _sdl2.throwSDL2Exception("SDL_CaptureMouse");
        }

        /// Use this function to stop capturing the mouse.
        /// See_also: $(LINK https://wiki.libsdl.org/SDL_CaptureMouse)
        /// Throws: $(D SDL2Exception) on error.
        void stopCapture()
        {
            if (SDL_CaptureMouse(SDL_FALSE) != 0)
                _sdl2.throwSDL2Exception("SDL_CaptureMouse");
        }
    }

    package
    {
        this(SDL2 sdl2)
        {
            _sdl2 = sdl2;
        }

        void updateMotion(const(SDL_MouseMotionEvent)* event)
        {
            // Get mouse buttons state but ignore mouse coordinates
            // because we get them from event data
            _buttonState = SDL_GetMouseState(null, null);
            _x = event.x;
            _y = event.y;
            _lastDeltaX = event.xrel;
            _lastDeltaY = event.yrel;
        }

        void updateButtons(const(SDL_MouseButtonEvent)* event)
        {
            // get mouse buttons state but ignore mouse coordinates
            // because we get them from event data
            _buttonState = SDL_GetMouseState(null, null);
            _x = event.x;
            _y = event.y;
        }

        void updateWheel(const(SDL_MouseWheelEvent)* event)
        {
            _buttonState = SDL_GetMouseState(&_x, &_y);
            _wheelX += event.x;
            _wheelY += event.y;
        }
    }

    private
    {
        SDL2 _sdl2;

        // Last button state
        int _buttonState;

        // Last mouse coordinates
        int _x = 0,
            _y = 0;

        // mouse wheel scrolled amounts
        int _wheelX = 0,
            _wheelY = 0;

        int _lastDeltaX = 0,
            _lastDeltaY = 0;
    }
}


/// Mouse cursor, can be created from custom bitmap or from system defaults.
final class SDL2Cursor
{
    public
    {
        /// Creates a cursor from a SDL surface.
        /// The surface should outlive this cursor, its ownership will not be taken.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_CreateColorCursor)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2 sdl2, SDL2Surface surface, int hotspotX, int hotspotY)
        {
            _sdl2 = sdl2;
            _handle = SDL_CreateColorCursor(surface.handle(), hotspotX, hotspotY);
            if(_handle is null)
                _sdl2.throwSDL2Exception("SDL_CreateColorCursor");
            _owned = true;
        }

        /// Creates a system cursor.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_CreateSystemCursor)
        /// Throws: $(D SDL2Exception) on error.
        this(SDL2 sdl2, SDL_SystemCursor id)
        {
            _sdl2 = sdl2;
            _handle = SDL_CreateSystemCursor(id);
            if(_handle is null)
                _sdl2.throwSDL2Exception("SDL_CreateSystemCursor");
            _owned = true;
        }

        /// Returns: Default cursor.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetDefaultCursor)
        /// Throws: $(D SDL2Exception) on error.
        static SDL2Cursor getDefault(SDL2 sdl2)
        {
            SDL_Cursor* handle = SDL_GetDefaultCursor();
            if(handle is null)
                sdl2.throwSDL2Exception("SDL_GetDefaultCursor");

            return new SDL2Cursor(sdl2, handle);

        }

        /// Returns: Current cursor.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetCursor)
        /// Throws: $(D SDL2Exception) on error.
        static SDL2Cursor getCurrent(SDL2 sdl2)
        {
            SDL_Cursor* handle = SDL_GetCursor();
            if(handle is null)
                sdl2.throwSDL2Exception("SDL_GetCursor");

            return new SDL2Cursor(sdl2, handle);
        }

        ~this()
        {
            close();
        }

        /// Returns: SDL handle.
        SDL_Cursor* handle()
        {
            return _handle;
        }

        void close()
        {
            if (_owned && _handle !is null)
            {
                SDL_FreeCursor(_handle);
                _handle = null;
            }
        }

        void setCurrent()
        {
            SDL_SetCursor(_handle);
        }
    }

    private
    {
        SDL2 _sdl2;
        SDL_Cursor* _handle;
        SDL2Surface _surface;
        bool _owned;

        // Create with specified handle.
        this(SDL2 sdl2, SDL_Cursor* handle)
        {
            _sdl2 = sdl2;
            _handle = handle;
            _owned = false;
        }
    }
}
