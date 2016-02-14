module gfm.sdl2.audio;

import derelict.sdl2.sdl;

import gfm.sdl2.sdl;

final class SDL2AudioDevice
{
    private
    {
        SDL_AudioDeviceID _id;
    }

    public
    {
        /++
        See_also: $(LINK https://wiki.libsdl.org/SDL_OpenAudioDevice)
        +/
        this(SDL2 sdl2, const(char)[] name, int iscapture, const(SDL_AudioSpec*) desired, SDL_AudioSpec* obtained, int allowed_changes)
        {
            import std.string : toStringz;
            _id = SDL_OpenAudioDevice(toStringz(name), iscapture, desired, obtained, allowed_changes);

            if (_id == 0)
            {
                sdl2.throwSDL2Exception("SDL_OpenAudioDevice");
            }
        }

        ~this()
        {
            SDL_CloseAudioDevice(_id);
        }

        nothrow @nogc
        {
            /++
            Starts playing sound on this device
            See_also: $(D pause), $(LINK https://wiki.libsdl.org/SDL_PauseAudioDevice)
            +/
            void play()
            {
                SDL_PauseAudioDevice(_id, 0);
            }

            /++
            Stops playing sound on this device
            See_also: $(D play), $(LINK https://wiki.libsdl.org/SDL_PauseAudioDevice)
            +/
            void pause()
            {
                SDL_PauseAudioDevice(_id, 1);
            }

            /++
            Makes SDL not run the callback from $(D desired).callback.
            See_also: $(D unlock), $(LINK https://wiki.libsdl.org/SDL_LockAudioDevice)
            +/
            void lock()
            {
                SDL_LockAudioDevice(_id);
            }

            /++
            Makes SDL run the callback from $(D desired).callback again.
            See_also: $(D lock), $(LINK https://wiki.libsdl.org/SDL_UnlockAudioDevice)
            +/
            void unlock()
            {
                SDL_UnlockAudioDevice(_id);
            }

            /++
            Checks if this audio device is currently playing sound.
            See_also: $(D status), $(LINK https://wiki.libsdl.org/SDL_AudioStatus)
            +/
            bool playing()
            {
                return status == SDL_AUDIO_PLAYING;
            }

            /++
            See_also: $(D playing), $(LINK https://wiki.libsdl.org/SDL_GetAudioDeviceStatus)
            +/
            SDL_AudioStatus status()
            {
                return SDL_GetAudioDeviceStatus(_id);
            }
        }
    }
}
