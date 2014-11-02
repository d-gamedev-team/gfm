module gfm.opengl.opengl;

import core.stdc.stdlib;

import std.string,
       std.conv,
       std.array,
       std.algorithm;

import derelict.opengl3.gl3,
       derelict.opengl3.gl;

import std.experimental.logger;

import gfm.core.log,
       gfm.core.text,
       gfm.opengl.textureunit;

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
            DerelictGL3.load(); // load latest available version

            DerelictGL.load(); // load deprecated functions too

            _logger.infof("OpenGL loaded, version %s", DerelictGL3.loadedVersion());

            // do not log here since unimportant errors might happen:
            // no context is necessarily created at this point
            getLimits(false); 

            _textureUnits = new TextureUnits(this);
        }

        ~this()
        {
            close();
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
            _logger.infof("OpenGL reloaded, version %s", DerelictGL3.loadedVersion());
            _logger.infof("    Version: %s", getVersionString());
            _logger.infof("    Renderer: %s", getRendererString());
            _logger.infof("    Vendor: %s", getVendorString());
            _logger.infof("    GLSL version: %s", getGLSLVersionString());

            // parse extensions
            _extensions = array(getExtensions());

            _logger.infof("    Extensions: %s found", _extensions.length);
            getLimits(true);
            _textureUnits = new TextureUnits(this);

            // now that the context exists, pipe OpenGL output
            pipeOpenGLDebugOutput();
        }

        /// Releases the OpenGL dynamic library.
        /// All resources should have been released at this point,
        /// since you won't be able to call any OpenGL function afterwards.
        void close()
        {
            DerelictGL.unload();
            DerelictGL3.unload();
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
        string getString(GLenum name)
        {
            const(char)* sZ = glGetString(name);
            runtimeCheck();
            if (sZ is null)
                return "(unknown)";
            else
                return sanitizeUTF8(sZ, _logger, "OpenGL");
        }

        /// Returns: OpenGL string returned by $(D glGetStringi)
        /// See_also: $(WEB www.opengl.org/sdk.docs/man/xhtml/glGetString.xml)
        string getString(GLenum name, GLuint index)
        {
            const(char)* sZ = glGetStringi(name, index);
            runtimeCheck();
            if (sZ is null)
                return "(unknown)";
            else
                return sanitizeUTF8(sZ, _logger, "OpenGL");
        }

        /// Returns: OpenGL version string, can be "major_number.minor_number" or 
        ///          "major_number.minor_number.release_number".
        string getVersionString()
        {
            return getString(GL_VERSION);
        }

        /// Returns: The company responsible for this OpenGL implementation, so
        ///          that you can plant a giant toxic mushroom below their office.
        string getVendorString()
        {
            return getString(GL_VENDOR);
        }

        /// Tries to detect the driver maker.
        /// Returns: Identified vendor.
        Vendor getVendor()
        {
            string s = getVendorString();
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
        string getRendererString()
        {
            return getString(GL_RENDERER);
        }

        /// Returns: GLSL version string, can be "major_number.minor_number" or 
        ///          "major_number.minor_number.release_number".
        string getGLSLVersionString()
        {
            return getString(GL_SHADING_LANGUAGE_VERSION);
        }

        /// Returns: A huge space-separated list of OpenGL extensions.
        string getExtensionsString()
        {
            return getString(GL_EXTENSIONS);
        }

        /// Returns: An input range of all supported OpenGL extensions.
        auto getExtensions()
        {
            struct Extensions
            {
                private
                {
                    uint current = 0;
                    uint count = 0;
                    OpenGL gl;
                }

                this(OpenGL gl)
                {
                    this.gl = gl;

                    int numExtensions;

                    if (gl.getInteger(GL_NUM_EXTENSIONS, numExtensions))
                        this.count = numExtensions;
                    else
                        this.count = 0;
                }

                bool empty() @property
                {
                    return current >= count;
                }

                string front() @property
                {
                    return gl.getString(GL_EXTENSIONS, current);
                }

                void popFront()
                {
                    ++current;
                }
            }

            return Extensions(this);
        }

        /// Calls $(D glGetIntegerv) and gives back the requested integer.
        /// Returns: true if $(D glGetIntegerv) succeeded.
        /// See_also: $(WEB www.opengl.org/sdk/docs/man4/xhtml/glGet.xml).
        /// Note: It is generally a bad idea to call $(D glGetSomething) since it might stall
        ///       the OpenGL pipeline.
        bool getInteger(GLenum pname, out int result) nothrow
        {
            GLint param;
            glGetIntegerv(pname, &param);

            if (runtimeCheckNothrow())
            {
                result = param;
                return true;
            }
            else
                return false;
        }

        /// Returns: The requested integer returned by $(D glGetIntegerv) 
        ///          or defaultValue if an error occured.
        /// See_also: $(WEB www.opengl.org/sdk/docs/man4/xhtml/glGet.xml).        
        int getInteger(GLenum pname, GLint defaultValue, bool logging)
        {
            int result;

            if (getInteger(pname, result))
            {
                return result;
            }
            else
            {
                if (logging)
                    _logger.warning("couldn't get OpenGL integer");
                return defaultValue;
            }
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

        /// Returns: The requested float returned by $(D glGetFloatv) 
        ///          or defaultValue if an error occured.
        /// See_also: $(WEB www.opengl.org/sdk/docs/man4/xhtml/glGet.xml).   
        float getFloat(GLenum pname, GLfloat defaultValue, bool logging)
        {
            try
            {
                return getFloat(pname);
            }
            catch(OpenGLException e)
            {
                if (logging)
                    _logger.warning(e.msg);
                return defaultValue;
            }
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
        /// Returns: Maximum texture size. 
        ///          This value should be at least 512 for a conforming OpenGL implementation.
        int maxTextureSize() pure const nothrow
        {
            return _maxTextureSize;
        }

        /// Returns: Number of texture units.
        int maxTextureUnits() pure const nothrow
        {
            return _maxTextureUnits;
        }

        /// Returns: Number of texture image units usable in a fragment shader.
        int maxFragmentTextureImageUnits() pure const nothrow
        {
            return _maxFragmentTextureImageUnits;
        }

        /// Returns: Number of texture image units usable in a vertex shader.
        int maxVertexImageUnits() pure const nothrow
        {
            return _maxVertexTextureImageUnits;
        }

        /// Returns: Number of combined texture image units.
        int maxCombinedImageUnits() pure const nothrow
        {
            return _maxCombinedTextureImageUnits;
        }

        /// Returns: Maximum number of color attachments. This is the number of targets a fragment shader can output to.
        /// You can rely on this number being at least 4 if MRT is supported.
        int maxColorAttachments() pure const nothrow
        {
            return _maxColorAttachments;
        }

        /// Returns: Texture units abstraction.
        TextureUnits textureUnits() pure nothrow
        {
            return _textureUnits;
        }

        /// Returns: Maximum value of anisotropic filter.
        float maxTextureMaxAnisotropy() pure const nothrow
        {
            return _maxTextureMaxAnisotropy;
        }
    }

    private
    {
        string[] _extensions;
        TextureUnits _textureUnits;
        int _majorVersion;
        int _minorVersion;
        int _maxTextureSize;
        int _maxTextureUnits; // number of conventional units, deprecated
        int _maxFragmentTextureImageUnits; // max for fragment shader
        int _maxVertexTextureImageUnits; // max for vertex shader
        int _maxCombinedTextureImageUnits; // max total
        int _maxColorAttachments;
        float _maxTextureMaxAnisotropy;

        void getLimits(bool logging)
        {
            _majorVersion = getInteger(GL_MAJOR_VERSION, 1, logging);
            _minorVersion = getInteger(GL_MINOR_VERSION, 1, logging);
            _maxTextureSize = getInteger(GL_MAX_TEXTURE_SIZE, 512, logging);
            // For other textures, add calls to:
            // GL_MAX_ARRAY_TEXTURE_LAYERS​, GL_MAX_3D_TEXTURE_SIZE​
            _maxTextureUnits = getInteger(GL_MAX_TEXTURE_UNITS, 2, logging);

            _maxFragmentTextureImageUnits = getInteger(GL_MAX_TEXTURE_IMAGE_UNITS, 2, logging); // odd GL enum name because of legacy reasons (initially only fragment shader could access textures)
            _maxVertexTextureImageUnits = getInteger(GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS, 2, logging);
            _maxCombinedTextureImageUnits = getInteger(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, 2, logging);
            // Get texture unit max for other shader stages with:
            // GL_MAX_GEOMETRY_TEXTURE_IMAGE_UNITS, GL_MAX_TESS_CONTROL_TEXTURE_IMAGE_UNITS, GL_MAX_TESS_EVALUATION_TEXTURE_IMAGE_UNITS

            _maxColorAttachments = getInteger(GL_MAX_COLOR_ATTACHMENTS, 4, logging);

            if (EXT_texture_filter_anisotropic())
                _maxTextureMaxAnisotropy = getFloat(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, 1.0f, logging);
            else
                _maxTextureMaxAnisotropy = 1.0f;
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

        // Redirect OpenGL debug output to the provided Logger.
        // You still has to use glDebugMessageControl to set which messages are emitted.
        // For example, to enable all messages, use:
        // glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, null, GL_TRUE);
        void pipeOpenGLDebugOutput()
        {
            if (KHR_debug())
            {
                glDebugMessageCallback(&loggingCallbackOpenGL, cast(void*)this);
                glEnable(GL_DEBUG_OUTPUT);
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

                string text = sanitizeUTF8(message, logger, "OpenGL debug output");

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

