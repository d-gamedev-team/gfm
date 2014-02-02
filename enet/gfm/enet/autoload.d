/// If included in the executable, loads DerelictENet and initializes ENet at
/// program start. Also deinitializes ENet and unloads DerelictENet at program
/// termination.

module enet.autoload;

import core.memory;
import enet.library;

shared static this()
{
    startENet();
}

shared static ~this()
{
    GC.collect(); // Ensure all ENet-related memory is freed by destructors
    stopENet();
}
