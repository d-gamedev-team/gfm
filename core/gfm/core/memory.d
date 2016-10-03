/**
  This module provide support for aligned memory.
 */
module gfm.core.memory;

import core.memory : GC;
import core.exception : onOutOfMemoryError;
import core.stdc.string : memcpy;
import core.stdc.stdlib : malloc, free, realloc;

import std.conv : emplace;
import std.traits;
import std.algorithm: swap;


/// Returns: next pointer aligned with alignment bytes.
deprecated("Use dplug:core instead") @nogc void* nextAlignedPointer(void* start, size_t alignment) pure nothrow
{
    return cast(void*)nextMultipleOf(cast(size_t)(start), alignment);
}

/// Allocates an aligned memory chunk.
/// Functionally equivalent to Visual C++ _aligned_malloc.
deprecated("Use dplug:core instead") @nogc void* alignedMalloc(size_t size, size_t alignment) nothrow
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

    return storeRawPointerPlusSizeAndReturnAligned(raw, size, alignment);
}

/// Frees aligned memory allocated by alignedMalloc or alignedRealloc.
/// Functionally equivalent to Visual C++ _aligned_free.
deprecated("Use dplug:core instead") @nogc void alignedFree(void* aligned) nothrow
{
    // support for free(NULL)
    if (aligned is null)
        return;

    void** rawLocation = cast(void**)(cast(char*)aligned - size_t.sizeof);
    free(*rawLocation);
}

/// Reallocates an aligned memory chunk allocated by alignedMalloc or alignedRealloc.
/// Functionally equivalent to Visual C++ _aligned_realloc.
deprecated("Use dplug:core instead") @nogc void* alignedRealloc(void* aligned, size_t size, size_t alignment) nothrow
{
    if (aligned is null)
        return alignedMalloc(size, alignment);

    if (size == 0)
    {
        alignedFree(aligned);
        return null;
    }

    size_t previousSize = *cast(size_t*)(cast(char*)aligned - size_t.sizeof * 2);


    void* raw = *cast(void**)(cast(char*)aligned - size_t.sizeof);
    size_t request = requestedSize(size, alignment);

    // Heuristic: if new requested size is within 50% to 100% of what is already allocated
    //            then exit with the same pointer
    if ( (previousSize < request * 4) && (request <= previousSize) )
        return aligned;

    void* newRaw = malloc(request);
    static if( __VERSION__ > 2067 ) // onOutOfMemoryError wasn't nothrow before July 2014
    {
        if (request > 0 && newRaw == null) // realloc(0) can validly return anything
            onOutOfMemoryError();
    }

    void* newAligned = storeRawPointerPlusSizeAndReturnAligned(newRaw, request, alignment);
    size_t minSize = size < previousSize ? size : previousSize;
    memcpy(newAligned, aligned, minSize);

    // Free previous data
    alignedFree(aligned);
    return newAligned;
}

private
{
    // Returns number of bytes to actually allocate when asking
    // for a particular alignement
    deprecated("Use dplug:core instead") @nogc size_t requestedSize(size_t askedSize, size_t alignment) pure nothrow
    {
        enum size_t pointerSize = size_t.sizeof;
        return askedSize + alignment - 1 + pointerSize * 2;
    }

    // Store pointer given my malloc, and size in bytes initially requested (alignedRealloc needs it)
    deprecated("Use dplug:core instead") @nogc void* storeRawPointerPlusSizeAndReturnAligned(void* raw, size_t size, size_t alignment) nothrow
    {
        enum size_t pointerSize = size_t.sizeof;
        char* start = cast(char*)raw + pointerSize * 2;
        void* aligned = nextAlignedPointer(start, alignment);
        void** rawLocation = cast(void**)(cast(char*)aligned - pointerSize);
        *rawLocation = raw;
        size_t* sizeLocation = cast(size_t*)(cast(char*)aligned - 2 * pointerSize);
        *sizeLocation = size;
        return aligned;
    }

    // Returns: x, multiple of powerOfTwo, so that x >= n.
    deprecated("Use dplug:core instead") @nogc size_t nextMultipleOf(size_t n, size_t powerOfTwo) pure nothrow
    {
        // check power-of-two
        assert( (powerOfTwo != 0) && ((powerOfTwo & (powerOfTwo - 1)) == 0));

        size_t mask = ~(powerOfTwo - 1);
        return (n + powerOfTwo - 1) & mask;
    }
}


/// Allocates and construct a struct or class object.
/// Returns: Newly allocated object.
deprecated("Use dplug:core instead") auto mallocEmplace(T, Args...)(Args args)
{
    static if (is(T == class))
        immutable size_t allocSize = __traits(classInstanceSize, T);
    else
        immutable size_t allocSize = T.sizeof;

    void* rawMemory = malloc(allocSize);
    if (!rawMemory)
        onOutOfMemoryError();

    static if (hasIndirections!T)
        GC.addRange(rawMemory, allocSize);

    static if (is(T == class))
    {
        T obj = emplace!T(rawMemory[0 .. allocSize], args);
    }
    else
    {
        T* obj = cast(T*)rawMemory;
        emplace!T(obj, args);
    }

    return obj;
}

/// Destroys and frees a class object created with $(D mallocEmplace).
deprecated("Use dplug:core instead") void destroyFree(T)(T p) if (is(T == class))
{
    if (p !is null)
    {
        .destroy(p);

        static if (hasIndirections!T)
            GC.removeRange(cast(void*)p);

        free(cast(void*)p);
    }
}

/// Destroys and frees a non-class object created with $(D mallocEmplace).
deprecated("Use dplug:core instead") void destroyFree(T)(T* p) if (!is(T == class))
{
    if (p !is null)
    {
        .destroy(p);

        static if (hasIndirections!T)
            GC.removeRange(cast(void*)p);

        free(cast(void*)p);
    }
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
deprecated("Use dplug:core instead") void debugBreak() nothrow @nogc
{
    version( AsmX86 )
    {
        asm nothrow @nogc
        {
            int 3;
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

deprecated("Use dplug:core instead") auto assumeNoGC(T) (T t) if (isFunctionPointer!T || isDelegate!T)
{
    enum attrs = functionAttributes!T | FunctionAttribute.nogc;
    return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

deprecated("Use dplug:core instead") auto assumeNothrow(T) (T t) if (isFunctionPointer!T || isDelegate!T)
{
    enum attrs = functionAttributes!T | FunctionAttribute.nothrow_;
    return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

deprecated("Use dplug:core instead") auto assumeNothrowNoGC(T) (T t) if (isFunctionPointer!T || isDelegate!T)
{
    enum attrs = functionAttributes!T | FunctionAttribute.nogc | FunctionAttribute.nothrow_;
    return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

/// Stresses the GC for a collect to occur, can be useful to reproduce bugs
deprecated void stressGC() pure nothrow
{
    class A { }
    A[] a;
    for (int i = 0; i < 1000; ++i)
    {
        a ~= new A;
    }
}

/// Must return -1 if a < b
///              0 if a == b
///              1 if a > b
alias nogcComparisonFunction(T) = int delegate(in T a, in T b) nothrow @nogc;

/// @nogc quicksort
/// From the excellent: http://codereview.stackexchange.com/a/77788
deprecated("Use dplug:core instead") void nogc_qsort(T)(T[] array, nogcComparisonFunction!T comparison) nothrow @nogc
{
    if (array.length < 2)
        return;

    int partition(T* arr, int left, int right) nothrow @nogc
    {
        immutable int mid = left + (right - left) / 2;
        T pivot = arr[mid];
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
