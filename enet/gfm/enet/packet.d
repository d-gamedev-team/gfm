/// Provides the Packet class.

module gfm.enet.packet;

import std.traits : isArray, isScalarType;
import derelict.enet.enet;
import gfm.enet.enet;


/// Encompasses an ENetPacket with an object-oriented wrapper. Once a packet has
/// been sent, the data cannot be modified.
final class Packet
{
    private size_t _largestPacketSize;

    package
    {
        ENet _enet;
        ENetPacket *_handle;
        bool _dirty; // Disallows changing after being sent
        bool _destroyed; // When ENet internally destroys packet
    }

    /**
     * Creates an ENetPacket internally.
     * Throws: ENetException when enet_packet_create fails
     * Params:
     *     enet = Library object
     *     data = Initial contents of the packet's data
     *     dataLength = Size of the data allocated for this packet
     *     flags = Flags for this packet
     */
    this(ENet enet, const(void) *data, size_t dataLength, uint flags=0)
    {
        _enet = enet;
        _handle = enet_packet_create(data, dataLength, flags);
        if(_handle is null)
            throw new ENetException("enet_packet_create failed");
        _largestPacketSize = dataLength;
        _dirty = false;
        _destroyed = false;
    }

    /// A convenience constructor for an already existing ENetPacket.
    this(ENet enet, ENetPacket *packet)
    {
        _enet = enet;
        _handle = packet;
        if(_handle != null)
            _largestPacketSize = _handle.dataLength;
        _dirty = false; // Not guaranteed, but trust thy user.
        _destroyed = false;
    }

    /// A convenience constructor for array data.
    this(T)(ENet enet, T data, uint flags=0) if(isArray!T)
    {
        this(enet, &data[0], data.length, flags);
    }

    /// A convenience constructor for scalar data.
    this(T)(ENet enet, T data, uint flags=0) if(isScalarType!T)
    {
        this(enet, &data, 1, flags);
    }

    /// Cleans up the internal ENetPacket.
    ~this()
    {
        if(_handle !is null && !_destroyed)
        {
            debug ensureNotInGC("Packet");
            enet_packet_destroy(_handle);
            _handle = null;
        }
    }

    /**
     * Resizes the ENetPacket.
     * Throws: ENetException if the packet cannot be resized
     * Throws: ENetException if the packet is dirty (has been sent)
     */
    void resize(size_t dataLength)
    {
        if(!_dirty)
        {
            if(dataLength != _handle.dataLength)
            {
                if(dataLength > _largestPacketSize)
                    _enet._logger.warning("Packet size is larger than underlying data");

                auto errCode = enet_packet_resize(_handle, dataLength);
                if(errCode < 0)
                    throw new ENetException("enet_packet_resize failed");
            }
        }
        else
        {
            throw new ENetException("Resizing sent packets is not allowed");
        }
    }

    /// Gets the ENetPacket's data.
    ubyte[] data()
    {
        return _handle.data[0.._handle.dataLength];
    }

    /**
        * Sets the ENetPacket's data.
        * Throws: ENetException if the packet is dirty (has been sent)
        * See_Also: resize
        */
    void setData(ubyte[] data)
    {
        if(!_dirty)
        {
            if(data.length > _largestPacketSize)
                _largestPacketSize = data.length;
            resize(data.length);
            _handle.data = &data[0];
        }
        else
        {
            throw new ENetException("Changing sent packets is not allowed");
        }
    }

    /// Gets the size of the ENetPacket in bytes.
    size_t size() pure const nothrow
    {
        return _handle.dataLength;
    }

    /// Gets application private data.
    void* userData()
    {
        return _handle.userData;
    }

    /// Sets application private data.
    void setUserData(void *newData)
    {
        _handle.userData = newData;
    }
}
