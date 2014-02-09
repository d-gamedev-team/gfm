module gfm.enet.address;

import std.string,
       core.stdc.string;

import derelict.enet.enet;

import gfm.enet.enet;

/// A wrapper for ENetAddress.
struct Address
{
    ENetAddress address;

    alias address this;

    this(ENetAddress other) pure const nothrow
    {
        address = other;
    }

    this(string hostName, ushort port)
    {
        auto errCode = enet_address_set_host(&address, hostName.toStringz());
        if(errCode < 0)
            throw new ENetException("enet_address_set_host failed");
        address.port = port;
    }

    this(uint host, ushort port) pure nothrow
    {
        address.host = host;
        address.port = port;
    }

    string host() const
    {
        enum MAX_LEN = 39; // Maximum ipv6 length 
        char[MAX_LEN] buffer; 
            
        auto errCode = enet_address_get_host_ip(&address, buffer.ptr, MAX_LEN);
        if(errCode < 0)
            throw new ENetException("enet_address_get_host failed");

        size_t len = strlen(buffer.ptr);
        return buffer[0..len].idup;
    }

    void setHost(const char* hostName)
    {
        auto errCode = enet_address_set_host(&address, hostName);
        if(errCode < 0)
            throw new ENetException("enet_address_set_host failed");
    }    
}

static assert(ENetAddress.sizeof == Address.sizeof);
