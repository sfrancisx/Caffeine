//  Copyright Yahoo! Inc. 2013-2014
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "windowhelpers.h"
#include <WindowsX.h>
#include <Shlobj.h>
#include <Shellapi.h>
#include <atlbase.h>
#include <stdlib.h>
#include <Wininet.h>
#include <ws2tcpip.h>
#include <map>
#include <regex>
#include <string>
#include <sstream>
#include "CaffeineStringManager.h"
#include "resource.h"

using namespace std;

namespace {
    map<HWND, WNDPROC> origWndProc;
};

extern CaffeineStringManager StringManager;

IsInternetConnected::IsInternetConnected()
: connect_fn(nullptr), hConnect(nullptr)
{
    hConnect = LoadLibrary(L"Connect.dll");
    connect_fn =(pfnIsInternetConnected)(::GetProcAddress(hConnect, "IsInternetConnected"));
}

IsInternetConnected::~IsInternetConnected()
{
    if(hConnect) FreeLibrary(hConnect);
    hConnect = nullptr;  connect_fn = nullptr;
}

bool IsInternetConnected::operator()()
{
    bool active_connection = true;

    if(connect_fn)
    {
        active_connection = (S_OK == connect_fn());
    }
    else
    {
        active_connection = !!::InternetCheckConnection(L"http://www.yahoo.com", FLAG_ICC_FORCE_CONNECTION, 0);
    }

    return active_connection;
}

WindowExtras::WindowExtras()
: IsIdle(false), IdleTimeThreshold(15*60*100), NetworkAvailable(), IsConnected(NetworkAvailable())
{
    //  Set  up the idle timer
    SystemParametersInfo(SPI_GETSCREENSAVETIMEOUT, 0, &IdleTimeThreshold, 0);
    if(IdleTimeThreshold == 0)
        IdleTimeThreshold = 15*60;
    IdleTimeThreshold *= 1000;
}

WindowExtras::~WindowExtras()
{
}

bool BackupFile(wstring FileToBackUp)
{
    bool retval = true;
    wstring BackupName = FileToBackUp + L".bak";

    if(PathFileExists(BackupName.c_str()))
    {
        DeleteFile(BackupName.c_str());
    }

    if(PathFileExists(FileToBackUp.c_str()))
    {
        MoveFile(FileToBackUp.c_str(), BackupName.c_str());
    }

    return retval;
}

LRESULT HitTestBorders(const RECT &client_rect, const POINT &point)
{
    int left_diff = abs(point.x - client_rect.left),
        right_diff = abs(point.x - client_rect.right),
        top_diff = abs(point.y - client_rect.top),
        bottom_diff = abs(point.y - client_rect.bottom),
        lft_rt = ((left_diff < 8)? 1 : ((right_diff < 8)? 2 : 0)),
        top_btm = ((top_diff < 16)? 1 : ((bottom_diff < 8)? 2 : 0));
    //  1st dimension:  0: neither left border nor right, 1: left border, 2: right border
    //  2nd dimension:  0: neither top nor bottom, 1: top border, 2: bottom border
    const LRESULT lookupTable[][3] = {
        {NULL, HTCAPTION, HTBOTTOM}, 
        {HTLEFT, HTTOPLEFT, HTBOTTOMLEFT}, 
        {HTRIGHT, HTTOPRIGHT, HTBOTTOMRIGHT}
    };

    return lookupTable[lft_rt][top_btm];
}

//  Only uses the top and left fields
void NormalizeScreenCoordinates(RECT &screenCoordinates)
{
    LONG screenwidth = GetSystemMetrics(SM_CXVIRTUALSCREEN),
         screenheight = GetSystemMetrics(SM_CYVIRTUALSCREEN),
         screenleft = GetSystemMetrics(SM_XVIRTUALSCREEN),
         screentop = GetSystemMetrics(SM_YVIRTUALSCREEN),
         &clientleft = screenCoordinates.left,
         &clienttop = screenCoordinates.top,
         &clientright = screenCoordinates.right,
         &clientbottom = screenCoordinates.bottom,
         width,
         height;

    if (clientleft > clientright) swap(clientleft, clientright);
    if (clienttop > clientbottom) swap(clienttop, clientbottom);
    width = min(max(clientright - clientleft, 50L), screenwidth),
    height = min(max(clientbottom - clienttop, 50L), screenheight);

    clientbottom = clienttop + height,
    clientright = clientleft + width;

    //  TODO:  The second clause doesn't seem necessary.
    if ((clienttop < screentop) || ((clientbottom - BOTTOM_EDGE_TOLERANCE) < screentop))
    {
        clienttop = screentop;
        clientbottom = clienttop + height;
    }

    if (((clientleft + VERT_EDGE_TOLERANCE) > screenleft + screenwidth) || (clientright > screenleft + screenwidth))
    {
        clientright = screenleft + screenwidth;
        clientleft = clientright - width;
    }

    if (((clientright - VERT_EDGE_TOLERANCE) < screenleft) || (clientleft < screenleft))
    {
        clientleft = screenleft;
        clientright = clientleft + width;
    }

    if (((clienttop + BOTTOM_EDGE_TOLERANCE) > screentop + screenheight) || (clientbottom > screentop + screenheight))
    {
        clientbottom = screentop + screenheight;
        clienttop = clientbottom - height;
    }
}

LRESULT CALLBACK newWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    if (msg == WM_NCHITTEST)
    {
        RECT rect = {0,};
        POINT pt = {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
        GetClientRect(hwnd, &rect);
        ScreenToClient(hwnd, &pt);

        LRESULT retval = HitTestBorders(rect, pt);
        if(retval)
        {
            return HTTRANSPARENT;
        }
    }
    return CallWindowProc(origWndProc[hwnd], hwnd, msg, wParam, lParam); 
}

void FixupWndProcs(const HWND &hwndOuterWindow)
{
    HWND hwndChild = hwndOuterWindow;
    LPCWSTR szClassNames[] = { L"CefBrowserWindow", L"Chrome_WidgetWin_0", L"Chrome_RenderWidgetHostHWND" };

    for(int i=0; i<3; ++i)
    {
        hwndChild = FindWindowEx(hwndChild, NULL, szClassNames[i], NULL);
        if(hwndChild)
        {
            origWndProc[hwndChild] = (WNDPROC)(::SetWindowLong(hwndChild, GWL_WNDPROC, (LONG)newWndProc));
        }
        else
        {
            break;
        }
    }
}

wstring ExtractYID(wstring YidValue)
{
    wstring retval;
    tr1::wregex URL_RE(L"^\"?ymsgr:SendIM\\?([^);\":,<>]+)\"?$");
    tr1::match_results<wstring::const_iterator> MR;
    if (regex_match(YidValue, MR, URL_RE))
    {
        retval = MR[1];
    }

    return retval;
}

//  TODO:  Should this be moved into another file?
GUIDList GetChannelGUIDs()
{
    HKEY hkUpdateChannel = NULL;
    GUIDList retval;

    LONG error = RegOpenKeyEx(HKEY_LOCAL_MACHINE, CHANNEL_PATH, 0, KEY_READ, &hkUpdateChannel);
    if (ERROR_SUCCESS == error)
    {
        //  Technically, the buffer can be smaller -- GUIDs are fixed length.
        DWORD bufSize = MAX_PATH;
        TCHAR szChannelGUID[MAX_PATH] = {0,};
        DWORD dwIndex = 0;

        while (ERROR_SUCCESS == RegEnumKeyEx(hkUpdateChannel, dwIndex, szChannelGUID, &bufSize, NULL, NULL, NULL, NULL))
        {
            retval.push_back(wstring(CT2CW(szChannelGUID)));
            *szChannelGUID = 0;  bufSize = MAX_PATH;
            ++dwIndex;
        }
    }
    RegCloseKey(hkUpdateChannel);

    return retval;
}

PersistentValues GetPersistentValues()
{
    HKEY hkPersistentStore = NULL;
    PersistentValues retval;

    LONG error = RegOpenKeyEx(HKEY_CURRENT_USER, PERSISTENT_STORE_PATH, 0, KEY_READ, &hkPersistentStore);
    if (ERROR_SUCCESS == error)
    {
        DWORD bufKeySize = MAX_PATH, bufCurrentKeySize = MAX_PATH;
        TCHAR *szKeyName = new TCHAR[MAX_PATH];
        DWORD bufValueSize = INFO_BUFFER_SIZE, bufCurrentValueSize = INFO_BUFFER_SIZE;
        BYTE *szKeyValue = new BYTE[INFO_BUFFER_SIZE];
        DWORD dwIndex = 0;
        DWORD dwType = REG_NONE;

        error = RegEnumValue(hkPersistentStore, dwIndex, szKeyName, &bufKeySize, nullptr, &dwType, szKeyValue, &bufValueSize);
        while (ERROR_SUCCESS == error || ERROR_MORE_DATA == error)
        {
            if(ERROR_MORE_DATA == error)
            {
                if(bufKeySize >= bufCurrentKeySize)
                {
                    delete [] szKeyName;
                    //  Potentially polynomial growth in time.
                    bufCurrentKeySize = bufKeySize + 1;
                    szKeyName = new TCHAR[bufCurrentKeySize];
                }

                if(bufValueSize > bufCurrentValueSize)
                {
                    delete [] szKeyValue;
                    bufCurrentValueSize = bufValueSize;
                    szKeyValue = new BYTE[bufCurrentValueSize];
                }
            }
            else
            {
                if (REG_SZ == dwType)
                {
                    retval[szKeyName] = reinterpret_cast<PTCHAR>(szKeyValue);
                }
                ++dwIndex;
            }
            *szKeyName = 0; bufKeySize = bufCurrentKeySize; 
            *szKeyValue = 0; bufValueSize = bufCurrentValueSize;
            error = RegEnumValue(hkPersistentStore, dwIndex, szKeyName, &bufKeySize, nullptr, &dwType, szKeyValue, &bufValueSize);
        }
        delete [] szKeyName; szKeyName = nullptr;
        delete [] szKeyValue; szKeyValue = nullptr;
    }
    RegCloseKey(hkPersistentStore);

    return retval;
}

PersistentValue GetPersistentValue(wstring key)
{
    HKEY hkPersistentStore = NULL;
    PersistentValue retval;

    LONG error = RegOpenKeyEx(HKEY_CURRENT_USER, PERSISTENT_STORE_PATH, 0, KEY_READ, &hkPersistentStore);
    if (ERROR_SUCCESS == error)
    {
        DWORD dwType = REG_NONE;
        DWORD bufValueSize = 0;
        LPBYTE szKeyValue = nullptr;

        // First get the value size
        if(ERROR_SUCCESS == RegQueryValueEx(hkPersistentStore, key.c_str(), 0, &dwType, NULL, &bufValueSize))
        {
            szKeyValue = new BYTE[bufValueSize];
            if(ERROR_SUCCESS == RegQueryValueEx(hkPersistentStore, key.c_str(), 0, &dwType, szKeyValue, &bufValueSize))
            {
                //  TODO:  Verify value type.
                wstring value = reinterpret_cast<PTCHAR>(szKeyValue);
                retval = make_pair(key, value);
            }
            delete szKeyValue;
            szKeyValue = nullptr;
        }
    }
    RegCloseKey(hkPersistentStore);

    return retval;
}

bool SetPersistentValue(const wstring key, const wstring value)
{
    HKEY hkPersistentStore = NULL;
    bool retval = false;

    LONG error = RegCreateKeyEx(HKEY_CURRENT_USER, PERSISTENT_STORE_PATH, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, NULL, &hkPersistentStore, NULL);
    if (ERROR_SUCCESS == error)
    {
        retval = (ERROR_SUCCESS == RegSetValueEx(
                hkPersistentStore, 
                key.c_str(), 
                0, 
                REG_SZ, 
                reinterpret_cast<const BYTE *>(value.c_str()), 
                static_cast<DWORD>((value.size()+1)*sizeof(TCHAR))
            )
        );
    }
    RegCloseKey(hkPersistentStore);

    return retval;
}

bool DeletePersistentValue(wstring key)
{
    HKEY hkPersistentStore = NULL;
    bool retval = false;

    LONG error = RegOpenKeyEx(HKEY_CURRENT_USER, PERSISTENT_STORE_PATH, 0, KEY_SET_VALUE, &hkPersistentStore);
    if (ERROR_SUCCESS == error)
    {
        retval = (ERROR_SUCCESS == RegDeleteValue(hkPersistentStore, key.c_str()));
    }
    RegCloseKey(hkPersistentStore);

    return retval;
}

//  TODO:  Dynamically size the buffer
wstring GetInstallerStats()
{
    HKEY hKey;
    TCHAR buffer[MAX_STATS_SIZE] = {0,};
    DWORD bufSize = sizeof(buffer);

    if(::RegOpenKeyEx(HKEY_CURRENT_USER, INSTALLER_STATS_PATH, NULL, KEY_QUERY_VALUE | KEY_SET_VALUE, &hKey) == ERROR_SUCCESS)
    {
        DWORD error = RegQueryValueEx(hKey, INSTALLER_STATS_VALUE, NULL, NULL, reinterpret_cast<LPBYTE>(buffer), &bufSize);
        if(ERROR_SUCCESS == error)
        {
            RegDeleteValue(hKey, INSTALLER_STATS_VALUE);
        }
    }
    RegCloseKey(hKey);

    return buffer;
}

wstring GetIPbyName(const wstring& hostname)
{
    wstring retval = hostname;

    ADDRINFOW *result = NULL;
    ADDRINFOW *ptr = NULL;
    ADDRINFOW hints;

    ZeroMemory( &hints, sizeof(hints) );
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    WCHAR ipstringbuffer[46] = {0,};
    DWORD ipbufferlength = sizeof(ipstringbuffer)/sizeof(WCHAR);

    DWORD dwRetval = GetAddrInfoW(hostname.c_str(), L"", &hints, &result);
    if (!dwRetval)
    {
        bool bFound = false;
        LPSOCKADDR sockaddr_ip;

        for(ptr=result; ptr != NULL && !bFound; ptr=ptr->ai_next) {
            ipbufferlength = 46;
            switch (ptr->ai_family) {
                case AF_UNSPEC:
                    break;
                case AF_INET:
                    sockaddr_ip = (LPSOCKADDR) ptr->ai_addr;
                    dwRetval = WSAAddressToString(sockaddr_ip, (DWORD) ptr->ai_addrlen, NULL, 
                        ipstringbuffer, &ipbufferlength );
                    if (!dwRetval)
                    {
                        bFound = true;
                        retval = ipstringbuffer;
                    }
                    break;
                case AF_INET6:
                    sockaddr_ip = (LPSOCKADDR) ptr->ai_addr;
                    dwRetval = WSAAddressToString(sockaddr_ip, (DWORD) ptr->ai_addrlen, NULL, 
                        ipstringbuffer, &ipbufferlength );
                    if (dwRetval)
                    {
                        retval = ipstringbuffer;
                    }
                    break;
                default:
                    break;
            }
        }
    }

    return retval;
}

bool IsValidRequestURL(string url)
{
    bool retval = true;

    if (strncmp("file://", url.c_str(), 7)==0)
    {
        url.erase(0, 7);
        //  Exclude paths with // in them to prevent navigation to long path names and
        //  exclude paths with ':' in them to prevent navigation to absolute paths.
        //  Chromium doesn't seem to allow using relative paths.
        //  TODO:  All of our file:// urls should eventually be handled by a custom
        //  TODO:  scheme handler.
        retval = (url.find("//") == string::npos && url.find(":") == string::npos);
    }

    return retval;
}

bool ShowFolder(string directory, string selected_file)
{
    TCHAR  infoBuf[INFO_BUFFER_SIZE]={0,};

    wstringstream ss;
    if( !GetWindowsDirectory( infoBuf, INFO_BUFFER_SIZE ) )
    {
        TCHAR szAppTitle[INFOTIPSIZE]={0,};
        StringManager.LoadString(IDS_APP_TITLE, szAppTitle, INFOTIPSIZE);

        TCHAR szErrorMessage[INFOTIPSIZE]={0,};
        StringManager.LoadString(IDS_MISSING_WINDOWS_DIRECTORY, szErrorMessage, INFOTIPSIZE);

        MessageBox(NULL, szErrorMessage, szAppTitle, MB_OK|MB_ICONWARNING);
        return false;
    }

    ss << infoBuf << TEXT("\\explorer.exe");
    wstring path = ss.str();
    LPWSTR explorerPath = const_cast<LPWSTR>(path.c_str());

    return (reinterpret_cast<int>(::ShellExecute(NULL, TEXT("open"), explorerPath, CA2CT(("/select," + directory + selected_file).c_str()), NULL, SW_SHOWNORMAL))>32);
}

//  TODO:  Hmmm ... do we want a dependence on CEF types here?
bool ShowFolder2(wstring directory, CefRefPtr<CefListValue> selected_files)
{
    bool retval = false;
    UINT num_files = selected_files->GetSize();
    LPITEMIDLIST pidlFolder = ILCreateFromPath(CW2CT(directory.c_str()));
    LPCITEMIDLIST *apidl = new LPCITEMIDLIST[num_files];

    //  Set up the PIDLs
    if(pidlFolder)
    {
        retval = true;
        for(UINT i=0; i<num_files; ++i)
        {
            TCHAR szPathOut[MAX_PATH] = {0,};

            apidl[i] = ILCreateFromPath(::PathCombine(szPathOut, CW2CT(directory.c_str()), CW2CT(selected_files->GetString(i).ToWString().c_str())));
        }
    }

    SHOpenFolderAndSelectItems(pidlFolder, num_files, apidl, 0);

    //  Free memory
    ILFree(pidlFolder);
    for(UINT i=0; i<num_files; ++i)
    {
        ILFree(const_cast<LPITEMIDLIST>(apidl[i]));
    }
    delete [] apidl;

    return retval;
}

bool IsWindowsVistaOrGreater() 
{
    OSVERSIONINFOEX osvi;
    DWORDLONG dwlConditionMask = 0;
    BYTE op=VER_GREATER_EQUAL;

    // Initialize the OSVERSIONINFOEX structure.

    ZeroMemory(&osvi, sizeof(OSVERSIONINFOEX));
    osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFOEX);
    osvi.dwMajorVersion = 6;
    osvi.dwMinorVersion = 0;
    osvi.wServicePackMajor = 0;
    osvi.wServicePackMinor = 0;

    // Initialize the condition mask.

    VER_SET_CONDITION( dwlConditionMask, VER_MAJORVERSION, op );
    VER_SET_CONDITION( dwlConditionMask, VER_MINORVERSION, op );
    VER_SET_CONDITION( dwlConditionMask, VER_SERVICEPACKMAJOR, op );
    VER_SET_CONDITION( dwlConditionMask, VER_SERVICEPACKMINOR, op );

    return TRUE == VerifyVersionInfo(&osvi, VER_MAJORVERSION | VER_MINORVERSION | 
        VER_SERVICEPACKMAJOR | VER_SERVICEPACKMINOR, dwlConditionMask);
}

wstring GetLastErrorString()
{
    DWORD error = GetLastError();
    if (error)
    {
        LPVOID lpMsgBuf;
        DWORD bufLen = FormatMessage(
            FORMAT_MESSAGE_ALLOCATE_BUFFER | 
            FORMAT_MESSAGE_FROM_SYSTEM |
            FORMAT_MESSAGE_IGNORE_INSERTS,
            NULL,
            error,
            MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
            (LPTSTR) &lpMsgBuf,
            0, NULL );
        if (bufLen)
        {
            LPCWSTR lpMsgStr = (LPCWSTR)lpMsgBuf;
            wstring result(lpMsgStr, lpMsgStr+bufLen);

            LocalFree(lpMsgBuf);

            return result;
        }
    }
    return wstring();
}

int GetWindowBorderSize(HWND hwnd)
{
    ::RECT windowRect, clientRect;
    ::GetWindowRect(hwnd, &windowRect);
    ::GetClientRect(hwnd, &clientRect);

    int size = ( (windowRect.right - windowRect.left) - (clientRect.right - clientRect.left) ) / 2;
    return size;
}