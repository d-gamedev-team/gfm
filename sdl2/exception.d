module gfm.sdl2.exception;

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

class SDL2ImageException : SDL2Exception
{
    public
    {
        this(string msg)
        {
            super(msg);
        }
    }
}
