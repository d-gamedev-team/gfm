module gfm.sdl2.eventqueue;

import std.string;

import derelict.sdl2.sdl;

import gfm.core.log,
       gfm.sdl2.sdl,
       gfm.sdl2.window,
       gfm.sdl2.keyboard;

// dispatch events to listeners
// hold state for mouse, keyboard and joysticks
final class SDL2EventQueue
{
    public
    {        
        this(SDL2 sdl2)
        {
            _sdl2 = sdl2;
            _quitWasRequested = false;
            _keyboard = new SDL2Keyboard(sdl2);
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

        void processEvents()
        {
            SDL_Event event;

            while(SDL_PollEvent(&event) != 0)
            {
                update(&event);
                dispatch(&event);
            }
        }

        // return true if returned an event
        bool pollEvent(SDL_Event* event)
        {
            if (SDL_PollEvent(event) != 0)
            {
                update(event);
                return true;
            }
            else
                return false;
        }

        bool wasQuitResquested() const
        {
            return _quitWasRequested;
        }

        SDL2Keyboard keyboard()
        {
            return _keyboard;
        }
    }

    private
    {
        SDL2 _sdl2;
        SDL2Keyboard _keyboard;
        SDL2Window[uint] _knownWindows;
        bool _quitWasRequested = false;

        // update state based on event
        void update(const (SDL_Event*) event)
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


        // dispatch to callbacks
        void dispatch(const (SDL_Event*) event)
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

        void dispatchWindowEvent(const (SDL_WindowEvent*) windowEvent)
        {
            assert(windowEvent.type == SDL_WINDOWEVENT);

            SDL2Window* window = (windowEvent.windowID in _knownWindows);

            if (window is null)
                return; // no such id known

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
                    break;
            }
        }
    }
}
