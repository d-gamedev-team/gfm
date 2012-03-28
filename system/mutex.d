module gfm.system.mutex;

// similar but no exceptions

version(Win32)
{
    import core.sys.windows.windows;
}
else
{
    static assert(false);
}

class Mutex
{
    public
    {
        this()
        {
            InitializeCriticalSection(&_handle);
        }

        ~this()
        {
            DeleteCriticalSection(&_handle);
        }

        void lock()
        {
            EnterCriticalSection(&_handle);
        }

        void unlock()
        {
            LeaveCriticalSection(&_handle);
        }
    }

    private
    {
        CRITICAL_SECTION _handle;
    }
}
