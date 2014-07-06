module gfm.sdl2.sdl;

import core.stdc.stdlib;

import std.conv,
       std.string,
       std.array;

import derelict.sdl2.sdl,
       derelict.sdl2.image,
       derelict.util.exception;

import std.logger;

import gfm.core.text,
       gfm.math.vector,
       gfm.math.box,
       gfm.sdl2.renderer,
       gfm.sdl2.window,
       gfm.sdl2.keyboard;

/// The one exception type thrown in this wrapper.
/// A failing SDL function should <b>always</b> throw a $(D SDL2Exception).
class SDL2Exception : Exception
{
    public
    {
        this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
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
        /// Throws: $(D SDL2Exception) on error.
        /// TODO: Custom SDL assertion handler.
        this(Logger logger)
        {
            _logger = logger is null ? new NullLogger() : logger;
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

                SDL_SetAssertionHandler(&assertCallbackSDL, cast(void*)this);
                _SDL2LoggingRedirected = true;
            }

            if (0 != SDL_Init(0))
                throwSDL2Exception("SDL_Init");

            _logger.infof("Platform: %s, %s CPU, L1 cacheline size: %sb", getPlatform(), getCPUCount(), getL1LineSize());
            
            subSystemInit(SDL_INIT_TIMER);
            subSystemInit(SDL_INIT_VIDEO);
            subSystemInit(SDL_INIT_JOYSTICK);
            subSystemInit(SDL_INIT_AUDIO);
            subSystemInit(SDL_INIT_HAPTIC);

            _logger.infof("Available drivers: %s", join(getVideoDrivers(), ", "));
            _logger.infof("Running using video driver: %s", sanitizeUTF8(SDL_GetCurrentVideoDriver(), _logger, "SDL_GetCurrentVideoDriver"));

            int numDisplays = SDL_GetNumVideoDisplays();
            
            _logger.infof("%s video display(s) detected.", numDisplays);

            _keyboard = new SDL2Keyboard(this);            
        }

        /// Releases the SDL library and all resources.
        /// All resources should have been released at this point,
        /// since you won't be able to call any SDL function afterwards.
        void close()
        {
            // restore previously set logging function
            if (_SDL2LoggingRedirected)
            {
                SDL_LogSetOutputFunction(_previousLogCallback, _previousLogUserdata);
                _SDL2LoggingRedirected = false;

                SDL_SetAssertionHandler(null, cast(void*)this);
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

        /// Returns: Resolution of the first display.
        /// Throws: $(D SDL2Exception) on error.
        vec2i firstDisplaySize()
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
                res ~= new SDL2RendererInfo(_logger, i, info);
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
                dispatchEvent(event);
                return true;
            }
            else
                return false;
        }   

        /// Process all pending SDL events.
        /// Input state gets updated and window callbacks are called too.
        void processEvents()
        {
            SDL_Event event;

            while(SDL_PollEvent(&event) != 0)
            {
                updateState(&event);
                dispatchEvent(&event);
            }
        }

        /// Returns: Keyboard state.
        /// The keyboard state is updated by processEvents() and pollEvent().
        SDL2Keyboard keyboard()
        {
            return _keyboard;
        }

        /// Returns: true if an application termination has been requested.
        bool wasQuitRequested() const
        {
            return _quitWasRequested;
        }        

        deprecated alias wasQuitResquested = wasQuitRequested;

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
        string getClipboard()
        {
            if (SDL_HasClipboardText() == SDL_FALSE)
                return null;

            const(char)* s = SDL_GetClipboardText();
            if (s is null)
                throwSDL2Exception("SDL_GetClipboardText");

            return sanitizeUTF8(s, _logger, "SDL clipboard text");
        }   

        /// Returns: Available SDL video drivers.
        string[] getVideoDrivers()
        {
            const int numDrivers = SDL_GetNumVideoDrivers();
            string[] res;
            res.length = numDrivers;
            for(int i = 0; i < numDrivers; ++i)
                res[i] = sanitizeUTF8(SDL_GetVideoDriver(i), _logger, "SDL_GetVideoDriver");
            return res;
        }

        /// Returns: Platform name.
        string getPlatform()
        {
            return sanitizeUTF8(SDL_GetPlatform(), _logger, "SDL_GetPlatform");
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
        string getErrorString()
        {
            const(char)* message = SDL_GetError();
            SDL_ClearError(); // clear error
            return sanitizeUTF8(message, _logger, "SDL error string");
        }

        void registerWindow(SDL2Window window)
        {
            _knownWindows[window.id()] = window;
        }

        void unregisterWindow(SDL2Window window)
        {
            assert((window.id() in _knownWindows) !is null);
            _knownWindows.remove(window.id());
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

        // hold keyboard state
        SDL2Keyboard _keyboard;

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
                                             sanitizeUTF8(message, _logger, "SDL logging"));

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

        // dispatch to relevant event callbacks
        void dispatchEvent(const (SDL_Event*) event)
        {
            switch(event.type)
            {
                case SDL_WINDOWEVENT:
                    dispatchWindowEvent(&event.window);
                    break;

                default:
                    break;
            }
        }

        // update state based on event
        // TODO: add mouse state
        //       add joystick state
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

                default:
                    break;
            }
        }

        // TODO: add window callbacks when pressing a key?
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

        // call callbacks that can be overriden by subclassing SDL2Window
        void dispatchWindowEvent(const (SDL_WindowEvent*) windowEvent)
        {
            assert(windowEvent.type == SDL_WINDOWEVENT);

            SDL2Window* window = (windowEvent.windowID in _knownWindows);

            if (window is null)
            {
                _logger.warningf("Received a SDL event for an unknown window (id = %s)", windowEvent.windowID);
                return; // no such id known, warning
            }

            switch (windowEvent.event)
            {
                case SDL_WINDOWEVENT_SHOWN:
                    window.onShow();
                    break;

                case SDL_WINDOWEVENT_HIDDEN:
                    window.onHide();
                    break;

                case SDL_WINDOWEVENT_EXPOSED:
                    window.onExposed();
                    break;

                case SDL_WINDOWEVENT_MOVED:
                    window.onMove(windowEvent.data1, windowEvent.data2);
                    break;

                case SDL_WINDOWEVENT_RESIZED:
                    window.onResized(windowEvent.data1, windowEvent.data2);
                    break;

                case SDL_WINDOWEVENT_SIZE_CHANGED:
                    window.onSizeChanged();
                    break;

                case SDL_WINDOWEVENT_MINIMIZED:
                    window.onMinimized();
                    break;

                case SDL_WINDOWEVENT_MAXIMIZED:
                    window.onMaximized();
                    break;

                case SDL_WINDOWEVENT_RESTORED:
                    window.onRestored();
                    break;

                case SDL_WINDOWEVENT_ENTER:
                    window.onEnter();
                    break;

                case SDL_WINDOWEVENT_LEAVE:
                    window.onLeave();
                    break;

                case SDL_WINDOWEVENT_FOCUS_GAINED:
                    window.onFocusGained();
                    break;

                case SDL_WINDOWEVENT_FOCUS_LOST:
                    window.onFocusLost();
                    break;

                case SDL_WINDOWEVENT_CLOSE:
                    window.onClose();
                    break;

                default:
                    // not a window event
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
        this(int displayindex, box2i bounds, SDL2DisplayMode[] availableModes)
        {
            _displayindex = displayindex;
            _bounds = bounds;
            _availableModes = availableModes;
        }

        const(SDL2DisplayMode[]) availableModes() pure const nothrow
        {
            return _availableModes;
        }

        const(vec2i) dimension() pure const nothrow
        {
            return vec2i(_bounds.width, _bounds.height);
        }

        const(box2i) bounds() pure const nothrow
        {
            return _bounds;
        }

        override string toString()
        {
            string res = format("display #%s (start = %s,%s - dimension = %s x %s)\n", _displayindex, 
                                _bounds.min.x, _bounds.min.y, _bounds.width, _bounds.height);
            foreach (mode; _availableModes)
                res ~= format("  - %s\n", mode);
            return res;
        }
    }

    private
    {
        int _displayindex;
        SDL2DisplayMode[] _availableModes;
        box2i _bounds;
    }
}

