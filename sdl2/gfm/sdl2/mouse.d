module gfm.sdl2.mouse;

import derelict.sdl2.sdl;
import gfm.sdl2.sdl;

/// Holds SDL mouse state.
final class SDL2Mouse
{
    public
    {
        /// Returns: true if a specific mouse button defined by mask is pressed
        /// Example:
        /// --------------------
        /// // Check if the left mouse button is pressed
        /// if(_sdl2.isMouseButtonPressed(SDL_BUTTON_LMASK))
        ///     ...
        /// --------------------
        bool isButtonPressed(int mask) pure const nothrow
        {
            return (_mouseButtonState & mask) != 0;
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

        /// Returns: Coordinates of mouse pointer.
        SDL_Point position() pure const nothrow
        {
            return SDL_Point(_x, _y);
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
            _mouseButtonState = SDL_GetMouseState(null, null);
            _x = event.x;
            _y = event.y;
        }

        void updateButtons(const(SDL_MouseButtonEvent)* event)
        {
            // get mouse buttons state but ignore mouse coordinates
            // because we get them from event data
            _mouseButtonState = SDL_GetMouseState(null, null);
            _x = event.x;
            _y = event.y;
        }

        void updateWheel(const(SDL_MouseWheelEvent)* event)
        {
            _mouseButtonState = SDL_GetMouseState(&_x, &_y);
            _wheelX += event.x;
            _wheelY += event.y;
        }
    }

    private
    {
        SDL2 _sdl2;

        // Last button state
        int _mouseButtonState;
        
        // Last mouse coordinates
        int _x = 0, 
            _y = 0;

        // mouse wheel scrolled amounts
        int _wheelX = 0, 
            _wheelY =0;

    }

}
