module gfm.sdl2.sdlmixer;

import std.string;

import derelict.sdl2.sdl,
       derelict.sdl2.mixer,
       derelict.util.exception;

import std.experimental.logger;

import gfm.sdl2.sdl;

final class SDLMixer
{
    public
    {
        this(SDL2 sdl2,
             int flags = MIX_INIT_FLAC | MIX_INIT_MOD | MIX_INIT_MP3 | MIX_INIT_OGG,
             int frequency = MIX_DEFAULT_FREQUENCY,
             ushort format = MIX_DEFAULT_FORMAT,
             int channels = MIX_DEFAULT_CHANNELS,
             int chunksize = 1024)
        {
            _sdl2 = sdl2;
            _logger = sdl2._logger;
            _SDLMixerInitialized = false;
            
            try
            {
                DerelictSDL2Mixer.load();
            }
            catch(DerelictException e)
            {
                throw new SDL2Exception(e.msg);
            }
            
            if(Mix_Init(flags) != flags)
            {
                throwSDL2MixerException("Mix_Init");
            }
            
            if(Mix_OpenAudio(frequency, format, channels, chunksize) != 0)
            {
                throwSDL2MixerException("Mix_OpenAudio");
            }
            
            _SDLMixerInitialized = true;
        }
        
        ~this()
        {
            if(!_SDLMixerInitialized)
            {
                debug ensureNotInGC("SDLMixer");
                _SDLMixerInitialized = false;
                Mix_CloseAudio();
                Mix_Quit();
            }
        }
    }
    
    private
    {
        SDL2 _sdl2;
        Logger _logger;
        bool _SDLMixerInitialized;
        
        void throwSDL2MixerException(string callThatFailed)
        {
            string message = format("%s failed: %s", callThatFailed, getErrorString());
            throw new SDL2Exception(message);
        }
        
        const(char)[] getErrorString()
        {
            return fromStringz(Mix_GetError());
        }
    }
}
