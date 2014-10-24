//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_CLIENT_HANDLER_H
#define CAFFEINE_CLIENT_HANDLER_H
#pragma once

#define CAFFEINE_MAX_LOG_SIZE (1024*1024*10)  //  10MB
#define DOWNLOAD_PATH (L"DownloadPath")

#include <map>
#include <set>
#include <string>
#include <list>
#include "include/cef_client.h"
#include "include/cef_browser.h"
#include "include/cef_cookie.h"
#include "include/cef_urlrequest.h"

// CEF 2062
#include "include/base/cef_lock.h"
#include "util.h"
#include "Brewery_platform.h"

#ifdef OS_WIN
#include <ShellApi.h>
#endif


// Define this value to redirect all popup URLs to the main application browser
// window.
// #define TEST_REDIRECT_POPUP_URLS

class CaffeineCookieVisitor: public CefCookieVisitor
{
    public:
        CaffeineCookieVisitor(CefRefPtr<CefCookieManager> manager, std::string urlToSetOn)
        : manager(manager), urlToSetOn(urlToSetOn)
        {
        }

        virtual bool Visit(const CefCookie& cookie, int count, int total, bool& deleteCookie)
        {
            REQUIRE_IO_THREAD();

            deleteCookie = false;
            
            CefCookie new_cookie;
            new_cookie.Set(cookie, true);
            std::string new_domain(urlToSetOn);
            //  Right now, we only support http:// based urls.  So, replace the first 7 characters.
            //  TODO:  Allow logic to handle other schemes/protocols.
            new_domain.replace(0, 7, "");

            cef_string_from_ascii(new_domain.c_str(), new_domain.length(), &new_cookie.domain);
            manager->SetCookie(urlToSetOn, new_cookie);

            //  We could probably always return true
            return !(count + 1 == total);
        }
    
    private:
        std::string urlToSetOn;
        CefRefPtr<CefCookieManager> manager;

    IMPLEMENT_REFCOUNTING(CaffeineCookieVisitor);
};


typedef std::vector<CefCookie> CookieVector;

class GetCookiesVisitor: public CefCookieVisitor
{
public:
    GetCookiesVisitor(CefRefPtr<CefCookieManager> manager): manager(manager) {
    }
    
    virtual bool Visit(const CefCookie& cookie, int count, int total, bool& deleteCookie)
    {
        REQUIRE_IO_THREAD();
        deleteCookie = false;
        CefCookie new_cookie;
        new_cookie.Set(cookie, true);
        
        cookies_.push_back(new_cookie);
        return  true;
    }

    CookieVector cookies_;
    
private:
    CefRefPtr<CefCookieManager> manager;
    
    IMPLEMENT_REFCOUNTING(GetCookiesVisitor);
};


void RequestCompleted( CefRefPtr<CefURLRequest> request, std::string& fileName );

class CaffeineRequestClient : public CefURLRequestClient {
public:
    CaffeineRequestClient() :
        upload_total_(0),
        download_total_(0) {}
    
    virtual void OnRequestComplete(CefRefPtr<CefURLRequest> request) OVERRIDE {
        RequestCompleted(request, uploadFile_);
    }
    virtual void OnUploadProgress(CefRefPtr<CefURLRequest> request,
                                  uint64 current,
                                  uint64 total) OVERRIDE {
    }
    
    virtual void OnDownloadProgress(CefRefPtr<CefURLRequest> request,
                                    uint64 current,
                                    uint64 total) OVERRIDE {
        download_total_ = total;
    }
    
    virtual void OnDownloadData(CefRefPtr<CefURLRequest> request,
                                const void* data,
                                size_t data_length) OVERRIDE {
    }
    
    // Cef 1547+ 1670
    virtual bool GetAuthCredentials(bool /*isProxy*/,
                                    const CefString& /*host*/,
                                    int /*port*/,
                                    const CefString& /*realm*/,
                                    const CefString& /*scheme*/,
                                    CefRefPtr<CefAuthCallback> /*callback*/) OVERRIDE {
        // Return false to cancel the request
        return true;
    }
    

    std::string uploadFile_;
    
private:
    uint64 upload_total_;
    uint64 download_total_;
    
    IMPLEMENT_REFCOUNTING(CaffeineRequestClient);
};

// CaffeineClientHandler implementation.
class CaffeineClientHandler : public CefClient,
#ifdef CUSTOM_FILE_DIALOGS
    public CefDialogHandler,
#endif
    public CefContextMenuHandler,
    public CefDisplayHandler,
    public CefDownloadHandler,
    public CefGeolocationHandler,
    public CefJSDialogHandler,
    public CefKeyboardHandler,
    public CefLifeSpanHandler,
    public CefLoadHandler,
    public CefRequestHandler,  
    public CefFocusHandler,
    public CefRenderHandler
{
public:
    //  The main browser process
    CefRefPtr<CefBrowser> m_MainBrowser;
    CefString uuid;
    CefString user_agent;
    std::string browserInitArg;
    std::map<std::string, std::string> requestPrefixMap;
    HWND hwndDockedWindow;
    std::list<CefString> AcceptableDownloadDirectories;

    void CreateAndDispatchCustomEvent(const CefString &eventName, const CefString &obj = "{}");
    bool RenameOldFile(std::wstring filename);

    // file transfer directories hack
    bool GetPathFromUser(CefString &suggested_filename, CefString &DirectoryPath);
    bool GetDirectoryFromUser(CefString &DirectoryPath);

    void SetMinWindowWidth(const int width);
    void SetMinWindowHeight(const int height);

    int GetMinWindowWidth();
    int GetMinWindowHeight();

    //  Interface for process message delegates. Do not perform work in the
    //  RenderDelegate constructor.
    class ProcessMessageDelegate : public virtual CefBase {
    public:
        // Called when a process message is received. Return true if the message was
        // handled and should not be passed on to other handlers.
        // ProcessMessageDelegates should check for unique message names to avoid
        // interfering with each other.
        virtual bool OnProcessMessageReceived(
            CefRefPtr<CaffeineClientHandler> handler,
            CefRefPtr<CefBrowser> browser,
            CefProcessId /*source_process*/,
            CefRefPtr<CefProcessMessage> message) {
                return false;
        }
    };
    
    // Interface implemented to handle off-screen rendering.
    class RenderHandler : public CefRenderHandler {
    public:
        virtual void OnBeforeClose(CefRefPtr<CefBrowser> browser) =0;
    };

    typedef std::set<CefRefPtr<ProcessMessageDelegate> >
        ProcessMessageDelegateSet;

    CaffeineClientHandler();
    virtual ~CaffeineClientHandler();

    // CefClient methods
    virtual CefRefPtr<CefContextMenuHandler> GetContextMenuHandler() OVERRIDE {
        return this;
    }
    virtual CefRefPtr<CefDisplayHandler> GetDisplayHandler() OVERRIDE {
        return this;
    }
    virtual CefRefPtr<CefDownloadHandler> GetDownloadHandler() OVERRIDE {
        return this;
    }

    virtual CefRefPtr<CefGeolocationHandler> GetGeolocationHandler() OVERRIDE {
        return this;
    }
    
    virtual CefRefPtr<CefJSDialogHandler> GetJSDialogHandler() OVERRIDE {
        return this;
    }

    virtual CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() OVERRIDE {
        return this;
    }
    virtual CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() OVERRIDE {
        return this;
    }
    virtual CefRefPtr<CefLoadHandler> GetLoadHandler() OVERRIDE {
        return this;
    }
    virtual CefRefPtr<CefRequestHandler> GetRequestHandler() OVERRIDE {
        return this;
    }
    virtual CefRefPtr<CefRenderHandler> GetRenderHandler() OVERRIDE {
        return this;
    }


#ifdef CUSTOM_FILE_DIALOGS
    virtual CefRefPtr<CefDialogHandler> GetDialogHandler() OVERRIDE {
        return this;
    }
#endif

    virtual bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
        CefProcessId source_process,
        CefRefPtr<CefProcessMessage> message)
        OVERRIDE;

    // CefContextMenuHandler methods
    virtual void OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefContextMenuParams> params,
        CefRefPtr<CefMenuModel> model) OVERRIDE;
    virtual bool OnContextMenuCommand(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefContextMenuParams> params,
        int command_id,
        EventFlags event_flags) OVERRIDE;

    // CefDisplayHandler methods
    virtual void OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
        bool isLoading,
        bool canGoBack,
        bool canGoForward) OVERRIDE;
    virtual void OnAddressChange(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        const CefString& url) OVERRIDE;
    virtual void OnTitleChange(CefRefPtr<CefBrowser> browser,
        const CefString& title) OVERRIDE;
    virtual bool OnConsoleMessage(CefRefPtr<CefBrowser> browser,
        const CefString& message,
        const CefString& source,
        int line) OVERRIDE;

    virtual bool OnBeforePluginLoad(CefRefPtr<CefBrowser> browser,
        const CefString& url,
        const CefString& policy_url,
        CefRefPtr<CefWebPluginInfo> info)  OVERRIDE;

    // CefDownloadHandler methods
    virtual void OnBeforeDownload(
        CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefDownloadItem> download_item,
        const CefString& suggested_name,
        CefRefPtr<CefBeforeDownloadCallback> callback) OVERRIDE;
    virtual void OnDownloadUpdated(
        CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefDownloadItem> download_item,
        CefRefPtr<CefDownloadItemCallback> callback) OVERRIDE;

    // CefJSDialogHandler
    virtual bool OnBeforeUnloadDialog(CefRefPtr<CefBrowser> browser,
        const CefString& message_text,
        bool is_reload,
        CefRefPtr<CefJSDialogCallback> callback) OVERRIDE;
    virtual bool OnJSDialog(CefRefPtr<CefBrowser> browser,
        const CefString& origin_url,
        const CefString& accept_lang,
        JSDialogType dialog_type,
        const CefString& message_text,
        const CefString& default_prompt_text,
        CefRefPtr<CefJSDialogCallback> callback,
        bool& suppress_message) OVERRIDE;

    // CefLifeSpanHandler methods
    virtual bool OnBeforePopup(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        const CefString& target_url,
        const CefString& target_frame_name,
        const CefPopupFeatures& popupFeatures,
        CefWindowInfo& windowInfo,
        CefRefPtr<CefClient>& client,
        CefBrowserSettings& settings,
        bool* no_javascript_access) OVERRIDE;
    virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser) OVERRIDE;
    virtual bool DoClose(CefRefPtr<CefBrowser> browser) OVERRIDE;
    virtual void OnBeforeClose(CefRefPtr<CefBrowser> browser) OVERRIDE;

    // CefLoadHandler methods
    virtual void OnLoadStart(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame) OVERRIDE;
    virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        int httpStatusCode) OVERRIDE;
    virtual void OnLoadError(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        ErrorCode errorCode,
        const CefString& errorText,
        const CefString& failedUrl) OVERRIDE;
    virtual void OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser,
        TerminationStatus status) OVERRIDE;

    // CefRequestHandler methods
    virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefRequest> request) OVERRIDE;

    virtual CefRefPtr<CefResourceHandler> GetResourceHandler(
        CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefRequest> request) OVERRIDE;
    virtual bool OnQuotaRequest(CefRefPtr<CefBrowser> browser,
        const CefString& origin_url,
        int64 new_size,
        CefRefPtr<CefQuotaCallback> callback) OVERRIDE;
    virtual void OnProtocolExecution(CefRefPtr<CefBrowser> browser,
        const CefString& url,
        bool& allow_os_execution) OVERRIDE;

    // CEF 2062
    // CefGeolocationHandler methods
    virtual bool OnRequestGeolocationPermission(
                                            CefRefPtr<CefBrowser> browser,
                                            const CefString& requesting_url,
                                            int request_id,
                                            CefRefPtr<CefGeolocationCallback> callback) OVERRIDE;

    // CefRenderHandler methods
    virtual bool GetRootScreenRect(CefRefPtr<CefBrowser> browser,
                                   CefRect& rect) OVERRIDE;
    virtual bool GetViewRect(CefRefPtr<CefBrowser> browser,
                         CefRect& rect) OVERRIDE;
    virtual bool GetScreenPoint(CefRefPtr<CefBrowser> browser,
                            int viewX,
                            int viewY,
                            int& screenX,
                            int& screenY) OVERRIDE;
    virtual bool GetScreenInfo(CefRefPtr<CefBrowser> browser,
                           CefScreenInfo& screen_info) OVERRIDE;
    virtual void OnPopupShow(CefRefPtr<CefBrowser> browser, bool show) OVERRIDE;
    virtual void OnPopupSize(CefRefPtr<CefBrowser> browser,
                         const CefRect& rect) OVERRIDE;
    virtual void OnPaint(CefRefPtr<CefBrowser> browser,
                     PaintElementType type,
                     const RectList& dirtyRects,
                     const void* buffer,
                     int width,
                         int height) OVERRIDE;
    virtual void OnCursorChange(CefRefPtr<CefBrowser> browser,
                            CefCursorHandle cursor) OVERRIDE;

    void SetOSRHandler(CefRefPtr<RenderHandler> handler) {
        m_OSRHandler = handler;
    }
    CefRefPtr<RenderHandler> GetOSRHandler() { return m_OSRHandler; }


#ifdef CUSTOM_FILE_DIALOGS
    // CefDialogHandler methods
    virtual bool OnFileDialog(CefRefPtr<CefBrowser> browser,
                          FileDialogMode mode,
                          const CefString& title,
                          const CefString& default_file_name,
                          const std::vector<CefString>& accept_types,
                          CefRefPtr<CefFileDialogCallback> callback) OVERRIDE;
#endif

    void SetMainHwnd(CefWindowHandle hwnd);
    CefWindowHandle GetMainHwnd() { return m_MainHwnd; }

void SetButtonHwnds(CefWindowHandle backHwnd,
                    CefWindowHandle forwardHwnd,
                    CefWindowHandle reloadHwnd,
                    CefWindowHandle stopHwnd);


    CefRefPtr<CefBrowser> GetBrowser() { return m_MainBrowser; }
    int GetBrowserId() { return m_BrowserId; }

    // Returns true if the main browser window is currently closing. Used in
    // combination with DoClose() and the OS close notification to properly handle
    // 'onbeforeunload' JavaScript events during window close.
    bool IsClosing() { return m_bIsClosing; }

    std::wstring GetLogFile();

    void OpenFile(const std::wstring& path);

    // Send a notification to the application. Notifications should not block the
    // caller.
    enum NotificationType {
        NOTIFY_CONSOLE_MESSAGE,
        NOTIFY_DOWNLOAD_COMPLETE,
        NOTIFY_DOWNLOAD_ERROR,
    };
    void SendNotification(NotificationType type);
    void CloseMainWindow();

    // Returns the startup URL.
    std::string GetStartupURL() { return m_StartupURL; }

    // Create an external browser window that loads the specified URL.
    static void LaunchExternalBrowser(const std::string& url);

    bool Save(const std::string& path, const std::string& data);
    
    // changing CefFocusHandler
    virtual CefRefPtr<CefFocusHandler> GetFocusHandler() OVERRIDE { return this; }
    
    virtual void OnTakeFocus(CefRefPtr<CefBrowser> browser, bool next) OVERRIDE;
    virtual bool OnSetFocus(CefRefPtr<CefBrowser> browser, FocusSource source) OVERRIDE;
    virtual void OnGotFocus(CefRefPtr<CefBrowser> browser) OVERRIDE;
    
    bool HasFocus() { return m_bHasFocus; }
    
    // Platform Specific
    void PlatformSpecificInitialization();
    void CreateRemoteWindow(const int height, const int width, const int left, const int top,
                            const std::string& uuid, const std::string& initArg, bool bCreateFrameless, bool bResizable,
                            const std::string& target, const int minWidth, const int minHeight);
    void CreateToastWindow(const std::string& uuid, const std::string& initArg);
    void StartFlashing(const CefString& browser_handle, bool bAutoStop);
    void StopFlashing(const CefString& browser_handle);
    void ActivateWindow(const CefString& browser_handle);
    void OpenDefaultBrowser(const CefString& target_url);
    bool ValidateRequestLoad(CefRefPtr<CefBrowser> browser,
                             CefRefPtr<CefFrame> frame,
                             CefRefPtr<CefRequest> request);
    bool ValidatePlugin(CefRefPtr<CefWebPluginInfo> info);
    
    void MoveOrResizeWindow(const std::string& uuid, const int left, const int top, const int height, const int width);
    
    void ShowWindow(const std::string& uuid);
    void HideWindow(const std::string& uuid);

#ifdef ENABLE_MUSIC_SHARE
    void ITunesPlayPreview(const std::wstring& url);
#endif

#ifdef OS_WIN
    void RestartApplication(std::wstring applicationPath);
    POINT GetToastAttributes();

    bool IsForegroundWindowInFullScreen();
    void SetEphemeralState(std::wstring state);
    std::wstring GetEphemeralState();
#endif
    // message received for possible Toast display
    void MessageReceived(std::wstring& from, std::wstring& displayName, std::wstring& msg, std::wstring& convId);
    
    // sent when state changes to Logged IN or Logout OUT (affects Mac menus - logout)
    void stateIsNowLoggedIn(bool value);

    // when renderer process is terminated
    void RendererProcessTerminated(CefRefPtr<CefBrowser> browser, TerminationStatus status);

#ifdef OS_MACOSX
    // sets the app icon badge number: negative or positive values for unread count or pending requests
    void ChangeBadgeCount(int valueChange, bool bRequest);

    // to grey or not the Mac view menus
    void ShowViewMenu(bool showOrHide);

    // Keychain handling
    void SetUserToken(const std::string& usr, const std::string& tok);
    void RemoveUserToken(const std::string& usr);
    void RemoveAllTokens();

    void ShakeWindow(const std::string& uuid);

#ifdef CUSTOM_FILE_DIALOGS
    bool FileDlg(std::vector<CefString>& file_paths, FileDialogMode mode, const CefString& title, const CefString& default_file_name, const std::vector<CefString>& accept_types);
#endif

#endif

protected:
    void SetLoading(bool isLoading);
    void SetNavState(bool canGoBack, bool canGoForward);

    // Returns the full download path for the specified file, or an empty path to
    // use the default temp directory.
    std::wstring GetDownloadPath(const std::wstring& file_name);
    std::wstring SetDownloadPath(const std::wstring &path);

    // The main frame window handle
    CefWindowHandle m_MainHwnd;

    // The child browser id
    int m_BrowserId;

    //  Default download path
    CefString DownloadPath;

    // offscreen renderer
    CefRefPtr<RenderHandler> m_OSRHandler;

    // Support for logging.
    std::wstring m_LogFile;

    // Support for downloading files.
    std::string m_LastDownloadFile;

    bool m_bIsClosing;

    // If true DevTools will be opened in an external browser window.
    bool m_bExternalDevTools;

    // List of open DevTools URLs if not using an external browser window.
    std::set<std::string> m_OpenDevToolsURLs;

    // The startup URL.
    std::string m_StartupURL;
    
    // focus helper
    bool m_bHasFocus;
private:
#ifdef OS_WIN
    POINT GetBottomToastAttribute(APPBARDATA & abd);
    POINT GetTopToastAttribute(APPBARDATA & abd);
    POINT GetLeftToastAttribute(APPBARDATA & abd);
    POINT GetRightToastAttribute(APPBARDATA & abd);

    bool isDesktopActive(HWND foregroundWindow);
#endif
    std::set<std::wstring> downloadedFiles;
    int minWindowWidth;
    int minWindowHeight;

    // Include the default reference counting implementation.
    IMPLEMENT_REFCOUNTING(CaffeineClientHandler);

    // CEF 2062
#ifdef __APPLE__

    base::Lock lock_;

#else
    // Include the default locking implementation.
    IMPLEMENT_LOCKING(CaffeineClientHandler);
#endif
};

#endif  //  CAFFEINE_CLIENT_HANDLER_H