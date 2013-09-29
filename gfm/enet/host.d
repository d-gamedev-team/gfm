module gfm.enet.host;

import derelict.enet.enet;

import gfm.enet.enet,
       gfm.enet.peer;

/// ENet host
/// http://enet.bespin.org/group__host.html
class Host
{
    public
    {
        this(ENet enet, ENetAddress* address, size_t peerCount, size_t channelLimit, uint incomingBandwidth, uint outgoingBandwidth)
        {
            _enet = enet;
            _handle = enet_host_create(address, peerCount, channelLimit, incomingBandwidth, outgoingBandwidth);
            if (_handle is null)
                throw new ENetException("enet_host_create failed");
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_handle !is null)
            {
                enet_host_destroy(_handle);
                _handle = null;
            }
        }

        Peer connect(const(ENetAddress) *address, size_t channelCount, enet_uint32 data)
        {
            ENetPeer* peer = enet_host_connect(_handle, address, channelCount, data);
            if (peer is null)
                throw new ENetException("enet_host_connect failed");
            return new Peer(_enet, peer);
        }

        void broadcast(ubyte channelID, ENetPacket* packet)
        {
            enet_host_broadcast(_handle, channelID, packet);
        }

        void flush()
        {
            enet_host_flush(_handle);
        }
        
        void channelLimit(size_t channelLimit)
        {
            enet_host_channel_limit(_handle, channelLimit);
        }   

        void bandwidthLimit(uint incomingBandwidth, uint outgoingBandwidth)
        {
             enet_host_bandwidth_limit(_handle, incomingBandwidth, outgoingBandwidth);
        }

        int service(ENetEvent* event, uint timeout)
        {
            int res = enet_host_service(_handle, event, timeout);
            if (res < 0)
                throw new ENetException("enet_host_service failed");
            return res;
        }

        int checkEvents(ENetHost* host, ENetEvent* event)
        {
            int res = enet_host_check_events(_handle, event);
            if (res < 0)
                throw new ENetException("enet_check_events failed");
            return res;
        }
    }

    private
    {
        ENet _enet;
        ENetHost* _handle;
    }
}