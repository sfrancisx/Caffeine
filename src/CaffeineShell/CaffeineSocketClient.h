#pragma once
#ifndef CAFFEINE_SOCKET_CLIENT_H
#define CAFFEINE_SOCKET_CLIENT_H

#include "include/internal/cef_types.h"

#define SECURITY_WIN32

#include <windows.h>
#include <atlbase.h>
#include <WinSock2.h>
#include <wincrypt.h>

#include <security.h>
#include <schnlsp.h>

#include <memory>
#include <string>

#include <openssl\bio.h>

//  Forward declarations
class CaffeineSocketClient;

class CaffeineSocketClientImpl
{
    friend CaffeineSocketClient;
    public:
        CaffeineSocketClientImpl(SOCKET s, std::wstring host_ip, int32 host_port)
        : socket(s), host_ip(host_ip), host_port(host_port) 
        {
        }
        ~CaffeineSocketClientImpl() 
        { 
            close(); 
        }

        virtual int connect()
        {
            sockaddr_in server_info = {0,};

            server_info.sin_family = AF_INET;
            server_info.sin_port = ::htons(static_cast<u_short>(host_port));
            //  TODO:  Would it be easier if host_ip was a string rather than wstring?
            server_info.sin_addr.s_addr = inet_addr(CW2A(host_ip.c_str()));

            int retval = ::connect(socket, (sockaddr *)&server_info, sizeof(server_info));

            return retval;
        }
        virtual int close() 
        { 
            return ::closesocket(socket); 
        }
        virtual int recv(char *data, int data_len, int flags) = 0;
        virtual int send(const char *data, int data_len, int flags) = 0;

    protected:
        CaffeineSocketClientImpl(const CaffeineSocketClientImpl& orig): socket(orig.socket) {}
        friend void swap(CaffeineSocketClientImpl &X, CaffeineSocketClientImpl &Y)
        {
            using namespace std;

            swap(X.socket, Y.socket);
            swap(X.host_ip, Y.host_ip);
            swap(X.host_port, Y.host_port);
        }

        SOCKET socket;
        //  TODO:  Do we need to stor this off?
        std::wstring host_ip;
        int32 host_port;
};

class CaffeineSocketClientImpl_NonSSL: public CaffeineSocketClientImpl
{
    friend CaffeineSocketClient;
    public:
        CaffeineSocketClientImpl_NonSSL(SOCKET s, std::wstring host_ip, int32 host_port);
        ~CaffeineSocketClientImpl_NonSSL();

        virtual int recv(char *data, int data_len, int flags);
        virtual int send(const char *data, int data_len, int flags);

    private:
        CaffeineSocketClientImpl_NonSSL(const CaffeineSocketClientImpl_NonSSL&);
        CaffeineSocketClientImpl_NonSSL& operator=(const CaffeineSocketClientImpl_NonSSL&);
};

class CaffeineSocketClientImpl_SSL: public CaffeineSocketClientImpl
{
    friend CaffeineSocketClient;
    public:
        CaffeineSocketClientImpl_SSL(SOCKET s, std::wstring hostname, std::wstring host_ip, int32 host_port);
        ~CaffeineSocketClientImpl_SSL();

        virtual int recv(char *data, int data_len, int flags);
        virtual int send(const char *data, int data_len, int flags);
        friend void swap(CaffeineSocketClientImpl_SSL &X, CaffeineSocketClientImpl_SSL &Y)
        {
            using namespace std;

            swap(static_cast<CaffeineSocketClientImpl &>(X), static_cast<CaffeineSocketClientImpl &>(Y));
            swap(X.bio, Y.bio);
            swap(X.pContext, Y.pContext);
            swap(X.pConnection, Y.pConnection);
        }

    private:
        CaffeineSocketClientImpl_SSL(const CaffeineSocketClientImpl_SSL&);
        CaffeineSocketClientImpl_SSL& operator=(const CaffeineSocketClientImpl_SSL&);

        std::wstring hostname;

        BIO *bio;
        SSL_CTX *pContext;
        SSL *pConnection;
};

class CaffeineSocketClient
{
    public:
        CaffeineSocketClient(std::wstring hostname, int32 host_port, bool isSSL, HWND hWindowForEvents);
        CaffeineSocketClient(const CaffeineSocketClient& orig);
        CaffeineSocketClient &operator=(const CaffeineSocketClient &orig);
        ~CaffeineSocketClient();

        operator int() { return impl->socket; }
        int close() { return impl->close(); }
        int connect() { return impl->connect(); }
        int recv(char *data, int data_len, int flags) { return impl->recv(data, data_len, flags); }
        int send(const char *data, int data_len, int flags) { return impl->send(data, data_len, flags); }

        friend void swap(CaffeineSocketClient &X, CaffeineSocketClient &Y)
        {
            using namespace std;

            swap(X.impl, Y.impl);
            swap(X.isSSL, Y.isSSL);
            swap(X.hWindowForEvents, Y.hWindowForEvents);
        }

    private:
        std::shared_ptr<CaffeineSocketClientImpl> impl;
        bool isSSL;
        HWND hWindowForEvents;
};

#endif //  CAFFEINE_SOCKET_CLIENT_H