/// Provides the Host, Server, and Client classes.

module gfm.enet.host;

import std.algorithm,
       /*std.stdio,*/
       std.typecons;

import derelict.enet.enet;

import gfm.enet.address,
       gfm.enet.event,
       gfm.enet.enet,
       gfm.enet.packet,
       gfm.enet.peer;

/**
 * A subclass of Host that exists to concisely create a client-oriented Host
 * 
 * The Host superclass' address is set to null which disallows other peers from
 * connecting to the Host.
 * 
 * See_Also: Host, Client
 */
final class Client : Host
{
    /**
     * Creates a new Client, a subclass of Host
     * 
     * Params:
     *  peerCount         = The maximum number of peers that should be allocated
     *                      for the host, for clients this is useful for
     *                      connecting to multiple servers.
     *  channelLimit      = The maximum number of channels allowed; if 0, then
     *                      this is equivalent to
     *                      ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT
     *  incomingBandwidth = downstream bandwidth of the host in bytes/second; if
     *                      0, ENet will assume unlimited bandwidth
     *  outgoingBandwidth = upstream bandwidth of the host in bytes/second; if
     *                      0, ENet will assume unlimited bandwidth
     *
     * Throws: ENetException if enet_create_host fails
     */
    this(ENet enet,
         size_t peerCount,
         size_t channelLimit,
         uint incomingBandwidth=0,
         uint outgoingBandwidth=0)
    {
        super(enet,
              null,
              peerCount,
              channelLimit,
              incomingBandwidth,
              outgoingBandwidth);
    }


    
    /**
     * Creates a new Client, a subclass of Host
     * 
     * This constructor sets peerCount to 1, meaning it can only connect to a
     * singular Peer.
     * 
     * Params:
     *  channelLimit      = The maximum number of channels allowed; if 0, then
     *                      this is equivalent to
     *                      ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT
     *  bandwidthLimits   = downstream and upstream bandwidth of the host in
     *                      bytes/second; if 0, ENet will assume unlimited
     *                      bandwidth
     * 
     * Throws: ENetException if enet_create_host fails
     */
    this(ENet enet, size_t channelLimit, uint[2] bandwidthLimits=[0, 0])
    {
        this(enet, 1, channelLimit, bandwidthLimits[0], bandwidthLimits[1]);
    }  
    
}

/**
 * A subclass of Host that exists to concisely create a server-oriented Host
 * 
 * The Host superclass' address is set to ENET_HOST_ANY which binds the server
 * to the default localhost.
 * 
 * See_Also: Host, Client
 */
class Server : Host
{
    /**
     * Creates a new Server, which is a type of Host.
     * 
     * Params:
     *  port              = Port that the server binds to
     *  peerCount         = The maximum number of peers that should be allocated
     *                      for the host
     *  channelLimit      = The maximum number of channels allowed; if 0, then
     *                      this is equivalent to
     *                      ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT
     *  incomingBandwidth = downstream bandwidth of the host in bytes/second; if
     *                      0, ENet will assume unlimited bandwidth
     *  outgoingBandwidth = upstream bandwidth of the host in bytes/second; if
     *                      0, ENet will assume unlimited bandwidth
     * 
     * Throws: ENetException if enet_address_set_host fails
     * Throws: ENetException if enet_create_host fails
     */
    this(ENet enet,
         ushort port,
         size_t peerCount,
         size_t channelLimit = 0,
         uint incomingBandwidth = 0,
         uint outgoingBandwidth = 0)
    {
        Address serverAddress = Address(ENET_HOST_ANY, port);
        super(enet,
              &serverAddress,
              peerCount,
              channelLimit,
              incomingBandwidth,
              outgoingBandwidth);
    }
}

/**
 * Encompasses an ENetHost structure with an object-oriented wrapper
 * 
 * See_Also: Client, Server
 */
class Host
{
    protected ENetHost *_handle;
    protected ENet _enet;
    private
    {
        Peer[] _peers;
        bool _usingRangeCoder;
    }

    /**
     * Creates a new Host
     * 
     * Params:
     *  address           = The address at which other peers may connect to this
     *                      host; if null, then no peers may connect to the host
     *  peerCount         = The maximum number of peers that should be allocated
     *                      for the host
     *  channelLimit      = The maximum number of channels allowed; if 0, then
     *                      this is equivalent to
     *                      ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT
     *  incomingBandwidth = downstream bandwidth of the host in bytes/second; if
     *                      0, ENet will assume unlimited bandwidth
     *  outgoingBandwidth = upstream bandwidth of the host in bytes/second; if
     *                      0, ENet will assume unlimited bandwidth
     *
     * Throws: ENetException if enet_create_host fails
     */
    this(ENet enet,
         Address* address,
         size_t peerCount,
         size_t channelLimit,
         uint incomingBandwidth=0,
         uint outgoingBandwidth=0)
    {
        _enet = enet;

        _handle = enet_host_create(&address.address,
                                   peerCount,
                                   channelLimit,
                                   incomingBandwidth,
                                   outgoingBandwidth);

        if(_handle is null)
            throw new ENetException("enet_host_create failed");
        _usingRangeCoder = false;
    }
    
    ~this()
    {
        close();
    }

    /// Cleans up any resources used by the Host
    void close()
    {
        if(_handle !is null)
        {
            enet_host_destroy(_handle);
            _handle = null;
        }
    }

    /** 
     * Initiates a connection to a foreign host
     * 
     * Params:
     *  foreignAddress = Destination for the connection
     *  channelCount   = Number of channels to allocate
     *  data           = User data supplied to the receiving host
     * 
     * Throws: ENetException if enet_host_connect fails
     */
    Peer connect(Address foreignAddress, size_t channelCount, uint data=0)
    {
        ENetPeer *peer = enet_host_connect(_handle,
                                           &foreignAddress.address,
                                           channelCount,
                                           data);

        if(peer is null)
            throw new ENetException("enet_host_connect failed");

        return new Peer(_enet, peer);
    }
    
    /** 
     * Initiates a connection to a foreign host
     * 
     * Params:
     *  hostName     = Destination hostname for the connection
     *  port         = Destination port for the connection
     *  channelCount = Number of channels to allocate
     *  data         = User data supplied to the receiving host
     * 
     * Throws: ENetException if enet_host_connect fails
     * See_Also: connect
     */
    Peer connect(string hostName, ushort port, size_t channelCount, uint data=0)
    {
        Address foreignAddress = Address(hostName, port);
        return connect(foreignAddress, channelCount, data);
    }

    /**
     * Queues a packet to be sent to all peers associated with the host
     * 
     * Dirties the sent packet, meaning it cannot be changed.
     * 
     * Params:
     *  packet    = Packet to broadcast to all associated peers
     *  channelID = Channel to broadcast the packet on
     */
    void broadcast(Packet packet, ubyte channelID=0)
    {
        // If there are no references to the packet, ENet destroys it
        if(packet._handle.referenceCount == 0)
            packet._destroyed = true;
        enet_host_broadcast(_handle, channelID, packet._handle);
        packet._dirty = true;
    }
    
    /// Sets the packet compressor the host should use to the default range
    /// coder
    void compressWithRangeCoder()
    {
        if(!_usingRangeCoder)
        {
            auto errCode = enet_host_compress_with_range_coder(_handle);
            if(errCode < 0)
            {
                string msg = "enet_host_compress_with_range_coder failed";
                throw new ENetException(msg);
            }
            _usingRangeCoder = true;
        }
    }
    
    /// Turns off the range coder packet compressor
    void disableRangeCoder()
    {
        if(_usingRangeCoder)
            enet_host_compress(_handle, null);
        _usingRangeCoder = false;
    }

    /**
     * Sends any queued packets on the host specified to its designated peers
     * 
     * This is not necessary if you are using service, which will also send
     * queued packets to its designated peers.
     * 
     * See_Also: service
     */
    void flush()
    {
        enet_host_flush(_handle);
    }

    /**
     * Checks for any queued events on the host and dispatches one if available
     * 
     * Returns:
     *  The event which occurred if one happened or null if no event happened.
     * 
     * Throws: ENetException if enet_host_check_events fails
     * 
     * See_Also: service
     */
    Event checkEvents()
    {
        ENetEvent event;
        auto result = enet_host_check_events(_handle, &event);
        if(result == 0)
            return null;
        else if(result > 0)
        {
            Event wrappedEvent = new Event(_enet, &event);
            processPeers(wrappedEvent);
            return wrappedEvent;
        }
        else
            throw new ENetException("enet_host_check_events failed");
    }

    /**
     * Waits for events on the host and shuttles packets between the host and
     * its peers
     * 
     * Params:
     *  timeout = number of milliseconds that ENet should wait for events
     * 
     * Returns:
     *  The event which occurred if one happened or null if no event happened.
     * 
     * Throws: ENetException if enet_host_service fails
     * 
     * See_Also: checkEvents
     */
    Event service(uint timeout=0)
    {
        ENetEvent event;
        auto result = enet_host_service(_handle, &event, timeout);
        if(result == 0)
            return null;
        else if(result > 0)
        {
            Event wrappedEvent = new Event(_enet, &event);
            processPeers(wrappedEvent);
            return wrappedEvent;
        }
        else
            throw new ENetException("enet_host_service failed");
    }

    private void processPeers(Event event)
    {
        if(event.type() == ENET_EVENT_TYPE_CONNECT)
        {
            _peers.length++;
            _peers[$-1] = event.peer();
        }
        else if(event.type() == ENET_EVENT_TYPE_DISCONNECT)
        {
            _peers = _peers.remove(_peers.countUntil(event.peer()));
        }
    }

    @property
    {
        ENetChecksumCallback checksum()
        {
            return _handle.checksum;
        }

        void checksum(ENetChecksumCallback callback)
        {
            _handle.checksum = callback;
        }
    }

    @property
    {
        ENetCompressor compressor()
        {
            return _handle.compressor;
        }
        
        void compressor(ENetCompressor compressor)
        {
            if(_usingRangeCoder)
                disableRangeCoder();
            _handle.compressor = compressor;
        }

        bool compress()
        {
            return _usingRangeCoder;
        }
        
        void compress(bool shouldCompress)
        {
            if(shouldCompress == true)
                compressWithRangeCoder();
            else
                disableRangeCoder();
        }
    }

    @property
    {
        ENetInterceptCallback intercept()
        {
            return _handle.intercept;
        }
        
        void intercept(ENetInterceptCallback callback)
        {
            _handle.intercept = callback;
        }
    }

    @property
    {
        size_t channelLimit()
        {
            return _handle.channelLimit;
        }

        void channelLimit(size_t channelLimit)
        {
            enet_host_channel_limit(_handle, channelLimit);
        }
    }

    @property
    {
        uint[2] bandwidthLimits()
        {
            return [ _handle.incomingBandwidth, _handle.outgoingBandwidth ];
        }

        uint incomingBandwidth()
        {
            return _handle.incomingBandwidth;
        }
        
        uint outgoingBandwidth()
        {
            return _handle.outgoingBandwidth;
        }

        void bandwidthLimits(uint[2] limits)
        {
            enet_host_bandwidth_limit(_handle, limits[0], limits[1]);
        }

        void incomingBandwidth(uint limit)
        {
            enet_host_bandwidth_limit(_handle, limit, _handle.outgoingBandwidth);
        }

        void outgoingBandwidth(uint limit)
        {
            enet_host_bandwidth_limit(_handle, _handle.incomingBandwidth, limit);
        }
    }

    @property
    {
        size_t duplicatePeers()
        {
            return _handle.duplicatePeers;
        }

        void duplicatePeers(size_t maxDuplicatePeers)
        {
            _handle.duplicatePeers = maxDuplicatePeers;
        }
    }

    // Getters
    @property
    {
        Address address() { return Address(_handle.address); }

        Address receivedAddress() { return Address(_handle.receivedAddress); }
        Peer[] peers() { return _peers; }

        // _ENetHost structure properties
        ENetSocket socket() { return _handle.socket; }
        uint bandwidthThrottleEpoch() { return _handle.bandwidthThrottleEpoch; }
        uint mtu() { return _handle.mtu; }
        uint randomSeed() { return _handle.randomSeed; }
        int recalculateBandwidthLimits() { return _handle.recalculateBandwidthLimits; }
        size_t peerCount() { return _handle.peerCount; }
        uint serviceTime() { return _handle.serviceTime; }
        ENetList dispatchQueue() { return _handle.dispatchQueue; }
        int continueSending() { return _handle.continueSending; }
        size_t packetSize() { return _handle.packetSize; }
        ushort headerFlags() { return _handle.headerFlags; }
        ENetProtocol[] commands() { return _handle.commands; }
        size_t commandCount() { return _handle.commandCount; }
        ENetBuffer[] buffers() { return _handle.buffers; }
        size_t bufferCount() { return _handle.bufferCount; }
        ubyte[ENET_PROTOCOL_MAXIMUM_MTU][2] packetData() { return _handle.packetData; }
        ubyte *receivedData() { return _handle.receivedData; }
        size_t receivedDataLength() { return _handle.receivedDataLength; }
        uint totalSentData() { return _handle.totalSentData; }
        uint totalSentPackets() { return _handle.totalSentPackets; }
        uint totalReceivedData() { return _handle.totalReceivedData; }
        uint totalReceivedPackets() { return _handle.totalReceivedPackets; }
        size_t connectedPeers() { return _handle.connectedPeers; }
        size_t bandwidthLimitedPeers() { return _handle.bandwidthLimitedPeers; }
    }
}


// Tests

// Creates a Client with 2 peers and 4 channels maximum
unittest
{
    auto enet = scoped!ENet();
    auto client = new Client(enet, 2, 4);
    assert(client.peerCount == 2);
    assert(client.channelLimit == 4);
    assert(client.bandwidthLimits == [0, 0]);
    assert(client.incomingBandwidth == 0);
    assert(client.outgoingBandwidth == 0);
    client.close(); // Don't let the GC destroy your resources.
}

// Similar to before, only with a downstream and upstream bandwidth limit
unittest
{
    auto enet = scoped!ENet();
    auto maxPeers = 32;
    auto maxChannels = 16;
    auto inLimit = (1*10^^6)/8; // 1mbps
    auto outLimit = (512*10^^5)/8; // 512kbps
    auto client = new Client(enet, maxPeers, maxChannels, inLimit, outLimit);
    assert(client.peerCount == 32);
    assert(client.channelLimit == 16);
    assert(client.bandwidthLimits == [(1*10^^6)/8, (512*10^^5)/8]);
    assert(client.incomingBandwidth == (1*10^^6)/8);
    assert(client.outgoingBandwidth == (512*10^^5)/8);
    client.close(); // Don't let the GC destroy your resources.
}

// Creates a client with 1 channel maximum, no bandwidth limits
unittest
{
    auto enet = scoped!ENet();
    auto client = new Client(enet, 1);
    assert(client.peerCount == 1);
    assert(client.channelLimit == 1);
    assert(client.bandwidthLimits == [0, 0]);
    assert(client.incomingBandwidth == 0);
    assert(client.outgoingBandwidth == 0);
    client.close(); // Can either manually destroy it or let the GC do it
}

// 4 channels, 768kbps downstream, 128kbps upstream
unittest
{
    auto enet = scoped!ENet();
    auto inLimit = (768*10^^5)/8; // 768kbps
    auto outLimit = (128*10^^5)/8; // 128kbps
    auto client = new Client(enet, 4, [inLimit, outLimit]);
    assert(client.peerCount == 1);
    assert(client.channelLimit == 4);
    assert(client.bandwidthLimits == [inLimit, outLimit]);
    assert(client.incomingBandwidth == inLimit);
    assert(client.outgoingBandwidth == outLimit);
    client.close(); // Can either manually destroy it or let the GC do it
}

// Creates a server on port 27777, with 32 max peers and 8 max channels, with bandwidth limits
unittest
{
    auto enet = scoped!ENet();
    auto inLimit = (20*10^^6)/8; // 20mbps
    auto outLimit = (10*10^^6)/8; // 10mbps
    auto server = new Server(enet, 27777, 32, 8, inLimit, outLimit);
    assert(server.peerCount == 32);
    assert(server.channelLimit == 8);
    assert(server.bandwidthLimits == [inLimit, outLimit]);
    assert(server.incomingBandwidth == inLimit);
    assert(server.outgoingBandwidth == outLimit);
    server.close(); // Can either manually destroy it or let the GC do it
}

// Creates Host for purposes of being a server
unittest
{
    auto enet = scoped!ENet();
    auto maxPeers = 32;
    auto maxChans = 16;
    auto inLimit = (2*10^^6)/8;
    auto outLimit = (2*10^^6)/8;
    // Create an address which refers to localhost address and port 32807
    auto hostAddr = new Address(ENET_HOST_ANY, 32807);
    auto host = new Host(enet, hostAddr, maxPeers, maxChans, inLimit, outLimit);
    assert(host.peerCount == 32);
    assert(host.channelLimit == 16);
    assert(host.bandwidthLimits == [inLimit, outLimit]);
    assert(host.incomingBandwidth == inLimit);
    assert(host.outgoingBandwidth == outLimit);
    host.close(); // Can either manually destroy it or let the GC do it
}

// Creates Host for purposes of being a client
unittest
{
    auto enet = scoped!ENet();
    // Bandwidth defaults to 0, which means unlimited
    auto maxPeers = 32;
    auto maxChannels = 16;
    // A null Address disallows other peers from connecting
    auto host = new Host(enet, null, maxPeers, maxChannels);
    assert(host.peerCount == 32);
    assert(host.channelLimit == 16);
    assert(host.bandwidthLimits == [0, 0]);
    assert(host.incomingBandwidth == 0);
    assert(host.outgoingBandwidth == 0);
    host.close(); // Can either manually destroy it or let the GC do it
}

// Creates and destroys a host
unittest
{
    auto enet = scoped!ENet();
    auto host = new Host(enet, null, 1, 1);
    host.close();
    assert(host._handle == null); // _handle is of package visibility
}

// Creates 2 hosts and connect them together
unittest
{
    auto enet = scoped!ENet();
    ushort port = 25403;
    auto maxPeers = 1;
    auto maxChannels = 1;
    auto server = new Server(enet, port, maxPeers, maxChannels);
    auto client = new Client(enet, maxPeers, maxChannels);
    client.connect(server.address, maxChannels);
    client.close(); // Or let GC handle it
    server.close();
}

// Creates 2 hosts and connect them together
unittest
{
    auto enet = scoped!ENet();
    ushort port = 25403;
    auto maxPeers = 1;
    auto maxChannels = 1;
    auto server = new Server(enet, port, maxPeers, maxChannels);
    auto client = new Client(enet, maxPeers, maxChannels);
    client.connect("localhost", port, maxChannels);
    client.close(); // Or let GC handle it
    server.close();
}

// Broadcasts a packet to several peers
unittest
{
    auto enet = scoped!ENet();
    ushort port = 25403;
    auto maxPeers = 2;
    auto maxChannels = 1;
    auto server = new Server(enet, port, maxPeers, maxChannels);
    auto client1 = new Client(enet, 1, maxChannels);
    auto client2 = new Client(enet, 1, maxChannels);
    auto packet = new Packet(enet, [0, 1, 2, 3, 4]);
    client1.connect(server.address, maxChannels);
    client2.connect(server.address, maxChannels);
    server.broadcast(packet);
    client1.close(); // Or let GC clean up
    client2.close();
    server.close();
}

// Makes a server and client host which use range coder
unittest
{
    import std.stdio;
    auto enet = scoped!ENet();
    ushort port = 25403;
    auto maxPeers = 1;
    auto maxChannels = 1;
    auto server = new Server(enet, port, maxPeers, maxChannels);
    auto client = new Client(enet, maxPeers, maxChannels);
    // Both hosts must be using range coder
    server.compressWithRangeCoder();
    client.compressWithRangeCoder();
    auto serverAddress = Address("localhost", port);
    client.connect(serverAddress, port);
    client.close(); // Or let GC clean it up
    server.close();
}

// Makes a server, enables the range coder, then disables it
unittest
{
    auto enet = scoped!ENet();
    auto server = new Server(enet, 25403, 1, 1);
    server.compressWithRangeCoder(); // Enable
    server.disableRangeCoder(); // Disable
    server.close(); // Or let GC clean it up
}