//  Copyright Yahoo! Inc. 2013-2014
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "CaffeineClientApp.h"  // NOLINT(build/include)
#include "AppExtensionHandler.h"
#include "ExtensionJS.h"

#ifdef ENABLE_MUSIC_SHARE
#include "CaffeineITunesMac.h"
#endif


#ifdef __APPLE__
void shellLogMac(const std::string& msg);
#endif

#include <sstream>
using namespace std;

#define MAIN_UUID "main"
// Main Window UUID
string mainUUID(MAIN_UUID);
int CaffeineClientApp::callback_counter = 0;

CaffeineClientApp::CaffeineClientApp() 
    : hwndRender(NULL),
        myUUID(MAIN_UUID),      // by default, uses the main UUID
                                // remote & docked windows should update it
   showFileSaveAsDialog(true),  // by default, show Save As
   shellHasLocationData(false), // by default, shell has no location
   windowIsKeyWindow(true),      // by default, window created is active
   isInsideInternalNetwork(false), // by default, it's not in the internal network
   ephemeralState(L"{}")
{
    // Default schemes that support cookies.
    cookieable_schemes_.push_back("http");
    cookieable_schemes_.push_back("https");
    
    browserPID = 0;

#ifdef ENABLE_MUSIC_SHARE
    iTunesTrackInfo = CefDictionaryValue::Create();
#endif
}

CaffeineClientApp::~CaffeineClientApp()
{
// CEF 2062
#ifdef __APPLE__
#else
    AutoLock lock_scope(this);
#endif
    
    
#ifdef __APPLE__
    closePersistentDB();
#endif
}

void CaffeineClientApp::SetMessageCallback(
    const string& message_name,
    int callback_number,
    CefRefPtr<CefV8Context> context,
    CefRefPtr<CefV8Value> function) 
{
    ASSERT(CefCurrentlyOn(TID_RENDERER));

// CEF 2062
#ifdef __APPLE__
#else
    AutoLock lock_scope(this);
#endif

    cbMap.insert(
        make_pair(
            make_pair(message_name, callback_number),
            make_pair(context, function)
        )
    );
}

bool CaffeineClientApp::RemoveMessageCallback(
    const string& message_name,
    int callback_number) 
{
    ASSERT(CefCurrentlyOn(TID_RENDERER));

// CEF 2062
#ifdef __APPLE__
#else
    AutoLock lock_scope(this);
#endif

    CallbackMap::iterator it =
        cbMap.find(make_pair(message_name, callback_number));
    if (it != cbMap.end()) {
        cbMap.erase(it);
        return true;
    }

    return false;
}

//  We might need an AutoLock here ...
void CaffeineClientApp::SetSocketCallback(SOCKET s, string state, CefRefPtr<CefV8Context> context, CefRefPtr<CefV8Value> function)
{
    ASSERT(CefCurrentlyOn(TID_RENDERER));
// CEF 2062
#ifdef __APPLE__
#else
    AutoLock lock_scope(this);
#endif
    
    sMap[s][state] = make_pair(context, function);
}

//  We might need an AutoLock here ...
bool  CaffeineClientApp::RemoveSocketCallback(SOCKET s)
{
    ASSERT(CefCurrentlyOn(TID_RENDERER));
// CEF 2062
#ifdef __APPLE__
#else
    AutoLock lock_scope(this);
#endif

    SocketMap::iterator it = sMap.find(s);
    if (it != sMap.end()) {
        sMap.erase(it);
        return true;
    }

    return false;
}

void CaffeineClientApp::OnContextInitialized()
{
    // Register cookieable schemes with the global cookie manager.
    CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager();
    ASSERT(manager.get());
    manager->SetSupportedSchemes(cookieable_schemes_);

    // Execute delegate callbacks.
    //BrowserDelegateSet::iterator it = browser_delegates_.begin();
    //for (; it != browser_delegates_.end(); ++it)
    //    (*it)->OnContextInitialized(this);
}

void CaffeineClientApp::OnBeforeChildProcessLaunch(
    CefRefPtr<CefCommandLine> command_line) 
{
}

bool CaffeineClientApp::OnBeforeNavigation(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefRequest> request,
    NavigationType navigation_type,
    bool is_redirect)
{
    return !IsValidRequestURL(request->GetURL());
}


// CefBrowserProcessHandler methods.
void CaffeineClientApp::OnRenderProcessThreadCreated(CefRefPtr<CefListValue> extra_info)
{
#ifdef __APPLE__
    extra_info->SetString(0, currentLocale);
    extra_info->SetInt(1, breweryGetpid());
    extra_info->SetInt(2, masterLogEnabled);
    
    static bool firstRender = true;

    // only the main render should receive the token
    if ( firstRender )
    {
        firstRender = false;
        string user;
        string token;
        if ( getDefaultUserToken( user, token ))
        {
            extra_info->SetString(3, user);
            extra_info->SetString(4, token);
        }
    }
#endif
}

// CefRenderProcessHandler methods.
void CaffeineClientApp::OnRenderThreadCreated(CefRefPtr<CefListValue> extra_info) {
#ifndef OS_WIN    
    if (extra_info->GetSize() > 0 )
    {
        currentLocale = extra_info->GetString(0);
        
        std::string msg = "Renderer - OnRenderThreadCreated " + currentLocale;
        shellLogMac( msg );
        
        browserPID = extra_info->GetInt(1);
        masterLogEnabled = extra_info->GetInt(2);
        
        if ( extra_info->GetSize() > 4 )
        {
            userTokens[extra_info->GetString(3)] = extra_info->GetString(4);
        }
    }
#endif    
}

//  TODO:  CEFContext needs to be a closure
void CaffeineClientApp::OnWebKitInitialized() 
{
    //ASSERT(CefCurrentlyOn(TID_UI));

     CefRegisterExtension("v8/Caffeine", caffeine_extension, new ClientAppExtensionHandler(this));
}

//  'document' is available here.
void CaffeineClientApp::OnContextCreated(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefV8Context> context) 
{
	beginJSExecutionStartTime.Now();
    frame->ExecuteJavaScript("String.prototype.getUTF8Size = function() { return Caffeine.CEFContext.getUTF8Size(this.toString()); }", frame->GetURL(), 0);
}

void CaffeineClientApp::OnContextReleased(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefV8Context> context) 
{
// CEF 2062
#ifdef __APPLE__
#else
    AutoLock lock_scope(this);
#endif

    //  Remove any JavaScript callbacks registered for the context that has been
    //  released.
    CallbackMap::iterator cbm_it = cbMap.begin();
    for (; cbm_it != cbMap.end();) {
        if (cbm_it->second.first->IsSame(context))
            cbMap.erase(cbm_it++);
        else
            ++cbm_it;
    }

#ifndef OS_WIN
    sMap.erase(sMap.begin(), sMap.end());
    wbMap.erase(wbMap.begin(), wbMap.end());
#else
    SocketMap::iterator sm_it = sMap.begin();
    for(; sm_it != sMap.end();)
    {
        bool cleanup = false;
        SocketMapEntry::iterator sme_it = sm_it->second.begin();
        for(; sme_it != sm_it->second.end();)
        {
            if(sme_it->second.first->IsSame(context))
            {
                cleanup = true;
                break;
            }
        }

        if(cleanup)
        {
            sMap.erase(sm_it++);
        }
        else
        {
            ++sm_it;
        }
    }

    WriteBufferMap::iterator wbm_it = wbMap.begin();
    for(; wbm_it != wbMap.end();)
    {
        bool cleanup = false;
        WriteBufferList::iterator wbl_it = wbm_it->second.begin();
        for(; wbl_it != wbm_it->second.end();)
        {
            if(wbl_it->second.first->IsSame(context))
            {
                cleanup = true;
                break;
            }
        }

        if(cleanup)
        {
            wbMap.erase(wbm_it++);
        }
        else
        {
            ++wbm_it;
        }
    }
    //scMap.erase(scMap.begin(), scMap.end());
#endif
}

void CaffeineClientApp::OnFocusedNodeChanged(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefDOMNode> node) 
{
}

bool CaffeineClientApp::OnProcessMessageReceived(
    CefRefPtr<CefBrowser> browser,
    CefProcessId source_process,
    CefRefPtr<CefProcessMessage> message) 
{
    ASSERT(CefCurrentlyOn(TID_RENDERER));
    //ASSERT(source_process == PID_BROWSER);

    bool handled = false;
    
    if(message->GetName() == "invokeCallback")
    {
        //  First find the callback object
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefString OriginalFn = retval->GetString(0);
        int CallbackNum = retval->GetInt(1);

        CaffeineClientApp::CallbackMap::iterator value = cbMap.find(CaffeineClientApp::CallbackMap::key_type(OriginalFn, CallbackNum));
        if(value != cbMap.end())
        {
            (value->second).first->Enter();
            //  Convert the status object to a V8 value
            CefRefPtr<CefDictionaryValue> StatusObject = retval->GetDictionary(2);
            CefRefPtr<CefV8Value> CallbackArg = CefV8Value::CreateObject(NULL);
            SetObject(StatusObject, CallbackArg);

            CefV8ValueList args;
            args.push_back(CallbackArg);

            ((value->second).second)->ExecuteFunction(NULL, args);
            (value->second).first->Exit();
            RemoveMessageCallback(OriginalFn, CallbackNum);

            //  Do any other bookkeeping?  Is this what the delegates were for?

            handled = true;
        }
    }
    else if(message->GetName() == "setHandle")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        hwndRender = reinterpret_cast<HWND>(retval->GetInt(0));
        handled = true;
    }
    else if(message->GetName() == "setBrowserPID")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        browserPID = retval->GetInt(0);
        handled = true;
    }
    else if(message->GetName() == "mainWindowCreationTime")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
		CefTime t1;
		CefRefPtr<CefBinaryValue> t2 = retval->GetBinary(0);
		t2->GetData(&t1, sizeof(t1), 0);

		stringstream ss;
		ss << "Caffeine.Performance.renderProcessCreation = new Date(" <<  (getRenderProcessCreationTime().GetTimeT() * 1000) << ");"
			<< "Caffeine.Performance.mainWindowCreation = new Date(" <<  (t1.GetTimeT() * 1000) << ");";

        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        frame->ExecuteJavaScript(ss.str(),  frame->GetURL(), 0 );

        handled = true;
    }
    else if(message->GetName() == "setUUID")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        myUUID = retval->GetString(0);
        handled = true;
    }
    else if(message->GetName() == "setLocationServices")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        shellHasLocationData = retval->GetBool(0);
        handled = true;
    }
    else if(message->GetName() == "setKeyWindow")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        windowIsKeyWindow = retval->GetBool(0);
        handled = true;
    }
    else if(message->GetName() == "changeInternalNetworkFlag")
    {
        isInsideInternalNetwork = message->GetArgumentList()->GetBool(0);
        handled = true;
    }
    
    else if(message->GetName() == "invokeSocketMethod")
    {
        handled = InvokeSocketMethod(message->GetArgumentList());
    }
    
    else if (message->GetName() == "lala")
    {
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        ephemeralState = retval->GetString(0);
        handled = true;
    }

    else if ( message->GetName() == "setLoggingLevelFrom" )
    {
#ifdef __APPLE__
        masterLogEnabled = message->GetArgumentList()->GetInt(0);
#endif
        handled = true;
    }
#ifdef __APPLE__
    else if(message->GetName() == "setDefUserToken")
    {
        CefRefPtr<CefListValue> list = message->GetArgumentList();
        userTokens[list->GetString(0)] = list->GetString(1);
        handled = true;
    }
#endif
    

    return handled;
}

// Enable media (WebRTC audio/video) streaming.
const char kEnableMediaStream[]           = "enable-media-stream";

const char kAllowFileAccessFromFiles[]    = "allow-file-access-from-files";

const char kDisableBreakpad[]             = "disable-breakpad";

// Force renderer accessibility to be on instead of enabling it on demand when
// a screen reader is detected. The disable-renderer-accessibility switch
// overrides this if present.
const char kForceRendererAccessibility[]    = "force-renderer-accessibility";


#ifdef OS_WIN // otherwise it causes a warning in the Mac static analysis

const char kDisableAcceleratedLayers[]    = "disable-accelerated-layers";

const char kDisableGPU[]                  = "disable-gpu";

#else

// disabling this to try to monitor energy consumption
//const char kGPUinProcess[]                = "in-process-gpu";

// Inform Chrome that a GPU context will not be lost in power saving mode,
// screen saving mode, etc.  Note that this flag does not ensure that a GPU
// context will never be lost in any situations, say, a GPU reset.
//const char kGpuNoContextLost[]              = "gpu-no-context-lost";

// Indicates whether the dual GPU switching is supported or not.
//const char kSupportsDualGpus[]              = "supports-dual-gpus";

// Overwrite the default GPU automatic switching behavior to force on
// integrated GPU or discrete GPU.
const char kGpuSwitching[]                  = "gpu-switching";

const char kGpuSwitchingOptionNameForceIntegrated[] = "force_integrated";
//const char kGpuSwitchingOptionNameForceDiscrete[]   = "force_discrete";

// When using CPU rasterizing disable low resolution tiling. This uses
// less power, particularly during animations, but more white may be seen
// during fast scrolling especially on slower devices.
const char kDisableLowResTiling[] = "disable-low-res-tiling";

// Disable the GPU process sandbox.
const char kDisableGpuSandbox[]             = "disable-gpu-sandbox";

// Disable rasterizer that writes directly to GPU memory.
// Overrides the kEnableMapImage flag.
const char kDisableMapImage[]               = "disable-map-image";

// Disable the thread that crashes the GPU process if it stops responding to
// messages.
//const char kDisableGpuWatchdog[]            = "disable-gpu-watchdog";


#endif


void CaffeineClientApp::OnBeforeCommandLineProcessing(const CefString& process_type,CefRefPtr<CefCommandLine> command_line)
{
    // add enabled media stream
    command_line->AppendSwitch(kEnableMediaStream);
    // add FileReader/Writer support
    command_line->AppendSwitch(kAllowFileAccessFromFiles);
    // disable breakpad
    command_line->AppendSwitch(kDisableBreakpad);
    
    command_line->AppendSwitch(kForceRendererAccessibility);

#ifdef OS_WIN
    
    command_line->AppendSwitch(kDisableGPU);
    
    //  Can get rid of this logic once we upgrade to cef 1750.
    if (!IsWindowsVistaOrGreater())
    {
        command_line->AppendSwitch(kDisableAcceleratedLayers);
    }
#else
    
    // Overwrite the default GPU automatic switching behavior to force on
    command_line->AppendSwitchWithValue(kGpuSwitching, kGpuSwitchingOptionNameForceIntegrated);
    // Disable rasterizer that writes directly to GPU memory.
    command_line->AppendSwitch(kDisableMapImage);
    // Disable the GPU process sandbox.
    command_line->AppendSwitch(kDisableGpuSandbox);
    // When using CPU rasterizing disable low resolution tiling. This uses less power,
    command_line->AppendSwitch(kDisableLowResTiling);
    
    // TODO: remove this after upgrading to chromium 37 or later:
    // https://code.google.com/p/chromium/issues/detail?id=389816
    // Disable the thread that crashes the GPU process if it stops responding to messages.
    //command_line->AppendSwitch(kDisableGpuWatchdog);
    

#endif
}

