//  Copyright Yahoo! Inc. 2013-2014
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "defines.h"

#include "CaffeineClientHandler.h"
#include "CaffeineClientUtils.h"
#include "CaffeineClientApp.h"

//#include "ModifyHeadersResourceHandler.h"

//#include "CaffeineShell.h"
#include "Brewery_platform.h"
#include <algorithm>
#include <sstream>
#include <string>
#include <stdio.h>
#include <sys/stat.h>
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "include/cef_path_util.h"
#include "include/cef_process_util.h"
#include "include/cef_runnable.h"
#include "include/wrapper/cef_stream_resource_handler.h"
#include "cefclient/resource_util.h"
#include "include/cef_trace.h"
using namespace std;

#ifdef OS_WIN

//#include <Shellapi.h>
#ifdef ENABLE_MUSIC_SHARE
#include "CaffeineITunesWin.h"
#endif

#else

#include "McBrewery/mac_util.h"

#ifdef ENABLE_MUSIC_SHARE
#include "CaffeineITunesMac.h"
#endif

// RTT socket calls "glue" calss
SOCKET  createSocket(CefRefPtr<CefListValue> values);
void    writeToSocket(CefRefPtr<CefListValue> values);
void    closeSocket(SOCKET s);

#endif

extern CefRefPtr<CaffeineClientApp> app;
extern string mainUUID;


const int SET_BROWSER_VALUE_FEEDBACK_LINK   = 0;

bool ShowFolder(string directory, string selected_file);
bool ShowFolder2(wstring directory, CefRefPtr<CefListValue> selected_files);

static const char* kMonths[] = { "jan", "feb", "mar", "apr", "may", "jun",
    "jul", "aug", "sep", "oct", "nov", "dec" };
static const char* kDaysOfWeek[] = {"sun","mon","tue","wed","thu","fry","sat"};

void IOT_Set(const string& name, const string& value, const int callbackNumber)
{
    string lowerval;
    transform(value.begin(), value.end(), back_inserter(lowerval), ::tolower);
    int commaPos = lowerval.find(';');
    string val1 = value.substr(0,commaPos);

    commaPos = lowerval.find("expires=");
    unsigned year = 0;
    unsigned month = 13; // invalid value
    unsigned day = 0;
    unsigned hour = 0;
    unsigned minute = 0;
    unsigned second = 0;
    unsigned day_of_week = 8; // invalid
    char monthBuffer[5] = {0,};
    char weekBuffer[5] = {0,};

    if ( commaPos >= 0 )
    {
        lowerval = lowerval.substr(commaPos+8); // removes expires
        commaPos = lowerval.find(" gmt;");
        lowerval = lowerval.substr(0, commaPos);  // ends befoe " GMT"

        sscanf(lowerval.c_str(), "%3s, %2u-%3s-%4u %2u:%2u:%2u",
               weekBuffer, &day, monthBuffer, &year, &hour, &minute, &second);

        for (int i = 0; i < 12; ++i) {
            if ( memcmp(kMonths[i], monthBuffer, 3) == 0 ) {
                month = i;
                break;
            }
        }
        for (int i = 0; i < 7; ++i) {
            if ( memcmp(kDaysOfWeek[i], weekBuffer, 3) == 0 ) {
                day_of_week = i;
                break;
            }
        }
    }

    bool secure = false;
    if ( value.find("secure") != string::npos )
    {
        secure = true;
    }
    bool httponly = false;
    if ( lowerval.find("httponly"))
    {
        httponly = true;
    }

    CefCookie cookie;
    CefString(&cookie.name).FromASCII(name.c_str());
    CefString(&cookie.value).FromASCII(val1.c_str());
    CefString(&cookie.domain).FromASCII(COOKIE_DOMAIN);
    CefString(&cookie.path).FromASCII("/");

    cookie.httponly = httponly;
    cookie.secure = secure;

    if ( month == 13 )
        cookie.has_expires = false;
    else
    {
        cookie.has_expires = true;
        cookie.expires.year = year;
        cookie.expires.month = month;
        cookie.expires.day_of_week = day_of_week;
        cookie.expires.day_of_month = day;
        cookie.expires.hour = hour;
        cookie.expires.minute = minute;
        cookie.expires.second = second;
    }

    CefString url = DIAGNOSTICS_URL;
    CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager();

    CefRefPtr<CefDictionaryValue> StatusObject = CefDictionaryValue::Create();

    if ( ! manager->SetCookie(url, cookie) )
    {
        app->ShellLog(L"Error setting cookie");
        //app->ShellLog(name.c_str());
        //app->ShellLog(value.c_str());
        StatusObject->SetString("status", "error");
    }
    else
    {
        StatusObject->SetString("status", "success");

    }

    CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
    callbackMsg->GetArgumentList()->SetString(0, "setCookie");
    callbackMsg->GetArgumentList()->SetInt(1, callbackNumber);
    callbackMsg->GetArgumentList()->SetDictionary(2, StatusObject);

    CefRefPtr<CefBrowser> browser = app->m_WindowHandler[mainUUID]->GetBrowser();
    browser->SendProcessMessage(PID_RENDERER, callbackMsg);
}


// ----------------------------------------------------------------
// CaffeineClientHandler - mail window handling
// ----------------------------------------------------------------

static string mailUUID = "";


CaffeineClientHandler::CaffeineClientHandler()
    : m_MainHwnd(NULL),
      m_BrowserId(0),
      m_bIsClosing(false),
      m_bHasFocus(true),
      hwndDockedWindow(NULL)
{
    PlatformSpecificInitialization(); // initializes UserAgent
}

CaffeineClientHandler::~CaffeineClientHandler()
{
}

//  This is the client message handler.
bool CaffeineClientHandler::OnProcessMessageReceived(
    CefRefPtr<CefBrowser> browser,
    CefProcessId source_process,
    CefRefPtr<CefProcessMessage> message)
{
    if(message->GetName() == "popupWindow" )
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();

        wstring msg = L"Window Creation Timing: ClientHandler popupWindow: " + retval->GetString(0).ToWString();
        app->ShellLog(msg);

        string uuid = retval->GetString(0);
        string initArg = retval->GetString(1).ToString();
        bool bCreateFrameless = retval->GetBool(2);

        int height = retval->GetInt(3);
        int width  = retval->GetInt(4);
        int left = retval->GetInt(5);
        int top = retval->GetInt(6);
        string target = (retval->GetSize()>7)?  retval->GetString(7) : "";
        bool bResizable = (retval->GetSize()>8)? retval->GetBool(8) : true;
        int minWidth = retval->GetInt(9);
        int minHeight = retval->GetInt(10);

        bool windowAlreadyExists = false;
        if ( target == "ymail" )
        {
            if (  mailUUID != "" )
                windowAlreadyExists = true;
            else
                mailUUID = uuid;
        }
        if ( ! windowAlreadyExists )
            CreateRemoteWindow(height, width, left, top, uuid, initArg, bCreateFrameless, bResizable, target, minWidth, minHeight);
        else
            ActivateWindow( uuid );
    }
    else if(message->GetName() == "setCookie" )
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();

        string name = retval->GetString(1);
        string value = retval->GetString(2);
        int callbackNumber = retval->GetInt(0);
        CefPostTask(TID_IO, NewCefRunnableFunction(IOT_Set, name, value, callbackNumber) );
    }

    else if(message->GetName() == "toastWindow" )
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();

        string uuid = retval->GetString(0);
        string initArg = retval->GetString(1).ToString();
        CreateToastWindow(uuid, initArg);
    }

#ifdef OS_WIN
    else if (message->GetName() == "triggerDump")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefRefPtr<CefDictionaryValue> StatusObject = CefDictionaryValue::Create();

        crAddScreenshot2(CR_AS_VIRTUAL_SCREEN | CR_AS_USE_JPEG_FORMAT, 80);

        CR_EXCEPTION_INFO crDump = {0,};
        crDump.cb = sizeof(CR_EXCEPTION_INFO);
        crDump.exctype = CR_SEH_EXCEPTION;
        crDump.code = 10203040;
        crDump.pexcptrs = NULL;
        if(crGenerateErrorReport(&crDump) == 0)
        {
            StatusObject->SetString("status", "success");
        }
        else
        {
            StatusObject->SetString("status", "error");
        }

        CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
        callbackMsg->GetArgumentList()->SetString(0, message->GetName());
        callbackMsg->GetArgumentList()->SetInt(1, retval->GetInt(0));
        callbackMsg->GetArgumentList()->SetDictionary(2, StatusObject);
        browser->SendProcessMessage(PID_RENDERER, callbackMsg);
    }
#endif
    else if(message->GetName() == "sendIPC")
    {
        //  Probably should have a few asserts around this
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefString browser_handle = retval->GetString(0);
        CefRefPtr<CefFrame> frame = NULL;

        if (app->m_WindowHandler.find(browser_handle) != app->m_WindowHandler.end())
        {
            //  TODO:  Do we really need this look up?
            CefRefPtr<CefBrowser> target_browser = app->m_WindowHandler[browser_handle]->GetBrowser();
            if (target_browser.get())
            {
                frame = target_browser->GetMainFrame();

                if (frame != NULL && frame->IsValid())
                {
                    CefString snippet = L"Caffeine.Event.fire(Caffeine.CEFContext, 'ipcReceived', '" + 
                        (retval->GetString(2)).ToWString() + L"', unescape('" + (retval->GetString(1)).ToWString() + L"'));";
                    frame->ExecuteJavaScript(snippet, frame->GetURL(), 0);
                }
            }
        }
    }

    else if (message->GetName() == "getDownloadDirectoryFromUser")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefRefPtr<CefDictionaryValue> StatusObject = CefDictionaryValue::Create();
        CefString DirectoryPicked;

        if(GetDirectoryFromUser(DirectoryPicked))
        {
            wstring empty = wstring(L"");
            //  TODO:  What about duplicate directory paths?
            AcceptableDownloadDirectories.push_front(DirectoryPicked);
            StatusObject->SetString("status", "success");
            StatusObject->SetString("downloadPath", DirectoryPicked);
            app->showFileSaveAsDialog = false;
        }
        else
        {
            StatusObject->SetString("status", "error");
        }

        CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
        callbackMsg->GetArgumentList()->SetString(0, message->GetName());
        callbackMsg->GetArgumentList()->SetInt(1, retval->GetInt(0));
        callbackMsg->GetArgumentList()->SetDictionary(2, StatusObject);
        browser->SendProcessMessage(PID_RENDERER, callbackMsg);
    }
    else if (message->GetName() == "getDownloadPathFromUser")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefRefPtr<CefDictionaryValue> StatusObject = CefDictionaryValue::Create();
        CefString filename = retval->GetString(1);
        CefString DirectoryPicked;

        if(GetPathFromUser(filename, DirectoryPicked))
        {
            //  TODO:  What about duplicate directory paths?
            wstring empty = wstring(L"");
            AcceptableDownloadDirectories.push_front(DirectoryPicked);
            StatusObject->SetString("status", "success");
            StatusObject->SetString("downloadPath", DirectoryPicked);
            StatusObject->SetString("filename", filename);
            app->showFileSaveAsDialog = false;
        }
        else
        {
            StatusObject->SetString("status", "error");
        }

        CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
        callbackMsg->GetArgumentList()->SetString(0, message->GetName());
        callbackMsg->GetArgumentList()->SetInt(1, retval->GetInt(0));
        callbackMsg->GetArgumentList()->SetDictionary(2, StatusObject);
        browser->SendProcessMessage(PID_RENDERER, callbackMsg);
    }

    else if (message->GetName() == "resetDownloadDirectory")
    {
        SetDownloadPath(L"");
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefRefPtr<CefDictionaryValue> StatusObject = CefDictionaryValue::Create();
        StatusObject->SetString("status", "success");
        app->showFileSaveAsDialog = true;

        CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
        callbackMsg->GetArgumentList()->SetString(0, message->GetName());
        callbackMsg->GetArgumentList()->SetInt(1, retval->GetInt(0));
        callbackMsg->GetArgumentList()->SetDictionary(2, StatusObject);
        browser->SendProcessMessage(PID_RENDERER, callbackMsg);
    }
    else if (message->GetName() == "getDownloadPath")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefRefPtr<CefDictionaryValue> StatusObject = CefDictionaryValue::Create();

        StatusObject->SetString("status", "success");
        app->showFileSaveAsDialog = false;
        StatusObject->SetString("downloadPath", GetDownloadPath(L""));

        CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
        callbackMsg->GetArgumentList()->SetString(0, message->GetName());
        callbackMsg->GetArgumentList()->SetInt(1, retval->GetInt(0));
        callbackMsg->GetArgumentList()->SetDictionary(2, StatusObject);
        browser->SendProcessMessage(PID_RENDERER, callbackMsg);
    }
    else if (message->GetName() == "setDownloadPath")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefRefPtr<CefDictionaryValue> StatusObject = CefDictionaryValue::Create();

        list<CefString>::iterator i = find(AcceptableDownloadDirectories.begin(), AcceptableDownloadDirectories.end(), retval->GetString(1));
        if (i != AcceptableDownloadDirectories.end())
        {
            StatusObject->SetString("status", "success");
            app->showFileSaveAsDialog = false;
            SetDownloadPath(retval->GetString(1));
        }
        else  //  Error case
        {
            StatusObject->SetString("status", "error");
            app->showFileSaveAsDialog = true;
        }

        CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
        callbackMsg->GetArgumentList()->SetString(0, message->GetName());
        callbackMsg->GetArgumentList()->SetInt(1, retval->GetInt(0));
        callbackMsg->GetArgumentList()->SetDictionary(2, StatusObject);
        browser->SendProcessMessage(PID_RENDERER, callbackMsg);
    }
    else if (message->GetName() == "showDirectory")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefString directory = retval->GetString(0);

        list<CefString>::iterator i = find(AcceptableDownloadDirectories.begin(), AcceptableDownloadDirectories.end(), directory);
        if (i != AcceptableDownloadDirectories.end())
        {
            if(retval->GetType(1) == VTYPE_LIST)
            {
                CefRefPtr<CefListValue> selected_files = retval->GetList(1);
                //  Probably could have just one function ShowFolders that checks the type of the second arg.
                ShowFolder2(directory.ToWString(), selected_files);
            }
            else  //  It's a string
            {
                CefString selected_file = retval->GetString(1);
                ShowFolder(directory.ToString(), selected_file);
            }
        }
        else
        {
            app->ShellLog(L"showDirectory called BUT no AcceptableDownloadDirectories value found");
        }
    }
    else if (message->GetName() == "startFlashing")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefString browser_handle = retval->GetString(0);
        bool bAutoStop = retval->GetBool(1);
        StartFlashing(browser_handle, bAutoStop);
    }
    else if(message->GetName() == "stopFlashing")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefString browser_handle = retval->GetString(0);
        StopFlashing(browser_handle);
    }
    else if(message->GetName() == "activateWindow")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefString browser_handle = retval->GetString(0);
        ActivateWindow(browser_handle);
    }
    else if(message->GetName() == "activateApp")
    {
#ifdef __APPLE__
        activatesApp();
#endif
    }
    else if(message->GetName() == "showWindow")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefString uuid = retval->GetString(0);
        ShowWindow(uuid);
        //  TODO:  Should probably handle this event from JS
        CreateAndDispatchCustomEvent("show");
    }
    else if(message->GetName() == "hideWindow")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefString uuid = retval->GetString(0);
        HideWindow(uuid);
        //  TODO:  Should probably handle this event from JS
        CreateAndDispatchCustomEvent("hide");
    }
    else if (message->GetName() == "setUserAgent")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefString UA = retval->GetString(0);
        user_agent = UA;
    }
    else if (message->GetName() == "setPrefixMapping")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        requestPrefixMap[retval->GetString(0)] = retval->GetString(1);
    }
#ifdef ENABLE_MUSIC_SHARE
    else if (message->GetName() == "ITunesPlayPreview")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        wstring url = retval->GetString(0);
        ITunesPlayPreview(url);
    }
#if defined(OS_WIN)
    else if (message->GetName() == "isITunesOn")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        string name = message->GetName();
        int retvalInt = retval->GetInt(0);
        CefRefPtr<CefDictionaryValue> isOn = CefDictionaryValue::Create();
        isITunesOn(isOn);
        CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
        callbackMsg->GetArgumentList()->SetString(0, name);
        callbackMsg->GetArgumentList()->SetInt(1, retvalInt);

        callbackMsg->GetArgumentList()->SetDictionary(2, isOn);
        browser->SendProcessMessage(PID_RENDERER, callbackMsg);
    }
    else if (message->GetName() == "getITunesTrackInfo")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        string name = message->GetName();
        int retvalInt = retval->GetInt(0);
        CefRefPtr<CefDictionaryValue> TrackInfo = CefDictionaryValue::Create();
        getITunesTrackInfo(TrackInfo);
        CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");

        callbackMsg->GetArgumentList()->SetString(0, name);
        callbackMsg->GetArgumentList()->SetInt(1, retvalInt);

        callbackMsg->GetArgumentList()->SetDictionary(2, TrackInfo);
        browser->SendProcessMessage(PID_RENDERER, callbackMsg);
    }
    else if (message->GetName() == "getInstalledPlayers")
    {
        ShellLog(L"FLAME CHART CaffeineClientHandler.getInstalledPlayers");

        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        string name = message->GetName();
        int retvalInt = retval->GetInt(0);
        CefRefPtr<CefDictionaryValue> InstalledPlayers = CefDictionaryValue::Create();
        getInstalledPlayers(InstalledPlayers);
        CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");

        callbackMsg->GetArgumentList()->SetString(0, name);
        callbackMsg->GetArgumentList()->SetInt(1, retvalInt);

        callbackMsg->GetArgumentList()->SetDictionary(2, InstalledPlayers);
        browser->SendProcessMessage(PID_RENDERER, callbackMsg);
    }
#else //OS_MAC
    else if (message->GetName() == "isITunesOn")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        string name = message->GetName();
        int retvalInt = retval->GetInt(0);
        isITunesOn(name, retvalInt);
    }
    else if (message->GetName() == "getITunesTrackInfo")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        string name = message->GetName();
        int retvalInt = retval->GetInt(0);
        getITunesTrackInfo(name, retvalInt);
    }
    else if (message->GetName() == "getInstalledPlayers")
    {
        ShellLog(L"FLAME CHART CaffeineClientHandler.getInstalledPlayers");
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        string name = message->GetName();
        int retvalInt = retval->GetInt(0);
        getInstalledPlayers(name, retvalInt);
    }
#endif  //OS_WIN

#endif  //ENABLE_MUSIC_SHARE

    else if (message->GetName() == "shakeWindow")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        ASSERT(retval->GetSize() == 1);
        
        string uuid = retval->GetString(0);
#ifdef __APPLE__
        ShakeWindow(uuid);
#endif
        
    }
    
    else if (message->GetName() == "moveWindowTo")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        ASSERT(retval->GetSize() == 5);

        string uuid = retval->GetString(0);
        int left  = retval->GetInt(1);
        int top  = retval->GetInt(2);
        int height  = retval->GetInt(3);
        int width  = retval->GetInt(4);

        MoveOrResizeWindow(uuid, left, top, height, width);
    }
    //  This needs to be broken up into two functions: one to determine if a
    //  window is the foreground window and another to pop up notifications.
    else if(message->GetName() == "messageReceived")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        wstring from = retval->GetString(0);
        wstring display = retval->GetString(1);
        wstring msg = retval->GetString(2);
        wstring convId = retval->GetString(3);
        MessageReceived(from, display, msg, convId);
    }
    else if(message->GetName() == "stateIsNowLoggedIn")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        stateIsNowLoggedIn(retval->GetBool(0));
    }
    else if(message->GetName() == "enableSessionMenus")
    {
#ifdef OS_MACOSX
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        enableSessionMenus(retval->GetBool(0));
#endif
    }

    else if (message->GetName() == "openFile")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        wstring path = retval->GetString(0);

        if (downloadedFiles.find(path) != downloadedFiles.end())
        {
            OpenFile(path);
        }
        else
        {
            wstringstream msg;
            msg << L"Attempt made to open file '";
            msg << path;
            msg << L"' that was not downloaded by the client";

            app->ShellLog(msg.str());
        }
    }
#ifdef OS_MACOSX
    else if(message->GetName() == "setBadgeCount")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        ChangeBadgeCount(retval->GetInt(0), retval->GetBool(1));

    }
    else if(message->GetName() == "showViewMenu")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        ShowViewMenu(retval->GetBool(0));
    }

    else if(message->GetName() == "setUserToken")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        string usr = retval->GetString(0);
        string tok = retval->GetString(1);
        SetUserToken(usr,tok);
    }
    else if(message->GetName() == "removeAllUserTokens" )
    {
        RemoveAllTokens();
    }
    else if(message->GetName() == "removeUserToken")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        string usr = retval->GetString(0);
        RemoveUserToken(usr);
    }
#endif

#ifdef OS_WIN
    else if (message->GetName() == "restartApplication")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        RestartApplication(retval->GetString(0));
    }

    else if (message->GetName() == "setEphemeralState")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        SetEphemeralState(retval->GetString(0));
    }
#endif


    else if (message->GetName() == "setBrowserValue")
    {
        CefRefPtr<CefListValue> args = message->GetArgumentList();

        switch (args->GetInt(0))
        {
            case SET_BROWSER_VALUE_FEEDBACK_LINK:
#ifdef __APPLE__
                setFeedbackLink( args->GetString(1).ToString());
#endif
                break;
        }
    }

#ifdef __APPLE__

#pragma mark === RTT2 Sockets - browser side ===

    else if ( message->GetName() == "createSocket" )
    {
        createSocket(message->GetArgumentList());
    }

    else if ( message->GetName() == "writeSocket" )
    {
        writeToSocket(message->GetArgumentList());
    }

    else if ( message->GetName() == "closeSocket" )
    {
        closeSocket(message->GetArgumentList()->GetInt(0));
    }

#endif

    return false;
}

void CaffeineClientHandler::OnBeforeContextMenu(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefContextMenuParams> params,
    CefRefPtr<CefMenuModel> model)
{
    if ((params->GetTypeFlags() & (CM_TYPEFLAG_PAGE | CM_TYPEFLAG_FRAME)) != 0) {
        // Add a separator if the menu already has items.
        if (model->GetCount() > 0)
            model->AddSeparator();

    }
}

bool CaffeineClientHandler::OnContextMenuCommand(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefContextMenuParams> params,
    int command_id,
    EventFlags event_flags)
{
    return true;
}

void CaffeineClientHandler::OnLoadingStateChange(
    CefRefPtr<CefBrowser> browser,
    bool isLoading,
    bool canGoBack,
    bool canGoForward)
{
    REQUIRE_UI_THREAD();
    SetLoading(isLoading);
    SetNavState(canGoBack, canGoForward);

#ifdef __APPLE__
    if ( browser->GetIdentifier() == 1 )
    {
        MainLoadingStateChanged(isLoading);
    }
#endif
}

bool CaffeineClientHandler::OnConsoleMessage(
    CefRefPtr<CefBrowser> browser,
    const CefString& message,
    const CefString& source,
    int line)
{
    REQUIRE_UI_THREAD();

#ifdef  __APPLE__
    ConsoleLog(browser->GetIdentifier(),  message);
#endif

#if defined(OS_WIN)
    wstringstream ss;
    wstring srcName = source;
    unsigned found = srcName.find_last_of(L"/\\");
    ss << L"(" << time(NULL) << L"," << srcName.substr(found+1) << L"," << line <<  L")" << message.ToWString() << endl;

    app->ShellLog(ss.str());
#endif

    return false;
}

bool CaffeineClientHandler::RenameOldFile(wstring filename)
{
    //  Determine if the file already exists.  We do this because of the fugly extension
    //  API we're using.
#ifdef __APPLE__
    return renameOldFile(filename);
#else
    bool retval = false;
    struct _stat buf = {0,};
    if(_wstat(filename.c_str(), &buf) == 0)
    {
        wstring fileExt = L"";

        unsigned index = filename.find_last_of('.');
        if (index != wstring::npos)
        {
            fileExt = filename.substr(index);
        }

        wstringstream newFileName;
        newFileName << filename.substr(0, index) << ".old" << fileExt;

        RenameOldFile(newFileName.str());
        _wrename(filename.c_str(), newFileName.str().c_str());
        retval = true;
    }

    return retval;
#endif

}

void CaffeineClientHandler::OnBeforeDownload(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefDownloadItem> download_item,
    const CefString& suggested_name,
    CefRefPtr<CefBeforeDownloadCallback> callback)
{
    REQUIRE_UI_THREAD();
    wstring filePath = GetDownloadPath(suggested_name);

    RenameOldFile(filePath);
    downloadedFiles.insert(filePath);

    // Continue the download and show the "Save As" dialog.
    callback->Continue(filePath, app->showFileSaveAsDialog);
}

void CaffeineClientHandler::OnDownloadUpdated(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefDownloadItem> download_item,
    CefRefPtr<CefDownloadItemCallback> callback)
{
    REQUIRE_UI_THREAD();

    if (download_item->IsComplete()) {
        SendNotification(NOTIFY_DOWNLOAD_COMPLETE);
    }
}


void CaffeineClientHandler::OnAfterCreated(CefRefPtr<CefBrowser> browser)
{
    REQUIRE_UI_THREAD();

    // CEF 2062
#ifdef __APPLE__
    base::AutoLock lock_scope(lock_);
#else
    AutoLock lock_scope(this);
#endif
    
    if (!m_MainBrowser.get())   {
        // We need to keep the main child window, but not popup windows
        m_MainBrowser = browser;
    }
    m_BrowserId = browser->GetIdentifier();
}

bool CaffeineClientHandler::DoClose(CefRefPtr<CefBrowser> browser)
{
    REQUIRE_UI_THREAD();

    // Closing the main window requires special handling. See the DoClose()
    // documentation in the CEF header for a detailed destription of this
    // process.

    if (m_BrowserId == browser->GetIdentifier()) {
        // Notify the browser that the parent window is about to close.
        // CEF 3.1916.1662
        //browser->GetHost()->ParentWindowWillClose();

        // Set a flag to indicate that the window close should be allowed.
        m_bIsClosing = true;
    }

    if ( mailUUID != ""
        && app->m_WindowHandler[mailUUID].get()
        && app->m_WindowHandler[mailUUID]->GetBrowser().get()
        && app->m_WindowHandler[mailUUID]->GetBrowser()->GetIdentifier() == browser->GetIdentifier()
        )
    {
        mailUUID = "";
    }

    // Allow the close. For windowed browsers this will result in the OS close
    // event being sent.
    return false;
}

void CaffeineClientHandler::OnBeforeClose(CefRefPtr<CefBrowser> browser)
{
    REQUIRE_UI_THREAD();

    if (m_BrowserId == browser->GetIdentifier()) {
        // Free the browser pointer so that the browser can be destroyed
        m_MainBrowser = NULL;
    }
}

void CaffeineClientHandler::OnLoadStart(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame)
{
    REQUIRE_UI_THREAD();

    if (m_BrowserId == browser->GetIdentifier() && frame->IsMain()) {
        // We've just started loading a page
        SetLoading(true);
    }
}

void CaffeineClientHandler::OnLoadEnd(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    int httpStatusCode)
{
    REQUIRE_UI_THREAD();

    if ( browser->GetIdentifier() != 1 ) // NOT MAIN
    {
        //  TODO:  the ids should probably move to OnWebkitInitialized and the
        //  TODO:  startStub2() call should be moved to the JS.
        frame->ExecuteJavaScript(
                                 "browserID='" + uuid.ToString() + "';"
                                 "IPC_id='" + uuid.ToString() + "';"
                                 "myInitArg=unescape('"+ browserInitArg + "');"
                                 "window.startStub2 && startStub2();",
                                 frame->GetURL(),
                                 0
                                 );
    }
    if (m_BrowserId == browser->GetIdentifier() && frame->IsMain()) {
        // We've just finished loading a page
        SetLoading(false);
    }
}

void CaffeineClientHandler::OnRenderProcessTerminated(
    CefRefPtr<CefBrowser> browser,
    TerminationStatus status)
{
    RendererProcessTerminated(browser, status);
    /*
    // Load the startup URL if that's not the website that we terminated on.
    CefRefPtr<CefFrame> frame = browser->GetMainFrame();
    string url = frame->GetURL();
    std::transform(url.begin(), url.end(), url.begin(), tolower);

    string startupURL = GetStartupURL();
    if (url.find(startupURL) != 0)
        frame->LoadURL(startupURL);
     */
}

bool CaffeineClientHandler::OnBeforeResourceLoad(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefRequest> request)
{
//    REQUIRE_IO_THREAD();

    CefRequest::HeaderMap x;

    request->GetHeaderMap(x);
    x.erase(TEXT("User-Agent"));
    x.insert(CefRequest::HeaderMap::value_type(TEXT("User-Agent"), user_agent));
    request->SetHeaderMap(x);

    return !ValidateRequestLoad(browser, frame, request);
}



bool CaffeineClientHandler::Save(const string& path, const string& data) {
    FILE* f = fopen(path.c_str(), "a+");
    if (!f)
        return false;
    size_t total = 0;
    do {
        size_t write = fwrite(data.c_str() + total, 1, data.size() - total, f);
        if (write == 0)
            break;
        total += write;
    } while (total < data.size());
    fclose(f);
    return true;
}


bool CaffeineClientHandler::OnQuotaRequest(CefRefPtr<CefBrowser> browser,
    const CefString& origin_url,
    int64 new_size,
    CefRefPtr<CefQuotaCallback> callback)
{
//    static const int64 max_size = 1024 * 1024 * 20;  // 20mb.

    // Grant the quota request if the size is reasonable.
//    callback->Continue(new_size <= max_size);
    //  TODO:  Revisit.  Do we really want to allow unlimited quota
    callback->Continue(true);
    return true;
}

void CaffeineClientHandler::OnProtocolExecution(CefRefPtr<CefBrowser> browser,
    const CefString& url,
    bool& allow_os_execution)
{
}

void CaffeineClientHandler::SetMainHwnd(CefWindowHandle hwnd)
{
// CEF 2062
#ifdef __APPLE__
    base::AutoLock lock_scope(lock_);
#else
    AutoLock lock_scope(this);
#endif
    m_MainHwnd = hwnd;
}


wstring CaffeineClientHandler::GetLogFile()
{
// CEF 2062
#ifdef __APPLE__
#else
    AutoLock lock_scope(this);
#endif
    return m_LogFile;
}

// static
void CaffeineClientHandler::LaunchExternalBrowser(const string& url)
{
    if (CefCurrentlyOn(TID_PROCESS_LAUNCHER)) {
        // Retrieve the current executable path.
        CefString file_exe;
        if (!CefGetPath(PK_FILE_EXE, file_exe))
            return;

        // Create the command line.
        CefRefPtr<CefCommandLine> command_line =
            CefCommandLine::CreateCommandLine();
        command_line->SetProgram(file_exe);

        // Launch the process.
        CefLaunchProcess(command_line);
    } else {
        // Execute on the PROCESS_LAUNCHER thread.
        CefPostTask(TID_PROCESS_LAUNCHER,
            NewCefRunnableFunction(&CaffeineClientHandler::LaunchExternalBrowser, url));
    }
}

bool CaffeineClientHandler::OnBeforePluginLoad(CefRefPtr<CefBrowser> browser,
    const CefString& url,
    const CefString& policy_url,
    CefRefPtr<CefWebPluginInfo> info)
{
    return ValidatePlugin(info);
}

bool CaffeineClientHandler::OnBeforePopup(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    const CefString& target_url,
    const CefString& target_frame_name,
    const CefPopupFeatures& popupFeatures,
    CefWindowInfo& windowInfo,
    CefRefPtr<CefClient>& client,
    CefBrowserSettings& settings,
    bool* no_javascript_access)
{
    OpenDefaultBrowser(target_url);

    //  Kill all pop ups!
    return true;
}

void CaffeineClientHandler::OnTakeFocus(CefRefPtr<CefBrowser> browser, bool next)
{
    m_bHasFocus = false;
}

bool CaffeineClientHandler::OnSetFocus(CefRefPtr<CefBrowser> browser, FocusSource source)
{
    if ( source == FOCUS_SOURCE_SYSTEM )
        m_bHasFocus = true;
    else
        m_bHasFocus = false;

    return false;
}

void CaffeineClientHandler::OnGotFocus(CefRefPtr<CefBrowser> browser)
{
    m_bHasFocus = true;
}

bool CaffeineClientHandler::OnRequestGeolocationPermission(
                                                            CefRefPtr<CefBrowser> browser,
                                                            const CefString& requesting_url,
                                                            int request_id,
                                                            CefRefPtr<CefGeolocationCallback> callback) {
    
    app->ShellLog(L"OnRequestGeolocationPermission was called");
    // Allow geolocation access from all websites.
    //    callback->Continue(true);
    callback->Continue(false);
    return true;
}

void CaffeineClientHandler::CreateAndDispatchCustomEvent(const CefString &eventName, const CefString &obj)
{
    if (this->GetBrowser())
    {
        CefRefPtr<CefFrame> frame = this->GetBrowser()->GetMainFrame();
        if (frame.get() && frame->IsValid())
        {
            string jsCode =
                "var event = new CustomEvent(\"" + eventName.ToString() + "\", {bubbles: true, cancelable: true, detail: JSON.parse('" + obj.ToString() + "')});"
                "window.dispatchEvent(event);";
            frame->ExecuteJavaScript(jsCode, frame->GetURL(), 0);
        }
    }
}

bool CaffeineClientHandler::OnBeforeUnloadDialog(CefRefPtr<CefBrowser> browser, const CefString& message_text, bool is_reload, CefRefPtr<CefJSDialogCallback> callback)
{
    callback->Continue(false, "Cancel unload");
    return true;
}

bool CaffeineClientHandler::OnJSDialog(
    CefRefPtr<CefBrowser> browser,
    const CefString& origin_url,
    const CefString& accept_lang,
    JSDialogType dialog_type,
    const CefString& message_text,
    const CefString& default_prompt_text,
    CefRefPtr<CefJSDialogCallback> callback,
    bool& suppress_message)
{
    if (dialog_type == JSDIALOGTYPE_ALERT)
    {
#ifdef OS_WIN
        //  TODO:  Look up from the string table.
        MessageBox(m_MainHwnd, message_text.c_str(), FULL_PRODUCT, MB_OK);
#else
        wstring msg = message_text;
        alertMessage(msg);
#endif

        callback->Continue(true, message_text);
        return true;
    }


    return false;
}

///
// Called to run a file chooser dialog. |mode| represents the type of dialog
// to display. |title| to the title to be used for the dialog and may be empty
// to show the default title ("Open" or "Save" depending on the mode).
// |default_file_name| is the default file name to select in the dialog.
// |accept_types| is a list of valid lower-cased MIME types or file extensions
// specified in an input element and is used to restrict selectable files to
// such types. To display a custom dialog return true and execute |callback|
// either inline or at a later time. To display the default dialog return
// false.
///
/*--cef(optional_param=title,optional_param=default_file_name,
 optional_param=accept_types)--*/

#ifdef CUSTOM_FILE_DIALOGS
bool CaffeineClientHandler::OnFileDialog(CefRefPtr<CefBrowser> browser,
                                          FileDialogMode mode,
                                          const CefString& title,
                                          const CefString& default_file_name,
                                          const vector<CefString>& accept_types,
                                          CefRefPtr<CefFileDialogCallback> callback)
{
    vector<CefString> files;

    if ( FileDlg(files, mode, title, default_file_name, accept_types) )
        callback->Continue(files);
    else
        callback->Cancel();

    return true;
}

#endif


//
// OSR

bool CaffeineClientHandler::GetRootScreenRect(CefRefPtr<CefBrowser> browser,
                                      CefRect& rect) {
    if (!m_OSRHandler.get())
        return false;
    return m_OSRHandler->GetRootScreenRect(browser, rect);
}

bool CaffeineClientHandler::GetViewRect(CefRefPtr<CefBrowser> browser, CefRect& rect) {
    if (!m_OSRHandler.get())
        return false;
    return m_OSRHandler->GetViewRect(browser, rect);
}

bool CaffeineClientHandler::GetScreenPoint(CefRefPtr<CefBrowser> browser,
                                   int viewX,
                                   int viewY,
                                   int& screenX,
                                   int& screenY) {
    if (!m_OSRHandler.get())
        return false;
    return m_OSRHandler->GetScreenPoint(browser, viewX, viewY, screenX, screenY);
}

bool CaffeineClientHandler::GetScreenInfo(CefRefPtr<CefBrowser> browser,
                                  CefScreenInfo& screen_info) {
    if (!m_OSRHandler.get())
        return false;
    return m_OSRHandler->GetScreenInfo(browser, screen_info);
}

void CaffeineClientHandler::OnPopupShow(CefRefPtr<CefBrowser> browser,
                                bool show) {
    if (!m_OSRHandler.get())
        return;
    return m_OSRHandler->OnPopupShow(browser, show);
}

void CaffeineClientHandler::OnPopupSize(CefRefPtr<CefBrowser> browser,
                                const CefRect& rect) {
    if (!m_OSRHandler.get())
        return;
    return m_OSRHandler->OnPopupSize(browser, rect);
}

void CaffeineClientHandler::OnPaint(CefRefPtr<CefBrowser> browser,
                            PaintElementType type,
                            const RectList& dirtyRects,
                            const void* buffer,
                            int width,
                            int height) {
    if (!m_OSRHandler.get())
        return;
    m_OSRHandler->OnPaint(browser, type, dirtyRects, buffer, width, height);
}

void CaffeineClientHandler::OnCursorChange(CefRefPtr<CefBrowser> browser,
                                   CefCursorHandle cursor) {
    if (!m_OSRHandler.get())
        return;
    m_OSRHandler->OnCursorChange(browser, cursor);
}

void CaffeineClientHandler::SetMinWindowWidth(const int width)
{
    minWindowWidth = width;
}

void CaffeineClientHandler::SetMinWindowHeight(const int height)
{
    minWindowHeight = height;
}

int CaffeineClientHandler::GetMinWindowWidth()
{
    return minWindowWidth;
}

int CaffeineClientHandler::GetMinWindowHeight()
{
    return minWindowHeight;
}


