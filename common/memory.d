module gfm.common.memory;

import std.c.stdlib : malloc, free, realloc;

// only works with powers of 2
size_t nextMultipleOf(size_t n, size_t powerOfTwo) pure nothrow
{
    size_t mask = ~(powerOfTwo - 1);
    return (n + powerOfTwo - 1) & mask;
}

void* nextAlignedPointer(void* start, size_t alignment) pure nothrow
{
    return cast(void*)nextMultipleOf(cast(size_t)(start), alignment);
}

// allocate aligned memory
// functionally equivalent to Visual C++ _aligned_malloc
void* alignedMalloc(size_t size, size_t alignment) nothrow
{
    if (size == 0)
        return null;

    void* raw = malloc(requestedSize(size, alignment));

    return storeRawPointerAndReturnAligned(raw, alignment);
}

// free aligned memory
// functionally equivalent to Visual C++ _aligned_free
void alignedFree(void* aligned) nothrow
{
    // support for free(NULL)
    if (aligned is null)
        return;

    void** rawLocation = cast(void**)(cast(char*)aligned - size_t.sizeof);
    free(*rawLocation);
}

// realloc aligned memory
// functionally equivalent to Visual C++ _aligned_realloc
void* alignedRealloc(void* aligned, size_t size, size_t alignment) nothrow
{
    if (aligned is null)
        return alignedMalloc(size, alignment);

    if (size == 0)
    {
        alignedFree(aligned);
        return null;
    }

    void* raw = *cast(void**)(cast(char*)aligned - size_t.sizeof);
    void* newRaw = realloc(raw, requestedSize(size, alignment));

    // if newRaw is raw, nothing to do
    if (raw is newRaw)
        return raw;

    // else write raw at the new location
    return storeRawPointerAndReturnAligned(newRaw, alignment);
}

// return number of bytes to actually allocate when asking
// for a particular alignement
private size_t requestedSize(size_t askedSize, size_t alignment) pure nothrow
{
    enum size_t pointerSize = size_t.sizeof;
    return askedSize + alignment - 1 + pointerSize;
}

private void* storeRawPointerAndReturnAligned(void* raw, size_t alignment) nothrow
{
    enum size_t pointerSize = size_t.sizeof;
    char* start = cast(char*)raw + pointerSize;
    void* aligned = nextAlignedPointer(start, alignment);
    void** rawLocation = cast(void**)(cast(char*)aligned - pointerSize);
    *rawLocation = raw;
    return aligned;
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
