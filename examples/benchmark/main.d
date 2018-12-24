import std.string;
import std.stdio;
import gfm.math;

// Provide numbers for improving performance of some operations.


// suggested cmdline: dub -b release-nobounds -a x86_64 --combined --compiler ldc2

void main()
{
    getCurrentThreadHandle();
    int N = 1024;
    int N4 = N / 4;
    int N8 = N / 8;
    int N44 = N / (4*4);

    float[] A = new float[N];
    float[] B = new float[N];
    float[] C = new float[N];

    for (int i = 0; i < N; ++i)
    {
        A[i] = i * 0.001f + 0.0001f;
        B[i] = i * 0.001f + 0.0001f;
        C[i] = 0;
    }

    bool precise = true;

    void benchmark(string title, void delegate() fun, int measures)
    {
        writeln(title);
        double[] samples = testFunN(fun, measures, precise);

        double minTime = double.infinity;
        foreach(m; samples)
        {
            if (minTime > m)
                minTime = m;
        }
        writefln(" => minimum time: %s", convertMicroSecondsToDisplay(minTime));
    }

    // Test vec4f additions
    vec4f* pAf = cast(vec4f*)(A.ptr);
    vec4f* pBf = cast(vec4f*)(A.ptr);
    vec4f* pCf = cast(vec4f*)(A.ptr);

    benchmark("vec4f+scalar",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = pAf[i] + B[i];
            }
        }
    }, 100);

    benchmark("vec4f*scalar",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = pAf[i] * B[i];
            }
        }
    }, 100);  

    benchmark("vec4f-scalar",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = pAf[i] - B[i];
            }
        }
    }, 100);  

    benchmark("vec4f/scalar",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = pAf[i] / B[i];
            }
        }
    }, 100);

    benchmark("scalar+vec4f",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = A[i] + pBf[i];
            }
        }
    }, 100);

    benchmark("scalar*vec4f",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = A[i] * pBf[i];
            }
        }
    }, 100);

    benchmark("scalar-vec4f-",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = A[i] - pBf[i];
            }
        }
    }, 100);

    benchmark("scalar/vec4f",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = A[i] / pBf[i];
            }
        }
    }, 100);

    benchmark("vec4f+vec4f",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = pAf[i] + pBf[i];
            }
        }
    }, 100);

    benchmark("vec4f+=vec4f",
    {
    for (int k = 0; k < 1024*32; ++k)
    {
        for (int i = 0; i < N4; ++i)
        {
            pCf[i] += pAf[i];
        }
    }
    }, 100);

    benchmark("vec4f*=vec4f",
    {
    for (int k = 0; k < 1024*32; ++k)
    {
        for (int i = 0; i < N4; ++i)
        {
            pCf[i] *= pAf[i];
        }
    }
    }, 100);


    benchmark("vec4f*vec4f",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = pAf[i] * pBf[i];
            }
        }
    }, 100);  

    benchmark("vec4f-vec4f",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = pAf[i] - pBf[i];
            }
        }
    }, 100); 

    benchmark("vec4f/vec4f",
    {
        for (int k = 0; k < 1024*32; ++k)
        {
            for (int i = 0; i < N4; ++i)
            {
                pCf[i] = pAf[i] / pBf[i];
            }
        }
    }, 100);
}



// return a time in us
double testFun(void delegate() fun, bool precise)
{
    long before = getTickUs(precise);
    fun();
    long after = getTickUs(precise);
    return after - before;
}

// return samples of measurements
double[] testFunN(void delegate() fun, int measures, bool precise)
{
    double[] res;
    foreach(i; 0..measures)
    {
        double time = testFun(fun, precise);
        res ~= time;
    }
    return res;
}


version(Windows)
{
    import core.sys.windows.windows;
    __gshared HANDLE hThread;

    extern(Windows) BOOL QueryThreadCycleTime(HANDLE   ThreadHandle, PULONG64 CycleTime) nothrow @nogc;
    long qpcFrequency;
    void getCurrentThreadHandle()
    {
        hThread = GetCurrentThread();    
        QueryPerformanceFrequency(&qpcFrequency);
    }
}
else
{
    void getCurrentThreadHandle()
    {
    }
}


static long getTickUs(bool precise) nothrow @nogc
{
    version(Windows)
    {
        if (precise)
        {
            // Note about -precise measurement
            // We use the undocumented fact that QueryThreadCycleTime
            // seem to return a counter in QPC units.
            // That may not be the case everywhere, so -precise is not reliable and should
            // never be the default.
            import core.sys.windows.windows;
            ulong cycles;
            BOOL res = QueryThreadCycleTime(hThread, &cycles);
            assert(res != 0);
            real us = 1000.0 * cast(real)(cycles) / cast(real)(qpcFrequency);
            return cast(long)(0.5 + us);
        }
        else
        {
            import core.time;
            return convClockFreq(MonoTime.currTime.ticks, MonoTime.ticksPerSecond, 1_000_000);
        }
    }
    else
    {
        import core.time;
        return convClockFreq(MonoTime.currTime.ticks, MonoTime.ticksPerSecond, 1_000_000);
    }
}


// Returns: "0.1 ms" when given 100 us
string convertMicroSecondsToDisplay(double us)
{
    double ms = (us / 1000.0);
    return format("%.3f ms", ms);
}