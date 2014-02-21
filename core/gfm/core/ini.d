module gfm.core.ini;

import std.stdio,
       std.string,
       std.algorithm;

import gfm.core.text;

/// A dumb and permissive INI reader/writer.
/// Bugs: This parser is not robust.
deprecated("Use the ctini package instead.") class INIFile
{
    public
    {
        /// Create empty (eg. to save settings).
        this()
        {
        }

        /// Create from a file (eg. to load settings).
        /// Bugs: <b>INI parsing never fails and ignores all kind of errors</b>.
        this(string filename)
        {
            string[] lines = readTextFile(filename);

            // parse lines (ignore errors)
            string sectionName = null;

            for (int i = 0; i < lines.length; ++i)
            {
                string line = strip(lines[i]);
                if ((line != "") && (line[0] != ';'))
                {
                    if ((line[0] == '[') && (line[$-1] == ']'))
                    {
                        sectionName = line[1..$-1];
                        IniSection currentSection = findOrCreateSection(strip(sectionName));
                    }
                    else
                    {
                        ptrdiff_t pos = countUntil(line, "=");
                        if ((pos != -1) && (sectionName !is null))
                        {
                            string name = line[0..pos];
                            string value = line[pos + 1..$];
                            write(sectionName, name, value);
                        }
                    }
                }
            }
        }

        /// Saves in an INI file.
        void save(string filename)
        {
            try
            {
                auto file = new File(filename, "w");
                scope(exit) file.close();

                foreach (s; _sections)
                    file.writef("%s", s.toString());
            }
            catch(StdioException e)
            {
                // ignoring errors for the moment
                // TODO: log a warning
            }
        }

        /// Gets the content of a given INI entry.        
        /// Returns: the value of the INI entry if available, or defaultValue is missing.
        string read(string section, string name, string defaultValue)
        {
            string res = findValue(section, name);
            if (res is null)
                return defaultValue;
            else
                return res;
        }    
     
        /// Sets the content of a given INI entry.
        /// Asked section and name are lazily created if missing.
        void write(string section, string name, string value) nothrow
        {
            auto s = findOrCreateSection(section);
            auto e = s.findOrCreateEntry(name);
            e.value = value;
        }
    }

    private
    {
        IniSection[] _sections;

        IniSection findSection(string name) pure nothrow
        {
            foreach(s; _sections)
                if (s.name == name) 
                    return s;
            return null;
        }

        IniSection findOrCreateSection(string name) nothrow
        {
            IniSection res = findSection(name);
            if (res !is null)
                return res;

            auto s = new IniSection(name);
            _sections ~= s;
            return s;            
        }

        string findValue(string section, string name) pure nothrow
        {
            auto s = findSection(section);
            if (s !is null)
            {
                auto entry = s.findEntry(name);
                if (entry !is null) 
                    return entry.value;
            }
            return null;
        }
    }
}

private final class IniEntry
{
    public
    {
        string value;
        string name;

        this(string name_, string value_) pure nothrow
        {
            name = name_;
            value = value_;
        }

        override string toString() const 
        {
            return format("%s=%s\n", name, value);
        }
    }
}

private final class IniSection
{
    public
    {
        string name;
        IniEntry[] entries;

        this(string name_) pure nothrow
        {
            name = name_;
        }

        IniEntry findEntry(string name) pure nothrow
        {
            foreach(e; entries)
                if (e.name == name) 
                    return e;
            return null;
        }

        IniEntry findOrCreateEntry(string name) nothrow
        {
            IniEntry res = findEntry(name);
            if (res !is null)
                return res;

            auto e = new IniEntry(name, "");
            entries ~= e;
            return e;
        }

        override string toString() const 
        {
            string s = format("[%s]\n", name);
            foreach(e; entries)
                s ~= e.toString();
            return s;
        }
    }
}

