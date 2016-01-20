module gfm.assimp.assimp;

import std.conv,
       std.string,
       std.array : join;

import std.experimental.logger;

import derelict.assimp3.assimp,
       derelict.util.exception;

/// The one exception type thrown in this wrapper.
/// A failing ASSIMP function should <b>always</b> throw an AssimpException.
class AssimpException : Exception
{
    public
    {
        @safe pure nothrow this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super(message, file, line, next);
        }
    }
}

/// Create one to use the ASSIMP libary.
/// Owns both the loader and logging redirection.
/// This object is passed around to other ASSIMP wrapper objects
/// to ensure library loading.
final class Assimp
{
    public
    {
        /// Load ASSIMP library, redirect logging to our logger.
        /// You can pass a null logger if you don't want logging.
        /// Throws: AssimpException on error.
        this(Logger logger)
        {
            _logger = logger is null ? new NullLogger() : logger;

            try
            {
                DerelictASSIMP3.load();
            }
            catch(DerelictException e)
            {
                throw new AssimpException(e.msg);
            }

            _libInitialized = true;

            // enable verbose logging by default
            aiEnableVerboseLogging(AI_TRUE);

            // route Assimp logging to our own
            _logStream.callback = &loggingCallbackAssimp;
            _logStream.user = cast(char*)(cast(void*)this);
            aiAttachLogStream(&_logStream);
        }

        /// Releases the ASSIMP library and all resources.
        /// All resources should have been released at this point,
        /// since you won't be able to call any ASSIMP function afterwards.
        ~this()
        {
            if (_libInitialized)
            {
                debug ensureNotInGC("Assimp");
                aiDetachLogStream(&_logStream);
                _libInitialized = false;
            }
        }
       
        /// Returns: ASSIMP version string as returned by the dynamic library.
        string getVersion()
        {
            string compileFlags()
            {
                string[] res;
                uint flags = aiGetCompileFlags();
                if ((flags & ASSIMP_CFLAGS_SHARED) != 0)
                    res ~= "shared";
                if ((flags & ASSIMP_CFLAGS_STLPORT) != 0)
                    res ~= "stl-port";
                if ((flags & ASSIMP_CFLAGS_DEBUG) != 0)
                    res ~= "debug";
                if ((flags & ASSIMP_CFLAGS_NOBOOST) != 0)
                    res ~= "no-boost";
                if ((flags & ASSIMP_CFLAGS_SINGLETHREADED) != 0)
                    res ~= "single-threaded";
                return join(res, ", ");
            }
            return format("v%s.%s_r%s (%s)", aiGetVersionMajor(), aiGetVersionMinor(), aiGetVersionRevision(), compileFlags());
        }

        /// Returns: A string with legal copyright and licensing information about Assimp.
        const(char)[] getLegalString()
        {
            const(char)* legalZ = aiGetLegalString();
            return fromStringz(legalZ);
        }
    }

    package
    {
        Logger _logger;

        // exception mechanism that shall be used by every module here
        void throwAssimpException(string callThatFailed)
        {
            string message = format("%s failed: %s", callThatFailed, getErrorString());
            throw new AssimpException(message);
        }

        const(char)[] getErrorString()
        {
            const(char)* errorZ = aiGetErrorString();
            return fromStringz(errorZ);
        }
    }

    private
    {
        bool _libInitialized;
        aiLogStream _logStream;
    }
}

extern (C) private
{
    void loggingCallbackAssimp(const(char)* message, char* user) nothrow
    {
        Assimp assimp = cast(Assimp)user;
        try
        {
            Logger logger = assimp._logger;
            logger.infof("assimp: %s");
        }
        catch(Exception e)
        {
            // ignoring IO exceptions, format errors, etc... to be nothrow
            // making the whole Log interface nothrow is not that trivial
        }
    }
}

/// Crash if the GC is running.
/// Useful in destructors to avoid reliance GC resource release.
package void ensureNotInGC(string resourceName) nothrow
{
    import core.exception;
    try
    {
        import core.memory;
        cast(void) GC.malloc(1); // not ideal since it allocates
        return;
    }
    catch(InvalidMemoryOperationError e)
    {

        import core.stdc.stdio;
        fprintf(stderr, "Error: clean-up of %s incorrectly depends on destructors called by the GC.\n", resourceName.ptr);
        assert(false);
    }
}