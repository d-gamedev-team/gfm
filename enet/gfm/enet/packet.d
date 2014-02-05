/// Provides the Packet class.

module gfm.enet.packet;

import std.traits : isArray, isScalarType;
import derelict.enet.enet;
import gfm.enet.exceptions;
import gfm.enet.library;

/// Encompasses an ENetPacket with an object-oriented wrapper. Once a packet has
/// been sent, the data cannot be modified.
class Packet
{
    debug private size_t _largestPacketSize;

    package
    {
        ENetPacket *_handle;
        bool _dirty; // Disallows changing after being sent
        bool _destroyed; // When ENet internally destroys packet
    }

    /// Flags to be used with the ENetPacket constructor which defines aspects
    /// of packet behavior. To use multiple flags, bitwise or them together.
    enum Flags
    {
        reliable = ENET_PACKET_FLAG_RELIABLE,
        unsequenced = ENET_PACKET_FLAG_UNSEQUENCED,
        noAllocate = ENET_PACKET_FLAG_NO_ALLOCATE,
        unreliableFragment = ENET_PACKET_FLAG_UNRELIABLE_FRAGMENT,
        sent = ENET_PACKET_FLAG_SENT
    }

    /**
     * Creates an ENetPacket internally.
     * Throws: ENetException when enet_packet_create fails
     * Params:
     *     data = Initial contents of the packet's data
     *     dataLength = Size of the data allocated for this packet
     *     flags = Flags for this packet
     */
    this(const(void) *data, size_t dataLength, uint flags=0)
    {
        _handle = enet_packet_create(data, dataLength, flags);
        if(_handle is null)
            throw new ENetException("enet_packet_create failed");
        debug _largestPacketSize = dataLength;
        _dirty = false;
        _destroyed = false;
    }

    /// A convenience constructor for an already existing ENetPacket.
    this(ENetPacket *packet)
    {
        _handle = packet;
        debug
        {
            if(_handle != null)
                _largestPacketSize = _handle.dataLength;
        }
        _dirty = false; // Not guaranteed, but trust thy user.
        _destroyed = false;
    }

    /// A convenience constructor for array data.
    this(T)(T data, uint flags=0) if(isArray!T)
    {
        this(&data[0], data.length, flags);
    }

    /// A convenience constructor for scalar data.
    this(T)(T data, uint flags=0) if(isScalarType!T)
    {
        this(&data, 1, flags);
    }

    ~this()
    {
        close();
    }

    /// Cleans up the internal ENetPacket.
    void close()
    {
        if(_handle !is null && !_destroyed)
        {
            if(enetInitialized)
                enet_packet_destroy(_handle);
            _handle = null;
        }
    }

    /// Alias for close.
    void destroy()
    {
        close();
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
                debug
                {
                    if(dataLength > _largestPacketSize)
                        writed("Packet size is larger than underlying data");
                }
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

    @property
    {
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
        void data(ubyte[] data)
        {
            if(!_dirty)
            {
                debug
                {
                    if(data.length > _largestPacketSize)
                        _largestPacketSize = data.length;
                }
                resize(data.length);
                _handle.data = &data[0];
            }
            else
            {
                throw new ENetException("Changing sent packets is not allowed");
            }
        }
    }

    @property
    {
        /// Gets the size of the ENetPacket.
        size_t size()
        {
            return _handle.dataLength;
        }

        /**
         * Resizes the ENetPacket. Alias for resize.
         * Throws: ENetException if the packet is dirty (has been sent)
         */
        void size(size_t dataLength)
        {
            resize(dataLength);
        }
    }

    @property
    {
        /// Gets application private data.
        void *userData()
        {
            return _handle.userData;
        }

        /// Sets application private data.
        void userData(void *newData)
        {
            _handle.userData = newData;
        }
    }
}
