module gfm.net.cbor;

import std.range,
       std.conv,
       std.utf,
       std.array,
       std.traits,
       std.exception,
       std.numeric,
       std.bigint;


/**
  CBOR: Concise Binary Object Representation.
  Implementation of RFC 7049.

  References: $(LINK http://tools.ietf.org/rfc/rfc7049.txt)
  Heavily inspired by std.json by Jeremie Pelletier.

  TODO: try to fit const-correctness, not that easy
 */


/*--------------------------- The Angry Implementer Rant ---------------------------------
  WHY OH WHY can CBOR represents integers on up to 65 bits? Yes you are reading correctly.
  When reading a negative integer, values range from -1 to -2^64.
  This requires 65+ bits storage, for no apparent reason. 
  Seriously, use msgpack-d.
  ----------------------------------------------------------------------------------------*/

// ALMOST UNTESTED

immutable string CBOR_MIME_TYPE = "application/cbor";

/// Possible type of a CBORValue. Does not map 1:1 to CBOR major types.
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

/// CBOR "simple" values
enum : ubyte
{
    CBOR_FALSE = 20,
    CBOR_TRUE  = 21,
    CBOR_NULL  = 22,
    CBOR_UNDEF = 23
}

/// CBOR tags are prefixes that add a semantic meaning + required type to a value
/// Currently emitted (bignums) but not parsed.
enum CBORTag
{
    DATE_TIME              = 0,
    EPOCH_DATE_TIME        = 1,
    POSITIVE_BIGNUM        = 2,
    NEGATIVE_BIGNUM        = 3,
    DECIMAL_FRACTION       = 4,
    BIG_FLOAT              = 5,
    ENCODED_CBOR_DATA_ITEM = 24,
    URI                    = 32,
    BASE64_URI             = 33,
    BASE64                 = 34,
    REGEXP                 = 35,
    MIME_MESSAGE           = 35,
    SELF_DESCRIBE_CBOR     = 55799
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

/**
 
    Holds a single CBOR value.

 */
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
        double         floating;
        CBORValue[]    array;
        CBORValue[2][] map; // implemented as an array of (CBOR value, CBOR value) pairs
    }

    CBORType type;
    Store store; 

    this(T)(T arg) pure
    {
        this = arg;
    }

    /// Create an undefined CBOR value.
    static CBORValue simpleValue(ubyte which) pure nothrow
    {
        CBORValue result;
        result.type = CBORType.SIMPLE;
        result.store.simpleID = which;
        return result;
    }

    void opAssign(T)(T arg) pure
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
        else static if(is(T : BigInt))
        {
            type = CBORType.BIGINT;
            // HACK: it seems BigInt opAssign don't work with const(BigInt)
            store.bigint = 0;
            store.bigint = store.bigint + arg;
        }
        else static if(is(T : long))
        {
            type = CBORType.INTEGER;
            store.integer = arg;
        }
        else static if(isFloatingPoint!T)
        {
            type = CBORType.FLOATING;
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
                store.array = arg.dup;
            }
            else
            {
                CBORValue[] new_arg = new CBORValue[arg.length];
                foreach(i, e; arg)
                    new_arg[i] = CBORValue(e);
                store.array = new_arg;
            }
        }
        else static if(is(Unqual!T : CBORValue))
        {
            type = arg.type;
            final switch(arg.type)
            {
                case CBORType.ARRAY:
                {
                    size_t n = arg.store.array.length;
                    store.array = new CBORValue[n];
                    foreach(i ; 0..n)
                        store.array[i] = arg.store.array[i];
                    break;
                }
                case CBORType.BIGINT:
                {
                    store.bigint = arg.store.bigint;
                    break;
                }
                case CBORType.BYTE_STRING:
                    store.byteStr = arg.store.byteStr.dup;
                    break;
                case CBORType.FLOATING:
                    store.floating = arg.store.floating;
                    break;
                case CBORType.INTEGER:
                    store.integer = arg.store.integer;
                    break;
                case CBORType.MAP:
                {
                    size_t n = arg.store.map.length;
                    store.array = new CBORValue[n];
                    foreach(i ; 0..n)
                    {
                        store.map[i][0] = arg.store.map[i][0];
                        store.map[i][1] = arg.store.map[i][1];
                    }
                    break;
                }                    
                case CBORType.SIMPLE:
                    store.simpleID = arg.store.simpleID;
                    break;
                case CBORType.STRING:
                    store.str = arg.store.str.idup;
                    break;
                case CBORType.UINTEGER:
                    store.uinteger = arg.store.uinteger;
                    break;
            }
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
    @property ref inout(double) floating() inout
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

/// Decode a single CBOR object from an input range.
CBORValue decodeCBOR(R)(R input) if (isInputRange!R)
{
    ubyte firstByte = input.popByte();
    CBORMajorType majorType = cast(CBORMajorType)(firstByte >> 5);
    ubyte rem = firstByte & 31;

    final switch(majorType)
    {
        case CBORMajorType.POSITIVE_INTEGER:
            return CBORValue(readBigEndianInt(input, rem));

        case CBORMajorType.NEGATIVE_INTEGER:
        {
            ulong ui = readBigEndianInt(input, rem);
            long neg = -1 - ui;
            if (neg < 0)
                return CBORValue(neg); // does fit in a long
            else
                return CBORValue(-BigInt(ui) - 1); // doesn't fit in a long
        }

        case CBORMajorType.BYTE_STRING:
        {
            ubyte[] bytes;
            if (rem == 31) // indefinite length
            {
                ubyte b = input.popByte();
                while (b != 0xff)
                {
                    bytes ~= b;
                    b = input.popByte();
                }           
            }
            else
            {
                ulong ui = readBigEndianInt(input, rem);
                bytes = new ubyte[cast(size_t)ui];
                for(uint i = 0; i < ui; ++i)
                    bytes[i] = input.popByte();
            }
            return CBORValue(assumeUnique(bytes));
        }

        case CBORMajorType.UTF8_STRING:
        {
            char[] sbytes;
            if (rem == 31)
            {
                char b = input.popByte();
                while (b != 0xff)
                {
                    sbytes ~= b;
                    b = input.popByte();
                }
            }
            else
            {
                ulong ui = readBigEndianInt(input, rem);
                sbytes = new char[cast(size_t)ui];
                for(uint i = 0; i < ui; ++i)
                    sbytes[i] = input.popByte();
            }

            try
                validate(sbytes);
            catch(Exception e)
                throw new CBORException("Invalid UTF-8 string");
            return CBORValue(assumeUnique(sbytes));
        }

        case CBORMajorType.ARRAY:
        {
            CBORValue[] items;
            if (rem == 31) // indefinite length
            {
                while (true)
                {
                    ubyte b = input.peekByte();
                    if (b == 0xff)
                    {
                        input.popFront();
                        break;
                    }
                    items ~= decodeCBOR(input);
                }        
            }
            else
            {
                ulong ui = readBigEndianInt(input, rem);
                items = new CBORValue[cast(size_t)ui];
                foreach(ref item; items)
                    item = decodeCBOR(input);
            }            
            return CBORValue(assumeUnique(items));
        }

        case CBORMajorType.MAP:
        {
            CBORValue[2][] items;
            if (rem == 31) // indefinite length
            {
                while (true)
                {
                    ubyte b = input.peekByte();
                    if (b == 0xff)
                    {
                        input.popFront();
                        break;
                    }
                    CBORValue[2] item;
                    item[0] = decodeCBOR(input);
                    item[1] = decodeCBOR(input);
                    items ~= item;
                }        
            }
            else
            {
                ulong ui = readBigEndianInt(input, rem);
                items = new CBORValue[2][cast(size_t)ui];

                for(ulong i = 0; i < ui; ++i)
                {
                    items[i][0] = decodeCBOR(input);
                    items[i][1] = decodeCBOR(input);
                }
            }            
            return CBORValue(assumeUnique(items));
        }

        case CBORMajorType.SEMANTIC_TAG:
        {
            // skip tag value
            readBigEndianInt(input, rem);

            // TODO: do not ignore tags
            return decodeCBOR(input);
        }

        case CBORMajorType.TYPE_7:
        {
            switch (rem)
            {
                case 0: .. case 23: // one byte simple value
                    return CBORValue.simpleValue(rem);

                case 24: // two bytes simple value
                {
                    ubyte b = input.popByte();
                    if (24 <= b && b <= 31) 
                        throw new CBORException("Reserved value used in Type 7 Additional Information");
                    return CBORValue.simpleValue(input.popByte());
                }

                case 25: // half-float
                {
                    half_ushort hu = void;
                    hu.i = cast(ushort)readBigEndianIntN(input, 2);
                    return CBORValue(cast(double)hu.f);
                }
                case 26: //float
                {
                    float_uint fu = void;
                    fu.i = cast(uint)readBigEndianIntN(input, 4);
                    return CBORValue(cast(double)fu.f);
                }
                case 27: // double
                {
                    double_ulong du = void;
                    du.i = readBigEndianIntN(input, 8);
                    return CBORValue(cast(real)du.f);
                }

                case 28: .. case 30:
                    throw new CBORException("Unknown type-7 sub-type");

                case 31:
                    throw new CBORException("Unexpected break stop code");

                default:
                    assert(false); // impossible
            }
        }
    }
}

/// Encode a single CBOR object to an array of bytes.
/// Only ever output so-called Canonical CBOR.
ubyte[] encodeCBORBytes(CBORValue value)
{
    auto app = std.array.appender!(ubyte[]);
    encodeCBOR(app, value);
    return app.data();
}

/// Encode a single CBOR object in a range.
/// Only ever output so-called Canonical CBOR (as small as possible).
void encodeCBOR(R)(R output, CBORValue value) if (isOutputRange!(R, ubyte))
{
    final switch(value.type)
    {
        case CBORType.STRING:
        {
            writeMajorTypeAndBigEndianInt(output, CBORMajorType.UTF8_STRING, value.store.str.length);
            foreach(char b; value.store.str)
                output.put(b);
            break;
        }

        case CBORType.BYTE_STRING: 
        {            
            writeMajorTypeAndBigEndianInt(output, CBORMajorType.BYTE_STRING, value.store.byteStr.length);
            foreach(ubyte b; value.store.byteStr)
                output.put(b);
            break;
        }

        case CBORType.INTEGER:
        {
            long x = value.store.integer;
            if (x >= 0)
                writeMajorTypeAndBigEndianInt(output, CBORMajorType.POSITIVE_INTEGER, x);
            else
                writeMajorTypeAndBigEndianInt(output, CBORMajorType.NEGATIVE_INTEGER, -x - 1); // always fit
            break;
        }

        case CBORType.UINTEGER:
        {
            writeMajorTypeAndBigEndianInt(output, CBORMajorType.POSITIVE_INTEGER, value.store.uinteger);
            break;
        }

        case CBORType.BIGINT:
        {
            BigInt N = value.store.bigint;
            if (0 <= N && N <= 4294967295)
            {
                // fit in a positive integer
                writeMajorTypeAndBigEndianInt(output, CBORMajorType.POSITIVE_INTEGER, N.toLong());
            }
            else if (-4294967296 <= N && N < 0)
            {
                // fit in a negative integer
                writeMajorTypeAndBigEndianInt(output, CBORMajorType.NEGATIVE_INTEGER, (-N-1).toLong());
            }
            else
            {
                // doesn't fit in integer major types
                // lack of access to byte data => using a hex string for now
                if (N >= 0)
                    output.putTag(CBORTag.POSITIVE_BIGNUM);
                else
                {
                    output.putTag(CBORTag.NEGATIVE_BIGNUM);
                    N = -N - 1;
                }

                ubyte[] bytes = bigintBytes(N);
                
                writeMajorTypeAndBigEndianInt(output, CBORMajorType.BYTE_STRING, bytes.length);
                foreach(ubyte b; bytes)
                    output.put(b);
            }
            break;
        }

        case CBORType.FLOATING:
        {
            double d = value.store.floating;
            half_t asHalf = cast(half_t)d;
            float asFloat = cast(float)d;
            
            if (cast(double)asHalf == d) // does it fit in a half?
            {
                half_ushort hu = void;
                hu.f = asHalf;
                output.writeMajorType(CBORMajorType.TYPE_7, 25);
                output.writeBigEndianIntN(2, hu.i);
            }
            else if (cast(double)asFloat == d) // does it fit in a float?
            {
                float_uint fu = void;
                fu.f = asFloat;
                output.writeMajorType(CBORMajorType.TYPE_7, 26);
                output.writeBigEndianIntN(4, fu.i);
            }
            else 
            {
                // encode as double
                double_ulong du = void;
                du.f = d;
                output.writeMajorType(CBORMajorType.TYPE_7, 27);
                output.writeBigEndianIntN(8, du.i);
            }
            break;
        }

        case CBORType.ARRAY:
        {
            size_t l = value.store.array.length;
            writeMajorTypeAndBigEndianInt(output, CBORMajorType.ARRAY, l);
            for(size_t i = 0; i < l; ++i)
                encodeCBOR(output, value.store.array[i]);
            break;
        }

        case CBORType.MAP:
        {
            size_t l = value.store.map.length;
            writeMajorTypeAndBigEndianInt(output, CBORMajorType.MAP, l);
            for(size_t i = 0; i < l; ++i)
            {
                encodeCBOR(output, value.store.map[i][0]);
                encodeCBOR(output, value.store.map[i][1]);
            }
            break;
        }

        case CBORType.SIMPLE: 
        {
            ubyte simpleID = value.store.simpleID;
            if (simpleID <= 23)
                output.writeMajorType(CBORMajorType.TYPE_7, simpleID);
            else
            {
                output.writeMajorType(CBORMajorType.TYPE_7, 24);
                output.put(simpleID);
            }
            break;
        }
    }    
}

private 
{
    alias CustomFloat!16 half_t; // when std.halffloat will be here, use it instead

    union half_ushort
    {
        half_t f;
        ushort i;
    }

    union float_uint
    {
        float f;
        uint i;
    }

    union double_ulong
    {
        double f;
        ulong i;
    }

    enum CBORMajorType
    {
        POSITIVE_INTEGER = 0,
        NEGATIVE_INTEGER = 1,
        BYTE_STRING      = 2,
        UTF8_STRING      = 3,
        ARRAY            = 4,
        MAP              = 5,
        SEMANTIC_TAG     = 6,
        TYPE_7           = 7
    }

    ubyte peekByte(R)(ref R input) if (isInputRange!R)
    {
        if (input.empty)
            throw new CBORException("Expected a byte, found end of input");
        return input.front;
    }

    ubyte popByte(R)(ref R input) if (isInputRange!R)
    {
        ubyte b = peekByte(input);
        input.popFront();
        return b;
    }

    ulong readBigEndianInt(R)(ref R input, ubyte rem) if (isInputRange!R)
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
            throw new CBORException(text("Unexpected 5-bit value: ", rem));
    }

    ulong readBigEndianIntN(R)(ref R input, int numBytes) if (isInputRange!R)
    {
        ulong result = 0;
        for (int i = 0; i < numBytes; ++i)
            result = (result << 8) | input.popByte();
        return result;
    }

    void writeBigEndianIntN(R)(ref R output, int numBytes, ulong n) if (isOutputRange!(R, ubyte))
    {
        for (int i = 0; i < numBytes; ++i)
        {
            ubyte b = (n >> (numBytes - 1 - i)) & 255;
            output.put(b);
        }
    }

    void writeMajorType(R)(ref R output, CBORMajorType majorType, ubyte rem) if (isOutputRange!(R, ubyte))
    {
        ubyte b = cast(ubyte)((majorType << 5) | rem);
        output.put(b);
    }

    void writeMajorTypeAndBigEndianInt(R)(R output, ubyte majorType, ulong n) if (isOutputRange!(R, ubyte))
    {
        int nAddBytes;
        ubyte firstB = (majorType << 5) & 255;
        if (0 <= n && n <= 23)
        {
            // encode with major type
            ubyte b = firstB | (n & 255);
            output.put(b);
            nAddBytes = 0;
        }
        else if (24 <= n && n <= 255)
        {
            ubyte b = firstB | 24;
            output.put(b);
            nAddBytes = 1;
        }
        else if (256 <= n && n <= 65535)
        {
            ubyte b = firstB | 25;
            output.put(b);
            nAddBytes = 2;
        }
        else if (65536 <= n && n <= 4294967295)
        {
            ubyte b = firstB | 26;
            output.put(b);
            nAddBytes = 4;
        }
        else 
        {
            ubyte b = firstB | 27;
            output.put(b);
            nAddBytes = 8;
        }

        for (int i = 0; i < nAddBytes; ++i)
        {
            ubyte b = (n >> ((nAddBytes - 1 - i) * 8)) & 255;
            output.put(b);
        }
    }

    void putTag(R)(ref R output, CBORTag tag) if (isOutputRange!(R, ubyte))
    {
        output.writeMajorTypeAndBigEndianInt(CBORMajorType.SEMANTIC_TAG, tag);
    }

    // Convert BigInt to bytes, much too involved.
    ubyte[] bigintBytes(BigInt n)
    {
        assert(n >= 0);
        string s = n.toHex();
        if (s.length % 2 != 0)
            assert(false);

        int hexCharToInt(char c)
        {
            if (c >= '0' && c <= '9')
                return c - '0';
            else if (c >= 'a' && c <= 'f')
                return c - 'a' + 10;
            else if (c >= 'A' && c <= 'F')
                return c - 'A' + 10;
            else
                assert(false);
        }

        size_t len = s.length / 2;
        ubyte[] bytes = new ubyte[len];
        for (size_t i = 0; i < len; ++i)
        {
            bytes[i] = cast(ubyte)(hexCharToInt(s[i * 2]) * 16 + hexCharToInt(s[i * 2 + 1]));
        }           
        return bytes;
    }
}


unittest
{
    ubyte[] x(string s)
    {
        ubyte[] res = new ubyte[s.length];
        memcpy(res.ptr, s.ptr, s.length);
        return res;
    }

    int[] arr = [1, 2, 3];
    CBORValue a = CBORValue(arr);
    CBORValue b = CBORValue(2);
    CBORValue c = CBORValue(true);
    ubyte[] bytes = x(x"83 01 02 03");

    
    CBORValue v = decodeCBOR(bytes);
    encodeCBORBytes(v);
  //  assert(v == a);
}
