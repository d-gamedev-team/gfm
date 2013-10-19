module gfm.sdl2.sdl;

import core.stdc.stdlib;

import std.conv,
       std.string,
       std.array;

import derelict.sdl2.sdl,
       derelict.sdl2.image,
       derelict.util.exception;

import gfm.sdl2.displaymode,
       gfm.sdl2.renderer,
       gfm.core.log,
       gfm.core.text,
       gfm.math.vector,
       gfm.math.box;


class SDL2Exception : Exception
{
    public
    {
        this(string msg)
        {
            super(msg);
        }
    }
}

final class SDL2
{
    public
    {
        this(Log log)
        {
            _log = log is null ? new NullLog() : log;
            _SDLInitialized = false;
            _SDL2LoggingRedirected = false;
            try
            {
                DerelictSDL2.load();
            }
            catch(DerelictException e)
            {
                throw new SDL2Exception(e.msg);
            }

            // enable all logging, and pipe it to our own logger object
            {
                SDL_LogGetOutputFunction(_previousLogCallback, &_previousLogUserdata);
                SDL_LogSetAllPriority(SDL_LOG_PRIORITY_VERBOSE);
                SDL_LogSetOutputFunction(&loggingCallbackSDL, cast(void*)this);
                _SDL2LoggingRedirected = true;
            }

            if (0 != SDL_Init(0))
                throwSDL2Exception("SDL_Init");

            _log.infof("Platform: %s, %s CPU, L1 cacheline size: %sb", getPlatform(), getCPUCount(), getL1LineSize());
            
            subSystemInit(SDL_INIT_TIMER);
            subSystemInit(SDL_INIT_VIDEO);
            subSystemInit(SDL_INIT_JOYSTICK);
            subSystemInit(SDL_INIT_AUDIO);
            subSystemInit(SDL_INIT_HAPTIC);

            _log.infof("Available drivers: %s", join(getVideoDrivers(), ", "));
            _log.infof("Running using video driver: %s", sanitizeUTF8(SDL_GetCurrentVideoDriver(), _log, "SDL_GetCurrentVideoDriver"));

            int numDisplays = SDL_GetNumVideoDisplays();
            
            _log.infof("%s video display(s) detected.", numDisplays);
            
        }

        void close()
        {
            // restore previously set logging function
            if (_SDL2LoggingRedirected)
            {
                SDL_LogSetOutputFunction(_previousLogCallback, _previousLogUserdata);
                _SDL2LoggingRedirected = false;
            }

            if (_SDLInitialized)
            {
                SDL_Quit();
                _SDLInitialized = false;
            }

            if (DerelictSDL2.isLoaded())
                DerelictSDL2.unload();
        }

        ~this()
        {
            close();
        }

        string[] getVideoDrivers()
        {
            const int numDrivers = SDL_GetNumVideoDrivers();
            string[] res;
            res.length = numDrivers;
            for(int i = 0; i < numDrivers; ++i)
                res[i] = sanitizeUTF8(SDL_GetVideoDriver(i), _log, "SDL_GetVideoDriver");
            return res;
        }

        string getPlatform()
        {
            return sanitizeUTF8(SDL_GetPlatform(), _log, "SDL_GetPlatform");
        }

        int getL1LineSize()
        {
            int res = SDL_GetCPUCacheLineSize();
            if (res <= 0)
                res = 64;
            return res;
        }

        int getCPUCount()
        {
            int res = SDL_GetCPUCount();
            if (res <= 0)
                res = 1;
            return res;
        }

        void delay(int milliseconds)
        {
            SDL_Delay(milliseconds);
        }

        uint getTicks()
        {
            return SDL_GetTicks();
        }

        SDL2VideoDisplay[] getDisplays()
        {
            int numDisplays = SDL_GetNumVideoDisplays();

            SDL2VideoDisplay[] availableDisplays;
            
            for (int displayIndex = 0; displayIndex < numDisplays; ++displayIndex)
            {
                SDL_Rect rect;
                int res = SDL_GetDisplayBounds(displayIndex, &rect);
                if (res != 0)
                    throwSDL2Exception("SDL_GetDisplayBounds");

                box2i bounds = box2i(rect.x, rect.y, rect.x + rect.w, rect.y + rect.h);
                SDL2DisplayMode[] availableModes;

                int numModes = SDL_GetNumDisplayModes(displayIndex);
                for(int modeIndex = 0; modeIndex < numModes; ++modeIndex)
                {
                    SDL_DisplayMode mode;
                    if (0 != SDL_GetDisplayMode(displayIndex, modeIndex, &mode))
                        throwSDL2Exception("SDL_GetDisplayMode");

                    availableModes ~= new SDL2DisplayMode(modeIndex, mode);
                }

                availableDisplays ~= new SDL2VideoDisplay(displayIndex, bounds, availableModes);
            }
            return availableDisplays;
        }

        vec2i firstDisplaySize()
        {
            auto displays = getDisplays();
            if (displays.length == 0)
                throw new SDL2Exception("no display");
            return displays[0].dimension();
        }

        SDL2RendererInfo[] getRenderersInfo()
        {
            SDL2RendererInfo[] res;
            int num = SDL_GetNumRenderDrivers();
            if (num < 0)
                throwSDL2Exception("SDL_GetNumRenderDrivers");

            for (int i = 0; i < num; ++i)
            {
                SDL_RendererInfo info;
                int err = SDL_GetRenderDriverInfo(i, &info);
                if (err != 0)
                    throwSDL2Exception("SDL_GetRenderDriverInfo");
                res ~= new SDL2RendererInfo(_log, i, info);
            }
            return res;
        }

        void startTextInput()
        {
            SDL_StartTextInput();
        }

        void stopTextInput()
        {
            SDL_StopTextInput();
        }


        // clipboard as a property
        // set clipboard
        @property string clipboard(string s)
        {
            int err = SDL_SetClipboardText(toStringz(s));
            if (err != 0)
                throwSDL2Exception("SDL_SetClipboardText");
            return s;
        }

        // get clipboard
        @property string clipboard()
        {
            if (SDL_HasClipboardText() == SDL_FALSE)
                return null;

            const(char)* s = SDL_GetClipboardText();
            if (s is null)
                throwSDL2Exception("SDL_GetClipboardText");

            return sanitizeUTF8(s, _log, "SDL clipboard text");
        }
    }

    package
    {
        // exception mechanism that shall be used by every module here
        void throwSDL2Exception(string callThatFailed)
        {
            string message = format("%s failed: %s", callThatFailed, getErrorString());
            throw new SDL2Exception(message);
        }

        string getErrorString()
        {
            const(char)* message = SDL_GetError();
            SDL_ClearError(); // clear error
            return sanitizeUTF8(message, _log, "SDL error string");
        } 
    }

    package
    {
        Log _log;
    }

    private
    {
        bool _SDL2LoggingRedirected;
        SDL_LogOutputFunction _previousLogCallback;
        void* _previousLogUserdata;


        bool _SDLInitialized;

        bool subSystemInitialized(int subSystem)
        {
            int inited = SDL_WasInit(SDL_INIT_EVERYTHING);
            return 0 != ( inited & subSystem );
        }

        void subSystemInit(int flag)
        {
            if (!subSystemInitialized(flag))
            {
                int res = SDL_InitSubSystem(flag);
                if (0 != res)
                    throwSDL2Exception("SDL_InitSubSystem");
            }
        }      

        void onLogMessage(int category, SDL_LogPriority priority, const(char)* message)
        {
            static string readablePriority(SDL_LogPriority priority) pure
            {
                switch(priority)
                {
                    case SDL_LOG_PRIORITY_VERBOSE  : return "verbose";
                    case SDL_LOG_PRIORITY_DEBUG    : return "debug";
                    case SDL_LOG_PRIORITY_INFO     : return "info";
                    case SDL_LOG_PRIORITY_WARN     : return "warn";
                    case SDL_LOG_PRIORITY_ERROR    : return "error";
                    case SDL_LOG_PRIORITY_CRITICAL : return "critical";
                    default                        : return "unknown";
                }
            }

            static string readableCategory(SDL_LogPriority priority) pure
            {
                switch(priority)
                {
                    case SDL_LOG_CATEGORY_APPLICATION : return "application";
                    case SDL_LOG_CATEGORY_ERROR       : return "error";
                    case SDL_LOG_CATEGORY_SYSTEM      : return "system";
                    case SDL_LOG_CATEGORY_AUDIO       : return "audio";
                    case SDL_LOG_CATEGORY_VIDEO       : return "video";
                    case SDL_LOG_CATEGORY_RENDER      : return "render";
                    case SDL_LOG_CATEGORY_INPUT       : return "input";
                    default                           : return "unknown";
                }
            }

            string formattedMessage = format("SDL (category %s, priority %s): %s", 
                                             readableCategory(category), 
                                             readablePriority(priority), 
                                             sanitizeUTF8(message, _log, "SDL logging"));

            if (priority == SDL_LOG_PRIORITY_WARN)
                _log.warn(formattedMessage);
            else if (priority == SDL_LOG_PRIORITY_ERROR ||  priority == SDL_LOG_PRIORITY_CRITICAL)
                _log.error(formattedMessage);
            else
                _log.info(formattedMessage);
        }
    }
}

extern(C) private nothrow
{
    void loggingCallbackSDL(void* userData, int category, SDL_LogPriority priority, const(char)* message)
    {
        try
        {
            SDL2 sdl2 = cast(SDL2)userData;

            try
                sdl2.onLogMessage(category, priority, message);
            catch (Exception e)
            {
                // got exception while logging, ignore it
            }
        }
        catch (Throwable e)
        {
            // No Throwable is supposed to cross C callbacks boundaries
            // Crash immediately
            exit(-1);
        }
    }
}
