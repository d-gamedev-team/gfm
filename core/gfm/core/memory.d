/**
  This module provide support for aligned memory.
 */
module gfm.core.memory;

import core.memory : GC;
import core.exception : onOutOfMemoryError;

import std.c.stdlib : malloc, free, realloc;
import std.conv : emplace;
import std.traits;
import std.algorithm: swap;


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
    assert(nextMultipleOf(0, 4) == 0);
    assert(nextMultipleOf(1, 4) == 4);
    assert(nextMultipleOf(2, 4) == 4);
    assert(nextMultipleOf(3, 4) == 4);
    assert(nextMultipleOf(4, 4) == 4);
    assert(nextMultipleOf(5, 4) == 8);

    {
        void* p = alignedMalloc(23, 16);
        assert(p !is null);
        assert(((cast(size_t)p) & 0xf) == 0);

        alignedFree(p);
    }

    assert(alignedMalloc(0, 16) == null);
    alignedFree(null);

    {
        int alignment = 16;
        int* p = null;

        // check if growing keep values in place
        foreach(int i; 0..100)
        {
            p = cast(int*) alignedRealloc(p, (i + 1) * int.sizeof, alignment);
            p[i] = i;
        }

        foreach(int i; 0..100)
            assert(p[i] == i);


        p = cast(int*) alignedRealloc(p, 0, alignment);
        assert(p is null);
    }
}


/// Destructors called by the GC enjoy a variety of limitations and
/// relying on them is dangerous.
/// See_also: $(WEB p0nce.github.io/d-idioms/#The-trouble-with-class-destructors)
/// Example:
/// ---
/// class Resource
/// {
///     ~this()
///     {
///         if (!alreadyClosed)
///         {
///             if (isCalledByGC())
///                 assert(false, "Resource release relies on Garbage Collection");
///             alreadyClosed = true;
///             releaseResource();
///         }
///     }
/// }
/// ---
bool isCalledByGC() nothrow
{
    import core.exception;
    try
    {
        import core.memory;
        cast(void) GC.malloc(1); // not ideal since it allocates
        return false;
    }
    catch(InvalidMemoryOperationError e)
    {
        return true;
    }
}

unittest
{
    import std.stdio;
    class A
    {
        ~this()
        {
            assert(!isCalledByGC());
        }
    }
    import std.typecons;
    auto a = scoped!A();
}

/// Crash if the GC is running.
/// Useful in destructors to avoid reliance GC resource release.
/// See_also: $(WEB p0nce.github.io/d-idioms/#GC-proof-resource-class)
void ensureNotInGC(string resourceName = null) nothrow
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
        fprintf(stderr, "Error: clean-up of %s incorrectly depends on destructors called by the GC.\n",
                        resourceName ? resourceName.ptr : "a resource".ptr);
        assert(false); // crash
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
    else version( GNU )
    {
        // __builtin_trap() is not the same thing unfortunately
        asm
        {
            "int $0x03" : : : ;
        }
    }
    else
    {
        static assert(false, "No debugBreak() for this compiler");
    }
}

auto assumeNoGC(T) (T t) if (isFunctionPointer!T || isDelegate!T)
{
    enum attrs = functionAttributes!T | FunctionAttribute.nogc;
    return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

auto assumeNothrow(T) (T t) if (isFunctionPointer!T || isDelegate!T)
{
    enum attrs = functionAttributes!T | FunctionAttribute.nothrow_;
    return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

auto assumeNothrowNoGC(T) (T t) if (isFunctionPointer!T || isDelegate!T)
{
    enum attrs = functionAttributes!T | FunctionAttribute.nogc | FunctionAttribute.nothrow_;
    return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

unittest
{
    void funcThatDoesGC()
    {
        throw new Exception("hello!");
    }

    void anotherFunction() nothrow @nogc
    {
        assumeNothrowNoGC( (){ funcThatDoesGC(); } )();
    }

    void aThirdFunction() @nogc
    {
        assumeNoGC( () { funcThatDoesGC(); } )();
    }
}

/// Must return -1 if a < b
///              0 if a == b
///              1 if a > b
alias nogcComparisonFunction(T) = int delegate(in T a, in T b) nothrow @nogc;

/// @nogc quicksort
/// From the excellent: http://codereview.stackexchange.com/a/77788
void nogc_qsort(T)(T[] array, nogcComparisonFunction!T comparison) nothrow @nogc
{
    if (array.length < 2)
        return;

    int partition(T* arr, int left, int right) nothrow @nogc
    {
        immutable int mid = left + (right - left) / 2;
        immutable T pivot = arr[mid];
        // move the mid point value to the front.
        swap(arr[mid],arr[left]);
        int i = left + 1;
        int j = right;
        while (i <= j)
        {
            while(i <= j && comparison(arr[i], pivot) <= 0 )
                i++;

            while(i <= j && comparison(arr[j], pivot) > 0)
                j--;

            if (i < j)
                swap(arr[i], arr[j]);
        }
        swap(arr[i - 1], arr[left]);
        return i - 1;
    }

    void doQsort(T* array, int left, int right) nothrow @nogc
    {
        if (left >= right)
            return;

        int part = partition(array, left, right);
        doQsort(array, left, part - 1);
        doQsort(array, part + 1, right);
    }

    doQsort(array.ptr, 0, cast(int)(array.length) - 1);
}

unittest
{
    int[] testData = [110, 5, 10, 3, 22, 100, 1, 23];
    nogc_qsort!int(testData, (a, b) => (a - b));
    assert(testData == [1, 3, 5, 10, 22, 23, 100, 110]);
}