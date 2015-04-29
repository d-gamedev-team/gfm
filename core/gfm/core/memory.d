/**
  This module provide support for aligned memory.
 */
module gfm.core.memory;

import core.memory : GC;
import core.exception : onOutOfMemoryError;

import std.c.stdlib : malloc, free, realloc;
import std.conv : emplace;
import std.traits;


static if( __VERSION__ < 2066 ) private enum nogc = 1;

/// Returns: next pointer aligned with alignment bytes.
@nogc void* nextAlignedPointer(void* start, size_t alignment) pure nothrow
{
    return cast(void*)nextMultipleOf(cast(size_t)(start), alignment);
}

/// Allocates an aligned memory chunk.
/// Functionally equivalent to Visual C++ _aligned_malloc.
@nogc void* alignedMalloc(size_t size, size_t alignment) nothrow
{
    if (size == 0)
        return null;

    size_t request = requestedSize(size, alignment);
    void* raw = malloc(request);

    static if( __VERSION__ > 2067 ) // onOutOfMemoryError wasn't nothrow before July 2014
    {
        if (request > 0 && raw == null) // malloc(0) can validly return anything
            onOutOfMemoryError();
    }

    return storeRawPointerAndReturnAligned(raw, alignment);
}

/// Frees aligned memory allocated by alignedMalloc or alignedRealloc.
/// Functionally equivalent to Visual C++ _aligned_free.
@nogc void alignedFree(void* aligned) nothrow
{
    // support for free(NULL)
    if (aligned is null)
        return;

    void** rawLocation = cast(void**)(cast(char*)aligned - size_t.sizeof);
    free(*rawLocation);
}

/// Reallocates an aligned memory chunk allocated by alignedMalloc or alignedRealloc.
/// Functionally equivalent to Visual C++ _aligned_realloc.
@nogc void* alignedRealloc(void* aligned, size_t size, size_t alignment) nothrow
{
    if (aligned is null)
        return alignedMalloc(size, alignment);

    if (size == 0)
    {
        alignedFree(aligned);
        return null;
    }

    void* raw = *cast(void**)(cast(char*)aligned - size_t.sizeof);

    size_t request = requestedSize(size, alignment);
    void* newRaw = realloc(raw, request);
    
    static if( __VERSION__ > 2067 ) // onOutOfMemoryError wasn't nothrow before July 2014
    {
        if (request > 0 && newRaw == null) // realloc(0) can validly return anything
            onOutOfMemoryError();
    }

    // if newRaw is raw, nothing to do
    if (raw is newRaw)
        return aligned;

    // else write raw at the new location
    return storeRawPointerAndReturnAligned(newRaw, alignment);
}

private
{
    // Returns number of bytes to actually allocate when asking
    // for a particular alignement
    @nogc size_t requestedSize(size_t askedSize, size_t alignment) pure nothrow
    {
        enum size_t pointerSize = size_t.sizeof;
        return askedSize + alignment - 1 + pointerSize;
    }

    @nogc void* storeRawPointerAndReturnAligned(void* raw, size_t alignment) nothrow
    {
        enum size_t pointerSize = size_t.sizeof;
        char* start = cast(char*)raw + pointerSize;
        void* aligned = nextAlignedPointer(start, alignment);
        void** rawLocation = cast(void**)(cast(char*)aligned - pointerSize);
        *rawLocation = raw;
        return aligned;
    }

    // Returns: x, multiple of powerOfTwo, so that x >= n.
    @nogc size_t nextMultipleOf(size_t n, size_t powerOfTwo) pure nothrow
    {
        // check power-of-two
        assert( (powerOfTwo != 0) && ((powerOfTwo & (powerOfTwo - 1)) == 0));

        size_t mask = ~(powerOfTwo - 1);
        return (n + powerOfTwo - 1) & mask;
    }
}

unittest
{
    {
        void* p = alignedMalloc(23, 16);
        assert(p !is null);
        assert(((cast(size_t)p) & 0xf) == 0);

        alignedFree(p);
    }

    assert(alignedMalloc(0, 16) == null);
    alignedFree(null);

    {
        void* p = alignedRealloc(null, 100, 16);
        p = alignedRealloc(p, 200, 16);
        p = alignedRealloc(p, 0, 16);
    }
}


/// Allocates and construct a struct or class object.
/// Returns: Newly allocated object.
auto mallocEmplace(T, Args...)(Args args)
{
    static if (is(T == class))
        immutable size_t allocSize = __traits(classInstanceSize, T);
    else
        immutable size_t allocSize = T.sizeof;

    void* rawMemory = malloc(allocSize);
    if (!rawMemory)
        onOutOfMemoryError();

    static if (is(T == class))
    {
        T obj = emplace!T(rawMemory[0 .. allocSize], args); 
    }
    else
    {
        T* obj = cast(T*)rawMemory;
        emplace!T(obj, args);
    }

    static if (hasIndirections!T)
        GC.addRange(rawMemory, allocSize);

    return obj;
}

/// Destroys and frees a class object created with $(D mallocEmplace).
void destroyFree(T)(T p) if (is(T == class))
{
    if (p !is null)
    {
        destroy(p);

        static if (hasIndirections!T)
            GC.removeRange(cast(void*)p);

        free(cast(void*)p);
    }
}

/// Destroys and frees a non-class object created with $(D mallocEmplace).
void destroyFree(T)(T* p) if (!is(T == class))
{
    if (p !is null)
    {
        destroy(p);

        static if (hasIndirections!T)
            GC.removeRange(cast(void*)p);

        free(cast(void*)p);
    }
}

unittest
{
    class A
    {
        int _i;
        this(int i)
        {
            _i = i;
        }
    }

    struct B
    {
        int i;
    }

    void testMallocEmplace()
    {
        A a = mallocEmplace!A(4);
        destroyFree(a);

        B* b = mallocEmplace!B(5);
        destroyFree(b);
    }

    testMallocEmplace();
}

version( D_InlineAsm_X86 )
{
    version = AsmX86;
}
else version( D_InlineAsm_X86_64 )
{
    version = AsmX86;
}

/// Inserts a breakpoint instruction. useful to trigger the debugger.
void debugBreak() nothrow @nogc
{
    version( AsmX86 )
    {
        static if( __VERSION__ >= 2067 )
        {
            mixin("asm nothrow @nogc { int 3; }");
        }
        else
        {
            mixin("asm { int 3; }");
        }
    }
    else
    {
        static assert(false, "Not implemented for this architecture");
    }
}
