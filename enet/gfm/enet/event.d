module gfm.enet.event;

import derelict.enet.enet;

import gfm.enet.enet,
       gfm.enet.packet,
       gfm.enet.peer;

final class Event
{
    private
    {
        ENetEvent *_handle;
        Peer _peer;
        Packet _packet;
    }

    public
    {
        this(ENet enet, ENetEvent *handle)
        {
            _handle = handle;
            _peer = new Peer(enet, _handle.peer);
            if(_handle.type == ENET_EVENT_TYPE_RECEIVE)
                _packet = new Packet(enet, _handle.packet);
            else
                _packet = null;
        }

        /// Trivial getters for _ENetEvent struct.
        ENetEventType type() pure const nothrow
        { 
            return _handle.type; 
        }

        Peer peer() pure nothrow
        { 
            return _peer; 
        }

        ubyte channelID() pure const nothrow
        { 
            return _handle.channelID; 
        }

        uint data() pure const nothrow
        { 
            return _handle.data; 
        }

        Packet packet() pure nothrow
        { 
            return _packet; 
        }
    }
}
