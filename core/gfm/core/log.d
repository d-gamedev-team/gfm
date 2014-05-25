module gfm.core.log;

import std.stream,
       std.stdio,
       std.string;

import std.logger;

version(Windows)
{
    import core.sys.windows.windows;
}

/**
Provides a common logging interface for GFM.

Bugs: 
    Log is not thread-safe. Messages will get squashed when output by multiple threads.

Deprecated: 
    This whole module will go away when std.logger is there.
*/
class Log
{
    protected
    {
        /// Custom loggers must implement this one method.
        abstract void logMessage(MessageType type, lazy string message);        
    }

    public
    {
        /// Log message severities.
        enum MessageType
        {
            DEBUG   = 0, /// This level is intended for debugging and should not happen in production.
            INFO    = 1, /// This level is for informational messages.
            WARNING = 2, /// An error which is not fatal and was recovered.
            ERROR   = 3, /// A serious error that can't be recovered.
        }

        /// Logs a message.
        final void message(MessageType type, lazy string message)
        {
            return logMessage(type, message);
        }

        /// Logs a formatted message.
        final void messagef(Args...)(MessageType type, Args args)
        {
            return logMessage(type, format(args));
        }

        // <shortcuts>

        /// Logs an INFO message.
        final void info(lazy string s)
        {
            logMessage(Log.MessageType.INFO, s);
        }

        /// Logs an INFO message, with formatting.
        final void infof(Args...)(Args args)
        {
            logMessage(Log.MessageType.INFO, format(args));
        }

        /// Logs a DEBUG message, with formatting.
        final void crap(lazy string s)
        {
            logMessage(Log.MessageType.DEBUG, s);
        }

        /// Logs a DEBUG message, with formatting.
        final void crapf(Args...)(Args args)
        {
            logMessage(Log.MessageType.DEBUG, format(args));
        }

        /// Logs a WARNING message, with formatting.
        final void warn(lazy string s)
        {
            logMessage(Log.MessageType.WARNING, s);
        }

        /// Logs a WARNING message, with formatting.
        final void warnf(Args...)(Args args)
        {
            logMessage(Log.MessageType.WARNING, format(args));
        }

        /// Logs an ERROR message, with formatting.
        final void error(lazy string s)
        {
            logMessage(Log.MessageType.ERROR, s);
        }

        /// Logs an ERROR message, with formatting.
        final void errorf(Args...)(Args args)
        {
            logMessage(Log.MessageType.ERROR, format(args));
        }        

        // </shortcuts>        
    }

    private string getTopic(MessageType type)
    {
        final switch (type)
        {
            case MessageType.DEBUG: return "debug";
            case MessageType.INFO: return "info";
            case MessageType.WARNING: return "warn";
            case MessageType.ERROR: return "error";
        }
    }
}

/**

Dispatch log messages to multiple loggers.

 */
deprecated("Use the logger package instead") final class MultiLog : Log
{
    public
    {
        this(Log[] logs)
        {
            _logs = logs;
        }
    }

    protected
    {
        override void logMessage(MessageType type, lazy string message)
        {
            foreach(log; _logs)
                log.logMessage(type, message);
        }
    }

    private Log[] _logs;
}


/**

Throw-away log messages.

*/
deprecated("Use a custom Logger instead from the logger package") final class NullLog : Log
{
    protected
    {
        override void logMessage(MessageType type, lazy string message)
        {
        }
    }
}

/**

Displays coloured log messages in the console.

*/
deprecated("Use ConsoleLogger instead") final class ConsoleLog : Log
{
    public
    {
        this()
        {
            version(Windows)
            {
                _console = GetStdHandle(STD_OUTPUT_HANDLE);

                // saves console attributes
                _savedInitialColor = (0 != GetConsoleScreenBufferInfo(_console, &consoleInfo));
            }
        }

        ~this()
        {
            close();
        }

        void close()
        {
            version(Windows)
            {
                // restore initial console attributes
                if (_savedInitialColor)
                {
                    SetConsoleTextAttribute(_console, consoleInfo.wAttributes);
                    _savedInitialColor = false;
                }
            }
        }
    }

    protected
    {
        override void logMessage(MessageType type, lazy string message)
        {
            version(Windows)
            {
                if (_console !is null)
                {
                    final switch (type)
                    {
                        case MessageType.DEBUG: 
                            SetConsoleTextAttribute(_console, 11);
                            break;
                        case MessageType.INFO: 
                            SetConsoleTextAttribute(_console, 15);
                            break;
                        case MessageType.WARNING: 
                            SetConsoleTextAttribute(_console, 14);
                            break;
                        case MessageType.ERROR: 
                            SetConsoleTextAttribute(_console, 12);
                            break;
                    }
                }
            }
            writefln("%s: %s", getTopic(type), message);
        }
    }

    private
    {
        version(Windows)
        {
            HANDLE _console;
            bool _savedInitialColor;
            CONSOLE_SCREEN_BUFFER_INFO consoleInfo;
        }
    }
}


/**

Output log messages in a file.

*/
deprecated("Use FileLogger instead from the logger package") final class FileLog : Log
{
    public
    {
        this(string filename = "log.html")
        {
            _indent = 0;
            try
            {
                _logFile = new std.stream.BufferedFile(filename, FileMode.OutNew);
                _logFile.writefln("<html>");
                _logFile.writefln("<head>");
                _logFile.writefln("<style>");
                _logFile.writefln("body { margin: 0px; padding: 0px; font-family: courier new, courier; font-size: 9pt; color: white; background-color: #000000; }");
                _logFile.writefln("div { margin: 5px 5px 5px 5px; }");
                _logFile.writefln(".debug { color: #9b7766; text-align: left;}");
                _logFile.writefln(".info { color: #80cf49; text-align: left;}");
                _logFile.writefln(".warn { color: #ff8020; text-align: left; text-decoration: bold;}");
                _logFile.writefln(".error { color: #ff2020; text-align: left; text-decoration: bold;}");
                _logFile.writefln("b { color: #ffff20; text-align: left; }");
                _logFile.writefln("</style>");
                _logFile.writefln("</head>");
                _logFile.writefln("<body>");
            }
            catch(StreamException e)
            {
                _logFile = null;
                writefln("%s", e.msg);
            }
        }
    }

    private
    {
        Stream _logFile;
        int _indent;
    }

    public
    {
        override void logMessage(MessageType type, lazy string message)
        {
            if (message.length == 0) return;

            if (message[0] == '<')
            {
                if (_indent > 0)
                    --_indent;
            }

            int usedIndent = _indent;

            if (message[0] == '>')
            {
                if (_indent < 32)
                    ++_indent;
            }

            string topic = getTopic(type);
            string indentString1 = "";
            for(int i = 0; i < usedIndent; ++i)
            {
                indentString1 ~= "    ";
            }

            if (_logFile !is null)
            {
                string HTMLmessage = message;
                if (message[0] == '>') HTMLmessage = "&rarr; " ~ HTMLmessage[1..$];
                else if (message[0] == '<') HTMLmessage = "&larr; " ~ HTMLmessage[1..$];
                else if (message[0] == '*') HTMLmessage = "&diams; " ~ HTMLmessage[1..$];

                try
                {
                    _logFile.writefln("<div class=\"%s\" style=\"margin-left: %dpt;\" ><b>[%s]</b> %s</div>", topic, usedIndent * 30, topic, HTMLmessage);
                    _logFile.flush();
                }
                catch(WriteException e)
                {
                    writefln(e.msg);
                }
            }
        }
    }
}

/// Gets the default logger.
/// Returns: the default logging object, which writes to both a file and the console.
deprecated("Use LogManager.defaultLogger() from the logger package instead") Log defaultLog()
{
    Log consoleLogger = new ConsoleLog();
    Log fileLogger = new FileLog("output_log.html");
    return new MultiLog( [ consoleLogger, fileLogger ] );
}


// Because default std.logger logger is a bit verbose, and lacks colors.
class ConsoleLogger : Logger
{
    public
    {
        this()
        {
            super("", LogLevel.info);

            version(Windows)
            {
                _console = GetStdHandle(STD_OUTPUT_HANDLE);

                // saves console attributes
                _savedInitialColor = (0 != GetConsoleScreenBufferInfo(_console, &consoleInfo));
            }
        }

        override void writeLogMsg(ref LoggerPayload payload) @trusted
        {
            LogLevel logLevel;
            synchronized(this)
            {
                version(Windows)
                {
                    switch(payload.logLevel)
                    {
                        case LogLevel.info:
                            SetConsoleTextAttribute(_console, 15);
                            break;

                        case LogLevel.warning:
                            SetConsoleTextAttribute(_console, 14);
                            break;

                        case LogLevel.error:
                        case LogLevel.critical:
                        case LogLevel.fatal:
                            SetConsoleTextAttribute(_console, 12);
                            break;

                        case LogLevel.unspecific:
                        case LogLevel.trace:
                        default:
                            SetConsoleTextAttribute(_console, 11); 
                    }
                }

                import std.stdio;
                writefln("%s: %s", logLevelToString(payload.logLevel), payload.msg);
            }
        }

        ~this()
        {
            close();
        }

        void close()
        {
            version(Windows)
            {
                // restore initial console attributes
                if (_savedInitialColor)
                {
                    SetConsoleTextAttribute(_console, consoleInfo.wAttributes);
                    _savedInitialColor = false;
                }
            }
        }
    }

    private
    {
        version(Windows)
        {
            HANDLE _console;
            bool _savedInitialColor;
            CONSOLE_SCREEN_BUFFER_INFO consoleInfo;
        }

        static pure string logLevelToString(const LogLevel lv)
        {
            switch(lv)
            {
                case LogLevel.unspecific:
                    return "";
                case LogLevel.trace:
                    return "trace";
                case LogLevel.info:
                    return "info";
                case LogLevel.warning:
                    return "warning";
                case LogLevel.error:
                    return "error";
                case LogLevel.critical:
                    return "critical";
                case LogLevel.fatal:
                    return "fatal";
                default:
                    assert(false);
            }
        }
    }
}
