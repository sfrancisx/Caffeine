//  Copyright Yahoo! Inc. 2013-2014
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "ToastWindow.h"
#include "CaffeineClientApp.h"
#include "CaffeineClientUtils.h"
#include "resource.h"
#include <sstream>
using namespace std;

extern CefRefPtr<CaffeineClientApp> app;
extern bool otherAppInFullScreen;

ATOM RegisterToastWindowClass(HINSTANCE hInstance, PTCHAR szWindowClass) {
    WNDCLASSEX wcex;

    wcex.cbSize = sizeof(WNDCLASSEX);

    wcex.style         = 0;
    wcex.lpfnWndProc   = ToastWindowWndProc;
    wcex.cbClsExtra    = 0;
    wcex.cbWndExtra    = 0;
    wcex.hInstance     = hInstance;
    wcex.hIcon         = NULL;
    wcex.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground = (HBRUSH) GetStockObject(BLACK_BRUSH);
    wcex.lpszMenuName  = NULL;
    wcex.lpszClassName = szWindowClass;
    wcex.hIconSm       = NULL;

    return RegisterClassEx(&wcex);
}

int GetToastWindowHeight()
{
    RECT rect;
    SystemParametersInfo( SPI_GETWORKAREA, 0, &rect, 0 );

    return (rect.bottom - rect.top);
}

HWND InitToastWindowInstance(
    HINSTANCE hInstance,
    PTCHAR szWindowClass, 
    PTCHAR szTitle,
    POINT point,
    string::const_pointer pUUID,
    string::const_pointer pInitArg)
{
    DWORD dwStyle = WS_POPUP | WS_DISABLED;
    DWORD extendedStyle = WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_NOACTIVATE;

    remoteWinID args;
    args.uuid = const_cast<string::pointer>(pUUID);
    args.initArg = const_cast<string::pointer>(pInitArg);

    HWND toastWindowHwnd = CreateWindowEx(extendedStyle, szWindowClass, szTitle, dwStyle,
        point.x, point.y, 300, GetToastWindowHeight(), NULL, NULL, hInstance,
        reinterpret_cast<LPVOID>(&args));

    if (toastWindowHwnd) 
    {
        EnableWindow(toastWindowHwnd, true);
    }
    return toastWindowHwnd;
}

LRESULT CALLBACK ToastWindowWndProc(
    HWND hWnd, 
    UINT message, 
    WPARAM wParam,
    LPARAM lParam) 
{
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
            SetWindowLong(hWnd, GWL_EXSTYLE, GetWindowLong(hWnd, GWL_EXSTYLE) | WS_EX_LAYERED);
            SetLayeredWindowAttributes(hWnd, RGB(0,0,0), 0, LWA_COLORKEY);

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
            string URL("file:///stub2.html");
            CefRefPtr<CefBrowser> toastBrowser = CefBrowserHost::CreateBrowserSync(info, newHandler.get(), URL, browser_settings, NULL);
            newHandler->m_MainBrowser = toastBrowser;

            app->hwndRender = hWnd;

            // setting handle
            CefRefPtr<CefProcessMessage> process_message = CefProcessMessage::Create("setHandle");
            process_message->GetArgumentList()->SetInt(0, reinterpret_cast<int>(hWnd));
            toastBrowser->SendProcessMessage(PID_RENDERER, process_message);

            // setting UUID
            process_message = CefProcessMessage::Create("setUUID");
            process_message->GetArgumentList()->SetString(0, uuid);
            toastBrowser->SendProcessMessage(PID_RENDERER, process_message);

            SetTimer(hWnd, TOASTTIMER, ToastTimerPollIntervalMS, NULL);

            return 0;
        }

        case WM_TIMER:
            if(hwnd2UUID.find(hWnd) != hwnd2UUID.end())
            {  
                CefString browser_id = hwnd2UUID[hWnd];
                CefRefPtr<CaffeineClientHandler> handler = app->m_WindowHandler[browser_id];

                if (handler.get())
                {
                    bool foreWindowfullScreen =  handler->IsForegroundWindowInFullScreen();
                    if ( otherAppInFullScreen != foreWindowfullScreen )
                    {
                        otherAppInFullScreen = foreWindowfullScreen;
                        otherAppInFullScreen? ShowWindow(hWnd, SW_HIDE) : ShowWindow(hWnd, SW_SHOWNA);
                        // Create event for js here
                    }
                }
            }
            return 0;

        case WM_ERASEBKGND:
            return 1;

        case WM_SETTINGCHANGE:
            if (wParam != SPI_SETWORKAREA)
            {
                return 0;
            }
            /* Intentional fall-through to update the toast window */
        case WM_DISPLAYCHANGE:
            if(hwnd2UUID.find(hWnd) != hwnd2UUID.end())
            {  
                CefString browser_id = hwnd2UUID[hWnd];
                CefRefPtr<CaffeineClientHandler> handler = app->m_WindowHandler[browser_id];

                if (handler.get())
                {
                    POINT point = handler->GetToastAttributes();
                    int height = GetToastWindowHeight();

                    SetWindowPos(hWnd, NULL, point.x, point.y, 300, height, SWP_NOSENDCHANGING|SWP_NOZORDER);

                    CefRefPtr<CefBrowser> browser = app->m_WindowHandler[browser_id]->GetBrowser();

                    if (browser.get())
                    {
                        CefWindowHandle cefHandle = browser->GetHost()->GetWindowHandle();
                        SetWindowPos(cefHandle, NULL, 0, 0, 300, height, SWP_NOSENDCHANGING|SWP_NOZORDER);
                    }
                }
            }
            return 0;

        case WM_DESTROY:
            KillTimer(hWnd, TOASTTIMER);
            return 0;

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
                        browser->GetHost()->CloseBrowser(false);

                        // Cancel the close.
                        return 0;
                    }
                }

                app->m_WindowHandler.erase(browser_id);
                hwnd2UUID.erase(hWnd);
            }
            break;
    }

    return DefWindowProc(hWnd, message, wParam, lParam);
}

