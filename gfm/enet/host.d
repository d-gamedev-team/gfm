module gfm.enet.host;

import gfm.enet.peer;

class Host
{
    public
    {
        this(ENet enet, in ENetAddress address, size_t peerCount, size_t channelLimit, uint incomingBandwidth, uint outgoingBandwidth)
        {
            _enet = enet;
            _handle = enet_host_create(&address, peerCount, channelLimit, incomingBandwidth, outgoingBandwidth);
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
            return new ENetPeer(_enet, peer);
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
             enet_host_bandwidth_limit(_handle, incomingBandwidth, outcomingBandwidth);
        }
    }

    private
    {
        ENet _enet;
        ENetHost* _handle;
    }
}