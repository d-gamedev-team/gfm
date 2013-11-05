module cbor;

import std.range,
       std.bigint,
       std.conv,
       std.utf,
       std.exception,
       std.numeric,
       std.bigint;


/*
  CBOR: Concise Binary Object Representation.
  Implementation of RFC 7049.

  References: $(LINK http://tools.ietf.org/rfc/rfc7049.txt)
  Heavily inspired by std.json by Jeremie Pelletier.

 */

enum CBORType
{
    STRING,      /// an UTF-8 encoded string
    BYTE_STRING, /// a string of bytes
    INTEGER,     /// a 64-bits signed integer
    UINTEGER,    /// a 64-bits unsigned integer
    BIGINT,      /// an integer that doesn't fit in either
    FLOATING,    /// a floating-point value
    ARRAY,       /// an array of CBOR values
    MAP,         /// a map CBOR value => CBOR value
    SIMPLE       /// null, undefined, true, false, break, and future values
}

enum : ubyte
{
    CBOR_FALSE = 20,
    CBOR_TRUE  = 21,
    CBOR_NULL  = 22,
    CBOR_UNDEF = 23
}

struct CBORValue
{
    union Store
    {
        ubyte          simpleID;
        string         str;
        ubyte[]        byteStr;
        long           integer;
        ulong          uinteger;
        BigInt         bigint;
        real           floating;
        CBORValue[]    array;
        CBORValue[2][] map; // implemented as an array of (CBOR value, CBOR value) pairs
    }

    CBORType type;
    Store store; 

    this(T)(T arg)
    {
        this = arg;
    }

    /// Create an undefined CBOR value.
    static CBORValue simpleValue(ubyte which)
    {
        CBORValue result;
        result.type = CBORType.SIMPLE;
        result.store.simpleID = which;
        return result;
    }

    void opAssign(T)(T arg)
    {
        static if(is(T : typeof(null)))
        {
            type = CBORType.SIMPLE;
            store.simpleID = CBOR_NULL;
        }
        else static if(is(T : string))
        {
            type = CBORType.STRING;
            store.str = arg;
        }
        else static if(is(T : ubyte[]))
        {
            type = CBORType.BYTE_STRING;
            store.byteStr = arg;
        }
        else static if(is(T : ulong) && isUnsigned!T)
        {
            type = CBORType.UINTEGER;
            store.uinteger = arg;
        }
        else static if(is(T : long))
        {
            type = CBORType.INTEGER;
            store.integer = arg;
        }
        else static if(isFloatingPoint!T)
        {
            type = CBORType.FLOAT;
            store.floating = arg;
        }
        else static if(is(T : bool))
        {
            type = CBORType.SIMPLE;
            store.simpleID = arg ? CBOR_TRUE : CBOR_FALSE;
        }
        else static if(is(T : CBORValue[2][]))
        {
            type = CBORType.MAP;
            store.arg = arg;

            // TODO handle AA
        }
        else static if(isArray!T)
        {
            type = CBORType.ARRAY;
            static if(is(ElementEncodingType!T : CBORValue))
            {
                store.array = arg;
            }
            else
            {
                CBORValue[] new_arg = new CBORValue[arg.length];
                foreach(i, e; arg)
                    new_arg[i] = CBORValue(e);
                store.array = new_arg;
            }
        }       
        else static if(is(T : CBORValue))
        {
            type = arg.type;
            store = arg.store;
        }
        else
        {
            static assert(false, text(`unable to convert type "`, T.stringof, `" to CBORValue`));
        }
    }

    @property bool isNull() pure nothrow const
    {
        return type == CBORType.SIMPLE && store.simpleID == CBOR_NULL;
    }

    @property bool isUndefined() pure nothrow const
    {
        return type == CBORType.SIMPLE && store.simpleID == CBOR_UNDEF;
    }

    /// Typesafe way of accessing $(D store.boolean).
    /// Throws $(D CBORException) if $(D type) is not a bool.
    @property bool boolean() inout
    {
        enforceEx!CBORException(type == CBORType.SIMPLE, "CBORValue is not a bool");
        if (store.simpleID == CBOR_TRUE)
            return true;
        else if (store.simpleID == CBOR_FALSE)
            return false;
        else 
            throw new CBORException("CBORValue is not a bool");
    }

    /// Typesafe way of accessing $(D store.str).
    /// Throws $(D CBORException) if $(D type) is not $(D CBORType.STRING).
    @property ref inout(string) str() inout
    {
        enforceEx!CBORException(type == CBORType.STRING, "CBORValue is not a string");
        return store.str;
    }

    /// Typesafe way of accessing $(D store.byteStr).
    /// Throws $(D CBORException) if $(D type) is not $(D CBORType.BYTE_STRING).
    @property ref inout(ubyte[]) byteStr() inout
    {
        enforceEx!CBORException(type == CBORType.BYTE_STRING, "CBORValue is not a byte string");
        return store.byteStr;
    }

    /// Typesafe way of accessing $(D store.integer).
    /// Throws $(D CBORException) if $(D type) is not $(D CBORType.INTEGER).
    @property ref inout(long) integer() inout
    {
        enforceEx!CBORException(type == CBORType.INTEGER, "CBORValue is not an integer");
        return store.integer;
    }

    /// Typesafe way of accessing $(D store.uinteger).
    /// Throws $(D CBORException) if $(D type) is not $(D CBORType.UINTEGER).
    @property ref inout(ulong) uinteger() inout
    {
        enforceEx!CBORException(type == CBORType.UINTEGER, "CBORValue is not an unsigned integer");
        return store.uinteger;
    }

    /// Typesafe way of accessing $(D store.bigint).
    /// Throws $(D CBORException) if $(D type) is not $(D CBORType.BIGINT).
    @property ref inout(BigInt) bigint() inout
    {
        enforceEx!CBORException(type == CBORType.BIGINT, "CBORValue is not a big integer");
        return store.bigint;
    }

    /// Typesafe way of accessing $(D store.floating).
    /// Throws $(D CBORException) if $(D type) is not $(D CBORType.FLOATING).
    @property ref inout(real) floating() inout
    {
        enforceEx!CBORException(type == CBORType.FLOATING, "CBORValue is not a floating point");
        return store.floating;
    }

    /// Typesafe way of accessing $(D store.map).
    /// Throws $(D CBORException) if $(D type) is not $(D CBORType.MAP).
    @property ref inout(CBORValue[2][]) map() inout
    {
        enforceEx!CBORException(type == CBORType.MAP, "CBORValue is not an object");
        return store.map;
    }

    /// Typesafe way of accessing $(D store.array).
    /// Throws $(D CBORException) if $(D type) is not $(D CBORType.ARRAY).
    @property ref inout(CBORValue[]) array() inout
    {
        enforceEx!CBORException(type == CBORType.ARRAY, "CBORValue is not an array");
        return store.array;
    }
}

/// Exception thrown on CBOR errors
class CBORException : Exception
{
    this(string msg)
    {
        super(msg);
    }

    this(string msg, string file, size_t line)
    {
        super(msg, file, line);
    }
}

/// Decode a single CBOR object from an input range.
CBORValue decodeCBOR(R)(R input) if (isInputRange(R))
{
    CBORValue result; 

    ubyte firstByte = popByte();
    int majorType = firstByte() >> 5;
    ubyte rem = firstByte & 31;

    final switch(majorType)
    {
        case 0: // positive integer
            return CBORValue(readBigEndianInt(input, rem));

        case 1: // negative integer
        {
            ulong ui = readBigEndianInt(input, rem);

            // (1 - ui) does not necessarily fits into a long
            // TODO choose either bigint or long
            assert(false);
        }

        case 2: // byte string
        {
            ulong ui = readBigEndianInt(input, rem);
            ubyte[] bytes = new ubyte[ui];
            for(uint i = 0; i < ui; ++i)
                bytes[i] = input.popByte();
            return CBORValue(assumeUnique(bytes));
        }

        case 3: // UTF-8 string
        {
            ulong ui = readBigEndianInt(input, rem);
            char[] sbytes = new char[ui];
            for(uint i = 0; i < ui; ++i)
                sbytes[i] = input.popByte();

            try
            {
                validate(sbytes);
            }
            catch(Exception e)
            {
                // ill-formed unicode
                throw CBORException("Invalid UTF-8 string");
            }
            return CBORValue(assumeUnique(sbytes));
        }

        case 4: // array
        {
            ulong ui = readBigEndianInt(input, rem);
            CBORValue[] items = new CBORValue[ui];

            foreach(ref item; items)
                item = decodeCBOR(input);
            
            return CBORValue(assumeUnique(items));
        }

        case 5: // map
        {
            ulong ui = readBigEndianInt(input, rem);
            CBORValue[2][] items = new CBORValue[2][ui];

            for(ulong i = 0; i < ui; ++i)
            {
                items[0] = decodeCBOR(input);
                items[1] = decodeCBOR(input);
            }
            
            return CBORValue(assumeUnique(items));
        }

        case 6: // tag
        {
            // skip tag value
            readBigEndianInt(input, rem);

            // TODO: do not ignore tags
            return decodeCBOR(input);
        }

        case 7: // type 7
        {
            if (rem == 25) // half-float
            {
                union
                {
                    CustomFloat!16 f;
                    ushort i;
                } u;
                u.i = cast(ushort)readBigEndianIntN(input, 2);
                return CBORValue(cast(real)i.f);
            }
            else if (rem == 26) // float
            {
                union
                {
                    float f;
                    uint i;
                } u;
                u.i = cast(uint)readBigEndianIntN(input, 2);
                return CBORValue(cast(real)i.f);
            }
            else if (rem == 27) // double
            {
                union
                {
                    double f;
                    ulong i;
                } u;
                u.i = readBigEndianIntN(input, 2);
                return CBORValue(cast(real)i.f);
            }
            else
            {
                ubyte simpleID = rem;
                if (rem == 24)
                    simpleID =  input.popByte();

                // TODO warn for unknown?
                return CBORValue.simpleValue(simpleID);
            }
        }
    }
    
    return result;
}

/// Encode a single CBOR object.
/// Only ever output so-called Canonical CBOR.
ubyte[] encodeCBOR(CBORValue value)
{
    assert(0); // unimplemented
}

private 
{
    ubyte peekByte(R)(R input) if (isInputRange(R))
    {
        if (input.empty)
            throw CBORException("Expected a byte, found end of input");
        return next;
    }

    ubyte popByte(R)(R input) if (isInputRange(R))
    {
        ubyte b = peekByte();
        input.popFront();
        return b;
    }

    ulong readBigEndianInt(R)(R input, ubyte rem) if (isInputRange(R))
    {
        if (rem <= 23)
            return rem;

        int numBytes = 0;

        if (rem >= 24 && rem <= 27)
        {
            numBytes = 1 << (rem - 24);
            return readBigEndianIntN(input, numBytes);
        }
        else
            throw CBORException(text("Unexpected 5-bit value: ", rem));
    }

    ulong readBigEndianIntN(R)(R input, int numBytes) if (isInputRange(R))
    {
        ulong result = 0;
        for (int i = 0; i < numBytes; ++i)
            result = (result << 8) | input.popByte();
        return result;
    }
}
