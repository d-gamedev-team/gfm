module gfm.sdl2.eventqueue;

import std.string;

import derelict.sdl2.sdl;

import gfm.common.log;
import gfm.sdl2.sdl;
import gfm.sdl2.exception;

interface IWindowListener
{
    void onShow();
    void onHide();
    void onExposed();
    void onMove();
    void onResized();
    void onSizeChanged();
    void onMinimized();
    void onMaximized();
    void onRestored();
    void onEnter();
    void onLeave();
    void onFocusGained();
    void onFocusLost();
    void onClose();
}

// dispatch events
final class SDL2EventQueue
{
    public
    {
        
        this(SDL2 sdl2, Log log)
        {
            _sdl2 = sdl2;
            _log = log;
            _quitWasRequested = false;
        }

        void addWindowListener(uint id, IWindowListener windowListener)
        {
            _windowListeners[id] = windowListener;
        }

        void processEvents()
        {
            SDL_Event event;

            while(SDL_PollEvent(&event) != 0)
                dispatch(&event);
        }

        bool wasQuitResquested() const
        {
            return _quitWasRequested;
        }
    }

    private
    {
        SDL2 _sdl2;
        Log _log;
        IWindowListener[uint] _windowListeners;
        bool _quitWasRequested = false;

        void dispatch(const (SDL_Event*) event)
        {
            switch(event.type)
            {
                case SDL_QUIT: 
                    _quitWasRequested = true;
                    break;

                case SDL_WINDOWEVENT:
                    dispatchWindowEvent(&event.window);
                    break;

                case SDL_KEYDOWN:
                case SDL_KEYUP:
                //case SDL_TEXTEDITING:
                //case SDL_TEXTINPUT:
                
                case SDL_MOUSEMOTION:
                case SDL_MOUSEBUTTONDOWN:
                case SDL_MOUSEBUTTONUP:
                case SDL_MOUSEWHEEL:

                case SDL_JOYAXISMOTION:
                case SDL_JOYBALLMOTION:
                case SDL_JOYHATMOTION:
                case SDL_JOYBUTTONDOWN:
                case SDL_JOYBUTTONUP:                
                    break;
                
                default:
                    break;
            }
        }

        void dispatchWindowEvent(const (SDL_WindowEvent*) windowEvent)
        {
            assert(windowEvent.type == SDL_WINDOWEVENT);

            IWindowListener* listener = (windowEvent.windowID in _windowListeners);

            if (listener is null)
                return; // no such id known

            switch (windowEvent.event)
            {
                case SDL_WINDOWEVENT_SHOWN:
                    listener.onShow();
                    break;

                case SDL_WINDOWEVENT_HIDDEN:
                    listener.onHide();
                    break;

                case SDL_WINDOWEVENT_EXPOSED:
                    listener.onExposed();
                    break;

                case SDL_WINDOWEVENT_MOVED:
                    listener.onMove();
                    break;

                case SDL_WINDOWEVENT_RESIZED:
                    listener.onResized();
                    break;

                case SDL_WINDOWEVENT_SIZE_CHANGED:
                    listener.onSizeChanged();
                    break;

                case SDL_WINDOWEVENT_MINIMIZED:
                    listener.onMinimized();
                    break;

                case SDL_WINDOWEVENT_MAXIMIZED:
                    listener.onMaximized();
                    break;

                case SDL_WINDOWEVENT_RESTORED:
                    listener.onRestored();
                    break;

                case SDL_WINDOWEVENT_ENTER:
                    listener.onEnter();
                    break;

                case SDL_WINDOWEVENT_LEAVE:
                    listener.onLeave();
                    break;

                case SDL_WINDOWEVENT_FOCUS_GAINED:
                    listener.onFocusGained();
                    break;

                case SDL_WINDOWEVENT_FOCUS_LOST:
                    listener.onFocusLost();
                    break;

                case SDL_WINDOWEVENT_CLOSE:
                    listener.onClose();
                    break;

                default:
                    break;
            }
        }
    }
}
