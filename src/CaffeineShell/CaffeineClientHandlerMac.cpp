//
//  CaffeineClientHandlerMac.cpp
//  McBrewery
//
//  Created by Fernando on 6/24/13.
//  Copyright (c) 2014 Yahoo. All rights reserved.
//

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#include "include/cef_base.h"
#pragma clang diagnostic pop
#include "CaffeineClientHandler.h"
#include "CaffeineClientUtils.h"
#include "CaffeineClientApp.h"
//#include "ModifyHeadersResourceHandler.h"
#include "McBrewery/mac_util.h"
#include <sstream>

void mainWindowIsLoaded(bool isLoading);
extern std::string userAgent;

std::wstring getDefaultDirectory();
std::wstring setDownloadName(const std::wstring& file_name);

void setLastResource(const std::string& url);
void shakeWindow(const std::string& uuid);

bool CaffeineClientHandler::GetPathFromUser(CefString &suggested_filename, CefString &DirectoryPath)
{
    std::vector<CefString> file_paths;
    std::wstring filename = std::wstring(suggested_filename);

    bool retval = saveFileDlg(file_paths, filename);
    if ( retval )
    {
        suggested_filename = CefString(filename);
        DirectoryPath = CefString(file_paths.front());
    }
    
    return retval;
}


bool CaffeineClientHandler::GetDirectoryFromUser(CefString &DirectoryPath)
{
    std::vector<CefString> file_paths;
    std::vector<CefString> file_types;
    
    bool retval = openFileDlg(file_paths, false, true, file_types, true);
    if ( retval )
    {
        DirectoryPath = CefString(file_paths.front());
    }
    return retval;
}


CefRefPtr<CefResourceHandler> CaffeineClientHandler::GetResourceHandler(CefRefPtr<CefBrowser> browser,
                                                                         CefRefPtr<CefFrame> frame,
                                                                         CefRefPtr<CefRequest> request)
{
    /*
    
    //  TODO:  We turned on exception handling so we could use the regex
    //  TODO:  library.  But we don't do any actual exception handling.
    //  TODO:  Can this cause mysterious crashes?  Would any particular
    //  TODO:  setting of it mitigate this potential?
    //std::tr1::regex whitelistedURLs("^https?://[^/]+/relay\?.*$");
    
    
    if((request->GetMethod() == "GET") &&  ns_regex_match(std::string(request->GetURL()), "^https?://[^/]+/relay\?.*$") )
    {
        return new ModifyHeadersResourceHandler(request);
        
        //    request->GetHeaderMap(x);
        //    x.insert(CefRequest::HeaderMap::value_type(TEXT("Cache-Control"), "max-age=315360000"));
        //    request->SetHeaderMap(x);
    }
     */
    
    return NULL;
}

void CaffeineClientHandler::RendererProcessTerminated(CefRefPtr<CefBrowser> browser, TerminationStatus status)
{
    rendererCrashed(browser);
}

void CaffeineClientHandler::CreateRemoteWindow(const int height, const int width,
                                                const int left, const int top,
                                                const std::string& uuid,
                                                const std::string& initArg,
                                                bool bCreateFrameless,
                                                bool bResizable,
                                                const std::string& target,
                                                const int minWidth, const int minHeight)
{
    AppCreateWindow(height, width, left, top, uuid, initArg.c_str(), bCreateFrameless, bResizable, target, minWidth, minHeight);
}


void CaffeineClientHandler::CreateDockableWindow(const std::string& uuid, const std::string& initArg, const std::string& targetUUID,
                              const int width, const int minTop, const int minBottom)
{
    AppCreateDockableWindow( uuid, initArg, targetUUID, width, minTop, minBottom);
}


void CaffeineClientHandler::PlatformSpecificInitialization()
{
    user_agent = userAgent;
}

void CaffeineClientHandler::SetUserToken(const std::string& usr, const std::string& tok)
{
    saveToken(usr, tok);
}

void CaffeineClientHandler::RemoveAllTokens()
{
    removeTokens();
}

void CaffeineClientHandler::RemoveUserToken(const std::string& usr)
{
    removeToken(usr);
}

void CaffeineClientHandler::StartFlashing(const CefString& browser_handle, bool bAutoStop)
{
    //bounceDockIcon();
    std::string str (browser_handle);
    startFlashing( str.c_str() );
}


void CaffeineClientHandler::StopFlashing(const CefString& browser_handle)
{
    std::string str (browser_handle);
    stopFlashing( str.c_str() );    
}


void CaffeineClientHandler::ActivateWindow(const CefString& browser_handle)
{
    std::string str (browser_handle);
    activatesWindow( str.c_str() );    
}

void CaffeineClientHandler::ShowWindow(const std::string& uuid)
{
    showWindow(uuid);
}

void CaffeineClientHandler::HideWindow(const std::string& uuid)
{
    hideWindow(uuid);
}

void CaffeineClientHandler::CreateToastWindow(const std::string& uuid, const std::string& initArg)
{
}

void CaffeineClientHandler::OpenDefaultBrowser(const CefString& target_url)
{
    std::wstring wurl = target_url;
    openURL(wurl);
}

bool CaffeineClientHandler::ValidateRequestLoad(CefRefPtr<CefBrowser> browser,
                                                 CefRefPtr<CefFrame> frame,
                                                 CefRefPtr<CefRequest> request)
{
    std::string url = request->GetURL();
    setLastResource( url );
    
#ifdef DEBUG
    validateFileResource( url );
#endif

    return true;
}

bool CaffeineClientHandler::ValidatePlugin(CefRefPtr<CefWebPluginInfo> info)
{
    if ( isVideoPluginValid( info->GetPath(),  info->GetVersion() ) == false )
        return true;
    return false;
}

void CaffeineClientHandler::OnAddressChange(CefRefPtr<CefBrowser> browser,
                                             CefRefPtr<CefFrame> frame,
                                             const CefString& url)
{
    REQUIRE_UI_THREAD();
    
    if (m_BrowserId == browser->GetIdentifier() && frame->IsMain())   {
    }
}

void CaffeineClientHandler::MessageReceived(std::wstring& from, std::wstring& displayName, std::wstring& msg, std::wstring& convId)
{
    incomingMessage(from, displayName, msg, convId);
}

void CaffeineClientHandler::ChangeBadgeCount(int valueChange, bool bRequest)
{
    changeBadgeCount(valueChange, bRequest);
}

void CaffeineClientHandler::ShowViewMenu(bool showOrHide)
{
    showViewMenu(showOrHide);
}

void CaffeineClientHandler::OnTitleChange(CefRefPtr<CefBrowser> browser,
                                           const CefString& title)
{
    REQUIRE_UI_THREAD();
    windowTitleChange(browser, title.ToWString());
}

void CaffeineClientHandler::SendNotification(NotificationType type)
{
    
}

void CaffeineClientHandler::SetLoading(bool isLoading)
{
    mainWindowIsLoaded(isLoading);
}

void CaffeineClientHandler::SetNavState(bool canGoBack, bool canGoForward)
{
}

void CaffeineClientHandler::CloseMainWindow()
{
}

void CaffeineClientHandler::MoveOrResizeWindow(const std::string& uuid, const int left, const int top, const int height, const int width)
{
    AppMoveOrResizeWindow( uuid, left, top, height, width);
    
}

void CaffeineClientHandler::stateIsNowLoggedIn(bool value)
{
    sessionLoggedIn(value);
}


void CaffeineClientHandler::OnLoadError(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, ErrorCode errorCode, const CefString& errorText, const CefString& failedUrl) 
{
    REQUIRE_UI_THREAD();
    
    // Don't display an error for downloaded files.
    if (errorCode == ERR_ABORTED)
        return;
    
    // Don't display an error for external protocols that we allow the OS to
    // handle. See OnProtocolExecution().
    if (errorCode == ERR_UNKNOWN_URL_SCHEME) {
        std::string urlStr = frame->GetURL();
        if (urlStr.find("spotify:") == 0)
            return;
    }
    
    std::wstring msg;
    loadLocalizedString("failedToLoadURL", msg);
    
    /*
    std::wstring temp (L"{url}");
    std::wstring msg (loadErrorMessage);
    size_t pos = msg.find(temp);
    
    msg.replace(pos, temp.length(), failedUrl);
    */
    
    // Display a load error message.
    std::wstringstream ss;
    ss << TEXT("<html><body><h2>") << msg << errorText.ToWString() << TEXT(" (") << errorCode << TEXT(").</h2></body></html>");
    frame->LoadString(ss.str(), failedUrl);
    
}

void CaffeineClientHandler::OpenFile(const std::wstring &path)
{
    launchFileFromFinder(path);
}

#ifdef ENABLE_MUSIC_SHARE
void CaffeineClientHandler::ITunesPlayPreview(const std::wstring &path)
{
    InternalITunesPlayPreview(path);
}
#endif

#ifdef CUSTOM_FILE_DIALOGS

bool CaffeineClientHandler::FileDlg(std::vector<CefString>& file_paths,
                                     FileDialogMode mode,
                                     const CefString& title,
                                     const CefString& default_file_name,
                                     const std::vector<CefString>& accept_types)
{
    if ( mode == FILE_DIALOG_SAVE )
    {
        std::wstring defFile = default_file_name.ToWString();
        return saveFileDlg(file_paths, defFile);
    }
    else
        return openFileDlg(file_paths, (mode == FILE_DIALOG_OPEN_MULTIPLE ? true : false), false, accept_types, false);
}

#endif


std::wstring CaffeineClientHandler::SetDownloadPath(const std::wstring &path)
{
    return setDownloadName(path);
}

std::wstring CaffeineClientHandler::GetDownloadPath(const std::wstring& file_name)
{
    std::wstring path;
    path = getDownloadName(file_name);
    
    /*
     if(DownloadPath.size() != 0)
     {
     path = DownloadPath;
     char ch = *path.rbegin();
     if ( ch != '/' )
     path += L"/";
     path += file_name;
     }
     else
     {
     path = getDownloadName(file_name);
     }
     */
    return path;
}

void CaffeineClientHandler::ShakeWindow(const std::string& uuid)
{
    shakeWindow(uuid);
}

// eof
