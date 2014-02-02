/// Provides the ReceivedPacket struct and the Packet class.

module enet.peer;

import derelict.enet.enet;
import enet.exceptions;
import enet.packet;

struct ReceivedPacket
{
    Packet packet;
    ubyte channelID;
}

/// Encompasses an ENetPeer with an object-oriented wrapper.
class Peer
{
    protected ENetPeer *_handle;

    /// Possibles states of a peer.
    enum State
    {
        disconnected = ENET_PEER_STATE_DISCONNECTED,
        connecting = ENET_PEER_STATE_CONNECTING,
        acknowledgingConnect = ENET_PEER_STATE_ACKNOWLEDGING_CONNECT,
        connectionPending = ENET_PEER_STATE_CONNECTION_PENDING,
        connectionSucceeded = ENET_PEER_STATE_CONNECTION_SUCCEEDED,
        connected = ENET_PEER_STATE_CONNECTED,
        disconnectLater = ENET_PEER_STATE_DISCONNECT_LATER,
        disconnecting = ENET_PEER_STATE_DISCONNECTING,
        acknowledgingDisconnect = ENET_PEER_STATE_ACKNOWLEDGING_DISCONNECT,
        zombie = ENET_PEER_STATE_ZOMBIE
    }

    this(ENetPeer *handle)
    {
        _handle = handle;
    }

    /// Queues a Packet's internal ENetPacket to be sent. Dirties the sent
    /// packet, meaning it cannot be changed.
    /// Throws: ENetException if enet_peer_send fails
    void send(Packet packet, ubyte channelID=0)
    {
        auto errCode = enet_peer_send(_handle, channelID, packet._handle);
        if(errCode < 0)
            throw new ENetException("enet_peer_send failed");
        packet._dirty = true;
    }

    /** 
     * Attempts to dequeue any incoming queued packet.
     * Returns: A ReceivedPacket struct, with packet member being null if no
     *          packet is received.
     */
    ReceivedPacket receive()
    {
        ubyte channelID;
        ENetPacket *packet = enet_peer_receive(_handle, &channelID);
        Packet wrappedPacket = new Packet(packet);
        return ReceivedPacket(wrappedPacket, channelID);
    }

    /// Forcefully disconnects a peer.
    void reset()
    {
        enet_peer_reset(_handle);
    }

    /// Request a disconnection from a peer.
    void disconnect(uint data=0)
    {
        enet_peer_disconnect(_handle, data);
    }

    /// Force an immediate disconnection from a peer
    void disconnectNow(uint data=0)
    {
        enet_peer_disconnect_now(_handle, data);
    }

    /// Request a disconnection from a peer, but only after all queued
    /// outgoing packets are sent.
    void disconnectLater(uint data=0)
    {
        enet_peer_disconnect_later(_handle, data);
    }

    /// Sends a ping request to a peer.
    void ping()
    {
        enet_peer_ping(_handle);
    }

    /// Sets the timeout parameters for a peer.
    void setTimeout(uint limit, uint min, uint max)
    {
        enet_peer_timeout(_handle, limit, min, max);
    }

    /// Sets the throttle parameters for a peer. The throttle represents a
    /// probability that an unreliable packet should not be dropped and thus
    /// sent by ENet to the peer.
    void throttleConfigure(uint interval, uint accel, uint decel)
    {
        enet_peer_throttle_configure(_handle, interval, accel, decel);
    }

    @property
    {
        /// Gets application private data.
        void *data()
        {
            return _handle.data;
        }

        /// Sets application private data.
        void data(void *newData)
        {
            _handle.data = newData;
        }
    }

    // Todo: Add all
    /// Trivial getters for _ENetPeer struct.
    @property
    {
        ENetAddress address() { return _handle.address; }
        size_t channelCount() { return _handle.channelCount; }
        uint incomingBandwidth() { return _handle.incomingBandwidth; }
        uint outgoingBandwidth() { return _handle.outgoingBandwidth; }
        uint packetLoss() { return _handle.packetLoss; }
        uint roundTripTime() { return _handle.roundTripTime; }
        State state() { return cast(State)_handle.state; }
    }
}
