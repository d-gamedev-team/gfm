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

    // Get all available audio devices
    auto devices = sdl2.getAudioDevices();

    // Open the first audio device
    auto device = new SDL2AudioDevice(sdl2, devices[0], 0, &spec, null, 0);

    // Play audio on the device for 1 second
    device.play();
    SDL_Delay(1_000);

    // Lock the device
    device.lock();

    // Unlock the device after 1 second
    SDL_Delay(1_000);
    device.unlock();

    // Pause the device
    device.pause();

    SDL_Delay(1_000);
}
