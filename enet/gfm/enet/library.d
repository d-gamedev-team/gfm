/// Deals with the setup and cleanup necessary to properly use the ENet library.

module gfm.enet.library;

import derelict.util.exception;
import derelict.enet.enet;
import gfm.enet.exceptions;

package bool enetInitialized = false;

/// Loads DerelictENet and initializes the ENet library.
/// Throws: ENetException when enet_initialize fails
void startENet()
{
    if(!enetInitialized)
    {
        try
        {
            DerelictENet.load();
        }
        catch(DerelictException e)
        {
            throw new ENetException(e.msg);
        }

        auto errCode = enet_initialize();
        if(errCode < 0)
            throw new ENetException("enet_initialize failed");
        
        enetInitialized = true;
    }
}

/// Deinitializes the ENet library and unloads DerelictENet.
void stopENet()
{
    if(enetInitialized)
    {
        enet_deinitialize();
        DerelictENet.unload();
        enetInitialized = false;
    }
}

