module gfm.sdl2.sdl;

import std.conv: to;
import std.string: format;

import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.util.exception;

import gfm.sdl2.exception;
import gfm.sdl2.displaymode;
import gfm.common.log;
import gfm.math.box;

final class SDL2
{
    public
    {
        this(Log log)
        {
            _log = log;
            try
            {
                // in debug builds, use a debgu version of SDL2
                debug
                    DerelictSDL2.load("SDL2d.dll");
                else
                    DerelictSDL2.load();
                DerelictSDL2.disableAutoUnload();
            }
            catch(DerelictException e)
            {
                throw new SDL2Exception(e.msg);
            }

            m_redirectSDL2Logging = true;

            // enable all logging, and pipe it to our own logger object
            if (m_redirectSDL2Logging)
            {
                SDL_LogGetOutputFunction(_previousLogCallback, &_previousLogUserdata);
                SDL_LogSetAllPriority(SDL_LOG_PRIORITY_VERBOSE);
                SDL_LogSetOutputFunction(&loggingCallback, cast(void*)this);
            }

            if (0 != SDL_Init(0))
                throwSDL2UsageError("SDL_Init");

            _log.infof("Platform: %s, %s CPU, L1 cacheline size: %sb", getPlatform(), getCPUCount(), getL1LineSize());
            
            subSystemInit(SDL_INIT_TIMER);
            subSystemInit(SDL_INIT_VIDEO);
            subSystemInit(SDL_INIT_JOYSTICK);
            subSystemInit(SDL_INIT_AUDIO);
            subSystemInit(SDL_INIT_HAPTIC);

            foreach(driver;getVideoDrivers())
                _log.infof("Available driver: %s", driver);

            {
                int res = SDL_VideoInit(null);
                if (res != 0)
                    throwSDL2UsageError("SDL_VideoInit");
            }

            _log.infof("Running using video driver: %s", to!string(SDL_GetCurrentVideoDriver()));

            int numDisplays = SDL_GetNumVideoDisplays();
            
            _log.infof("%s video display(s) detected.", numDisplays);
            
        }

        ~this()
        {
            // restore previously set logging function
            if (m_redirectSDL2Logging)
                SDL_LogSetOutputFunction(_previousLogCallback, _previousLogUserdata);

            SDL_Quit();
            DerelictSDL2.unload();
        }

        string[] getVideoDrivers()
        {
            const int numDrivers = SDL_GetNumVideoDrivers();
            string[] res;
            res.length = numDrivers;
            for(int i = 0; i < numDrivers; ++i)
                res[i] = to!string(SDL_GetVideoDriver(i));
            return res;
        }

        string getPlatform()
        {
            return to!string(SDL_GetPlatform());
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
                    throwSDL2UsageError("SDL_GetDisplayBounds");

                box2i bounds = box2i(rect.x, rect.y, rect.x + rect.w, rect.y + rect.h);
                SDL2DisplayMode[] availableModes;

                int numModes = SDL_GetNumDisplayModes(displayIndex);
                for(int modeIndex = 0; modeIndex < numModes; ++modeIndex)
                {
                    SDL_DisplayMode mode;
                    if (0 != SDL_GetDisplayMode(displayIndex, modeIndex, &mode))
                        throwSDL2UsageError("SDL_GetDisplayMode");

                    availableModes ~= new SDL2DisplayMode(modeIndex, mode);
                }

                availableDisplays ~= new SDL2VideoDisplay(displayIndex, bounds, availableModes);
            }
            return availableDisplays;
        }
    }

    public // package
    {
        void throwSDL2UsageError(string callThatFailed)
        {
            string message = format("%s failed: %s", callThatFailed, getErrorString());
            throw new SDL2Exception(message);
        }

        string getErrorString()
        {
            return to!string(SDL_GetError());
        } 
    }

    private
    {
        Log _log;

        bool m_redirectSDL2Logging;
        SDL_LogOutputFunction _previousLogCallback;
        void* _previousLogUserdata;

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
                    throwSDL2UsageError("SDL_InitSubSystem");
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
                                             to!string(message));

            if (priority == SDL_LOG_PRIORITY_WARN)
                _log.warn(formattedMessage);
            else if (priority == SDL_LOG_PRIORITY_ERROR ||  priority == SDL_LOG_PRIORITY_CRITICAL)
                _log.error(formattedMessage);
            else
                _log.info(formattedMessage);
        }
    }
}

extern(C)
{
    void loggingCallback(void* userData, int category, SDL_LogPriority priority, const(char)* message)
    {
        SDL2 sdl2 = cast(SDL2)userData;
        sdl2.onLogMessage(category, priority, message);
    }
}