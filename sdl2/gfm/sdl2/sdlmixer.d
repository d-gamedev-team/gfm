module gfm.sdl2.sdlmixer;

import std.datetime;
import std.string;

import derelict.sdl2.sdl,
       derelict.sdl2.mixer,
       derelict.util.exception;

import std.experimental.logger;

import gfm.sdl2.sdl;

/// SDL_mixer library wrapper.
final class SDLMixer
{
    public
    {
        /// Loads the SDL_mixer library and opens audio.
        /// Throws: $(D SDL2Exception) on error.
        /// See_also: $(LINK https://www.libsdl.org/projects/SDL_mixer/docs/SDL_mixer.html#SEC11)
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
        
        /// Releases the SDL_mixer library.
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
        
        /// Returns: The number of mixing channels currently allocated.
        int getChannels()
        {
            return Mix_AllocateChannels(-1);
        }
        
        /// Sets the number of mixing channels.
        void setChannels(int numChannels)
        {
            Mix_AllocateChannels(numChannels);
        }
        
        /// Pauses the channel. Passing -1 pauses all channels.
        void pauseChannel(int channel)
        {
            Mix_Pause(channel);
        }
        
        /// Unpauses the channel. Passing -1 unpauses all channels.
        void unpauseChannel(int channel)
        {
            Mix_Resume(channel);
        }
        
        /// Returns: Whether the channel is paused.
        bool isChannelPaused(int channel)
        {
            return Mix_Paused(channel) != 0;
        }
        
        /// Clears the channel and pauses it.
        /// Params:
        ///     channel = channel to halt. -1 halts all channels.
        ///     delay = time after which to perform the halt.
        void haltChannel(int channel, Duration delay = 0.msecs)
        {
            Mix_ExpireChannel(channel, cast(int)delay.total!"msecs");
        }
        
        /// Fades out the channel and then halts it.
        /// Params:
        ///     channel = channel to halt. -1 fades all channels.
        ///     time = time over which the channel is faded out.
        void fadeChannel(int channel, Duration time)
        {
            Mix_FadeOutChannel(channel, cast(int)time.total!"msecs");
        }
        
        /// Returns: Fading status of the channel.
        Mix_Fading channelFading(int channel)
        {
            return Mix_FadingChannel(channel);
        }
        
        /// Returns: Whether the channel is currently playing.
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

/// SDL_mixer audio chunk wrapper.
final class SDLSample
{
    public
    {
        /// Loads a sample from a file.
        /// Params:
        ///     sdlmixer = library object.
        ///     filename = path to the audio sample.
        /// Throws: $(D SDL2Exception) on error.
        this(SDLMixer sdlmixer, string filename)
        {
            _sdlmixer = sdlmixer;
            _chunk = Mix_LoadWAV(toStringz(filename));
            if(_chunk is null)
                _sdlmixer.throwSDL2MixerException("Mix_LoadWAV");
        }
        
        /// Releases the SDL resource.
        ~this()
        {
            if(_chunk !is null)
            {
                debug ensureNotInGC("SDLSample");
                Mix_FreeChunk(_chunk);
                _chunk = null;
            }
        }
        
        /// Returns: SDL handle.
        Mix_Chunk* handle()
        {
            return _chunk;
        }
        
        /// Plays this sample.
        /// Params:
        ///     channel = channel to play on. -1 plays on first inactive channel.
        ///     loops = number of times to loop this sample.
        ///     fadeInTime = time over which this sample is faded in.
        void play(int channel, int loops = 0, Duration fadeInTime = 0.seconds)
        {
            Mix_FadeInChannel(channel, _chunk, loops, cast(int)fadeInTime.total!"msecs");
        }
        
        /// Plays this sample only within a certain time limit.
        /// Params:
        ///     channel = channel to play on. -1 plays on first inactive channel.
        ///     timeLimit = time after which the sample stops playing.
        ///     loops = number of times to loop this sample.
        ///     fadeInTime = time over which this sample is faded in.
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
