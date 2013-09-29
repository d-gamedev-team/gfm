module gfm.enet.peer;

import derelict.enet.enet;
import gfm.enet.enet;

/// ENet peer
/// http://enet.bespin.org/group__peer.html
class Peer
{
    public
    {
        this(ENet enet, ENetPeer* handle)
        {
            _enet = enet;
            _handle = handle;
        }

        void send(ubyte channelID, ENetPacket* packet)
        {
            int errCode = enet_peer_send(_handle, channelID, packet);
            if (0 != errCode)
                throw new ENetException("enet_peer_send failed");
        }

        ENetPacket* receive(out ubyte channelID) // TODO return aggregate
        {
            return enet_peer_receive(_handle, &channelID);
        }
        
        /// Forcefully disconnects a peer. 
        void reset()
        {
            enet_peer_reset(_handle);
        }

        /// Request a disconnection from a peer. 
        void disconnect(uint data)
        {
            enet_peer_disconnect(_handle, data);
        }

        /// Force an immediate disconnection from a peer. 
        void disconnectNow(uint data)
        {
            enet_peer_disconnect_now(_handle, data);
        }

        /// Request a disconnection from a peer, but only after all queued outgoing packets are sent. 
        void disconnectLater(uint data)
        {
            enet_peer_disconnect_later(_handle, data);
        }

        /// Sends a ping request to a peer. 
        void ping()
        {
            enet_peer_ping(_handle);
        }

        // Sends a ping request to a peer. 
        void setPingInterval(uint pingInterval)
        {
            enet_peer_ping_interval(_handle, pingInterval);
        }

        void setTimeout(uint timeoutLimit, uint timeoutMinimum, uint timeoutMaximum)
        {
            enet_peer_timeout(_handle, timeoutLimit, timeoutMinimum, timeoutMaximum);     
        }

        void throttleConfigure(uint interval, uint acceleration, uint deceleration)
        {
            enet_peer_throttle_configure(_handle, interval, acceleration, deceleration);
        }
    }

    private
    {
        ENet _enet;
        ENetPeer* _handle;
    }
}