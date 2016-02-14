module gfm.sdl2.sdl;

import core.stdc.stdlib;

import std.conv,
       std.string,
       std.array;

import derelict.sdl2.sdl,
       derelict.sdl2.image,
       derelict.util.exception,
       derelict.util.loader;

import std.experimental.logger;

import gfm.sdl2.renderer,
       gfm.sdl2.window,
       gfm.sdl2.keyboard,
       gfm.sdl2.mouse;

/// The one exception type thrown in this wrapper.
/// A failing SDL function should <b>always</b> throw a $(D SDL2Exception).
class SDL2Exception : Exception
{
    public
    {
        @safe pure nothrow this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super(message, file, line, next);
        }
    }
}

/// Owns both the loader, logging, keyboard state...
/// This object is passed around to other SDL wrapper objects
/// to ensure library loading.
final class SDL2
{
    public
    {
        /// Load SDL2 library, redirect logging to our logger.
        /// You can pass a null logger if you don't want logging.
        /// You can specify a minimum version of SDL2 you wish your project to support.
        /// Creating this object doesn't initialize any SDL subsystem!
        /// Params:
        ///     logger         = The logger to redirect logging to.
        ///     sdl2Version    = The version of SDL2 to load. Defaults to SharedLibVersion(2, 0, 2).
        /// Throws: $(D SDL2Exception) on error.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_Init), $(D subSystemInit)
        this(Logger logger, SharedLibVersion sdl2Version = SharedLibVersion(2, 0, 2))
        {
            _logger = logger is null ? new NullLogger() : logger;
            _SDLInitialized = false;
            _SDL2LoggingRedirected = false;
            try
            {
                DerelictSDL2.load(sdl2Version);
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

                SDL_SetAssertionHandler(&assertCallbackSDL, cast(void*)this);
                _SDL2LoggingRedirected = true;
            }

            if (0 != SDL_Init(0))
                throwSDL2Exception("SDL_Init");

            _keyboard = new SDL2Keyboard(this);
            _mouse = new SDL2Mouse(this);
        }

        /// Releases the SDL library and all resources.
        /// All resources should have been released at this point,
        /// since you won't be able to call any SDL function afterwards.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_Quit)
        ~this()
        {
            // restore previously set logging function
            if (_SDL2LoggingRedirected)
            {
                debug ensureNotInGC("SDL2");
                SDL_LogSetOutputFunction(_previousLogCallback, _previousLogUserdata);
                _SDL2LoggingRedirected = false;

                SDL_SetAssertionHandler(null, cast(void*)this);
            }

            if (_SDLInitialized)
            {
                debug ensureNotInGC("SDL2");
                SDL_Quit();
                _SDLInitialized = false;
            }
        }

        /// Returns: true if a subsystem is initialized.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_WasInit)
        bool subSystemInitialized(int subSystem)
        {
            int inited = SDL_WasInit(SDL_INIT_EVERYTHING);
            return 0 != (inited & subSystem);
        }

        /// Initialize a subsystem. By default, all SDL subsystems are uninitialized.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_InitSubSystem)
        void subSystemInit(int flag)
        {
            if (!subSystemInitialized(flag))
            {
                int res = SDL_InitSubSystem(flag);
                if (0 != res)
                    throwSDL2Exception("SDL_InitSubSystem");
            }
        }

        /// Returns: Available displays information.
        /// Throws: $(D SDL2Exception) on error.
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

                SDL2DisplayMode[] availableModes;

                int numModes = SDL_GetNumDisplayModes(displayIndex);
                for(int modeIndex = 0; modeIndex < numModes; ++modeIndex)
                {
                    SDL_DisplayMode mode;
                    if (0 != SDL_GetDisplayMode(displayIndex, modeIndex, &mode))
                        throwSDL2Exception("SDL_GetDisplayMode");

                    availableModes ~= new SDL2DisplayMode(modeIndex, mode);
                }

                availableDisplays ~= new SDL2VideoDisplay(displayIndex, rect, availableModes);
            }
            return availableDisplays;
        }

        /// Returns: Resolution of the first display.
        /// Throws: $(D SDL2Exception) on error.
        SDL_Point firstDisplaySize()
        {
            auto displays = getDisplays();
            if (displays.length == 0)
                throw new SDL2Exception("no display");
            return displays[0].dimension();
        }

        /// Returns: Available renderers information.
        /// Throws: $(D SDL2Exception) on error.
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
                res ~= new SDL2RendererInfo(info);
            }
            return res;
        }

        /// Get next SDL event.
        /// Input state gets updated and window callbacks are called too.
        /// Returns: true if returned an event.
        bool pollEvent(SDL_Event* event)
        {
            if (SDL_PollEvent(event) != 0)
            {
                updateState(event);
                return true;
            }
            else
                return false;
        }

        /// Wait for next SDL event.
        /// Input state gets updated and window callbacks are called too.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_WaitEvent)
        /// Throws: $(D SDL2Exception) on error.
        void waitEvent(SDL_Event* event)
        {
            int res = SDL_WaitEvent(event);
            if (res == 0)
                throwSDL2Exception("SDL_WaitEvent");
            updateState(event);
        }

        /// Wait for next SDL event, with a timeout.
        /// Input state gets updated and window callbacks are called too.
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_WaitEventTimeout)
        /// Throws: $(D SDL2Exception) on error.
        /// Returns: true if returned an event.
        bool waitEventTimeout(SDL_Event* event, int timeoutMs)
        {
            //  "This also returns 0 if the timeout elapsed without an event arriving."
            // => no way to separate errors from no event, error code is ignored
            int res = SDL_WaitEventTimeout(event, timeoutMs);
            if (res == 1)
            {
                updateState(event);
                return true;
            }
            else
                return false;
        }

        /// Process all pending SDL events.
        /// Input state gets updated. You would typically look at event instead of calling
        /// this function.
        /// See_also: $(D pollEvent), $(D waitEvent), $(D waitEventTimeout)
        void processEvents()
        {
            SDL_Event event;
            while(SDL_PollEvent(&event) != 0)
                updateState(&event);
        }

        /// Returns: Keyboard state.
        /// The keyboard state is updated by processEvents() and pollEvent().
        SDL2Keyboard keyboard()
        {
            return _keyboard;
        }

        /// Returns: Mouse state.
        /// The mouse state is updated by processEvents() and pollEvent().
        SDL2Mouse mouse()
        {
            return _mouse;
        }

        /// Returns: true if an application termination has been requested.
        bool wasQuitRequested() const
        {
            return _quitWasRequested;
        }

        /// Start text input.
        void startTextInput()
        {
            SDL_StartTextInput();
        }

        /// Stops text input.
        void stopTextInput()
        {
            SDL_StopTextInput();
        }

        /// Sets clipboard content.
        /// Throws: $(D SDL2Exception) on error.
        string setClipboard(string s)
        {
            int err = SDL_SetClipboardText(toStringz(s));
            if (err != 0)
                throwSDL2Exception("SDL_SetClipboardText");
            return s;
        }

        /// Returns: Clipboard content.
        /// Throws: $(D SDL2Exception) on error.
        const(char)[] getClipboard()
        {
            if (SDL_HasClipboardText() == SDL_FALSE)
                return null;

            const(char)* s = SDL_GetClipboardText();
            if (s is null)
                throwSDL2Exception("SDL_GetClipboardText");

            return fromStringz(s);
        }

        /// Returns: Available SDL video drivers.
        alias getVideoDrivers = getDrivers!(SDL_GetNumVideoDrivers, SDL_GetVideoDriver);

        /// Returns: Available SDL audio drivers.
        alias getAudioDrivers = getDrivers!(SDL_GetNumAudioDrivers, SDL_GetAudioDriver);

        /++
        Returns: Available audio device names.
        See_also: https://wiki.libsdl.org/SDL_GetAudioDeviceName
        Bugs: SDL2 currently doesn't support recording, so it's best to
              call this without any arguments.
        +/
        const(char)[][] getAudioDevices(int type = 0)
        {
            const(int) numDevices = SDL_GetNumAudioDevices(type);

            const(char)[][] res;
            foreach (i; 0..numDevices)
            {
                res ~= fromStringz(SDL_GetAudioDeviceName(i, type));
            }

            return res;
        }

        /// Returns: Platform name.
        const(char)[] getPlatform()
        {
            return fromStringz(SDL_GetPlatform());
        }

        /// Returns: L1 cacheline size in bytes.
        int getL1LineSize()
        {
            int res = SDL_GetCPUCacheLineSize();
            if (res <= 0)
                res = 64;
            return res;
        }

        /// Returns: number of CPUs.
        int getCPUCount()
        {
            int res = SDL_GetCPUCount();
            if (res <= 0)
                res = 1;
            return res;
        }

        /// Returns: A path suitable for writing configuration files, saved games, etc...
        /// See_also: $(LINK http://wiki.libsdl.org/SDL_GetPrefPath)
        /// Throws: $(D SDL2Exception) on error.
        const(char)[] getPrefPath(string orgName, string applicationName)
        {
            char* basePath = SDL_GetPrefPath(toStringz(orgName), toStringz(applicationName));
            if (basePath != null)
            {
                const(char)[] result = fromStringz(basePath);
                SDL_free(basePath);
                return result;
            }
            else
            {
                throwSDL2Exception("SDL_GetPrefPath");
                return null; // unreachable
            }
        }
    }

    package
    {
        Logger _logger;

        // exception mechanism that shall be used by every module here
        void throwSDL2Exception(string callThatFailed)
        {
            string message = format("%s failed: %s", callThatFailed, getErrorString());
            throw new SDL2Exception(message);
        }

        // return last SDL error and clears it
        const(char)[] getErrorString()
        {
            const(char)* message = SDL_GetError();
            SDL_ClearError(); // clear error
            return fromStringz(message);
        }
    }

    private
    {
        bool _SDL2LoggingRedirected;
        SDL_LogOutputFunction _previousLogCallback;
        void* _previousLogUserdata;


        bool _SDLInitialized;

        // all created windows are keeped in this map
        // to be able to dispatch event
        SDL2Window[uint] _knownWindows;

        // SDL_QUIT was received
        bool _quitWasRequested = false;

        // Holds keyboard state
        SDL2Keyboard _keyboard;

        // Holds mouse state
        SDL2Mouse _mouse;

        const(char)[][] getDrivers(alias numFn, alias elemFn)()
        {
            const(int) numDrivers = numFn();
            const(char)[][] res;
            res.length = numDrivers;
            foreach (i; 0..numDrivers)
            {
                res[i] = fromStringz(elemFn(i));
            }
            return res;
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
                                             fromStringz(message));

            if (priority == SDL_LOG_PRIORITY_WARN)
                _logger.warning(formattedMessage);
            else if (priority == SDL_LOG_PRIORITY_ERROR ||  priority == SDL_LOG_PRIORITY_CRITICAL)
                _logger.error(formattedMessage);
            else
                _logger.info(formattedMessage);
        }

        SDL_assert_state onLogSDLAssertion(const(SDL_assert_data)* adata)
        {
            _logger.warningf("SDL assertion error: %s in %s line %d", adata.condition, adata.filename, adata.linenum);

            debug
                return SDL_ASSERTION_ABORT; // crash in debug mode
            else
                return SDL_ASSERTION_ALWAYS_IGNORE; // ingore SDL assertions in release
        }

        // update state based on event
        // TODO: add joystick state
        //       add haptic state
        void updateState(const (SDL_Event*) event)
        {
            switch(event.type)
            {
                case SDL_QUIT:
                    _quitWasRequested = true;
                    break;

                case SDL_KEYDOWN:
                case SDL_KEYUP:
                    updateKeyboard(&event.key);
                    break;

                case SDL_MOUSEMOTION:
                    _mouse.updateMotion(&event.motion);
                break;

                case SDL_MOUSEBUTTONUP:
                case SDL_MOUSEBUTTONDOWN:
                    _mouse.updateButtons(&event.button);
                break;

                case SDL_MOUSEWHEEL:
                    _mouse.updateWheel(&event.wheel);
                break;

                default:
                    break;
            }
        }

        void updateKeyboard(const(SDL_KeyboardEvent*) event)
        {
            // ignore key-repeat
            if (event.repeat != 0)
                return;

            switch (event.type)
            {
                case SDL_KEYDOWN:
                    assert(event.state == SDL_PRESSED);
                    _keyboard.markKeyAsPressed(event.keysym.scancode);
                    break;

                case SDL_KEYUP:
                    assert(event.state == SDL_RELEASED);
                    _keyboard.markKeyAsReleased(event.keysym.scancode);
                    break;

                default:
                    break;
            }
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

    SDL_assert_state assertCallbackSDL(const(SDL_assert_data)* data, void* userData)
    {
        try
        {
            SDL2 sdl2 = cast(SDL2)userData;

            try
                return sdl2.onLogSDLAssertion(data);
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
        return SDL_ASSERTION_ALWAYS_IGNORE;
    }
}

final class SDL2DisplayMode
{
    public
    {
        this(int modeIndex, SDL_DisplayMode mode)
        {
            _modeIndex = modeIndex;
            _mode = mode;
        }

        override string toString()
        {
            return format("mode #%s (width = %spx, height = %spx, rate = %shz, format = %s)",
                          _modeIndex, _mode.w, _mode.h, _mode.refresh_rate, _mode.format);
        }
    }

    private
    {
        int _modeIndex;
        SDL_DisplayMode _mode;
    }
}

final class SDL2VideoDisplay
{
    public
    {
        this(int displayindex, SDL_Rect bounds, SDL2DisplayMode[] availableModes)
        {
            _displayindex = displayindex;
            _bounds = bounds;
            _availableModes = availableModes;
        }

        const(SDL2DisplayMode[]) availableModes() pure const nothrow
        {
            return _availableModes;
        }

        SDL_Point dimension() pure const nothrow
        {
            return SDL_Point(_bounds.w, _bounds.h);
        }

        SDL_Rect bounds() pure const nothrow
        {
            return _bounds;
        }

        override string toString()
        {
            string res = format("display #%s (start = %s,%s - dimension = %s x %s)\n", _displayindex,
                                _bounds.x, _bounds.y, _bounds.w, _bounds.h);
            foreach (mode; _availableModes)
                res ~= format("  - %s\n", mode);
            return res;
        }
    }

    private
    {
        int _displayindex;
        SDL2DisplayMode[] _availableModes;
        SDL_Rect _bounds;
    }
}

/// Crash if the GC is running.
/// Useful in destructors to avoid reliance GC resource release.
package void ensureNotInGC(string resourceName) nothrow
{
    import core.exception;
    try
    {
        import core.memory;
        cast(void) GC.malloc(1); // not ideal since it allocates
        return;
    }
    catch(InvalidMemoryOperationError e)
    {

        import core.stdc.stdio;
        fprintf(stderr, "Error: clean-up of %s incorrectly depends on destructors called by the GC.\n", resourceName.ptr);
        assert(false);
    }
}