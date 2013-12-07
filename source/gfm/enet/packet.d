module gfm.enet.packet;

import derelict.enet.enet;
import gfm.enet.enet;

// http://enet.bespin.org/group__Packet.html
class Packet
{
    public
    {
        /// Creates an ENet packet.
        /// Flags:
        /// - ENET_PACKET_FLAG_RELIABLE - packet must be received by the target peer
        /// - ENET_PACKET_FLAG_UNSEQUENCED - packet will not be sequenced with other packets 
        /// - ENET_PACKET_FLAG_NO_ALLOCATE - packet will not allocate data, and user must supply it instead
        /// Throws: ENetException on error.
        this(ENet enet, const(void)* data, size_t dataLength, uint flags)
        {
            _enet = enet;
            _handle = enet_packet_create(data, dataLength, flags);
            if (_handle is null)
                throw new ENetException("enet_packet_create failed");
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_handle !is null)
            {
                enet_packet_destroy(_handle);
                _handle = null;
            }
        }

        /// Throws: ENetException on error.
        void resize(size_t dataLength)
        {
            int result = enet_packet_resize(_handle, dataLength);
            if (result < 0)
                throw new ENetException("enet_packet_resize failed");
        }
    }

    private
    {
        ENet _enet;
        ENetPacket* _handle;
    }
}