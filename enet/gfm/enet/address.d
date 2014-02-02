module enet.address;

import std.string;
import std.c.stdlib;
import derelict.enet.enet;
import enet.exceptions;

class Address
{
    package ENetAddress *_handle;

    enum Host
    {
        any = ENET_HOST_ANY,
        broadcast = ENET_HOST_BROADCAST
    }

    enum Port
    {
        any = ENET_PORT_ANY
    }

    this(string hostName, ushort port)
    {
        _handle = cast(ENetAddress*)malloc(ENetAddress.sizeof);
        if(_handle == null)
            throw new ENetException("malloc failed");
        auto errCode = enet_address_set_host(_handle, hostName.toStringz());
        if(errCode < 0)
            throw new ENetException("enet_address_set_host failed");
        _handle.port = port;
    }

    this(uint host, ushort port)
    {
        _handle = cast(ENetAddress*)malloc(ENetAddress.sizeof);
        if(_handle == null)
            throw new ENetException("malloc failed");
        _handle.host = host;
        _handle.port = port;
    }

    this(ENetAddress *address)
    {
        _handle = address;
    }

    ~this()
    {
        free(_handle);
    }

    @property
    {
        string host()
        {
            import std.algorithm : countUntil;
            enum maxLen = 39; // Maximum ipv6
            auto hostName = new char[maxLen];
            char *ptr = &hostName[0];
            auto errCode = enet_address_get_host_ip(_handle, ptr, maxLen);
            if(errCode < 0)
                throw new ENetException("enet_address_get_host failed");
            hostName.length = hostName.countUntil('\0');
            return cast(string)hostName;
        }

        void host(const char* hostName)
        {
            auto errCode = enet_address_set_host(_handle, hostName);
            if(errCode < 0)
                throw new ENetException("enet_address_set_host failed");
        }
    }

    @property
    {
        ushort port()
        {
            return _handle.port;
        }

        void port(ushort newPort)
        {
            _handle.port = newPort;
        }
    }
}
