module gfm.sdl.application;

import std.string;
import derelict.sdl.sdl;
public import derelict.sdl.sdltypes;
import gfm.sdl.sdl;
import gfm.sdl.exception;
import gfm.sdl.surface;
import gfm.sdl.keyboard;
import gfm.sdl.joystick;
import gfm.math.smallvector;
import gfm.common.log;

// create fullscreen application with current desktop resolution
// TODO: support joystick updates

class SDLApplication
{
    public
    {
        enum Windowing
        {
            WINDOWED,
            FULLSCREEN
        }

        enum ScreenSurfaceStyle
        {
            SOFTWARE,
            HARDWARE
        }

        this(Log log,
             SDL sdl,
             int width,
             int height,
             Windowing windowing,
             ScreenSurfaceStyle screenSurfaceStyle)
        {
            _log = log;
            _sdl = sdl;

            bool fullscreen = (windowing == Windowing.FULLSCREEN);
            bool hardwareSurface = (screenSurfaceStyle == ScreenSurfaceStyle.HARDWARE);

            const SDL_VideoInfo* videoInfo = SDL_GetVideoInfo();

            _log.info(format("current video flags: %s", videoInfo.flags));
            _log.info(format("current video_mem: %s", videoInfo.video_mem));
            _log.info(format("bits per pixel: %s", videoInfo.vfmt.BitsPerPixel));
            _log.info(format("bytes per pixel: %s", videoInfo.vfmt.BytesPerPixel));

            if (width <= 0)
                width = videoInfo.current_w;

            if (height <= 0)
                height = videoInfo.current_h;

            uint flags = 0;
            if (hardwareSurface)
                flags |= SDL_DOUBLEBUF | SDL_HWSURFACE | SDL_ANYFORMAT;
            else
                flags |= SDL_SWSURFACE | SDL_ANYFORMAT;

            if (fullscreen)
                flags |= SDL_FULLSCREEN;

            SDL_Surface* screenSurface = SDL_SetVideoMode(width, height, 0, flags);

            if (screenSurface is null)
                throw new SDLException(sdl.getErrorString());

            _screen = new SDLSurface(sdl, screenSurface, false);

            {
                const SDL_VideoInfo* videoInfoPost = SDL_GetVideoInfo();
                _dimension = vec2i(videoInfo.current_w, videoInfo.current_h);
                _log.info(format("video flags after change: %s", videoInfo.flags));
                _log.info(format("video_mem after change: %s", videoInfo.video_mem));
            }

            _keyboard = new SDLKeyboard(sdl);
            _joysticks = new SDLJoysticks(sdl);
        }

        final int width()
        {
             return _dimension.x;
        }

        final int height()
        {
             return _dimension.y;
        }

        final SDLSurface screen()
        {
            return _screen;
        }

        string title(string s)
        {
            SDL_WM_SetCaption(toStringz(s), null);
            return s;
        }
    }

    protected
    {
        final void processEvents()
        {
            SDL_Event event;
            while (SDL_PollEvent(&event))
            {
                switch (event.type)
                {
                    // handle keyboard

                    case SDL_KEYUP:
                    {
                        SDLKey key = event.key.keysym.sym;
                        _keyboard.markAsReleased(key);
                        onKeyUp(key, event.key.keysym.mod, event.key.keysym.unicode);
                        break;
                    }

                    case SDL_KEYDOWN:
                    {
                        SDLKey key = event.key.keysym.sym;
                        _keyboard.markAsPressed( key );
                        onKeyDown( key, event.key.keysym.mod, event.key.keysym.unicode);
                        break;
                    }

                    // handle mouse
                    case SDL_MOUSEMOTION:
                        _oldMousePosition = _mousePosition;
                        _mousePosition = vec2i(event.motion.x, event.motion.y);
                        onMouseMove(_mousePosition, _mousePosition - _oldMousePosition);
                        break;

                    case SDL_MOUSEBUTTONDOWN:
                        onMouseDown(event.button.button);
                        break;

                    case SDL_MOUSEBUTTONUP:
                        onMouseUp(event.button.button);
                        break;
/*
                    case SDL_JOYAXISMOTION:
                        int joy_index = event.jaxis.which;
                        int axis_index = event.jaxis.axis;
                        float value = event.jaxis.value / cast(float)(short.max);
                        SDL.instance.joystick(joy_index).setAxis(axis_index, value);
                        break;

                    case SDL_JOYBUTTONUP:
                    case SDL_JOYBUTTONDOWN:
                    {
                        int joy_index = event.jbutton.which;
                        int button_index = event.jbutton.button;
                        bool value = (event.jbutton.state == SDL_PRESSED);
                        SDL.instance.joystick(joy_index).setButton(button_index, value);
                        break;
                    }
*/
                    case SDL_QUIT:
                        onQuit();
                        break;

                    case SDL_VIDEORESIZE:
                        _dimension = vec2i(event.resize.w, event.resize.h);
                        onResize(_dimension);
                        break;

                    default:
                        break;
                }
            }
        }

        // events handlers

        void onKeyUp(int key, int mod, wchar ch)
        {
        }

        void onKeyDown(int key, int mod, wchar ch)
        {
        }

        void onMouseMove(vec2i position, vec2i displacement)
        {
        }

        void onMouseDown(int button)
        {
        }

        void onMouseUp(int button)
        {
        }

        void onResize(vec2i dimension)
        {
        }

        void onQuit()
        {
        }

        final vec2i mousePosition() const
        {
             return _mousePosition;
        }
    }

    private
    {
        SDL _sdl;
        Log _log;
        SDLSurface _screen;
        SDLKeyboard _keyboard;
        SDLJoysticks _joysticks;

        vec2i _dimension;
        vec2i _mousePosition;
        vec2i _oldMousePosition;
    }
}


