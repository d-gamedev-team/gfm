module gfm.sdl2.joystick;

import std.format : format;
import std.string;

import derelict.sdl2.sdl;

import gfm.sdl2.sdl;

final class SDLJoystick
{
    private SDL_Joystick *_joystick = null;
    private SDL2 _sdl = null;

    public static int joystickCount()
    {
        return SDL_NumJoysticks();
    }

    public static void runUpdate()
    {
        SDL_JoystickUpdate();
    }

    public static bool update()
    {
        return (SDL_ENABLE == SDL_JoystickEventState(SDL_QUERY));
    }

    public static void update(bool autoProc)
    {
        SDL_JoystickEventState(autoProc ? SDL_ENABLE : SDL_IGNORE);
    }

    this(SDL2 sdl2, int joystickIdx)
    {
        this._sdl = sdl2;
        this._joystick = SDL_JoystickOpen(joystickIdx);

        if (this._joystick is null)
            this._sdl.throwSDL2Exception("SDL_JoystickOpen");
    }

    this(SDL2 sdl2, string joystickName)
    {
        this._sdl = sdl2;
        for (int i = 0; i < SDLJoystick.joystickCount(); i++)
        {
            if (joystickName == SDL_JoystickNameForIndex(i).fromStringz)
            {
                this._joystick = SDL_JoystickOpen(i);

                if (this._joystick is null)
                    this._sdl.throwSDL2Exception("SDL_JoystickOpen");
                else
                    break;
            }
        }

        throw new SDL2Exception("Failed to find a joystick matching name " ~ joystickName);
    }

    ~this()
    {
        if (this._joystick)
        {
            SDL_JoystickClose(this._joystick);
            this._joystick = null;
        }
    }

    @property string name()
    {
        return cast(string)SDL_JoystickName(this._joystick).fromStringz;
    }

    @property ubyte[16] guid()
    {
        return SDL_JoystickGetGUID(this._joystick).data;
    }

    @property string guidString()
    {
        return cast(string)SDL_JoystickGetGUIDString(SDL_JoystickGetGUID(this._joystick)).fromStringz;
    }

    @property bool attached()
    {
        return SDL_JoystickGetAttached(this._joystick) == SDL_TRUE;
    }

    @property int numAxes()
    {
        return SDL_JoystickNumAxes(this._joystick);
    }

    @property int numBalls()
    {
        return SDL_JoystickNumBalls(this._joystick);
    }

    @property int numHats()
    {
        return SDL_JoystickNumHats(this._joystick);
    }

    @property int numButtons()
    {
        return SDL_JoystickNumButtons(this._joystick);
    }

    short getAxis(int idx)
    {
        return SDL_JoystickGetAxis(this._joystick, idx);
    }

    ubyte getHat(int idx)
    {
        return SDL_JoystickGetHat(this._joystick, idx);
    }

    void getBall(int idx, out int dx, out int dy)
    {
        if (0 != SDL_JoystickGetBall(this._joystick, idx, &dx, &dy))
            this._sdl.throwSDL2Exception("SDL_JoystickGetBall");
    }

    bool getButton(int idx)
    {
        return (1 == SDL_JoystickGetButton(this._joystick, idx));
    }
}
