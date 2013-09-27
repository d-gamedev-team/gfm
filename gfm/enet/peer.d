module gfm.enet.peer;


class Peer
{
    public
    {
        this(ENet enet, ENetPeer* handle)
        {
            _enet = enet;
            _handle = handle;
        }
        
    }

    private
    {
        ENet _enet;
        ENetPeer* _handle;
    }
}