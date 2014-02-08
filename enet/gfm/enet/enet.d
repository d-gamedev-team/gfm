module gfm.enet.enet;

import derelict.enet.enet;
import derelict.util.exception;

import gfm.core.log;

/// General ENet exception thrown for all cases.
final class ENetException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

/// Owns the loader, logging, keyboard state...
/// This object is passed around to other SDL wrapper objects
/// to ensure library loading.
final class ENet
{
    public
    {
        /// Loads DerelictENet and initializes the ENet library.
        /// Throws: ENetException when enet_initialize fails.
        this(Log log = null)
        {   
            _log = log is null ? new NullLog() : log;
            try
                DerelictENet.load();
            catch(DerelictException e)
                throw new ENetException(e.msg);
     
            int errCode = enet_initialize();
            if(errCode < 0)
                throw new ENetException("enet_initialize failed");

            _enetInitialized = true;
        }
    
        ~this()
        {
            close();
        }

        /// Deinitializes the ENet library and unloads DerelictENet.
        void close()
        {
            if(_enetInitialized)
            {
                enet_deinitialize();
                DerelictENet.unload();
                _enetInitialized = false;
            }
        }
    }

    package
    {
        Log _log;
    }

    private
    {
        bool _enetInitialized = false;
    }
}