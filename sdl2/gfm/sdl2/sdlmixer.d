module gfm.sdl2.sdlmixer;

import std.datetime;
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
        
        int getChannels()
        {
            return Mix_AllocateChannels(-1);
        }
        
        void setChannels(int numChannels)
        {
            Mix_AllocateChannels(numChannels);
        }
        
        void pauseChannel(int channel)
        {
            Mix_Pause(channel);
        }
        
        void unpauseChannel(int channel)
        {
            Mix_Resume(channel);
        }
        
        bool isChannelPaused(int channel)
        {
            return Mix_Paused(channel) != 0;
        }
        
        void haltChannel(int channel, Duration delay = 0.msecs)
        {
            Mix_ExpireChannel(channel, cast(int)delay.total!"msecs");
        }
        
        void fadeChannel(int channel, Duration time)
        {
            Mix_FadeOutChannel(channel, cast(int)time.total!"msecs");
        }
        
        Mix_Fading channelFading(int channel)
        {
            return Mix_FadingChannel(channel);
        }
        
        bool isChannelPlaying(int channel)
        {
            return Mix_Playing(channel) != 0;
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

final class SDLSample
{
    public
    {
        this(SDLMixer sdlmixer, string filename)
        {
            _sdlmixer = sdlmixer;
            _chunk = Mix_LoadWAV(toStringz(filename));
            if(_chunk is null)
                _sdlmixer.throwSDL2MixerException("Mix_LoadWAV");
        }
        
        ~this()
        {
            if(_chunk !is null)
            {
                debug ensureNotInGC("SDLSample");
                Mix_FreeChunk(_chunk);
                _chunk = null;
            }
        }
        
        Mix_Chunk* handle()
        {
            return _chunk;
        }
        
        void play(int channel, int loops = 0, Duration fadeInTime = 0.seconds)
        {
            Mix_FadeInChannel(channel, _chunk, loops, cast(int)fadeInTime.total!"msecs");
        }
        
        void playTimed(int channel, Duration timeLimit, int loops = 0, Duration fadeInTime = 0.seconds)
        {
            Mix_FadeInChannelTimed(channel, _chunk, loops, cast(int)fadeInTime.total!"msecs", cast(int)timeLimit.total!"msecs");
        }
    }
    
    private
    {
        SDLMixer _sdlmixer;
        Mix_Chunk* _chunk;
    }
}
