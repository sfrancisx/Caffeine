#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "CaffeineSocketClient.h"
#include "CaffeineWindowsMessages.h"
#include "windowhelpers.h"
#include "include/internal/cef_types.h"

#define SECURITY_WIN32

#include <windows.h>
#include <atlbase.h>
#include <WinSock2.h>
#include <ws2tcpip.h>
#include <wincrypt.h>

#include <security.h>
#include <schnlsp.h>

#include <algorithm>
#include <exception>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

#include <openssl/ssl.h>
#include <openssl/err.h>
using namespace std;

namespace {
    typedef map< const SSL *, wstring > PeerNameMap;

    PeerNameMap peer_name_map;

    int check_cert_chain(const SSL *pConnection, X509 *cert) 
    {
        int retval = 0;  //  Fail the peer name check
        char peer_CN[256];

        if(SSL_get_verify_result(pConnection)==X509_V_OK) 
        {
            if(cert)
            {
                PeerNameMap::const_iterator i = peer_name_map.find(pConnection);
                if(i != peer_name_map.cend())
                {
                    X509_NAME_get_text_by_NID(X509_get_subject_name(cert), NID_commonName, peer_CN, 256); 
                    if(!_stricmp(peer_CN, CW2A(i->second.c_str()))) 
                    {
                        retval = 1;
                    }
                }
            }
        }

        return retval;
    } 

    int verify_callback(int ok, X509_STORE_CTX *store)
    {
        X509 *cert = X509_STORE_CTX_get_current_cert(store);
        int  depth = X509_STORE_CTX_get_error_depth(store);
        //int  err = X509_STORE_CTX_get_error(store);

        if((0 == depth)&&ok)
        {
            ok = check_cert_chain(static_cast<const SSL *>(X509_STORE_CTX_get_ex_data(store, SSL_get_ex_data_X509_STORE_CTX_idx())), cert);
        }

        return ok;
    }
}  //  namespace

//  host_ip is the ip address as a string
CaffeineSocketClient::CaffeineSocketClient(wstring hostname, int32 host_port, bool isSSL, HWND hWindowForEvents)
: isSSL(isSSL), hWindowForEvents(hWindowForEvents)
{
    //  Create the socket
    SOCKET created_socket = {0,};

    created_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
    if(INVALID_SOCKET == created_socket)
    {
//        throw runtime_error("Can't create socket!");
    }

    //  Where does this go?  Do we need to check the return value?
    WSAAsyncSelect(created_socket, hWindowForEvents, CAFFEINE_SOCKETS_MSG, FD_CONNECT | FD_READ | FD_WRITE | FD_CLOSE);
    
    //  TODO:  We can move this into the base impl.
    wstring host_ip = GetIPbyName(hostname);
    //  impl will do any additional bookkeeping and then connect
    if (isSSL)
    {
        impl = make_shared<CaffeineSocketClientImpl_SSL>(created_socket, hostname, host_ip, host_port);
    }
    else
    {
        impl = make_shared<CaffeineSocketClientImpl_NonSSL>(created_socket, host_ip, host_port);
    }
}

CaffeineSocketClient::CaffeineSocketClient(const CaffeineSocketClient& orig)
: isSSL(orig.isSSL), hWindowForEvents(orig.hWindowForEvents), impl(orig.impl)
{
}

CaffeineSocketClient& CaffeineSocketClient::operator=(const CaffeineSocketClient &orig)
{
    using namespace std;

    CaffeineSocketClient temp(orig);
    swap(*this, temp);

    return *this;
}

CaffeineSocketClient::~CaffeineSocketClient()
{
}

CaffeineSocketClientImpl_NonSSL::CaffeineSocketClientImpl_NonSSL(SOCKET s, wstring host_ip, int32 host_port)
: CaffeineSocketClientImpl(s, host_ip, host_port)
{
}

CaffeineSocketClientImpl_NonSSL::~CaffeineSocketClientImpl_NonSSL()
{
}

int CaffeineSocketClientImpl_NonSSL::recv(char *data, int data_len, int flags)
{
    return ::recv(socket, data, data_len, flags);
}

int CaffeineSocketClientImpl_NonSSL::send(const char *data, int data_len, int flags)
{
    return ::send(socket, data, data_len, flags);
}

CaffeineSocketClientImpl_SSL::CaffeineSocketClientImpl_SSL(SOCKET s, wstring hostname, wstring host_ip, int32 host_port)
: CaffeineSocketClientImpl(s, host_ip, host_port), hostname(hostname)
{
    bio = BIO_new_socket(s, 0);
    const SSL_METHOD *pMethod = SSLv3_client_method();
    pContext = SSL_CTX_new(pMethod);

    SSL_CTX_set_mode(pContext, SSL_MODE_AUTO_RETRY);
    SSL_CTX_load_verify_locations(pContext, "caz.crt", 0);
    SSL_CTX_set_verify(pContext, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT, verify_callback);

    pConnection = SSL_new(pContext);
    SSL_set_bio(pConnection, bio, bio);
    BIO_set_nbio(bio, 1);
    //  TODO:  Shouldn't this be part of the connect()?
    SSL_connect(pConnection);

    //  Add the hostname to the hostname map for the peer name check
    peer_name_map[pConnection] = hostname;
}

CaffeineSocketClientImpl_SSL::~CaffeineSocketClientImpl_SSL()
{
    peer_name_map.erase(pConnection);
    SSL_free(pConnection);
    SSL_CTX_free(pContext);
}


int CaffeineSocketClientImpl_SSL::recv(char *data, int data_len, int flags) 
{
    //  What about the flags??
    return SSL_read(pConnection, data, data_len);
}

int CaffeineSocketClientImpl_SSL::send(const char *data, int data_len, int flags)
{
    //  What about the flags??
    return SSL_write(pConnection, data, data_len);
}

