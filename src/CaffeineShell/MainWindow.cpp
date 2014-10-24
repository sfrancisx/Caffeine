//  Copyright Yahoo! Inc. 2013-2014
#define STRICT

#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "CaffeineShell.h"
#include "MainWindow.h"
#include "CaffeineClientApp.h"
#include "CaffeineClientUtils.h"
#include "windowhelpers.h"
#include "JumpList.h"
#include "resource.h"
#include "CaffeineStringManager.h"
#include "CaffeineWindowsMessages.h"

#include <shellapi.h>
#include <Wtsapi32.h>
#include <ctime>
using namespace std;

extern HINSTANCE hInst; 
//  TODO:  app is pretty much useless.  Get rid of it.
extern CefRefPtr<CaffeineClientApp> app;
extern CaffeineStringManager StringManager;

extern string mainUUID;
extern const WPARAM g_exitCode;
extern bool devMode;
bool enableClose = true;

//  TODO:  Get rid of these globals
CefRefPtr<CefBrowser> mainWinBrowser;
HWND mainWindowHandle = 0;
JumpList jumpList;  //  Careful!  This only makes sense on Win7
HMENU hPopMenu;
static CefTime beginMainWindowCreationTime;
//  TODO:  end

//
//  FUNCTION: RegisterMainWindowClass()
//
//  PURPOSE: Registers the window class.
//
//  COMMENTS:
//
//    This function and its usage are only necessary if you want this code
//    to be compatible with Win32 systems prior to the 'RegisterClassEx'
//    function that was added to Windows 95. It is important to call this
//    function so that the application will get 'well formed' small icons
//    associated with it.
//
ATOM RegisterMainWindowClass(HINSTANCE hInstance, PTCHAR szWindowClass) 
{
	WNDCLASSEX wcex;

    wcex.cbSize = sizeof(WNDCLASSEX);

    wcex.style         = CS_HREDRAW | CS_VREDRAW;// | CS_DROPSHADOW;
    wcex.lpfnWndProc   = MainWindowWndProc;
    wcex.cbClsExtra    = 0;
    wcex.cbWndExtra    = sizeof(WindowExtras *);
    wcex.hInstance     = hInstance;
    wcex.hIcon         = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_CAFFEINE));
    wcex.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground = (HBRUSH)(COLOR_WINDOW+1);
    wcex.lpszMenuName  = NULL;
    wcex.lpszClassName = szWindowClass;
    wcex.hIconSm       = LoadIcon(wcex.hInstance, MAKEINTRESOURCE(IDI_CAFFEINE));

    return RegisterClassEx(&wcex);
}

//
//   FUNCTION: InitMainWindowInstance(HINSTANCE, int)
//
//   PURPOSE: Saves instance handle and creates main window
//
//   COMMENTS:
//
//        In this function, we save the instance handle in a global variable and
//        create and display the main program window.
//
HWND InitMainWindowInstance(
    HINSTANCE hInstance, 
    int nCmdShow, 
    PTCHAR szWindowClass, 
    PTCHAR szTitle) 
{
    hInst = hInstance;  // Store instance handle in our global variable

    beginMainWindowCreationTime.Now();

    //  Should make window size be data driven
    mainWindowHandle = CreateWindowEx(WS_EX_OVERLAPPEDWINDOW | WS_EX_CLIENTEDGE,
                                    szWindowClass, szTitle,
                                    WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN,
                                    CW_USEDEFAULT, CW_USEDEFAULT,
                                    //        WS_POPUP, CW_USEDEFAULT, 0,
                                    DEFAULT_WIN_WIDTH, DEFAULT_WIN_HEIGHT,
                                    NULL, NULL,
                                    hInstance, NULL);

    if (mainWindowHandle)
    {
        if (!devMode)
        {
            jumpList.SetUpJumpList(hInst);
        }
    }

    return mainWindowHandle;
}

//
//  FUNCTION: MainWindowWndProc(HWND, UINT, WPARAM, LPARAM)
//
//  PURPOSE:  Processes messages for the main window.
//
LRESULT CALLBACK MainWindowWndProc(
    HWND hWnd, 
    UINT message, 
    WPARAM wParam,
    LPARAM lParam) 
{
    PAINTSTRUCT ps;
    HDC hdc;
    HMENU sysMenu;

    // Callback for the main window
    switch (message) 
    {
        case WM_CREATE: 
        {
            DWORD bufferSize = 65535;
            wstring buff;
            buff.resize(bufferSize);
            bufferSize = ::GetEnvironmentVariable(L"lala", &buff[0], bufferSize);

            if (bufferSize)
            {
                buff.resize(bufferSize);
                SetEnvironmentVariable(L"lala", NULL);
            }

            // Add exit option to system menu
            TCHAR szDescription[INFOTIPSIZE];
            StringManager.LoadString(IDS_EXIT_CAFFEINE, szDescription, INFOTIPSIZE);

            sysMenu = GetSystemMenu(hWnd, FALSE);
            InsertMenu(sysMenu, 2, MF_SEPARATOR, 0, L"-");
            AppendMenu(sysMenu, MF_STRING, IDS_EXIT_CAFFEINE, szDescription);

            WTSRegisterSessionNotification(hWnd, NOTIFY_FOR_THIS_SESSION);
            app->m_WindowHandler[mainUUID] = new CaffeineClientHandler();
            app->m_WindowHandler[mainUUID]->SetMainHwnd(hWnd);

            // Create the child windows used for navigation
            RECT rect;

            GetClientRect(hWnd, &rect);

            CefWindowInfo info;
            CefBrowserSettings browser_settings;
            browser_settings.universal_access_from_file_urls = STATE_ENABLED;
//            browser_settings.file_access_from_file_urls = STATE_ENABLED;
            browser_settings.web_security = STATE_DISABLED;
            browser_settings.local_storage = STATE_ENABLED;
            browser_settings.application_cache = STATE_DISABLED;
            browser_settings.javascript_open_windows = STATE_DISABLED;
//            browser_settings.accelerated_compositing = STATE_DISABLED;
            
            // Initialize window info to the defaults for a child window
            info.SetAsChild(hWnd, rect);

            // Create the new child browser window
            wstring URL(L"file:///stub.html?" + AppGetCommandLine()->GetSwitchValue("querystring").ToWString());
            if (AppGetCommandLine()->HasSwitch("yid"))
            {
                URL += L"&yid=" + ExtractYID(AppGetCommandLine()->GetSwitchValue("yid").ToWString());
            }
            //  TODO:  Can we just use the same window handler (assuming we get rid of the globals and add some sync)?
            CefRefPtr<CefBrowser> browser = CefBrowserHost::CreateBrowserSync(info, app->m_WindowHandler[mainUUID].get(), URL, browser_settings, NULL);
            app->m_WindowHandler[mainUUID]->m_MainBrowser = browser;
            mainWinBrowser = browser;

            app->hwndRender = hWnd; // setup current handle to use in Show/HideWindow
        
            CefRefPtr<CefProcessMessage> process_message = CefProcessMessage::Create("setHandle");
            process_message->GetArgumentList()->SetInt(0, reinterpret_cast<int>(hWnd));
            browser->SendProcessMessage(PID_RENDERER, process_message);

            // Send the main window creation start time to the renderer
            process_message = CefProcessMessage::Create("mainWindowCreationTime");
            CefRefPtr<CefBinaryValue> startTime = CefBinaryValue::Create(&beginMainWindowCreationTime, sizeof(CefTime));
            process_message->GetArgumentList()->SetBinary(0, startTime);
            browser->SendProcessMessage(PID_RENDERER, process_message);

            if (bufferSize)
            {
                process_message = CefProcessMessage::Create("lala");
                process_message->GetArgumentList()->SetString(0, buff);
                browser->SendProcessMessage(PID_RENDERER, process_message);
            }

            SetWindowLongPtr(hWnd, 0, reinterpret_cast<LONG_PTR>(new WindowExtras));

            SetTimer(hWnd, IDLETIMER, IdleTimerPollIntervalMS, NULL);
            SetTimer(hWnd, NETWORKTIMER, NetworkTimerPollIntervalMS, NULL);

            return 0;
        }

        case WM_MOVE:
            if (app->m_WindowHandler[mainUUID].get())
            {
                //  TODO:  Below is a hack to work around the fact that CEF isn't updating screenX and screenY.  Periodically,
                //  TODO:  check to see if they fix it.  
                //  TODO:  See issue https://code.google.com/p/chromiumembedded/issues/detail?id=1303&thanks=1303&ts=1402082749
                WINDOWINFO wi = {sizeof(WINDOWINFO), 0};
                GetWindowInfo(hWnd, &wi);
                RECT rClient = wi.rcWindow;

                CefString JS = "window.screenLeft = window.screenX = " + to_string(_Longlong(rClient.left)) + "; window.screenTop = window.screenY = " + 
                    to_string(_Longlong(rClient.top)) + ";";
                CefRefPtr<CefFrame> frame = app->m_WindowHandler[mainUUID]->GetBrowser()->GetMainFrame();
                frame->ExecuteJavaScript(JS, frame->GetURL(), 0);

                //  TODO:  Another workaround.  For whatever reason, the window positions get updated when the size changes,
                //  TODO:  but not when the window is moved.
                CefWindowHandle hwnd = app->m_WindowHandler[mainUUID]->GetBrowser()->GetHost()->GetWindowHandle();
                if (hwnd) 
                {
                    wi.cbSize = sizeof(WINDOWINFO);
                    GetWindowInfo(hwnd, &wi);
                    RECT rWindow = wi.rcWindow;

                    MoveWindow(hwnd, 0, 0, rWindow.right - rWindow.left, rWindow.bottom - rWindow.top + 1, FALSE);
                    MoveWindow(hwnd, 0, 0, rWindow.right - rWindow.left, rWindow.bottom - rWindow.top, FALSE);
                }

                app->m_WindowHandler[mainUUID]->CreateAndDispatchCustomEvent("move");
            }

            break;

        case WM_POWERBROADCAST:
            if (app->m_WindowHandler[mainUUID].get())
            {
                if (wParam == PBT_APMRESUMEAUTOMATIC || wParam == PBT_APMSUSPEND)
                {
                    app->m_WindowHandler[mainUUID]->CreateAndDispatchCustomEvent(wParam == PBT_APMSUSPEND? "suspend" : "resume");
                    //  Do we really need a return value?
                    return TRUE;
                }
            }
            break;

        case WM_WTSSESSION_CHANGE:
            if (app->m_WindowHandler[mainUUID].get())
            {
                string eventName;

                switch(wParam)
                {
                    //  Used
                    case WTS_SESSION_LOGON:
                        eventName = "os:logon";
                        break;
                    //  Used
                    case WTS_SESSION_LOGOFF:
                        eventName = "os:logoff";
                        break;
                    //  Used
                    case WTS_SESSION_LOCK:
                        eventName = "os:locked";
                        break;
                    //  Used
                    case WTS_SESSION_UNLOCK:
                        eventName = "os:unlocked";
                        break;
                }

                app->m_WindowHandler[mainUUID]->CreateAndDispatchCustomEvent(eventName);
            }
            break;

        case WM_PAINT:
            {
                //RECT cr = {0,};
                //::GetClientRect(hWnd, &cr);
                //::InvalidateRect(hWnd, &cr, FALSE);
                hdc = BeginPaint(hWnd, &ps);
                EndPaint(hWnd, &ps);
                return 0;
            }

        case WM_ACTIVATE:
            if (app->m_WindowHandler[mainUUID].get() && app->m_WindowHandler[mainUUID]->GetBrowser()) 
            {
                app->m_WindowHandler[mainUUID]->CreateAndDispatchCustomEvent((LOWORD(wParam)>0)? "activated" : "deactivated");
            }
            break;
        case WM_SETFOCUS:
            if (app->m_WindowHandler[mainUUID].get() && app->m_WindowHandler[mainUUID]->GetBrowser()) 
            {
                // Pass focus to the browser window
                CefWindowHandle hwnd = app->m_WindowHandler[mainUUID]->GetBrowser()->GetHost()->GetWindowHandle();
                if (hwnd) PostMessage(hwnd, message, wParam, lParam);
            }
            return 0;

        case WM_SIZE:
            // Minimizing resizes the window to 0x0 which causes our layout to go all
            // screwy, so we just ignore it.
            if (wParam != SIZE_MINIMIZED && app->m_WindowHandler[mainUUID].get() && 
                app->m_WindowHandler[mainUUID]->GetBrowser()) 
            {
                    CefWindowHandle hwnd = app->m_WindowHandler[mainUUID]->GetBrowser()->GetHost()->GetWindowHandle();
                    if (hwnd) 
                    {
                        //  This will send a WM_SIZE and WM_PAINT message to the render process
                        SetWindowPos(hwnd, NULL, 0, 0, LOWORD(lParam), HIWORD(lParam), SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOZORDER); 
                        return 0;
                    }
            }
            break;

        case WM_ERASEBKGND:
            if (app->m_WindowHandler[mainUUID].get() && app->m_WindowHandler[mainUUID]->GetBrowser()) {
                CefWindowHandle hwnd =
                    app->m_WindowHandler[mainUUID]->GetBrowser()->GetHost()->GetWindowHandle();
                if (hwnd) {
                    // Dont erase the background if the browser window has been loaded
                    // (this avoids flashing)
                    return 0;
                }
            }
            break;

        case WM_SYSCOMMAND:
            if (wParam == IDS_EXIT_CAFFEINE) {
                PostMessage(hWnd, WM_CLOSE, g_exitCode, 0);
                return 0;
            }
            break;

        case WM_COMMAND:
            // Currently only option from the context menu is to exit, hence the fall through to the WM_CLOSE
            wParam = g_exitCode;

        case WM_CLOSE:
        {
            if (devMode || enableClose)
            {
                wParam = g_exitCode;
            }

            CefRefPtr<CaffeineClientHandler> handler = app->m_WindowHandler[mainUUID].get();

            if (handler && !handler->IsClosing()) {
                if (wParam == g_exitCode) // Jump list exit
                {
                    for (map<string, CefRefPtr<CaffeineClientHandler> >::iterator it=app->m_WindowHandler.begin(); it!=app->m_WindowHandler.end(); ++it)
                    {
                        if(it->second.get()) 
                        {
                            CefRefPtr<CefBrowser> browser = it->second->GetBrowser();
                            browser->GetHost()->CloseBrowser(false);
                        }
                    }

					//CefRefPtr<CefBrowser> browser = handler->GetBrowser();
					//if (browser.get()) {
					//	browser->GetHost()->CloseBrowser(false);
					//}
				} else {
                    ShowWindow(hWnd, SW_MINIMIZE);
                }
                return 0;
            }

            break;
        }

        case WM_TIMER:
        {
            if(IDLETIMER == wParam)
            {
                //  TODO:  Check timer id
                LASTINPUTINFO lif = {sizeof(LASTINPUTINFO), 0};
                GetLastInputInfo(&lif);
                UINT IdleTimePassed = GetTickCount() - lif.dwTime;
                
                WindowExtras *pWE = reinterpret_cast<WindowExtras *>(::GetWindowLongPtr(hWnd, 0));
                bool CurrentlyIdle = (pWE->IdleTimeThreshold < IdleTimePassed);
                if(CurrentlyIdle != pWE->IsIdle)
                {
                    const CefString EventName = (CurrentlyIdle? "startIdle" : "stopIdle");
                    pWE->IsIdle = CurrentlyIdle;
                    app->m_WindowHandler[mainUUID]->CreateAndDispatchCustomEvent(EventName);
                }
            }
            //  TODO:  When we drop XP support, we can use COM and get network connectivity events.
            else if(NETWORKTIMER == wParam)
            {
                WindowExtras *pWE = reinterpret_cast<WindowExtras *>(::GetWindowLongPtr(hWnd, 0));
                bool CurrentlyConnected = pWE->NetworkAvailable();
                if(CurrentlyConnected != pWE->IsConnected)
                {
                    const CefString EventName = (CurrentlyConnected? "os:online" : "os:offline");
                    pWE->IsConnected = CurrentlyConnected;
                    app->m_WindowHandler[mainUUID]->CreateAndDispatchCustomEvent(EventName);
                }
            }
            break;
        }

        case WM_DESTROY:
        {
            WTSUnRegisterSessionNotification(hWnd);
            // The frame window has exited

            if (!devMode)
            {
                jumpList.RemoveAllTasks();
            }

            KillTimer(hWnd, IDLETIMER);
            KillTimer(hWnd, NETWORKTIMER);
            WindowExtras *pWE = reinterpret_cast<WindowExtras *>(::GetWindowLongPtr(hWnd, 0));
            delete pWE;
            SetWindowLongPtr(hWnd, 0, 0);
            SetShutdownFlag(true);
            PostQuitMessage(0);
            return 0;
        }

        case WM_GETMINMAXINFO:
        {
            LPMINMAXINFO minmaxInfoPtr = (LPMINMAXINFO) lParam;
            minmaxInfoPtr->ptMinTrackSize.x = MAIN_WINDOW_MIN_WIN_WIDTH;
            minmaxInfoPtr->ptMinTrackSize.y = MAIN_WINDOW_MIN_WIN_HEIGHT;

            // Keep the width the same
            RECT rect;
            GetWindowRect(hWnd, &rect);
            minmaxInfoPtr->ptMaxSize.x = (rect.right - rect.left);

            // Keep window at same position
            minmaxInfoPtr->ptMaxPosition.x = rect.left;
            minmaxInfoPtr->ptMaxPosition.y = 0;

            SystemParametersInfo( SPI_GETWORKAREA, 0, &rect, 0 );
            minmaxInfoPtr->ptMaxSize.y = (rect.bottom - rect.top);

            return 0;
        }

        case WM_COPYDATA:
        {
            BOOL retval = FALSE;
            PCOPYDATASTRUCT pCds = reinterpret_cast<PCOPYDATASTRUCT>(lParam);
            if (pCds->dwData == WM_PENDING_YID) 
            {
                if (app->m_WindowHandler[mainUUID].get() && app->m_WindowHandler[mainUUID]->GetBrowser()) 
                {
                    CefRefPtr<CefFrame> frame = app->m_WindowHandler[mainUUID]->GetBrowser()->GetMainFrame();
                    wstring code = L"Caffeine.pendingYIDs.push(\"";
                    //  TODO:  Escape this ... otherwise there's an XSS
                    code += static_cast<LPWSTR>(pCds->lpData);
                    code += L"\");";
                    frame->ExecuteJavaScript(code, frame->GetURL(), 0);
                }

                retval = TRUE;
            }
            return retval;
        }

        case CAFFEINE_SOCKETS_MSG:
            CefRefPtr<CefProcessMessage> process_message = CefProcessMessage::Create("invokeSocketMethod");
            process_message->GetArgumentList()->SetInt(0, wParam);
            if (WSAGETSELECTERROR(lParam))
            {
                process_message->GetArgumentList()->SetString(1, "error");
                process_message->GetArgumentList()->SetInt(2, WSAGETSELECTERROR(lParam));
            }
            else
            {
                //  No error
                switch(WSAGETSELECTEVENT(lParam))
                {
                    case FD_CONNECT:
                        process_message->GetArgumentList()->SetString(1, "connect");
                        break;
                    case FD_CLOSE:
                        process_message->GetArgumentList()->SetString(1, "close");
                        break;
                    case FD_READ:
                        process_message->GetArgumentList()->SetString(1, "read");
                        break;
                    case FD_WRITE:
                        process_message->GetArgumentList()->SetString(1, "write");
                        break;
                }
            }
            mainWinBrowser->SendProcessMessage(PID_RENDERER, process_message);
            break;
    }

    return DefWindowProc(hWnd, message, wParam, lParam);
}
