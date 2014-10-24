//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_CLIENT_APP_H
#define CAFFEINE_CLIENT_APP_H
#pragma once

#define RPC_USE_NATIVE_WCHAR
#define POPUP_WINDOW_NUMBER_OF_ARGUMENTS    (10)

#ifdef __APPLE__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#include "include/cef_base.h"
#pragma clang diagnostic pop
#endif

#include "CaffeineClientHandler.h"

#ifdef OS_WIN
#include "CaffeineSocketClient.h"
#endif

#include <deque>
#include <list>
#include <map>
#include <set>
#include <string>
//#include <tuple>
#include <utility>
#include <vector>
#include "include/cef_app.h"
#include "Brewery_platform.h"

// to send as as argument with UUID + initArg to CreateWindow
typedef struct {
    std::string::pointer uuid;
    std::string::pointer initArg;
    int minWidth;
    int minHeight;
} remoteWinID;

class CaffeineClientApp : public CefApp,
    public CefBrowserProcessHandler,
    public CefRenderProcessHandler {

public:
    static int callback_counter;

    typedef std::pair< std::string, int > CallbackMapKey;
    typedef std::pair< CefRefPtr<CefV8Context>, CefRefPtr<CefV8Value> > CallbackMapEntry;
    typedef std::map< CallbackMapKey,  CallbackMapEntry > CallbackMap;

    CallbackMap cbMap;

    // RTTv2 support
    // Win
    typedef std::map< std::string, CallbackMapEntry > SocketMapEntry;
    typedef std::map< SOCKET, SocketMapEntry > SocketMap;
    SocketMap sMap;

    bool InvokeSocketMethod(CefRefPtr<CefListValue> values);
    bool InvokeSocketMethod(SOCKET s, CefString state, int32 error_code = 0);

    typedef std::pair< std::string /*bytes to write*/, CallbackMapEntry > WriteBufferItem;
    typedef std::deque< WriteBufferItem > WriteBufferList;
    typedef std::map< SOCKET, WriteBufferList > WriteBufferMap;

    WriteBufferMap wbMap;

#ifdef OS_WIN

    typedef std::map< SOCKET, CaffeineSocketClient > SocketClientMap;

    SocketClientMap scMap;

    void NonBlockingSocketWrite(SOCKET s);

#endif

    CaffeineClientApp();
    virtual ~CaffeineClientApp();

    //  Create a map of the remote browsers.  Use the unique id for the browser
    //  for the key in the map.
    std::map<std::string, CefRefPtr<CaffeineClientHandler> > m_WindowHandler;
    HWND hwndRender;
    //  TODO:  This doesn't work.  NEED TO GET RID OF IT.
    std::string myUUID;

    std::wstring GetIPbyName(const std::wstring& hostName);

    // should show the File SaveAs dialog (default==true)
    bool showFileSaveAsDialog;

    // shell has location data (default==false)
    bool shellHasLocationData;

    // window associated with this app has key
    // for multiple windows we need to check not only if the application is active but also
    // if the given window is the keywindow
    bool windowIsKeyWindow;

    // set on create render
    int browserPID;
#ifdef ENABLE_MUSIC_SHARE
    // set by msg sent from browser process
    CefRefPtr<CefDictionaryValue> iTunesTrackInfo;
#endif
    bool isInternalIP();
    std::string encrypt(const CefString &plaintext);
    CefString decrypt(const CefString &blob);

#if defined(OS_WIN)
    std::wstring GetLatestVersion(std::wstring GUID);
    std::wstring GetLatestApplicationPath();
    std::wstring GetWindowState();

    std::wstring GetEphemeralState();

    void DeleteCrashLogs();
    int GetCrashLogCount();
    std::wstring GetCrashLogsDirectory();
    bool PostCrashLogs(CefString CrashLog, CefString AppVersion, CefString UserDescription);

#else
    std::string currentLocale; // locale (Mac)

    // to avoid using the Renderer process to access the keychain, we will send the requests to the main browser process
    std::map<std::string, std::string> userTokens;

    // calls to access tokens (stored in the Mac keychain)
    std::string GetUserToken(const std::string&user);
    void SetUserToken(const std::string& user, const std::string& token);
    void RemoveUserToken(const std::string&user);
    void RemoveAllUserTokens();

    void SetRenderProcessCreationTime(const CefTime time);

    // just returns a string with the name of the update channel (nightly, dogfood, etc)
    const char* GetUpdateChannel();
#endif

    bool UploadCrashLogs(CefString AppVersion, CefString UserDescription);

    std::string GetIP();
    CefTime getRenderProcessCreationTime();

    virtual void OnBeforeCommandLineProcessing(const CefString& process_type,CefRefPtr<CefCommandLine> command_line) OVERRIDE;

    // Set a JavaScript callback for the specified |message_name| and |browser_id|
    // combination. Will automatically be removed when the associated context is
    // released. Callbacks can also be set in JavaScript using the
    // app.setMessageCallback function.
    void SetMessageCallback(const std::string& message_name,
        int browser_id,
        CefRefPtr<CefV8Context> context,
        CefRefPtr<CefV8Value> function);

    // Removes the JavaScript callback for the specified |message_name| and
    // |browser_id| combination. Returns true if a callback was removed. Callbacks
    // can also be removed in JavaScript using the app.removeMessageCallback
    // function.
    bool RemoveMessageCallback(const std::string& message_name, int browser_id);

    void SetSocketCallback(SOCKET s, std::string state, CefRefPtr<CefV8Context> context, CefRefPtr<CefV8Value> function);
    //  Do we want to allow the removal of individual callbacks?
    bool RemoveSocketCallback(SOCKET s);

    void ShellLog(const std::wstring& msg);
private:
    void AppendStringToFile(const std::wstring& zipFile, const std::wstring& msg);
    void InsertDescriptionIntoCrashLogs(const std::wstring& file, const std::wstring& description);

    CefTime beginJSExecutionStartTime;
    bool isInsideInternalNetwork;
    std::wstring ephemeralState;

    CefTime renderProcessExecutionCreationTime;

    virtual CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler()
        OVERRIDE {
            return this;
    }
    virtual CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler()
        OVERRIDE {
            return this;
    }

    // CefBrowserProcessHandler methods.
    virtual void OnContextInitialized() OVERRIDE;
    virtual void OnBeforeChildProcessLaunch(
        CefRefPtr<CefCommandLine> command_line) OVERRIDE;

    virtual void OnRenderProcessThreadCreated(CefRefPtr<CefListValue> extra_info)
        OVERRIDE;

    // CefRenderProcessHandler methods.
    virtual void OnRenderThreadCreated(CefRefPtr<CefListValue> extra_info)
        OVERRIDE;

    virtual bool OnBeforeNavigation(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefRequest> request,
        NavigationType navigation_type,
        bool is_redirect) OVERRIDE;
    virtual void OnWebKitInitialized() OVERRIDE;
    virtual void OnContextCreated(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefV8Context> context) OVERRIDE;
    virtual void OnContextReleased(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefV8Context> context) OVERRIDE;
    virtual void OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefDOMNode> node) OVERRIDE;
    virtual bool OnProcessMessageReceived(
        CefRefPtr<CefBrowser> browser,
        CefProcessId source_process,
        CefRefPtr<CefProcessMessage> message) OVERRIDE;

    // Proxy configuration.
    CefString proxy_config_;

    // Schemes that will be registered with the global cookie manager.
    std::vector<CefString> cookieable_schemes_;

    IMPLEMENT_REFCOUNTING(CaffeineClientApp);

// CEF 2062
#ifdef __APPLE__
#else
    // Include the default locking implementation.
    IMPLEMENT_LOCKING(CaffeineClientApp);
#endif
};


//  TODO:  Clean up
///////////////////////////////////////////////
//
// Platform specific Helper functions
//

std::string GenerateUUID();

void ExecuteHasFocus(CefRefPtr<CaffeineClientApp>& client_app,
                     const CefV8ValueList& arguments,
                     CefRefPtr<CefV8Value>& retval );

void GetZippedLogFiles(CefRefPtr<CefV8Value>& retval );



#endif  //  CAFFEINE_CLIENT_APP_H