module gfm.assimp.assimp;

import std.conv,
       std.string,
       std.array : join;

import std.logger;

import gfm.core.text;

import derelict.assimp3.assimp,
       derelict.util.exception;

/// The one exception type thrown in this wrapper.
/// A failing ASSIMP function should <b>always</b> throw an AssimpException.
class AssimpException : Exception
{
    public
    {
        this(string msg)
        {
            super(msg);
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
            _logger = logger is null ? new StdIOLogger(LogLevel.off) : logger;

            try
            {
                DerelictASSIMP3.load();
            }
            catch(DerelictException e)
            {
                throw new AssimpException(e.msg);
            }

            _libInitialized = true;

            _logger.infoF("Assimp %s initialized.", getVersion());
            _logger.infoF("%s.", getLegalString());

            // enable verbose logging in debug-mode
            debug
                aiEnableVerboseLogging(AI_TRUE);
            else
                aiEnableVerboseLogging(AI_FALSE);

            // route Assimp logging to our own
            _logStream.callback = &loggingCallbackAssimp;
            _logStream.user = cast(char*)(cast(void*)this);
            aiAttachLogStream(&_logStream);
        }

        ~this()
        {
            close();
        }

        /// Releases the ASSIMP library and all resources.
        /// All resources should have been released at this point,
        /// since you won't be able to call any ASSIMP function afterwards.
        void close()
        {
            if (_libInitialized)
            {
                aiDetachLogStream(&_logStream);
                DerelictASSIMP3.unload();
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
        string getLegalString()
        {
            const(char)* legalZ = aiGetLegalString();
            return sanitizeUTF8(legalZ, _logger, "Assimp legal string");
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

        string getErrorString()
        {
            const(char)* errorZ = aiGetErrorString();
            return sanitizeUTF8(errorZ, _logger, "Assimp error string");
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
            logger.infoF("assimp: %s", sanitizeUTF8(message, log, "Assimp logging"));
        }
        catch(Exception e)
        {
            // ignoring IO exceptions, format errors, etc... to be nothrow
            // making the whole Log interface nothrow is not that trivial
        }
    }
}
