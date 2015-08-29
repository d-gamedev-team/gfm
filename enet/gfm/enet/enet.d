module gfm.enet.enet;

import derelict.enet.enet;
import derelict.util.exception;

static if( __VERSION__ >= 2067 )
    import std.experimental.logger;
else
    import std.historical.logger;


/// General ENet exception thrown for all cases.
final class ENetException : Exception
{
    @safe pure nothrow this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}

/// Owns the loader, logging, keyboard state...
/// This object is passed around to other ENet wrapper objects
/// to ensure library loading.
final class ENet
{
    public
    {
        /// Loads DerelictENet and initializes the ENet library.
        /// Throws: ENetException when enet_initialize fails.
        this(Logger logger = null)
        {
            _logger = logger is null ? new NullLogger() : logger;

            ShouldThrow missingSymFunc( string symName )
            {
                // Supports from libenet 1.3.3 to 1.3.11+
                // Obviously we should take extras care in gfm:enet
                // not to strictly rely on these functions.

                if (symName == "enet_linked_version")
                    return ShouldThrow.No;

                if (symName == "enet_socket_get_address")
                    return ShouldThrow.No;

                if (symName == "enet_socket_get_option")
                    return ShouldThrow.No;

                if (symName == "enet_socket_shutdown")
                    return ShouldThrow.No;

                if (symName == "enet_host_random_seed")
                    return ShouldThrow.No;

                if (symName == "enet_peer_ping_interval")
                    return ShouldThrow.No;

                if (symName == "enet_peer_timeout")
                    return ShouldThrow.No;

                if (symName == "enet_peer_on_connect")
                    return ShouldThrow.No;

                if (symName == "enet_peer_on_disconnect")
                    return ShouldThrow.No;

                // Any other missing symbol should throw.
                return ShouldThrow.Yes;
            }

            DerelictENet.missingSymbolCallback = &missingSymFunc;

            try
                DerelictENet.load();
            catch(DerelictException e)
                throw new ENetException(e.msg);

            int errCode = enet_initialize();
            if(errCode < 0)
                throw new ENetException("enet_initialize failed");

            _enetInitialized = true;
        }

        /// Deinitializes the ENet library and unloads DerelictENet.
        ~this()
        {
            if(_enetInitialized)
            {
                ensureNotInGC("ENet");
                enet_deinitialize();
                _enetInitialized = false;
            }
        }
        deprecated("Use .destroy instead") void close(){}
    }

    package
    {
        Logger _logger;
    }

    private
    {
        bool _enetInitialized = false;
    }
}

/// Crash if the GC is running.
/// Useful in destructors to avoid reliance GC resource release.
package void ensureNotInGC(string resourceName) nothrow
{
    debug
    {
        import core.exception;
        try
        {
            import core.memory;
            void* p = GC.malloc(1); // not ideal since it allocates
            return;
        }
        catch(InvalidMemoryOperationError e)
        {

            import core.stdc.stdio;
            fprintf(stderr, "Error: clean-up of %s incorrectly depends on destructors called by the GC.\n", resourceName.ptr);
            assert(false);
        }
    }
}