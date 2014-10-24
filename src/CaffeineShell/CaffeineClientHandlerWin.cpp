//  Copyright Yahoo Inc. 2013-2014

//  TODO:  Do we really need this many #include's???
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include <windows.h>
#include <shlobj.h> 
#include <atlbase.h>
#include <sstream>
#include <string>
#include <direct.h>
#include <Shlwapi.h>

#include "CaffeineClientHandler.h"
#include "CaffeineClientUtils.h"
#include "CaffeineClientApp.h"
#include "CaffeineShell.h"
#include "windowhelpers.h"
#include "Brewery_platform.h"

#include "RemoteWindow.h"
#include "ToastWindow.h"

#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "resource.h"

#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "include/cef_path_util.h"
#include "include/cef_process_util.h"
#include "include/cef_runnable.h"
#include "include/wrapper/cef_stream_resource_handler.h"
#include "cefclient/resource_util.h"
#include "include/cef_trace.h"
#include <Strsafe.h>
#include "CaffeineStringManager.h"

using namespace std;

extern HINSTANCE hInst;   // current instance
extern TCHAR szWindowTitle[MAX_LOADSTRING];  // The title bar text
extern CefRefPtr<CaffeineClientApp> app;
extern bool enableClose;
extern CaffeineStringManager StringManager;

//  TODO:  CLEAN UP
extern string mainUUID;
extern HWND mainWindowHandle;
extern LONG log_count;

bool bDockIsHidden = true;
bool otherAppInFullScreen = false;
//  TODO:  END CLEAN UP

#define TOAST_SPACING_FROM_TASKBAR (10)
#define TOAST_SPACING_FROM_BOTTOM_EDGE (50)
#define TOAST_WIDTH (300)
#define TOAST_HEIGHT (54)

// called from CaffeineRequestClient
void RequestCompleted(CefRefPtr<CefURLRequest> request, string& fileName)
{
    if(!::InterlockedDecrement(&log_count))
    {
        app->DeleteCrashLogs();
    }
}

CefRefPtr<CefResourceHandler> CaffeineClientHandler::GetResourceHandler(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefRequest> request)
{
    return NULL;
}


void CaffeineClientHandler::OnAddressChange(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    const CefString& url) 
{
    REQUIRE_UI_THREAD();

    if (m_BrowserId == browser->GetIdentifier() && frame->IsMain())   {
    }
}

void CaffeineClientHandler::OnTitleChange(
    CefRefPtr<CefBrowser> browser,
    const CefString& title) 
{
    REQUIRE_UI_THREAD();

    // Set the frame window title bar
    CefWindowHandle hwnd = browser->GetHost()->GetWindowHandle();
    if (m_BrowserId == browser->GetIdentifier())   {
        // The frame window will be the parent of the browser window
        hwnd = GetParent(hwnd);
    }
    SetWindowText(hwnd, wstring(title).c_str());
}

void CaffeineClientHandler::SendNotification(NotificationType type) 
{
}

void CaffeineClientHandler::SetLoading(bool isLoading) 
{
}

void CaffeineClientHandler::SetNavState(bool canGoBack, bool canGoForward) 
{
}

void CaffeineClientHandler::RendererProcessTerminated(CefRefPtr<CefBrowser> browser, TerminationStatus status)
{
}

void CaffeineClientHandler::CloseMainWindow() 
{
    PostMessage(m_MainHwnd, WM_CLOSE, 0, 0);
}

bool CaffeineClientHandler::GetDirectoryFromUser(CefString &DirectoryPath)
{
    bool retval = false;
    TCHAR szPath[MAX_PATH] = {0,};
    LPITEMIDLIST pidlSelected = NULL;
    BROWSEINFO bi = {0,};

    bi.hwndOwner = m_MainHwnd;
    bi.pidlRoot = NULL;
    bi.ulFlags = BIF_USENEWUI | BIF_RETURNONLYFSDIRS;
    bi.lpfn = NULL;
    bi.lParam = NULL;

    OleInitialize(NULL);

    pidlSelected = SHBrowseForFolder(&bi);
    if (pidlSelected != NULL)
    {
        SHGetPathFromIDList(pidlSelected, szPath);
        DirectoryPath = szPath;
        retval = true;
    }

    OleUninitialize();
    return retval;
}

bool CaffeineClientHandler::GetPathFromUser(CefString &suggested_filename, CefString &DirectoryPath)
{
    bool retval = false;
    TCHAR szPath[MAX_PATH] = {0,};
    TCHAR szFile[MAX_PATH] = {0,};

    _tcsncpy_s(szPath, MAX_PATH, CW2CT(suggested_filename.c_str()), _TRUNCATE);
    OPENFILENAME ofnUsersChoice = {0,};
    ofnUsersChoice.lStructSize =  sizeof(OPENFILENAME);
    ofnUsersChoice.hwndOwner = m_MainHwnd;
    ofnUsersChoice.lpstrFile = szPath;
    ofnUsersChoice.nMaxFile = MAX_PATH;
//    ofnUsersChoice.lpstrInitialDir = CW2CT(DirectoryPath.c_str());
    ofnUsersChoice.lpstrFileTitle = szFile;
    ofnUsersChoice.nMaxFileTitle = MAX_PATH;
    ofnUsersChoice.Flags = OFN_HIDEREADONLY | OFN_NONETWORKBUTTON;

    if(::GetSaveFileName(&ofnUsersChoice))
    {
        suggested_filename = CefString(szFile);
        DirectoryPath = CefString(szPath, ofnUsersChoice.nFileOffset-1, true);
        retval = true;
    }

    return retval;
}

wstring CaffeineClientHandler::SetDownloadPath(const wstring &path)
{
    CRegKey crk;
    
    if(ERROR_SUCCESS == crk.Create(HKEY_CURRENT_USER, DOWNLOAD_KEY_PATH, REG_NONE, REG_OPTION_NON_VOLATILE, KEY_WRITE))
    {
        if(ERROR_SUCCESS == crk.SetStringValue(DOWNLOAD_PATH, path.c_str()))
        {
            DownloadPath = path;
        }
    }

    return DownloadPath;
}

wstring CaffeineClientHandler::GetDownloadPath(const wstring &file_name) 
{
    CRegKey crk;
    wstring path;
    TCHAR szBuf[MAX_PATH] = {0,};
    ULONG bufSize = MAX_PATH;

    if(ERROR_SUCCESS == crk.Create(HKEY_CURRENT_USER, DOWNLOAD_KEY_PATH, REG_NONE, REG_OPTION_NON_VOLATILE, KEY_READ))
    {
        if(ERROR_SUCCESS == crk.QueryStringValue(DOWNLOAD_PATH, szBuf, &bufSize))
        {
            path = szBuf;
        }
    }

    if(path.empty())
    {
        HMODULE hShell32 = LoadLibrary(L"shell32.dll");
        typedef HRESULT (__stdcall *fnSHGetKnownFolderPath)(__in REFKNOWNFOLDERID rfid, __in DWORD dwFlags, __in_opt HANDLE hToken, __deref_out PWSTR *ppszPath);

        //  This should always succeed.
        if(hShell32)
        {
            PWSTR download_path = NULL;

            fnSHGetKnownFolderPath fn = reinterpret_cast<fnSHGetKnownFolderPath>(GetProcAddress(hShell32, "SHGetKnownFolderPath"));
            if(fn)
            {
                if(S_OK == fn(FOLDERID_Downloads, 0, NULL, &download_path))
                {
                    path = CefString(download_path);
                    CoTaskMemFree(download_path);
                }
            }
            FreeLibrary(hShell32);
        }
    }

    if(path.empty())
    {
        // Save the file in the user's "My Documents" folder.
        if (SUCCEEDED(SHGetFolderPath(NULL, CSIDL_PERSONAL | CSIDL_FLAG_CREATE,
                    NULL, 0, szBuf))) 
        {
            path = CefString(szBuf);
        }
    }

    path += TEXT("\\") + file_name;
    return path;
}

void CaffeineClientHandler::PlatformSpecificInitialization()
{
    user_agent = USER_AGENT;
    AcceptableDownloadDirectories.push_front(CefString(GetDownloadPath(L"")));
}

void CaffeineClientHandler::CreateRemoteWindow(const int height, const int width, const int left, const int top,
                                                const string& uuid, const string& initArg, bool bCreateFrameless, bool bResizable,
                                                const string& target, const int minWidth, const int minHeight)
{
    // Perform application initialization
    InitRemoteWindowInstance(hInst, SW_SHOWNORMAL, TEXT("EmbeddedCEFClientRemoteWindow"), szWindowTitle, uuid.data(),
                             height, width, left, top, initArg.data(), bCreateFrameless, bResizable, minWidth, minHeight);
}

POINT CaffeineClientHandler::GetBottomToastAttribute(APPBARDATA & abd)
{
    POINT point;
    point.x = abd.rc.right - TOAST_WIDTH - TOAST_SPACING_FROM_TASKBAR;
    point.y = 0;

    return point;
}

POINT CaffeineClientHandler::GetTopToastAttribute(APPBARDATA & abd)
{
    POINT point;
    point.x = abd.rc.right - TOAST_WIDTH - TOAST_SPACING_FROM_TASKBAR;
    point.y = abd.rc.bottom + TOAST_SPACING_FROM_TASKBAR;

    return point;
}

POINT CaffeineClientHandler::GetLeftToastAttribute(APPBARDATA & abd)
{
    POINT point;
    point.x = abd.rc.right + TOAST_SPACING_FROM_TASKBAR;
    point.y = 0;

    return point;
}

POINT CaffeineClientHandler::GetRightToastAttribute(APPBARDATA & abd)
{
    POINT point;
    point.x = abd.rc.left - TOAST_WIDTH - TOAST_SPACING_FROM_TASKBAR;
    point.y = 0;

    return point;
}

POINT CaffeineClientHandler::GetToastAttributes()
{
    HWND taskbar = FindWindow(L"Shell_TrayWnd", NULL);

    APPBARDATA abd;
    abd.cbSize = sizeof(APPBARDATA);
    abd.hWnd = taskbar;
    SHAppBarMessage(ABM_GETTASKBARPOS, &abd);

    switch (abd.uEdge)
    {
        case ABE_BOTTOM:
            return GetBottomToastAttribute(abd);
        case ABE_TOP:
            return GetTopToastAttribute(abd);
        case ABE_LEFT:
            return GetLeftToastAttribute(abd);
        default:
            return GetRightToastAttribute(abd);
    }
}

void CaffeineClientHandler::CreateToastWindow(const string& uuid, const string& initArg)
{
    POINT attrib = GetToastAttributes();

    if (!InitToastWindowInstance(hInst, TEXT("EmbeddedCEFClientToastWindow"), szWindowTitle, attrib, uuid.data(), initArg.data()))
    {
        wstring message = L"Could not create toast window: " + GetLastErrorString();
        app->ShellLog(message);
    }
}

void CaffeineClientHandler::StartFlashing(const CefString& browser_handle, bool bAutoStop)
{
    if (app->m_WindowHandler.find(browser_handle) != app->m_WindowHandler.end())
    {
        HWND hwnd = app->m_WindowHandler[browser_handle]->GetMainHwnd();
        
        if(hwnd)
        {
            FLASHWINFO fwi = { sizeof(FLASHWINFO), hwnd, FLASHW_ALL|(bAutoStop? FLASHW_TIMERNOFG : FLASHW_TIMER), 0, 0};
            ::FlashWindowEx(&fwi);
        }
    }
}

void CaffeineClientHandler::StopFlashing(const CefString& browser_handle)
{
    HWND hwnd = NULL;
    
    if (app->m_WindowHandler.find(browser_handle) != app->m_WindowHandler.end())
    {
        hwnd = app->m_WindowHandler[browser_handle]->GetMainHwnd();
        
        if(hwnd)
        {
            FLASHWINFO fwi = { sizeof(FLASHWINFO), hwnd, FLASHW_STOP, 0, 0};
            FlashWindowEx(&fwi);
        }
    }    
}

void CaffeineClientHandler::ActivateWindow(const CefString& browser_handle)
{
    HWND hwnd = NULL;
    if (app->m_WindowHandler.find(browser_handle) != app->m_WindowHandler.end())
    {
        hwnd = app->m_WindowHandler[browser_handle]->GetMainHwnd();
        
        if(hwnd)
        {
            ::ShowWindow(hwnd, SW_RESTORE);
            SwitchToThisWindow(hwnd, true);
        }
    }    
}

void CaffeineClientHandler::OpenDefaultBrowser(const CefString& target_url)
{
    string url = target_url.ToString();

    if ( (url.find("http://") == 0) || (url.find("https://") == 0) )
    {
        ShellExecute(NULL, TEXT("open"), target_url.c_str(), NULL, NULL, SW_SHOWNORMAL);    
    }
}

bool CaffeineClientHandler::ValidateRequestLoad(CefRefPtr<CefBrowser> browser,
                                                 CefRefPtr<CefFrame> frame,
                                                 CefRefPtr<CefRequest> request)
{
    //__asm int 3;
    string url = request->GetURL();
    bool retval = IsValidRequestURL(url);

    //  Downloads are reseting the CWD for some reason.  
    //  TODO:  Check if the upgrade fixed this.
    _chdir(AppGetWorkingDirectory().c_str());
    
    return retval;
}

bool CaffeineClientHandler::ValidatePlugin(CefRefPtr<CefWebPluginInfo> info)
{
    return false;
}

void CaffeineClientHandler::MoveOrResizeWindow(const string& uuid, const int left, const int top, const int height, const int width)
{
    HWND hwnd = NULL;
    if (app->m_WindowHandler.find(uuid) != app->m_WindowHandler.end())
    {
        hwnd = app->m_WindowHandler[uuid]->GetMainHwnd();
        
        if(hwnd)
        {
            //  TODO:  Coordinate the window styles between here and the window creation.
            RECT rectClient = {0, 0, width, height};

            //  The coordinates passed in are for the client area.
            DWORD dwStyle = GetWindowLongPtr(hwnd, GWL_STYLE);
            DWORD dwExStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
            AdjustWindowRectEx(&rectClient, dwStyle, FALSE, dwExStyle);

            RECT screenCoords = {left, top, left+(rectClient.right-rectClient.left), top+(rectClient.bottom-rectClient.top)};
            NormalizeScreenCoordinates(screenCoords);
            MoveWindow(hwnd, screenCoords.left, screenCoords.top, (screenCoords.right-screenCoords.left), (screenCoords.bottom-screenCoords.top), TRUE);
        }
    }    
}

void CaffeineClientHandler::MessageReceived(wstring& from, wstring& displayName, wstring& msg, wstring& convId)
{
    /*if ( IsWindowsVistaOrGreater() )
    {
        return;
    }*/

    bool static firstNotification = true;
    static NOTIFYICONDATA nid;

    if (firstNotification)
    {
        memset(&nid, 0, sizeof(NOTIFYICONDATA));
        nid.cbSize = sizeof(NOTIFYICONDATA);
        nid.hWnd = mainWindowHandle;
        nid.uID = 93;

        nid.uFlags = NIF_INFO | NIF_ICON;
        nid.dwInfoFlags = NIIF_INFO;
        nid.uTimeout = 5000;
        nid.hIcon = LoadIcon(hInst, MAKEINTRESOURCE(IDI_CAFFEINE));

        StringCchCopy(nid.szTip, 64, szWindowTitle);
        StringCchCopy(nid.szInfo, 256, msg.c_str());
        StringCchCopy(nid.szInfoTitle, 64, from.c_str());

        Shell_NotifyIcon(NIM_ADD, &nid);
        firstNotification = false;
    } 
    else
    {
        bool appIsActive = false;
        map<string, CefRefPtr<CaffeineClientHandler> >::iterator iter;
        TCHAR szBuf[80];

        for (iter = app->m_WindowHandler.begin(); iter != app->m_WindowHandler.end(); iter++)
        {
            if (iter->second->GetMainHwnd() == ::GetForegroundWindow())
            {
                GetWindowText(iter->second->GetMainHwnd(), szBuf, 80);

                appIsActive = true;
                break;
            }
        }

        if ( !appIsActive )
        {
            StringCchCopy(nid.szInfo, 256, msg.c_str());
            StringCchCopy(nid.szInfoTitle, 64, from.c_str());

            Shell_NotifyIcon(NIM_MODIFY, &nid);
        }
        
    }


/*    bool appIsActive = false;
    map<string, CefRefPtr<CaffeineClientHandler> >::iterator iter;
    for (iter = app->m_WindowHandler.begin(); iter != app->m_WindowHandler.end(); iter++)
    {
        if (iter->second->GetMainHwnd() == GetForegroundWindow())
        {
            TCHAR szBuf[80];
            GetWindowText(iter->second->GetMainHwnd(), szBuf, 80);

            appIsActive = true;
        }
    }

    if ( appIsActive == false )
    {
        NOTIFYICONDATA nid;
        memset(&nid, 0, sizeof(NOTIFYICONDATA));
        nid.cbSize = NOTIFYICONDATA_V2_SIZE;
        nid.hWnd = mainWindowHandle;
        nid.uID = 93;

        nid.uFlags = NIF_INFO | NIF_ICON;
        StringCchCopy(nid.szInfo, 256, msg.c_str());
        StringCchCopy(nid.szInfoTitle, 64, from.c_str());
        nid.dwInfoFlags = NIIF_INFO;
        nid.uTimeout = 5000;

        nid.hIcon = LoadIcon(hInst, MAKEINTRESOURCE(IDI_CAFFEINE));
        StringCchCopy(nid.szTip, 64, szWindowTitle);
        if ( firstNotification )
        {
            firstNotification = false;
            Shell_NotifyIcon(NIM_ADD, &nid);
        }
        else
        {
            Shell_NotifyIcon(NIM_MODIFY, &nid);
        }
    }*/
}

void CaffeineClientHandler::stateIsNowLoggedIn(bool value)
{
    enableClose = !value;
}

bool CaffeineClientHandler::isDesktopActive(HWND foregroundWindow)
{
    // The desktop class name is "Progman and after changing the wallpaper, its called "WorkerW"
    TCHAR szBuf[80];
    GetClassName(foregroundWindow, szBuf, 80);

    if ( !_tcscmp(szBuf, _T("Progman")) || !_tcscmp(szBuf, _T("WorkerW")) )
    {
        return true;
    }
    return false;
}

bool CaffeineClientHandler::IsForegroundWindowInFullScreen()
{
    RECT rect;
    HWND foregroundWindow = GetForegroundWindow();

    if ( !foregroundWindow || isDesktopActive(foregroundWindow) || !GetWindowRect(foregroundWindow, &rect) )
    {
        return false;
    }

    int scrX = GetSystemMetrics(SM_CXSCREEN),
        scrY = GetSystemMetrics(SM_CYSCREEN);

    return scrX == (rect.right - rect.left) && scrY == (rect.bottom - rect.top);
}

void CaffeineClientHandler::ShowWindow(const string& uuid)
{
    HWND hwnd = NULL;
    if (app->m_WindowHandler.find(uuid) != app->m_WindowHandler.end())
    {
        hwnd = app->m_WindowHandler[uuid]->GetMainHwnd();
        
        if (hwnd)
        {
            if (otherAppInFullScreen)
            {
                ::ShowWindow(hwnd, SW_SHOWMINNOACTIVE);
                return;
            }

            ::ShowWindow(hwnd, SW_SHOWNA);
        }
    }
    
}

void CaffeineClientHandler::HideWindow(const string& uuid)
{
    HWND hwnd = NULL;
    if (app->m_WindowHandler.find(uuid) != app->m_WindowHandler.end())
    {
        hwnd = app->m_WindowHandler[uuid]->GetMainHwnd();
        
        if (hwnd)
        {
            ::ShowWindow(hwnd, SW_HIDE);
        }
    }
}

void CaffeineClientHandler::SetEphemeralState(wstring state)
{
    if (! SetEnvironmentVariable(L"lala", state.c_str())) 
    {
        app->ShellLog(L"SetEphemeralState: Failed to set ephermal state");
    }
}

void CaffeineClientHandler::RestartApplication(wstring applicationPath)
{
    STARTUPINFO             si = {0};
    PROCESS_INFORMATION     pi = {0};
    si.cb = sizeof(STARTUPINFO);

    wstringstream ss;
    ss << applicationPath << TEXT(" --restart") << TEXT(" --cwd=\"");

    unsigned found = applicationPath.find_last_of(TEXT("\\"));
    ss << applicationPath.substr(0, found) << TEXT("\"");

    wstring newAppPath = ss.str();
    LPWSTR str = const_cast<LPWSTR>(newAppPath.c_str());

    wstring logMsg = L"Restarting Application with path: " + applicationPath;
    app->ShellLog(logMsg);

    // Create another copy of process
    if (!CreateProcess(NULL, str, NULL, NULL, false, NULL, NULL, NULL, &si, &pi))
    {
        app->ShellLog(L"Failed to create new process to launch the updated app");
    }

    //  Need to close the handles.
    CloseHandle(si.hStdInput);
    CloseHandle(si.hStdOutput);
    CloseHandle(si.hStdError);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
}

void CaffeineClientHandler::OnLoadError(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    ErrorCode errorCode,
    const CefString& errorText,
    const CefString& failedUrl) 
{
    REQUIRE_UI_THREAD();

    // Don't display an error for downloaded files.
    if (errorCode == ERR_ABORTED)
        return;

    TCHAR loadErrorMessage[INFOTIPSIZE];
    StringManager.LoadString(IDS_URL_LOAD_FAILURE, loadErrorMessage, INFOTIPSIZE);

    wstring temp (L"{url}");
    wstring msg (loadErrorMessage);
    size_t pos = msg.find(temp);

    msg.replace(pos, temp.length(), failedUrl);

    // Display a load error message.
    wstringstream ss;
    ss << TEXT("<html><body><h2>") << msg << errorText.ToWString() << TEXT(" (") << errorCode << TEXT(").</h2></body></html>");
    frame->LoadString(ss.str(), failedUrl);
}

void CaffeineClientHandler::OpenFile(const wstring& applicationPath)
{
    ShellExecute(NULL, NULL, applicationPath.c_str(), NULL, NULL, SW_SHOWNORMAL);
}
#ifdef ENABLE_MUSIC_SHARE
void CaffeineClientHandler::ITunesPlayPreview(const wstring& url)
{
    HKEY hKey = NULL;

    //Check if WMP is installed
    LONG lResult = RegOpenKeyEx(HKEY_CLASSES_ROOT, TEXT("Applications\\wmplayer.exe\\shell\\open\\command"), 0, KEY_READ, &hKey);
    RegCloseKey(hKey);

    //If version is XP and below or WMP is not installed launch in browser, otherwise use WMP
    if ( (lResult != ERROR_SUCCESS) || !IsWindowsVistaOrGreater() ) {
        ShellExecute(NULL, NULL, url.c_str(), NULL, NULL, SW_SHOWNORMAL);
    } else {
        ShellExecute(NULL, TEXT("open"), TEXT("wmplayer.exe"), url.c_str(), NULL, SW_SHOWNORMAL);
    }
}
#endif