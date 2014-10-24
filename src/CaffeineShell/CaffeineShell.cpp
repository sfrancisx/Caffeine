//  Copyright Yahoo! Inc. 2013-2014
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "defines.h"

#include <fstream>
#include <regex>
#include <string>

#include "CaffeineShell.h"
#include "MainWindow.h"
#include "RemoteWindow.h"
#include "ToastWindow.h"
#include "CaffeineClientApp.h"
#include "CaffeineClientUtils.h"
#include "CaffeineStringManager.h"
#include <windows.h>
#include <commdlg.h>
#include <shellapi.h>
#include <Shlobj.h>
#include <Shlwapi.h>
#include <direct.h>
#include <sstream>
#include <string>
#include <atlbase.h>
#include "include/cef_base.h"
#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "include/cef_runnable.h"
#include "CaffeineClientHandler.h"
#include "CrashRpt.h"
#include "resource.h"

#include <openssl/ssl.h>

using namespace std;

// Global Variables:
HINSTANCE hInst;   // current instance
CaffeineStringManager StringManager;
TCHAR szWindowTitle[MAX_LOADSTRING];  // The title bar text
CaffeineSettings CaffeineSettings;

char szWorkingDir[MAX_PATH];  // The current working directory
LPCTSTR g_szAppIDForTaskBar = L"Caffeine.Caffeine.Shell.1.0.0.0";

// Forward declarations of functions included in this code module:
CefRefPtr<CaffeineClientApp> app(new CaffeineClientApp);

extern const WPARAM g_exitCode = IDI_CAFFEINE;
bool devMode = false;
#define INFO_BUFFER_SIZE (8192)

#if defined(OS_WIN)
// Add Common Controls to the application manifest because it's required to
// support the default tooltip implementation.
#pragma comment(linker, "/manifestdependency:\"type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")  // NOLINT(whitespace/line_length)
#endif

/*
 * Post a message that will cause the application to exit
 */
void PostExitMessage()
{
    HWND mainWindow = FindWindow(TEXT("EmbeddedCEFClientMainWindow"), NULL);

    if (mainWindow ) 
    {
        PostMessage(mainWindow, WM_CLOSE, g_exitCode, 0);	
    }
}

/*
 * This function is needed because SetCurrentProcessExplicitAppUserModelID is only available in Win7 and beyond
 */
void SetAppID()
{
    TCHAR infoBuf[INFO_BUFFER_SIZE] = {0,};
    wstringstream ss;
    if(!GetSystemDirectory(infoBuf, INFO_BUFFER_SIZE))
    {
        TCHAR szErrorMessage[INFOTIPSIZE];
        StringManager.LoadString(IDS_MISSING_SYSTEM_DIRECTORY, szErrorMessage, INFOTIPSIZE);
        MessageBox(NULL, szErrorMessage, szWindowTitle, MB_OK|MB_ICONWARNING);
        PostExitMessage();
        return;
    }

    //  TODO:  Use the system standard functions for this.
    ss << infoBuf << TEXT("\\shell32.dll");
    wstring path = ss.str();
    LPWSTR shell32Path = const_cast<LPWSTR>(path.c_str());

    // Set AppID for this process
    // According to MSDN, this SetCurrentProcessExplicitAppUserModelID must be called before any UI operation in this process.
    HMODULE hShell32 = LoadLibrary (shell32Path);

    if (hShell32)
    {
        typedef HRESULT (WINAPI *PFNSetCurrentProcessExplicitAppUserModelID)(PCWSTR AppID);

        PFNSetCurrentProcessExplicitAppUserModelID fnSetCurrentProcessExplicitAppUserModelID;
        fnSetCurrentProcessExplicitAppUserModelID = (PFNSetCurrentProcessExplicitAppUserModelID)GetProcAddress(hShell32, "SetCurrentProcessExplicitAppUserModelID" );
        if ( fnSetCurrentProcessExplicitAppUserModelID )
        {
            fnSetCurrentProcessExplicitAppUserModelID ( g_szAppIDForTaskBar );
        }
        FreeLibrary(hShell32);
    } 
    else
    {
        StringManager.LoadString(IDS_MISSING_SHELL32, infoBuf, INFOTIPSIZE);
        MessageBox(NULL, infoBuf, szWindowTitle, MB_OK|MB_ICONWARNING);
        PostExitMessage();
    }
}

bool SendPendingYID()
{
    bool bRetVal = false;

    if (AppGetCommandLine()->HasSwitch("yid"))
    {
        HANDLE hSem = getCaffeineSemaphore();
        wstring yid = ExtractYID(AppGetCommandLine()->GetSwitchValue("yid").ToWString());

        //  Send the yid to the running instance
        if (::WaitForSingleObject(hSem, 0) == WAIT_TIMEOUT) 
        {
            HWND MainWindow = FindWindow(TEXT("EmbeddedCEFClientMainWindow"), NULL);
            if (MainWindow ) 
            {
                COPYDATASTRUCT cds = {0,};
                cds.dwData = WM_PENDING_YID;
                cds.cbData = sizeof(CefString::char_type)*(yid.size()+1);
                cds.lpData = reinterpret_cast<PVOID>(const_cast<CefString::char_type *>(yid.c_str()));
                SendMessage(MainWindow, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(reinterpret_cast<PVOID>(&cds)));
                bRetVal = true;
            }
        }
        else
        {
            ReleaseSemaphore(hSem, 1, NULL);
        }
    }

    return bRetVal;
}

/*
 * Change the current working directory if the cwd command line option is applied
 */
void ChangeCurrentWorkingDirectory()
{
    if (AppGetCommandLine()->HasSwitch("cwd"))
    {
        _chdir(AppGetCommandLine()->GetSwitchValue("cwd").ToString().c_str());
    }
}

void DeleteDebugLogs()
{
    WCHAR szTemp[MAX_PATH] = {0,};
    wcsncpy(szTemp, (CaffeineSettings.user_dir + L"\\debug*.log").c_str(), MAX_PATH-2);
    SHFILEOPSTRUCT sfop = {
        NULL, 
        FO_DELETE, 
        szTemp,
        NULL,
        FOF_ALLOWUNDO | FOF_FILESONLY | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_NORECURSION | FOF_SILENT,
        FALSE,
        NULL,
        NULL
    };
    SHFileOperation(&sfop);
}

//  TODO:  Mark as throw()?
bool SetShutdownFlag(bool bClear)
{
    CRegKey crk;
    bool retval = false;

    if(ERROR_SUCCESS == crk.Create(HKEY_CURRENT_USER, SHUTDOWN_KEY_PATH, REG_NONE, REG_OPTION_NON_VOLATILE, KEY_WRITE))
    {
        retval = (ERROR_SUCCESS == crk.SetDWORDValue(SHUTDOWN_KEY_VALUE, (bClear? 0 : 1)));
    }

    return retval;
}

//  This will be wrong on first launch.
bool ImproperShutdownHappened()
{
    CRegKey crk;
    bool retval = true;

    if(ERROR_SUCCESS == crk.Create(HKEY_CURRENT_USER, SHUTDOWN_KEY_PATH, REG_NONE, REG_OPTION_NON_VOLATILE, KEY_READ))
    {
        DWORD dwValue = 0;
        LONG hr = crk.QueryDWORDValue(SHUTDOWN_KEY_VALUE, dwValue);
        if(ERROR_SUCCESS == hr)
        {
            retval = !!dwValue;
        }
    }

    return retval;
}

bool DebugLogHasErrors()
{
    ifstream debug_log(CaffeineSettings.debug_log);
    string line;
    regex RE(DEBUG_LOG_REGEX);

    while(getline(debug_log, line))
    {
        if(regex_search(line, RE))
        {
            return true;
        }
    }

    return false;
}

bool CacheTooBig()
{
    bool retval = false;

    return retval;
}

bool ShellHasCorruptCache()
{
    return DebugLogHasErrors() || ImproperShutdownHappened() || CacheTooBig();
}

bool HandleCache()
{
    bool retval = true;

    if(ShellHasCorruptCache())
    {
        WCHAR szTemp[MAX_PATH] = {0,};
        wcsncpy(szTemp, CaffeineSettings.app_cache_dir.c_str(), MAX_PATH-2);
        SHFILEOPSTRUCT sfop = {
            NULL, 
            FO_DELETE, 
            szTemp,
            NULL,
            FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_SILENT,
            FALSE,
            NULL,
            NULL
        };
        retval = (0 == SHFileOperation(&sfop));
    }

    return retval;
}

/*
 * Set the app working directory
 */
void SetAppWorkingDirectory()
{
    if (::_getcwd(szWorkingDir, MAX_PATH) == NULL)
    {
        szWorkingDir[0] = 0;
    }
}

/*
 * Create a semaphore for the app to avoid multiple launches
 */
HANDLE getCaffeineSemaphore()
{
    return CreateSemaphore(NULL, 1, 1, L"CaFfEiNesEmApHoRe#$%^&*!~");
}

bool InitializeNetworking()
{
    bool retval = false;

    WSADATA wsaData;
    if(!::WSAStartup(MAKEWORD(2, 2), &wsaData))
    {
        CRYPTO_malloc_init(); // Initialize malloc, free, etc for OpenSSL's use
        SSL_library_init(); // Initialize OpenSSL's SSL libraries
        SSL_load_error_strings(); // Load SSL error strings
        ERR_load_BIO_strings(); // Load BIO error strings
        OpenSSL_add_all_algorithms(); // Load all available encryption algorithms

        retval = true;
    }

    return retval;
}

bool InitializeCrashReporting(wstring AppName, wstring Version)
{
    // Install crash reporting
    CR_INSTALL_INFO info = {0,};
    info.cb = sizeof(CR_INSTALL_INFO);  
    info.pszAppName = AppName.c_str(); // Define application name.
    info.pszAppVersion = Version.c_str(); // Define application version.
    info.dwFlags = CR_INST_DONT_SEND_REPORT | CR_INST_ALL_POSSIBLE_HANDLERS | CR_INST_NO_GUI | CR_INST_STORE_ZIP_ARCHIVES;

    int nResult = crInstall(&info);
    //  If nResult !=0 then there was a problem installing the errror reporting, but we don't fail the 
    //  rest of the program execution ...

    //  Add reg key
    crAddRegKey(UPDATE_KEY_PATH, L"install_regkey.xml", 0);
    crAddRegKey(PERSISTENT_STORE_PATH, L"persist_regkey.xml", 0);

    return !!nResult;
}

/*
 * Program entry point function.
 */
#pragma warning(disable:4189)  //  For nResult
int APIENTRY wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    UNREFERENCED_PARAMETER(hPrevInstance);
    UNREFERENCED_PARAMETER(lpCmdLine);

#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
    _CrtSetDbgFlag ( _CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF );
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG
    InitializeCrashReporting(FULL_PRODUCT, _T("1.0.0"));

    // Needed to initialize command line options like --exit, --dev, --cwd that are used below
    AppInitCommandLine(0, NULL);

    // Handle exit application option
    if (AppGetCommandLine()->HasSwitch("exit"))
    {
        PostExitMessage();
        return 0;
    }

    bool restart = false;
    HANDLE hSem = NULL;
    if (AppGetCommandLine()->HasSwitch("restart"))
    {
        hSem = getCaffeineSemaphore();
        PostExitMessage();

        WaitForSingleObject(hSem, INFINITE);
        ReleaseSemaphore(hSem, 1, NULL);
        CloseHandle(hSem);

        restart = true;
    }

    ChangeCurrentWorkingDirectory();
    SetAppWorkingDirectory();
    StringManager.SetHInstance(hInstance);

    // Initialize global strings
    StringManager.LoadString(IDS_APP_TITLE, szWindowTitle, MAX_LOADSTRING);	

    RegisterMainWindowClass(hInstance, TEXT("EmbeddedCEFClientMainWindow"));
    RegisterRemoteWindowClass(hInstance, TEXT("EmbeddedCEFClientRemoteWindow"));
    RegisterToastWindowClass(hInstance, TEXT("EmbeddedCEFClientToastWindow"));

    CefMainArgs main_args(hInstance);

    CefSettings base_settings;
    base_settings.no_sandbox = 1;
    base_settings.windowless_rendering_enabled = 0;
    //  base_settings.single_process = 1;
    GUIDList InstalledChannels = GetChannelGUIDs();
    if (find(InstalledChannels.begin(), InstalledChannels.end(), L"{FF81D7B2-1FBF-4095-9B03-F6CE4968DE04}") != InstalledChannels.end() ||
        find(InstalledChannels.begin(), InstalledChannels.end(), L"{A6A0F15A-817A-4342-9650-2436BC6B1732}") != InstalledChannels.end())
    {
        base_settings.remote_debugging_port = 6747;
    }

    CreateDirectory(CaffeineSettings.app_cache_dir.c_str(), NULL);
    cef_string_set(CaffeineSettings.app_cache_dir.c_str(), CaffeineSettings.app_cache_dir.size(), &(base_settings.cache_path), true);
  
    hSem = getCaffeineSemaphore();

    //  TODO:  Since the debug log includes the PID as part of its name, it will need to be cleaned up or 
    //  TODO:  otherwise handled upon exit.
    cef_string_set(CaffeineSettings.debug_log.c_str(), CaffeineSettings.debug_log.size(), &(base_settings.log_file), true);

    if (!AppGetCommandLine()->HasSwitch("verbose"))
    {
        base_settings.log_severity = LOGSEVERITY_ERROR;
    }

    //  If we're the first instance
    if (::WaitForSingleObject(hSem, 0) != WAIT_TIMEOUT)         
    {
        HandleCache();
        SetShutdownFlag(false);
        BackupFile(CaffeineSettings.debug_log);
        //  Clean up the debug logs.
//        DeleteDebugLogs();

        ReleaseSemaphore(hSem, 1, NULL);
    }

    crAddFile2(CaffeineSettings.console_log.c_str(), NULL, NULL, CR_AF_MISSING_FILE_OK | CR_AF_MAKE_FILE_COPY);
    crAddFile2((CaffeineSettings.console_log + L".bak").c_str(), NULL, NULL, CR_AF_MISSING_FILE_OK | CR_AF_MAKE_FILE_COPY);

    crAddFile2(CaffeineSettings.debug_log.c_str(), NULL, NULL, CR_AF_MISSING_FILE_OK | CR_AF_MAKE_FILE_COPY);
    crAddFile2((CaffeineSettings.debug_log + L".bak").c_str(), NULL, NULL, CR_AF_MISSING_FILE_OK | CR_AF_MAKE_FILE_COPY);

    //  TODO:  Check the return value
    InitializeNetworking();

    cef_string_set(USER_AGENT, wcslen(USER_AGENT), &(base_settings.user_agent), true);
    
    SetAppID();

    // Execute the secondary process, if any.
    int exit_code = CefExecuteProcess(main_args, app.get(), NULL);
    if (exit_code >= 0)
    {
        return exit_code;
    }

    //  Set dev command line option that disables jump list and restores windows close functionality
    if (AppGetCommandLine()->HasSwitch("dev"))
    {
        devMode = true;
    }

    SendPendingYID();
    if (!devMode && !restart)
    {
        // Limit no more than one instance of caffeine to run
        hSem = getCaffeineSemaphore();
        HWND hwndMainWindow = FindWindow(TEXT("EmbeddedCEFClientMainWindow"), NULL);

        if(hwndMainWindow)
        {
            SetForegroundWindow(hwndMainWindow);
            return 0;
        }
        //  TODO:  Get rid of the magic number.  The JS gives the app 5s to shutdown.
        //  TODO:  We triple that just to be safe.  We should consider the idea that 
        //  TODO:  the JS let's the shell know when it's shutting down.
        else if(::WaitForSingleObject(hSem, 15000) == WAIT_TIMEOUT)
        {
            hwndMainWindow = FindWindow(TEXT("EmbeddedCEFClientMainWindow"), NULL);
            if(hwndMainWindow)
            {
                SetForegroundWindow(hwndMainWindow);
            }
            return 0;
        }
    }

    // Initialize CEF.  Has to happen after CefExecuteProcess.
    CefInitialize(main_args, base_settings, app.get(), NULL);

    // Perform application initialization
    if (!InitMainWindowInstance(hInstance, nCmdShow, TEXT("EmbeddedCEFClientMainWindow"), szWindowTitle))
        return FALSE;

    // Run the CEF message loop. This function will block until the application
    // recieves a WM_QUIT message.
    CefRunMessageLoop();

    // Shut down CEF.
    CefShutdown();

    // Before shutdown
    if(hSem)
    {
        ReleaseSemaphore(hSem, 1, NULL);
        CloseHandle(hSem);
    }

    WSACleanup();

    // Uninstall crash reporting
    crUninstall();

    return 0;
}
#pragma warning(default:4189)  //  For nResult

// Global functions
string AppGetWorkingDirectory() {
    return szWorkingDir;
}
