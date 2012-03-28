module gfm.system.semaphore;

version (Win32)
{
    import core.sys.windows.windows;
}
else
{
    static assert(false);
}

class Semaphore
{
    public
    {
        this(uint count)
        {
            _handle = CreateSemaphoreA(null, count, int.max, null);
            assert(_handle != _handle.init);
        }

        ~this()
        {
            CloseHandle(_handle);
        }

        void wait()
        {
            WaitForSingleObject(_handle, INFINITE);
        }

        void notify()
        {
            ReleaseSemaphore(_handle, 1, null);
        }

        bool tryWait()
        {
            switch( WaitForSingleObject(_handle, 0))
            {
                case WAIT_OBJECT_0:
                    return true;
                default:
                    return false;
            }
        }
    }

    private
    {
         HANDLE _handle;
    }
}