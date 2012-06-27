module gfm.common.log;

import std.stream;
import std.stdio : writefln;
import std.string;



version(Windows)
{
    import core.sys.windows.windows;
}

class Log
{
    public
    {
        enum MessageType
        {
            DEBUG = 0, // crap message for debugging to be removed in debug mode, forbidden in release mode
            INFO = 1, // detailed functionning of the program, do not show in release mdoe
            WARNING = 2,
            ERROR = 3,
        }

        final void info(lazy string s)
        {
            logMessage(Log.MessageType.INFO, s);
        }

        final void infof(Args...)(Args args)
        {
            logMessage(Log.MessageType.INFO, format(args));
        }

        final void crap(lazy string s)
        {
            logMessage(Log.MessageType.DEBUG, s);
        }

        final void crapf(Args...)(Args args)
        {
            logMessage(Log.MessageType.DEBUG, format(args));
        }

        final void warn(lazy string s)
        {
            logMessage(Log.MessageType.WARNING, s);
        }

        final void warnf(Args...)(Args args)
        {
            logMessage(Log.MessageType.WARNING, format(args));
        }

        final void error(lazy string s)
        {
            logMessage(Log.MessageType.ERROR, s);
        }

        final void errorf(Args...)(Args args)
        {
            logMessage(Log.MessageType.ERROR, format(args));
        }
    }

    protected
    {
        abstract void logMessage(MessageType type, lazy string message);

        string getTopic(MessageType type)
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
}

final class MultiLog : Log
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
                logMessage(type, message);
        }
    }

    private Log[] _logs;
}

final class NullLog : Log
{
    protected
    {
        override void logMessage(MessageType type, lazy string message)
        {
        }
    }
}

final class ConsoleLog : Log
{
    public
    {
        this()
        {
            version(Windows)
            {
                _console = GetStdHandle(STD_OUTPUT_HANDLE);
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
        }
    }
}

final class FileLog : Log
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
                _logFile.writefln(".CRAP { color: #9b7766; text-align: left;}");
                _logFile.writefln(".INFO { color: #80cf49; text-align: left;}");
                _logFile.writefln(".WTF { color: #ff8020; text-align: left; text-decoration: bold;}");
                _logFile.writefln(".EPICFAIL { color: #ff2020; text-align: left; text-decoration: bold;}");
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
