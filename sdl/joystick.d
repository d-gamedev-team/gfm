module gfm.sdl.joystick;

import std.conv;

import derelict.sdl.sdl;

import gfm.sdl.sdl;

// TODO support dynamic joysticks

final class SDLJoysticks
{
    public
    {
        this(SDL sdl)
        {
            _sdl = sdl;
            _joysticks.length = SDL_NumJoysticks();
            for (int i = 0; i < _joysticks.length; i++)
            {
                _joysticks[i] = new SDLJoystick(sdl, i);
            }
        }

        SDLJoystick[] items()
        {
            return _joysticks;
        }
    }

    private
    {
        SDLJoystick[] _joysticks;
        SDL _sdl;
    }
}

class SDLJoystick
{
    public
    {
        this(SDL sdl, int index)
        {
            _sdl = sdl;
            open(index);

            _button_pressed.length = SDL_JoystickNumButtons(_handle);
            _button_pressed[] = RELEASED;

            _axis.length = SDL_JoystickNumAxes(_handle);
            _axis[] = 0.f;

            _name = to!string(SDL_JoystickName(_index));

        }

        ~this()
        {
            close();
        }

        bool button(int i)
        {
            return (_button_pressed[i] == PRESSED);
        }

        void setButton(int i, bool newValue)
        {
            _button_pressed[i] = newValue;
        }

        void setAxis(int i, float newValue)
        {
            _axis[i] = newValue;
        }

        float axis(int i)
        {
            return _axis[i];
        }

        int getNumAxis()
        {
            return _axis.length;
        }

        int getNumButtons()
        {
            return _button_pressed.length;
        }

        string getName()
        {
            return _name;
        }
    }

    private
    {
        SDL _sdl;
        SDL_Joystick* _handle;
        int _index;

        const PRESSED = true,
              RELEASED = false;

        bool[] _button_pressed;
        float[] _axis;
        string _name;



        void open(int num)
        {
            _index = num;
            _handle = SDL_JoystickOpen(num);
        }

        void close()
        {
            if (opened())
                SDL_JoystickClose(_handle);
        }

        bool opened()
        {
            return (SDL_JoystickOpened(_index) != 0);
        }
    }
}
