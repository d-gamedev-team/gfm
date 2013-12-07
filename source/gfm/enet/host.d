module gfm.enet.host;

import derelict.enet.enet;

import gfm.enet.enet,
       gfm.enet.peer;

/// ENet host.
/// Inherit this class to dispatch packets.
/// See_also: $(WEB enet.bespin.org/group__host.html)
class Host
{
    public
    {
        /// Throws: ENetException on error.
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

        final void close()
        {
            if (_handle !is null)
            {
                enet_host_destroy(_handle);
                _handle = null;
            }
        }

        /// Throws: ENetException on error.
        final Peer connect(const(ENetAddress) *address, size_t channelCount, enet_uint32 data = 0)
        {
            ENetPeer* peer = enet_host_connect(_handle, address, channelCount, data);
            if (peer is null)
                throw new ENetException("enet_host_connect failed");

            return new Peer(_enet, peer, false);
        }

        final void broadcast(ubyte channelID, ENetPacket* packet)
        {
            enet_host_broadcast(_handle, channelID, packet);
        }

        final void flush()
        {
            enet_host_flush(_handle);
        }
        
        final void channelLimit(size_t channelLimit)
        {
            enet_host_channel_limit(_handle, channelLimit);
        }   

        final void bandwidthLimit(uint incomingBandwidth, uint outgoingBandwidth)
        {
             enet_host_bandwidth_limit(_handle, incomingBandwidth, outgoingBandwidth);
        }


        /// Throws: ENetException on error.
        // 0 => no timeout
        final void processEvent(bool blocking, int timeout = 0)
        {
            ENetEvent event;

            int nEvents;

            if (blocking)
                nEvents = service(&event, 100); // apparently throws if no peer connected...
            else
                nEvents = checkEvents(&event);
  
            // dispatch events
            if (nEvents >= 0)
            {
                switch (event.type)
                {
                    case ENET_EVENT_TYPE_CONNECT:
                        {
                            Peer* p = event.peer in _knownPeers;
                            if (p is null)
                            {
                                _knownPeers[event.peer] = new Peer(_enet, event.peer, true);
                            }
                            onPeerConnect(event.peer);
                        }
                        break;                    

                    case ENET_EVENT_TYPE_DISCONNECT:
                        onPeerDisconnect(event.peer, event.data);
                        _knownPeers.remove(event.peer);
                        break;

                    case ENET_EVENT_TYPE_RECEIVE:
                        onPacketReceive(event.peer, event.channelID, event.packet);
                        enet_packet_destroy(event.packet);
                        break;

                    default:
                }
            }
        }
    }

    protected
    {
        // called when a peer successfully connected
        void onPeerConnect(ENetPeer* peer)
        {
        }

        void onPeerDisconnect(ENetPeer* peer, uint data)
        {
        }

        void onPacketReceive(ENetPeer* peer, ubyte channelID, ENetPacket* packet)
        {
        }
    }

    private
    {
        ENet _enet;
        ENetHost* _handle;

        Peer[ENetPeer*] _knownPeers; // connected or not!
        

        final int service(ENetEvent* event, uint timeout)
        {
            int res = enet_host_service(_handle, event, timeout);
            if (res < 0)
                throw new ENetException("enet_host_service failed");
            return res;
        }

        final int checkEvents(ENetEvent* event)
        {
            int res = enet_host_check_events(_handle, event);
            if (res < 0)
                throw new ENetException("enet_check_events failed");
            return res;
        }
    }
}