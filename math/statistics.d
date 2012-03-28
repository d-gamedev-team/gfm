module gfm.math.statistics;

import std.range;
import std.math;
import gfm.common.queue;

nothrow
{
    /**
     * Arithmetic mean.
     */
    auto average(R)(R r) if (isInputRange!R)
    {
        assert(!r.empty);
        typeof(r.front()) sum = 0;
        size_t count = 0;
        foreach(e; r)
        {
            sum += e;
            ++count;
        }
        return sum / count;
    }

    /**
     * Minimum of a range.
     */
    auto minimum(R)(R r) if (isInputRange!R)
    {
        return minmax!("<", R)(r);
    }

    /**
     * Maximum of a range.
     */
    auto maximum(R)(R r) if (isInputRange!R)
    {
        return minmax!(">", R)(r);
    }

    double standardDeviation(R)(R r) if (isForwardRange!R)
    {
        assert(!r.empty);
        auto avg = average(r.save); // getting the average

        typeof(avg) sum = 0;
        size_t count = 0;
        foreach(e; r)
        {
            sum += (e - avg) ^^ 2;
            ++count;
        }
        if (count <= 1)
            return 0.0;
        else
            return sqrt(sum / (count - 1.0)); // using sample std deviation as estimator
    }

    private
    {
        typeof(R.front()) minmax(string op, R)(R r) if (isInputRange!R)
        {
            assert(!r.empty);
            auto best = r.front();
            r.popFront();
            foreach(e; r)
            {
                mixin("if (e " ~ op ~ " best) best = e;");
            }
            return best;
        }
    }
}

class Statistics(T)
{
nothrow:
    public
    {
        this(size_t nSamples, T initialValue)
        {
            _samples = new Queue!T(nSamples);

            for (size_t i = 0; i < nSamples; ++i)
                _samples.pushBack(initialValue);
        }

        void eat(T x)
        {
            _samples.popFront();
            _samples.pushBack(x);
        }

        T computeMinimum()
        {
            return minimum(_samples.range());
        }

        T computeMaximum()
        {
            return maximum(_samples.range());
        }

        T computeAverage()
        {
            return average(_samples.range());
        }

        double computeStdDeviation()
        {
            return standardDeviation(_samples.range());
        }
    }

    private
    {
        Queue!ulong _samples; // samples FIFO
    }
}
