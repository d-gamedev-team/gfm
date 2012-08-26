module gfm.math.statistics;

import std.range;
import std.math;
import gfm.common.queue;

/**
 * Arithmetic mean.
 */
double average(R)(R r) if (isInputRange!R)
{
    if (r.empty)
        return double.nan;

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
 * TODO: remove, dupe
 */
double minimum(R)(R r) if (isInputRange!R)
{
    // do like Javascript for an empty range
    if (r.empty)
        return double.infinity;

    return minmax!("<", R)(r);
}

/**
 * Maximum of a range.
 * TODO: remove, dupe
 */
double maximum(R)(R r) if (isInputRange!R)
{
    // do like Javascript for an empty range
    if (r.empty)
        return -double.infinity;

    return minmax!(">", R)(r);
}

/**
 * Variance of a range.
 */
double variance(R)(R r) if (isForwardRange!R)
{
    if (r.empty)
        return double.nan;

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
        return (sum / (count - 1.0)); // using sample std deviation as estimator
}

/**
 * Standard deviation of a range.
 */
double standardDeviation(R)(R r) if (isForwardRange!R)
{
    return sqrt(variance(r));
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
