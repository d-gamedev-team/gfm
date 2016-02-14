import std.typecons;

import derelict.sdl2.sdl;


import gfm.logger,
       gfm.sdl2,
       gfm.sdl2.audio;

void main()
{
    auto log = new ConsoleLogger;

    auto sdl2 = scoped!SDL2(log);
    sdl2.subSystemInit(SDL_INIT_AUDIO);

    SDL_AudioSpec spec;
    spec.freq = 48_000;
    spec.format = AUDIO_F32;
    spec.channels = 1;
    spec.samples = 4096;

    auto devices = sdl2.getAudioDevices();

    auto device = new SDL2AudioDevice(sdl2, devices[0], 0, &spec, null, 0);

    SDL_Delay(2_000);
}
