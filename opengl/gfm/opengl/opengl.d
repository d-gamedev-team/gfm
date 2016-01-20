module gfm.opengl.opengl;

import core.stdc.stdlib;

import std.string,
       std.conv,
       std.array,
       std.algorithm;

import derelict.util.exception;

import derelict.opengl3.gl3,
       derelict.opengl3.gl;

import std.experimental.logger;

/// The one exception type thrown in this wrapper.
/// A failing OpenGL function should <b>always</b> throw an $(D OpenGLException).
class OpenGLException : Exception
{
    public
    {
        @safe pure nothrow this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super(message, file, line, next);
        }
    }
}

/// This object is passed around to other OpenGL wrapper objects
/// to ensure library loading.
/// Create one to use OpenGL.
final class OpenGL
{
    public
    {
        enum Vendor
        {
            AMD,
            Apple, // for software rendering aka no driver
            Intel,
            Mesa,
            Microsoft, // for "GDI generic" aka no driver
            NVIDIA,
            other
        }

        /// Load OpenGL library, redirect debug output to our logger.
        /// You can pass a null logger if you don't want logging.
        /// Throws: $(D OpenGLException) on error.
        this(Logger logger)
        {
            _logger = logger is null ? new NullLogger() : logger;

            ShouldThrow missingSymFunc( string symName )
            {
                // Some NVIDIA drivers are missing these functions

                if (symName == "glGetSubroutineUniformLocation")
                    return ShouldThrow.No;

                if (symName == "glVertexAttribL1d")
                    return ShouldThrow.No;

                // Any other missing symbol should throw.
                return ShouldThrow.Yes;
            }

            DerelictGL3.missingSymbolCallback = &missingSymFunc;

            DerelictGL3.load(); // load latest available version

            DerelictGL.load(); // load deprecated functions too

            getLimits(false);
        }

        /// Returns: true if the OpenGL extension is supported.
        bool supportsExtension(string extension)
        {
            foreach(s; _extensions)
                if (s == extension)
                    return true;
            return false;
        }

        /// Reload OpenGL function pointers.
        /// Once a first OpenGL context has been created,
        /// you should call reload() to get the context you want.
        void reload()
        {
            DerelictGL3.reload();

            getLimits(true);
        }


        /// Redirects OpenGL debug output to the Logger.
        /// You still has to use glDebugMessageControl to set which messages are emitted.
        /// For example, to enable all messages, use:
        /// glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, null, GL_TRUE);
        void redirectDebugOutput()
        {
            if (KHR_debug())
            {
                glDebugMessageCallback(&loggingCallbackOpenGL, cast(void*)this);
                runtimeCheck();
                glEnable(GL_DEBUG_OUTPUT);
                runtimeCheck();
            }
        }

        /// Check for pending OpenGL errors, log a message if there is.
        /// Only for debug purpose since this check will be disabled in a release build.
        void debugCheck()
        {
            debug
            {
                GLint r = glGetError();
                if (r != GL_NO_ERROR)
                {
                    flushGLErrors(); // flush other errors if any
                    _logger.errorf("OpenGL error: %s", getErrorString(r));
                    assert(false); // break here
                }
            }
        }

        /// Checks pending OpenGL errors.
        /// Throws: $(D OpenGLException) if at least one OpenGL error was pending.
        void runtimeCheck()
        {
            GLint r = glGetError();
            if (r != GL_NO_ERROR)
            {
                string errorString = getErrorString(r);
                flushGLErrors(); // flush other errors if any
                throw new OpenGLException(errorString);
            }
        }

        /// Checks pending OpenGL errors.
        /// Returns: true if at least one OpenGL error was pending. OpenGL error status is cleared.
        bool runtimeCheckNothrow() nothrow
        {
            GLint r = glGetError();
            if (r != GL_NO_ERROR)
            {
                flushGLErrors(); // flush other errors if any
                return false;
            }
            return true;
        }

        /// Returns: OpenGL string returned by $(D glGetString).
        /// See_also: $(WEB www.opengl.org/sdk/docs/man/xhtml/glGetString.xml)
        const(char)[] getString(GLenum name)
        {
            const(char)* sZ = glGetString(name);
            runtimeCheck();
            if (sZ is null)
                return "(unknown)";
            else
                return fromStringz(sZ);
        }

        /// Returns: OpenGL string returned by $(D glGetStringi)
        /// See_also: $(WEB www.opengl.org/sdk.docs/man/xhtml/glGetString.xml)
        const(char)[] getString(GLenum name, GLuint index)
        {
            const(char)* sZ = glGetStringi(name, index);
            runtimeCheck();
            if (sZ is null)
                return "(unknown)";
            else
                return fromStringz(sZ);
        }

        /// Returns: OpenGL major version.
        int getMajorVersion() pure const nothrow @nogc
        {
            return _majorVersion;
        }

        /// Returns: OpenGL minor version.
        int getMinorVersion() pure const nothrow @nogc
        {
            return _minorVersion;
        }

        /// Returns: OpenGL version string, can be "major_number.minor_number" or
        ///          "major_number.minor_number.release_number", eventually
        ///          followed by a space and additional vendor informations.
        /// See_also: $(WEB www.opengl.org/sdk/docs/man/xhtml/glGetString.xml)
        const(char)[] getVersionString()
        {
            return getString(GL_VERSION);
        }

        /// Returns: The company responsible for this OpenGL implementation, so
        ///          that you can plant a giant toxic mushroom below their office.
        const(char)[] getVendorString()
        {
            return getString(GL_VENDOR);
        }

        /// Tries to detect the driver maker.
        /// Returns: Identified vendor.
        Vendor getVendor()
        {
            const(char)[] s = getVendorString();
            if (canFind(s, "AMD") || canFind(s, "ATI") || canFind(s, "Advanced Micro Devices"))
                return Vendor.AMD;
            else if (canFind(s, "NVIDIA") || canFind(s, "nouveau") || canFind(s, "Nouveau"))
                return Vendor.NVIDIA;
            else if (canFind(s, "Intel"))
                return Vendor.Intel;
            else if (canFind(s, "Mesa"))
                return Vendor.Mesa;
            else if (canFind(s, "Microsoft"))
                return Vendor.Microsoft;
            else if (canFind(s, "Apple"))
                return Vendor.Apple;
            else
                return Vendor.other;
        }

        /// Returns: Name of the renderer. This name is typically specific
        ///          to a particular configuration of a hardware platform.
        const(char)[] getRendererString()
        {
            return getString(GL_RENDERER);
        }

        /// Returns: GLSL version string, can be "major_number.minor_number" or
        ///          "major_number.minor_number.release_number".
        const(char)[] getGLSLVersionString()
        {
            return getString(GL_SHADING_LANGUAGE_VERSION);
        }

        /// Returns: A slice made up of available extension names.
        string[] getExtensions() pure nothrow @nogc
        {
            return _extensions;
        }

        /// Calls $(D glGetIntegerv) and gives back the requested integer.
        /// Returns: true if $(D glGetIntegerv) succeeded.
        /// See_also: $(WEB www.opengl.org/sdk/docs/man4/xhtml/glGet.xml).
        /// Note: It is generally a bad idea to call $(D glGetSomething) since it might stall
        ///       the OpenGL pipeline.
        int getInteger(GLenum pname)
        {
            GLint param;
            glGetIntegerv(pname, &param);
            runtimeCheck();
            return param;
        }


        /// Returns: The requested float returned by $(D glGetFloatv).
        /// See_also: $(WEB www.opengl.org/sdk/docs/man4/xhtml/glGet.xml).
        /// Throws: $(D OpenGLException) if at least one OpenGL error was pending.
        float getFloat(GLenum pname)
        {
            GLfloat res;
            glGetFloatv(pname, &res);
            runtimeCheck();
            return res;
        }
    }

    package
    {
        Logger _logger;

        static string getErrorString(GLint r) pure nothrow
        {
            switch(r)
            {
                case GL_NO_ERROR:          return "GL_NO_ERROR";
                case GL_INVALID_ENUM:      return "GL_INVALID_ENUM";
                case GL_INVALID_VALUE:     return "GL_INVALID_VALUE";
                case GL_INVALID_OPERATION: return "GL_INVALID_OPERATION";
                case GL_OUT_OF_MEMORY:     return "GL_OUT_OF_MEMORY";
                case GL_TABLE_TOO_LARGE:   return "GL_TABLE_TOO_LARGE";
                case GL_STACK_OVERFLOW:    return "GL_STACK_OVERFLOW";
                case GL_STACK_UNDERFLOW:   return "GL_STACK_UNDERFLOW";
                default:                   return "Unknown OpenGL error";
            }
        }

    }

    public
    {
        /// Returns: Maximum number of color attachments. This is the number of targets a fragment shader can output to.
        /// You can rely on this number being at least 4 if MRT is supported.
        int maxColorAttachments() pure const nothrow
        {
            return _maxColorAttachments;
        }

		/// Sets the "active texture" which is more precisely active texture unit.
        /// Throws: $(D OpenGLException) on error.
        void setActiveTexture(int texture)
        {
            glActiveTexture(GL_TEXTURE0 + texture);
            runtimeCheck();
        }
    }

    private
    {
        string[] _extensions;
        int _majorVersion;
        int _minorVersion;
        int _maxColorAttachments;

        void getLimits(bool isReload)
        {
            // parse GL_VERSION string
            if (isReload)
            {
                const(char)[] verString = getVersionString();

                // "Vendor-specific information may follow the version number.
                // Its format depends on the implementation, but a space always
                // separates the version number and the vendor-specific information."
                // Consequently we must slice the version string up to the first space.
                // Thanks to @ColonelThirtyTwo for reporting this.
                int firstSpace = cast(int)countUntil(verString, " ");
                if (firstSpace != -1)
                    verString = verString[0..firstSpace];

                const(char)[][] verParts = std.array.split(verString, ".");

                if (verParts.length < 2)
                {
                    cant_parse:
                    _logger.warning(format("Couldn't parse GL_VERSION string '%s', assuming OpenGL 1.1", verString));
                    _majorVersion = 1;
                    _minorVersion = 1;
                }
                else
                {
                    try
                        _majorVersion = to!int(verParts[0]);
                    catch (Exception e)
                        goto cant_parse;

                    try
                        _minorVersion = to!int(verParts[1]);
                    catch (Exception e)
                        goto cant_parse;
                }

                // 2. Get a list of available extensions
                if (_majorVersion < 3)
                {
                    // Legacy way to get extensions
                    _extensions = std.array.split(getString(GL_EXTENSIONS).idup);
                }
                else
                {
                    // New way to get extensions
                    int numExtensions = getInteger(GL_NUM_EXTENSIONS);
                    _extensions.length = 0;
                    for (int i = 0; i < numExtensions; ++i)
                        _extensions ~= getString(GL_EXTENSIONS, i).idup;
                }

                // 3. Get limits
                _maxColorAttachments = getInteger(GL_MAX_COLOR_ATTACHMENTS);
            }
            else
            {
                _majorVersion = 1;
                _minorVersion = 1;
                _extensions = [];
                _maxColorAttachments = 0;
            }
        }

        // flush out OpenGL errors
        void flushGLErrors() nothrow
        {
            int timeout = 0;
            while (++timeout <= 5) // avoid infinite loop in a no-driver situation
            {
                GLint r = glGetError();
                if (r == GL_NO_ERROR)
                    break;
            }
        }
    }
}

extern(System) private
{
    // This callback can be called from multiple threads
    nothrow void loggingCallbackOpenGL(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const(GLchar)* message, GLvoid* userParam)
    {
        try
        {
            OpenGL opengl = cast(OpenGL)userParam;

            try
            {
                Logger logger = opengl._logger;

                string ssource;
                switch (source)
                {
                    case GL_DEBUG_SOURCE_API:             ssource = "API"; break;
                    case GL_DEBUG_SOURCE_WINDOW_SYSTEM:   ssource = "window system"; break;
                    case GL_DEBUG_SOURCE_SHADER_COMPILER: ssource = "shader compiler"; break;
                    case GL_DEBUG_SOURCE_THIRD_PARTY:     ssource = "third party"; break;
                    case GL_DEBUG_SOURCE_APPLICATION:     ssource = "application"; break;
                    case GL_DEBUG_SOURCE_OTHER:           ssource = "other"; break;
                    default:                              ssource= "unknown"; break;
                }

                string stype;
                switch (type)
                {
                    case GL_DEBUG_TYPE_ERROR:               stype = "error"; break;
                    case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR: stype = "deprecated behaviour"; break;
                    case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:  stype = "undefined behaviour"; break;
                    case GL_DEBUG_TYPE_PORTABILITY:         stype = "portabiliy"; break;
                    case GL_DEBUG_TYPE_PERFORMANCE:         stype = "performance"; break;
                    case GL_DEBUG_TYPE_OTHER:               stype = "other"; break;
                    default:                                stype = "unknown"; break;
                }

                LogLevel level;

                string sseverity;
                switch (severity)
                {
                    case GL_DEBUG_SEVERITY_HIGH:
                        level = LogLevel.error;
                        sseverity = "high";
                        break;

                    case GL_DEBUG_SEVERITY_MEDIUM:
                        level = LogLevel.warning;
                        sseverity = "medium";
                        break;

                    case GL_DEBUG_SEVERITY_LOW:
                        level = LogLevel.warning;
                        sseverity = "low";
                        break;

                    case GL_DEBUG_SEVERITY_NOTIFICATION:
                        level = LogLevel.info;
                        sseverity = "notification";
                        break;

                    default:
                        level = LogLevel.warning;
                        sseverity = "unknown";
                        break;
                }

                const(char)[] text = fromStringz(message);

                if (level == LogLevel.info)
                    logger.infof("opengl: %s (id: %s, source: %s, type: %s, severity: %s)", text, id, ssource, stype, sseverity);
                if (level == LogLevel.warning)
                    logger.warningf("opengl: %s (id: %s, source: %s, type: %s, severity: %s)", text, id, ssource, stype, sseverity);
                if (level == LogLevel.error)
                    logger.errorf("opengl: %s (id: %s, source: %s, type: %s, severity: %s)", text, id, ssource, stype, sseverity);
            }
            catch (Exception e)
            {
                // got exception while logging, ignore it
            }
        }
        catch (Throwable e)
        {
            // No Throwable is supposed to cross C callbacks boundaries
            // Crash immediately
            exit(-1);
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