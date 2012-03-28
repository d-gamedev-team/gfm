module sdl.sdlimage;

import derelict.sdl.sdl;
import derelict.sdl.image;
import sdl.state;
import misc.logger;
import std.string;


final class SDLImage
{

    private
    {
        SDL_Surface * m_handle = null;
        SDL m_libInstance;
    }

    public
    {

        this()
        {
            m_libInstance = SDL.instance;
            DerelictSDLImage.load();
        }

        this(char[] filename)
        {
            this();
            loadImage(filename);
        }

        ~this()
        {
            /* free the loaded image */
            if (m_handle !is null) SDL_FreeSurface(m_handle);
        }

        void loadImage(char[] filename)
        {
            m_handle = IMG_Load(toStringz(filename));


            if (m_handle is null)
            {
                char* errorStringz = IMG_GetError();

                for (char* p = errorStringz; *p != 0; ++p)
                {
                    *p = *p & 127;
                }

                char[] errorString = std.string.toString(errorStringz);
                throw new SDLError(format("Unable to load image %s, SDL says \"%s\"", filename, errorString));
            }

            SDL_PixelFormat RGBAformat;

            RGBAformat.palette = null;
            RGBAformat.BitsPerPixel = 32;
            RGBAformat.BytesPerPixel = 4;
            RGBAformat.Rloss = 0;
            RGBAformat.Gloss = 0;
            RGBAformat.Bloss = 0;
            RGBAformat.Aloss = 0;
            RGBAformat.Rmask = 0x000000ff;
            RGBAformat.Gmask = 0x0000ff00;
            RGBAformat.Bmask = 0x00ff0000;
            RGBAformat.Amask = 0xff000000;
            RGBAformat.Rshift = 0;
            RGBAformat.Gshift = 8;
            RGBAformat.Bshift = 16;
            RGBAformat.Ashift = 24;
            RGBAformat.colorkey = 0xff000000;
            RGBAformat.alpha = 255;

            SDL_Surface * convertedSurface = SDL_ConvertSurface(m_handle, &RGBAformat, SDL_SWSURFACE);

            if (convertedSurface is null) throw new SDLError(format("Cannor convert %s in proper RGBA format", filename));

            SDL_FreeSurface(m_handle);

            m_handle = convertedSurface;
        }

        void * data()
        {
            return m_handle.pixels;
        }

        int height()
        {
            return m_handle.h;
        }

        int width()
        {
            return m_handle.w;
        }

        void lock()
        {
            if (SDL_MUSTLOCK(m_handle))
            {
                SDL_LockSurface(m_handle);     // unsafe, suppose it works
            }
        }

        void unlock()
        {
            if (SDL_MUSTLOCK(m_handle))
            {
                SDL_UnlockSurface(m_handle);     // quite unsafe too
            }
        }
    }
}
