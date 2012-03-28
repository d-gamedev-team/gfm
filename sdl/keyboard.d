module gfm.sdl.keyboard;

import derelict.sdl.sdl;
import gfm.sdl.sdl;

final class SDLKeyboard
{
    public
    {
        this(SDL sdl)
        {
            _sdl = sdl;
            key_pressed[] = RELEASED;
        }

        bool isPressed(SDLKey key)
        {
            return (key_pressed[key] == PRESSED);
        }

        bool markAsPressed(SDLKey key)
        {
            bool oldState = key_pressed[key];
            key_pressed[key] = PRESSED;
            return oldState;
        }

        bool markAsReleased(SDLKey key)
        {
            bool oldState = key_pressed[key];
            key_pressed[key] = RELEASED;
            return oldState;
        }
    }

    private
    {
        SDL _sdl;
        bool[SDLK_LAST] key_pressed;

        const PRESSED = true,
              RELEASED = false;
    }
}
