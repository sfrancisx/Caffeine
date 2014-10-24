//  Copyright Yahoo! Inc. 2013-2014
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include <string>
#include "RemoteWindow.h"
#include "windowhelpers.h"
#include "CaffeineClientApp.h"
#include "CaffeineClientUtils.h"
#include "CaffeineWindowsMessages.h"
#include "resource.h"

#include <WindowsX.h>
#include <Wtsapi32.h>

using namespace std;

extern HINSTANCE hInst; 
extern CefRefPtr<CaffeineClientApp> app;

//
//  FUNCTION: RegisterRemoteWindowClass()
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
ATOM RegisterRemoteWindowClass(HINSTANCE hInstance, PTCHAR szWindowClass) {
    WNDCLASSEX wcex;

    wcex.cbSize = sizeof(WNDCLASSEX);

    wcex.style         = CS_HREDRAW | CS_VREDRAW;// | CS_DROPSHADOW;
    wcex.lpfnWndProc   = RemoteWindowWndProc;
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
//   FUNCTION: InitRemoteWindowInstance(HINSTANCE, int)
//
//   PURPOSE: Saves instance handle and creates main window
//
//   COMMENTS:
//
//        In this function, we save the instance handle in a global variable and
//        create and display the main program window.
//
HWND InitRemoteWindowInstance(
    HINSTANCE hInstance, 
    int nCmdShow, 
    PTCHAR szWindowClass, 
    PTCHAR szTitle, 
    string::const_pointer pUUID,
    int clientheight,
    int clientwidth,
    int clientleft,
    int clienttop,
    string::const_pointer pInitArg, 
    bool bCreateFrameless,
    bool isResizable,
    int minWidth,
    int minHeight)
{
    DWORD dwStyle = (bCreateFrameless? WS_POPUP : WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN);

    if (!isResizable)
    {
        dwStyle &= ~WS_THICKFRAME;
		dwStyle &= ~WS_MAXIMIZEBOX;
    }

    DWORD extendedStyle = WS_EX_OVERLAPPEDWINDOW|WS_EX_CLIENTEDGE;
    RECT rectClient = {0, 0, clientwidth, clientheight};
    //  The coordinates passed in are for the client area.
    AdjustWindowRectEx(&rectClient, dwStyle, FALSE, extendedStyle);

    RECT screenCoords = {clientleft, clienttop, clientleft+(rectClient.right-rectClient.left), clienttop+(rectClient.bottom-rectClient.top)};
    NormalizeScreenCoordinates(screenCoords);
    
    remoteWinID args;
    args.uuid = const_cast<string::pointer>(pUUID);
    args.initArg = const_cast<string::pointer>(pInitArg);
    args.minWidth = minWidth;
    args.minHeight = minHeight;

    HWND hWnd = CreateWindowEx(extendedStyle,
                               szWindowClass, szTitle,
                               dwStyle,
                               screenCoords.left, screenCoords.top,
                               (screenCoords.right-screenCoords.left), (screenCoords.bottom-screenCoords.top),
                               NULL, NULL, hInstance,
                               reinterpret_cast<LPVOID>(&args));

    if (hWnd) 
    {
        ShowWindow(hWnd, SW_HIDE);
//        SetActiveWindow(mainWindowHandle);
//        UpdateWindow(hWnd);
    }

    return hWnd;
}

//
//  FUNCTION: RemoteWindowWndProc(HWND, UINT, WPARAM, LPARAM)
//
//  PURPOSE:  Processes messages for the main window.
//
LRESULT CALLBACK RemoteWindowWndProc(
    HWND hWnd, 
    UINT message, 
    WPARAM wParam,
    LPARAM lParam) 
{
    PAINTSTRUCT ps;
    HDC hdc;
    //  Window handle based look up.  This isn't a part of the client handler
    //  because I'm not sure that it'll work cross process
    //  TODO:  These maps shouldn't be one per window class.  There should be just
    //  TODO:  one for all window classes.  The main window should also be in here
    static map<HWND, CefString> hwnd2UUID;

    // Callback for the main window
    switch (message) 
    {
        case WM_CREATE: 
        {
            WTSRegisterSessionNotification(hWnd, NOTIFY_FOR_THIS_SESSION);
            //  Do we need to use the UNALIGNED decoration here?
            LPCREATESTRUCT csNewWindow = reinterpret_cast<LPCREATESTRUCT>(lParam);
            remoteWinID* pargs = static_cast<remoteWinID*>(csNewWindow->lpCreateParams);
            string uuid(pargs->uuid);
            hwnd2UUID[hWnd] = uuid;

            // Create the single static handler class instance
            CefRefPtr<CaffeineClientHandler> newHandler = new CaffeineClientHandler();
            newHandler->SetMainHwnd(hWnd);

            newHandler->uuid = uuid;
            newHandler->browserInitArg = pargs->initArg;
            newHandler->SetMinWindowWidth(pargs->minWidth);
            newHandler->SetMinWindowHeight(pargs->minHeight);

            app->m_WindowHandler[uuid] = newHandler;

            // Create the child windows used for navigation
            RECT rect;
            GetClientRect(hWnd, &rect);

            CefWindowInfo info;
            CefBrowserSettings browser_settings;
            browser_settings.universal_access_from_file_urls = STATE_ENABLED;
            browser_settings.file_access_from_file_urls = STATE_ENABLED;
            browser_settings.web_security = STATE_DISABLED;
            browser_settings.local_storage = STATE_ENABLED;
            browser_settings.application_cache = STATE_DISABLED;
            browser_settings.javascript_open_windows = STATE_DISABLED;

            // Initialize window info to the defaults for a child window
            info.SetAsChild(hWnd, rect);

            // Create the new child browser window
            string URL("file:///stub2.html?" + AppGetCommandLine()->GetSwitchValue("querystring").ToString());
            CefRefPtr<CefBrowser> newBrowser = CefBrowserHost::CreateBrowserSync(info, newHandler.get(), URL, browser_settings, NULL);
            newHandler->m_MainBrowser = newBrowser;

            app->hwndRender = hWnd; // setup current handle to use in Show/HideWindow
        
            // setting handle
            CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("setHandle");
            message->GetArgumentList()->SetInt(0, reinterpret_cast<int>(hWnd));
            newBrowser->SendProcessMessage(PID_RENDERER, message);
        
            // setting UUID
            message = CefProcessMessage::Create("setUUID");
            message->GetArgumentList()->SetString(0, uuid);
            newBrowser->SendProcessMessage(PID_RENDERER, message);

            SetWindowLongPtr(hWnd, 0, reinterpret_cast<LONG_PTR>(new WindowExtras));

            SetTimer(hWnd, IDLETIMER, IdleTimerPollIntervalMS, NULL);
            SetTimer(hWnd, NETWORKTIMER, NetworkTimerPollIntervalMS, NULL);

            return 0;
        }

        case WM_COMMAND:
        {
            break;
        }

        case WM_PAINT:
            hdc = BeginPaint(hWnd, &ps);
            EndPaint(hWnd, &ps);
            return 0;

        case WM_NCACTIVATE:
            break;

        case WM_ACTIVATE:
            if(hwnd2UUID.find(hWnd) != hwnd2UUID.end()) 
            {
                //__asm int 3;
                CefString browser_id = hwnd2UUID[hWnd];
                if (app->m_WindowHandler[browser_id].get() && app->m_WindowHandler[browser_id]->GetBrowser()) 
                {
                    app->m_WindowHandler[browser_id]->CreateAndDispatchCustomEvent((LOWORD(wParam)>0)? "activated" : "deactivated");
                }
            }
            return 0;


        case WM_SETFOCUS:
            if(hwnd2UUID.find(hWnd) != hwnd2UUID.end()) 
            {
                //__asm int 3;
                CefString browser_id = hwnd2UUID[hWnd];
                if (app->m_WindowHandler[browser_id].get() && app->m_WindowHandler[browser_id]->GetBrowser()) 
                {
                    CefRefPtr<CefBrowser> browser = app->m_WindowHandler[browser_id]->GetBrowser();
                    CefWindowHandle hwnd = browser->GetHost()->GetWindowHandle();
                    if (hwnd)
                    {
                        PostMessage(hwnd, message, wParam, lParam);
                        return 0;
                    }
                }
            }   
            break;

        case WM_SIZE:
            // Minimizing resizes the window to 0x0 which causes our layout to go all
            // screwy, so we just ignore it.
            if (wParam != SIZE_MINIMIZED && (hwnd2UUID.find(hWnd) != hwnd2UUID.end()))
            {
                CefString browser_id = hwnd2UUID[hWnd];
                if(app->m_WindowHandler[browser_id].get() && app->m_WindowHandler[browser_id]->GetBrowser()) 
                {
                    CefWindowHandle hwnd = app->m_WindowHandler[browser_id]->GetBrowser()->GetHost()->GetWindowHandle();
                    if (hwnd) {
                        //  This will send a WM_SIZE and WM_PAINT message to the render process
                        SetWindowPos(hwnd, NULL, 0, 0, LOWORD(lParam), HIWORD(lParam), SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOZORDER); 

                        return 0;
                    }
                }
            }
            break;
            
        case WM_MOVE:
            if (hwnd2UUID.find(hWnd) != hwnd2UUID.end())
            {
                CefString browser_id = hwnd2UUID[hWnd];
                if (app->m_WindowHandler[browser_id].get())
                {
                    //  TODO:  Below is a hack to work around the fact that CEF isn't updating screenX and screenY.  Periodically,
                    //  TODO:  check to see if they fix it.  
                    //  TODO:  See issue https://code.google.com/p/chromiumembedded/issues/detail?id=1303&thanks=1303&ts=1402082749
                    WINDOWINFO wi = {sizeof(WINDOWINFO), 0};
                    GetWindowInfo(hWnd, &wi);
                    RECT rClient = wi.rcWindow;

                    CefString JS = "window.screenLeft = window.screenX = " + to_string(_Longlong(rClient.left)) + "; window.screenTop = window.screenY = " + 
                        to_string(_Longlong(rClient.top)) + ";";
                    CefRefPtr<CefFrame> frame = app->m_WindowHandler[browser_id]->GetBrowser()->GetMainFrame();
                    frame->ExecuteJavaScript(JS, frame->GetURL(), 0);

                    //  TODO:  Another workaround.  For whatever reason, the window positions get updated when the size changes,
                    //  TODO:  but not when the window is moved.
                    CefWindowHandle hwnd = app->m_WindowHandler[browser_id]->GetBrowser()->GetHost()->GetWindowHandle();
                    if (hwnd) 
                    {
                        wi.cbSize = sizeof(WINDOWINFO);
                        GetWindowInfo(hwnd, &wi);
                        RECT rWindow = wi.rcWindow;

                        MoveWindow(hwnd, 0, 0, rWindow.right - rWindow.left, rWindow.bottom - rWindow.top + 1, FALSE);
                        MoveWindow(hwnd, 0, 0, rWindow.right - rWindow.left, rWindow.bottom - rWindow.top, FALSE);
                    }

                    app->m_WindowHandler[browser_id]->CreateAndDispatchCustomEvent("move");
                }
            }
            break;
            
        case WM_POWERBROADCAST:
            if (hwnd2UUID.find(hWnd) != hwnd2UUID.end())
            {
                CefString browser_id = hwnd2UUID[hWnd];
                if (app->m_WindowHandler[browser_id].get())
                {
                    if (wParam == PBT_APMRESUMEAUTOMATIC || wParam == PBT_APMSUSPEND)
                    {
                        app->m_WindowHandler[browser_id]->CreateAndDispatchCustomEvent(wParam == PBT_APMSUSPEND? "suspend" : "resume");
                        //  Do we really need a return value?
                        return TRUE;
                    }
                }
            }
            break;

        case WM_WTSSESSION_CHANGE:
            if(hwnd2UUID.find(hWnd) != hwnd2UUID.end())
            {
                CefString browser_id = hwnd2UUID[hWnd];
                if (app->m_WindowHandler[browser_id].get())
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

                    app->m_WindowHandler[browser_id]->CreateAndDispatchCustomEvent(eventName);
                }
            }
            break;

        case WM_ERASEBKGND:
            if (hwnd2UUID.find(hWnd) != hwnd2UUID.end())
            {
                //__asm int 3;
                CefString browser_id = hwnd2UUID[hWnd];
                if (app->m_WindowHandler[browser_id].get() && app->m_WindowHandler[browser_id]->GetBrowser()) 
                {
                    CefWindowHandle hwnd = app->m_WindowHandler[browser_id]->GetBrowser()->GetHost()->GetWindowHandle();
                    if (hwnd) 
                    {
                        // Dont erase the background if the browser window has been loaded
                        // (this avoids flashing)
                        return 0;
                    }
                }
            }
            break;

        case WM_CLOSE:
            if(hwnd2UUID.find(hWnd) != hwnd2UUID.end())
            {
                CefString browser_id = hwnd2UUID[hWnd];
                CefRefPtr<CaffeineClientHandler> handler = app->m_WindowHandler[browser_id];
                if (handler.get() && !handler->IsClosing()) 
                {
                    CefRefPtr<CefBrowser> browser = app->m_WindowHandler[browser_id]->GetBrowser();
                    if (browser.get()) 
                    {             
                        // Notify the browser window that we would like to close it. This
                        // will result in a call to ClientHandler::DoClose() if the
                        // JavaScript 'onbeforeunload' event handler allows it.
                        browser->GetHost()->CloseBrowser(false);

                        // Cancel the close.
                        return 0;
                    }
                }

                app->m_WindowHandler.erase(browser_id);
                hwnd2UUID.erase(hWnd);
            }
            break;

        case WM_GETMINMAXINFO:
            {
                LPMINMAXINFO minmaxInfoPtr = (LPMINMAXINFO) lParam;

                if(hwnd2UUID.find(hWnd) != hwnd2UUID.end())
                {
                    CefString browser_id = hwnd2UUID[hWnd];
                    CefRefPtr<CaffeineClientHandler> handler = app->m_WindowHandler[browser_id];

                    minmaxInfoPtr->ptMinTrackSize.x = handler->GetMinWindowWidth();
                    minmaxInfoPtr->ptMinTrackSize.y = handler->GetMinWindowHeight();
                }
            }
            return 0;

        case WM_TIMER:
        {
            if(hwnd2UUID.find(hWnd) != hwnd2UUID.end())
            {
                CefString browser_id = hwnd2UUID[hWnd];
                CefRefPtr<CaffeineClientHandler> handler = app->m_WindowHandler[browser_id];

                if(IDLETIMER == wParam)
                {
                    //  TODO:  Check timer id
                    LASTINPUTINFO lif = {sizeof(LASTINPUTINFO), 0};
                    GetLastInputInfo(&lif);
                    UINT IdleTimePassed = GetTickCount() - lif.dwTime;
                
                    WindowExtras *pWE = reinterpret_cast<WindowExtras *>(GetWindowLongPtr(hWnd, 0));
                    bool CurrentlyIdle = (pWE->IdleTimeThreshold < IdleTimePassed);
                    if(CurrentlyIdle != pWE->IsIdle)
                    {
                        const CefString EventName = (CurrentlyIdle? "startIdle" : "stopIdle");
                        pWE->IsIdle = CurrentlyIdle;
                        handler->CreateAndDispatchCustomEvent(EventName);
                    }
                }
                //  When we drop XP support, we can use COM and get network connectivity events.
                else if(NETWORKTIMER == wParam)
                {
                    WindowExtras *pWE = reinterpret_cast<WindowExtras *>(GetWindowLongPtr(hWnd, 0));
                    bool CurrentlyConnected = pWE->NetworkAvailable();
                    if(CurrentlyConnected != pWE->IsConnected)
                    {
                        const CefString EventName = (CurrentlyConnected? "os:online" : "os:offline");
                        pWE->IsConnected = CurrentlyConnected;
                        handler->CreateAndDispatchCustomEvent(EventName);
                    }
                }
            }
            break;
        }

        case WM_DESTROY:
        {
            WTSUnRegisterSessionNotification(hWnd);
            //  I don't think we need to return 0 in this case.

            KillTimer(hWnd, IDLETIMER);
            KillTimer(hWnd, NETWORKTIMER);
            WindowExtras *pWE = reinterpret_cast<WindowExtras *>(::GetWindowLongPtr(hWnd, 0));
            delete pWE;
            SetWindowLongPtr(hWnd, 0, 0);

            break;
        }

        case CAFFEINE_SOCKETS_MSG:
            CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("invokeSocketMethod");
            message->GetArgumentList()->SetInt(0, wParam);
            if (WSAGETSELECTERROR(lParam))
            {
                message->GetArgumentList()->SetString(1, "error");
                message->GetArgumentList()->SetInt(2, WSAGETSELECTERROR(lParam));
            }
            else
            {
                //  No error
                switch(WSAGETSELECTEVENT(lParam))
                {
                    case FD_CONNECT:
                        message->GetArgumentList()->SetString(1, "connect");
                        break;
                    case FD_CLOSE:
                        message->GetArgumentList()->SetString(1, "close");
                        break;
                    case FD_READ:
                        message->GetArgumentList()->SetString(1, "read");
                        break;
                    case FD_WRITE:
                        message->GetArgumentList()->SetString(1, "write");
                        break;
                }
            }

            if(hwnd2UUID.find(hWnd) != hwnd2UUID.end())
            {
                CefString browser_id = hwnd2UUID[hWnd];
                if (app->m_WindowHandler[browser_id].get())
                {
                    app->m_WindowHandler[browser_id]->GetBrowser()->SendProcessMessage(PID_RENDERER, message);
                }
            }

            break;
    }

    return DefWindowProc(hWnd, message, wParam, lParam);
}

