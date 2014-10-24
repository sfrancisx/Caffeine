//
//  mac_util.mm
//  McBrewery
//
//  Created by pereira on 3/16/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <string>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#include "include/cef_base.h"
#pragma clang diagnostic pop
#import "YAppDelegate.h"
#import "CaffeineClientApp.h"
#import "mac_util.h"
#import "CommonDefs.h"
#import "NSString_NSString_wstring.h"
#import "NSString_YMAdditions.h"
#import "MAAttachedWindow.h"
#import "YRTTManager.h"

#ifdef ENABLE_MUSIC_SHARE
    #import "Track.h"
#endif

extern std::string mainUUID ;
extern CefRefPtr<CaffeineClientApp> app;

extern int gCurrentOS;

#pragma mark --- required global functions -----------------

// Creates Popup window
void AppCreateWindow(const int height, const int width, const int left, const int top,const std::string& uuid, const char* initArg, bool frameless, bool resizable,
                     const std::string& target, const int minWidth, const int minHeight)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    if ( width > 0 && height > 0 )
    {
        NSRect frame = NSMakeRect(left, top, width, height);
        [appDel createWindow:uuid initArg:initArg size:&frame frameless:frameless resizable:resizable target:target minWidth:minWidth minHeight:minHeight];
    }
    else
    {
        [appDel createWindow:uuid initArg:initArg size:NULL  frameless:frameless resizable:resizable target:target minWidth:minWidth minHeight:minHeight];
    }
}

// Creates Docked Window
void AppCreateDockableWindow(const std::string& uuid, const std::string& initArg, const std::string& targetUUID,
                          const int width, const int minTop, const int minBottom)
{
    //YLog(LOG_NORMAL, @"Creating a Dockable Window %s docked to the Conv=%s, width=%d", uuid.c_str(), targetUUID.c_str(), width);
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel createDockable:uuid initArg:initArg.c_str() target:targetUUID width:width top:minTop bottom:minBottom];
}


// activates app and makes it front window
void activatesApp()
{
    [NSApp activateIgnoringOtherApps:TRUE];
}

// activates window
void activatesWindow(const std::string& uuid)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    YBreweryWindowController* ctrl = [appDel getWindowBy:uuid];
    if ( ctrl == nil ) return ;
    if ( [ctrl isDocked] == false )
    {
        //[NSApp activateIgnoringOtherApps:FALSE];
        [ctrl updateFrame];
        [ctrl.window makeKeyAndOrderFront: ctrl.window];
    }
}

void showWindow(const std::string& uuid)
{
#ifdef DEBUG
    YLog(LOG_NORMAL, @"Calling showWindow for %s", uuid.c_str());
#endif
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel showWindow:uuid];
}

void hideWindow(const std::string& uuid)
{
#ifdef DEBUG
    YLog(LOG_NORMAL, @"Calling hideWindow for %s", uuid.c_str());
#endif
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel hideWindow:uuid];
}

void windowTitleChange(CefRefPtr<CefBrowser> browser, const std::wstring& title)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel changeWindowTitle:browser newTitle:[NSString stringWithwstring:title]];    
}


void AppMoveOrResizeWindow(const std::string& uuid, const int left, const int top,  const int height, const int width)
{
    NSRect frame = NSMakeRect(left, top, width, height);
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel moveOrResizeWindow:uuid sizeAndPosition:&frame];
}

// called by logout notification in JS
void sessionLoggedIn(bool loggedIn)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel sessionLoggedInStateChange:loggedIn];
}

// called by mpop,etc in AppLogic notification in JS
void enableSessionMenus(bool value)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel enableSessionMenus:value];
}


// returns main handle
CefRefPtr<CaffeineClientHandler> AppGetMainHandler()
{
    return AppGetHandler(mainUUID);
}

// CEF AppGetMainHwnd
CefWindowHandle AppGetMainHwnd()
{
    CefRefPtr<CaffeineClientHandler> handler = AppGetMainHandler();
    if ( handler == NULL ) return NULL;
    return handler->GetMainHwnd();
}

// is this window the key window?
bool isWindowActive(const std::string& uuid)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    YBreweryWindowController* ctrl = [appDel getWindowBy:uuid];
    if ( ctrl == nil ) return false ;
    
    if ( [ctrl isDocked] == true )
        return false;
    
    return  [ctrl.window isKeyWindow];
}

// Notifications:
//   calls Growl/Mac notifications with new messages
void incomingMessage(const std::wstring& from, const std::wstring& displayName, const std::wstring& msg, const std::wstring& convId)
{
    if ( ([[NSString stringWithwstring:convId] length] > 0) && [NSApp isActive] )
    {
        return;
    }
    
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel incomingMessage:[NSString stringWithwstring:from]  displayName:[NSString stringWithwstring:displayName] msg:[NSString stringWithwstring:msg] convId:[NSString stringWithwstring:convId]];
}

void MainLoadingStateChanged(bool isLoading)
{
    if (isLoading == FALSE)
    {
        YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
        [appDel mainFinishedLoading];
    }    
}

#pragma mark ------ CEF utilities ---------

// gets CEF handler by UUID
CefRefPtr<CaffeineClientHandler> AppGetHandler(const std::string& uuid)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    YBreweryWindowController* ctrl = [appDel getWindowBy:uuid];
    if ( ctrl == nil ) return NULL;
    return [ctrl getHandler];
}

// gets CefBrowser by UUUID
CefRefPtr<CefBrowser> getBrowserByUUID(std::string& browser_handle)
{
    CefRefPtr<CefBrowser> browser = NULL;
    if (app->m_WindowHandler.find(browser_handle) != app->m_WindowHandler.end())
    {
        browser = app->m_WindowHandler[browser_handle]->GetBrowser();
    }
    return browser;
}

// gets CefFrame by UUID
CefRefPtr<CefFrame> getFrameByUUID(std::string& browser_handle)
{
    CefRefPtr<CefFrame> frame = NULL;
    CefRefPtr<CefBrowser> browser = getBrowserByUUID( browser_handle );
    if ( browser != NULL )
    {
        frame = browser->GetMainFrame();
    }
    
    if (frame != NULL && frame->IsValid())
    {
        return frame;
    }
    return NULL;
}

// notification for a renderer crash
void rendererCrashed(CefRefPtr<CefBrowser> browser)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel rendererHasCrashed:browser];
}


#pragma mark ------ flashing/notifications/badge counts -------------

void showViewMenu(bool showOrHide)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel showOrHideViewMenu:showOrHide];
}

void startFlashing(const std::string& uuid)
{
    /*
     YLog(LOG_NORMAL, @"Start flashing window %s", uuid.c_str());
    {
        // shaking
        YBreweryWindowController* ctrl = [[NSApp delegate] getWindowBy:uuid];
        [ctrl startShaking];
    }
    */
    
    // dock badge
    //changeBadgeCount(1);
}

void stopFlashing(const std::string& uuid)
{
    YLog(LOG_ONLY_IN_DEBUG, @"Stop flashing window %s", uuid.c_str());
}

void shakeWindow(const std::string& uuid)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel shakeWindow: uuid];
}

void bounceDockIcon()
{
    //[[NSApplication sharedApplication] requestUserAttention:NSInformationalRequest];
    // until app is active
    [[NSApplication sharedApplication] requestUserAttention:NSCriticalRequest];
}

void changeBadgeCount (int count, bool bRequest)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel setMsgCount: count bRequest: bRequest];
    
}
#pragma mark --- KC

void saveToken (const std::string& usr, const std::string& tok)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel setKCFromRenderer: [NSString stringWithUTF8String:tok.c_str()] forUser:[NSString stringWithUTF8String: usr.c_str()]];
}

void removeTokens ()
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel clearTokens];
}

void removeToken(const std::string& usr )
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel clearToken:[NSString stringWithUTF8String:usr.c_str()]];
}

#pragma --------------- file resource paths -------------------------

// allows use of non-default file location for development
//
NSString* getJSFilePath()
{
	BOOL runningAtLeast10_7 = floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6;
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    if ( appDel->inSandbox || ! runningAtLeast10_7 )
    {
        return [[NSBundle mainBundle] resourcePath];
    }
    
    NSString* strPath = [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultPath];
    if ( [strPath compare:[NSString stringWithUTF8String:defaultPathValue]] == NSOrderedSame )
    {
        return [[NSBundle mainBundle] resourcePath];
    }
    return strPath;
}

void validateFileResource(std::string& original)
{
#ifdef DEBUG
    YLog(LOG_ONLY_IN_DEBUG, @"Loading %s", original.c_str());
    if ( gCurrentOS >= OSX109 )
    {
        NSURL* originalURL = [[NSURL fileURLWithPath:[NSString stringWithUTF8String: original.c_str()] ] standardizedURL];
        if ( originalURL == nil || ![originalURL isFileURL]) return; // not a file}
        
        NSString* conv = [[originalURL path] stringByReplacingOccurrencesOfString:@"%20" withString:@" "];
        
        // ignore config.js
        if ( [conv rangeOfString:@"config.js"].location != NSNotFound ) return;

        if ( ! [[NSFileManager defaultManager] fileExistsAtPath:conv] )
        {
            YLog(LOG_MAXIMUM, @"ERROR: File %@ does NOT exist",conv);
        }
    }
#endif
}

#pragma mark ------------------ JS alert message ---------------------

void alertMessage(std::wstring& message)
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: NSLocalizedString(kAppTitle, kAppTitle)];
    [alert setInformativeText: [NSString stringWithwstring:message]];
    [alert addButtonWithTitle: NSLocalizedString(@"OK", @"OK")];
    [alert runModal];
    alert = nil;
    
}

#pragma mark --- CaffeineRequestClient request completed handler

void RequestCompleted( CefRefPtr<CefURLRequest> request, std::string& fileName  )
{
    CefURLRequest::Status status = request->GetRequestStatus();
    CefURLRequest::ErrorCode error_code = request->GetRequestError();
    //CefRefPtr<CefResponse> response = request->GetResponse();
    
    if ( fileName.length() > 0 && status == 0)
    {
        NSError* error = nil;
        NSString* zipFile = [NSString stringWithUTF8String:fileName.c_str()];
        [[NSFileManager defaultManager] removeItemAtPath:zipFile  error:&error];
        if ( error )
        {
            YLog(LOG_NORMAL, @"Error removing diagnostics zipfile %@", zipFile);
        }
    }
    YLog(LOG_NORMAL, @"Request completed with status=%d - error code = %d", status, error_code);
    
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel submitDone: ( error_code == 0 ?  TRUE : FALSE ) ];
}

#pragma mark ---- crashreport + logs -----

const int kYMVendorID = 101;                         //100; // legacy
const unsigned kDescriptionParameterMaxLength = 160;

void sendCrashReports(std::wstring wcomments, CefRefPtr<CefURLRequest> url_request)
{
    NSString* comments = [NSString stringWithwstring:wcomments ];
    NSString* buildNo = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	NSString *descriptionText = [comments stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([descriptionText length] > kDescriptionParameterMaxLength) {
		descriptionText = [[descriptionText substringToIndex:kDescriptionParameterMaxLength] stringByAppendingString:@"..."];
	}
    
    NSString* zipFile = compressLogFilesForEmail();
	NSData *zipData = [NSData dataWithContentsOfMappedFile:zipFile];
    
	NSString *baseURL = [NSString stringWithFormat: @"%@/upload?intl=%s&f=report.zip&bn=%@&r=%@&fr=0%@%@&vid=%d",
						 NSLocalizedStringFromTable(@"http://submit.msg.Caffeine.com", @"URLs", @"Problem Report form submit - YMReportProblemWindowController.m"),
						 app->currentLocale.c_str(),
						 [buildNo stringByEncodingIllegalURLCharacters],
						 [descriptionText stringByEncodingIllegalURLCharacters],
						 @"0100",   // OTHER category
						 @"0100",
						 kYMVendorID];
    
    YLog(LOG_NORMAL, @"Submit Diagnostics with URL=%@", baseURL);
    CefRefPtr<CefRequest> cefReq(CefRequest::Create());
    
    cefReq->SetURL([baseURL UTF8String]);
    cefReq->SetMethod("POST");
    
    // as of cef1916,UR_FLAG_ALLOW_COOKIES was merged into UR_FLAG_ALLOW_CACHED_CREDENTIALS
    // https://code.google.com/p/chromiumembedded/source/detail?spec=svn1678&r=1641
    cefReq->SetFlags(UR_FLAG_ALLOW_CACHED_CREDENTIALS);
    
    // Add post data to the request.  The correct method and content-
    // type headers will be set by CEF.
    CefRefPtr<CefPostDataElement> postDataElement(CefPostDataElement::Create());
    postDataElement->SetToBytes ([zipData length], [zipData bytes]);
    
    CefRefPtr<CefPostData> postData(CefPostData::Create());
    postData->AddElement(postDataElement);
    cefReq->SetPostData(postData);
    
    CefRequest::HeaderMap headerMap;
    headerMap.insert(std::make_pair("Content-Type", "application/zip"));
    cefReq->SetHeaderMap(headerMap);
    
    // Create the client instance.
    CefRefPtr<CaffeineRequestClient> client = new CaffeineRequestClient();
    client->uploadFile_ = [zipFile UTF8String];
    
    // Start the request. MyRequestClient callbacks will be executed asynchronously.
    url_request = CefURLRequest::Create(cefReq, client.get());
    // To cancel the request: url_request->Cancel();
}


void setFeedbackLink(const std::string& link)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    appDel->feedbackLink = [NSString stringWithUTF8String: link.c_str()];
}

#ifdef ENABLE_MUSIC_SHARE
#pragma mark =============== iTunes ====================

void isITunesOn(std::string name, int retvalInt ){
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0), ^{
        
        @try {
            //Track *aTrack = [[Track alloc] init];
            CefRefPtr<CefDictionaryValue> isOn = CefDictionaryValue::Create();
            CefString cefKey = [@"isOn" UTF8String];
            CefString cefValue;
            
            if([Track isITunesOn])
                cefValue = [@"1" UTF8String];
            else
                cefValue = [@"0" UTF8String];
            
            isOn->SetString(cefKey, cefValue);
            
            CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
            
            CefRefPtr<CaffeineClientHandler> handler = AppGetMainHandler();
            if ( handler.get() && callbackMsg.get() )
            {
                CefRefPtr<CefBrowser> browser = handler->GetBrowser();
                if ( browser.get() )
                {
                    callbackMsg->GetArgumentList()->SetString(0, name);
                    callbackMsg->GetArgumentList()->SetInt(1, retvalInt);
                    
                    callbackMsg->GetArgumentList()->SetDictionary(2, isOn);
                    browser->SendProcessMessage(PID_RENDERER, callbackMsg);
                }
            }
        }
        @catch (NSException *exception) {
            YLog(LOG_NORMAL, @"Exception when trying to find if iTunes is on - %@", [exception description]);
        }
        @finally {
        }
    });
}


void InternalITunesPlayPreview(const std::wstring& previewURL)
{
    
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel playMediaFile: [NSString stringWithwstring:previewURL]];
    
    /*
     NSArray* urls = [NSArray arrayWithObject: [NSURL URLWithString:[NSString stringWithwstring:previewURL]]];
    [[NSWorkspace sharedWorkspace] openURLs: urls
                    withAppBundleIdentifier:@"com.apple.QuickTimePlayerX"
                                    options:NSWorkspaceLaunchDefault
             additionalEventParamDescriptor:NULL
                          launchIdentifiers:NULL];
    */
    
    /*
     id qtApp = [SBApplication applicationWithBundleIdentifier:@"com.apple.QuickTimePlayerX"];
     
     
     NSURL *URL = [NSURL URLWithString:NSpreviewURL];
     
     [qtApp activate];
     if ([qtApp isRunning])
     [qtApp openURL:URL];
     */
}


void getITunesTrackInfo(std::string name, int retvalInt)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    
    CefRefPtr<CefDictionaryValue> TrackInfo = CefDictionaryValue::Create();
    if ([Track isITunesOn] && ![appDel isTheAppTerminating] )
    {
        /*
        static Track*   track = nil;
        if ( track == nil )
        {
            track = [[Track alloc] init];
        }
        NSDictionary* iTunesPlayerStat = [track getTrackInfo];
        */
        NSDictionary* iTunesPlayerStat = [appDel getCurrentiTunesPlayerStat];
        YLog(LOG_NORMAL, @"Reading track information (itunes is on) - song=%@", [iTunesPlayerStat valueForKey:@"song"]);
        
        for(NSString* key in iTunesPlayerStat)
        {
            CefString cefKey = [key UTF8String];
            CefString cefValue = [[iTunesPlayerStat valueForKey:key] UTF8String];
            TrackInfo->SetString((const CefString)cefKey, (const CefString)cefValue);
        }
    }
    else
    {
        YLog(LOG_NORMAL, @"Reading track information (itunes is OFF)");
        TrackInfo->SetString("isITunesOn", "0");
    }
    
    CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
    CefRefPtr<CaffeineClientHandler> handler = AppGetMainHandler();
    if ( handler.get() && callbackMsg.get() )
    {
        CefRefPtr<CefBrowser> browser = handler->GetBrowser();
        if ( browser.get() )
        {
            callbackMsg->GetArgumentList()->SetString(0, name);
            callbackMsg->GetArgumentList()->SetInt(1, retvalInt);
            
            callbackMsg->GetArgumentList()->SetDictionary(2, TrackInfo);
            browser->SendProcessMessage(PID_RENDERER, callbackMsg);
        }
    }
    
    
    /*
    dispatch_async(dispatch_get_global_queue(0, 0),^{
        
        Track *aTrack = [[Track alloc] init] ;
        NSDictionary *_trackInfo = [aTrack getTrackInfo];
        CefRefPtr<CefDictionaryValue> TrackInfo = CefDictionaryValue::Create();
        
        if ([Track isITunesOn]){
            for(NSString* key in _trackInfo){
                
                CefString cefKey = [key UTF8String];
                CefString cefValue = [[_trackInfo valueForKey:key] UTF8String];
                TrackInfo->SetString((const CefString)cefKey, (const CefString)cefValue);
            }
        }
        CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
        
        CefRefPtr<CaffeineClientHandler> handler = AppGetMainHandler();
        if ( handler.get() && callbackMsg.get() )
        {
            CefRefPtr<CefBrowser> browser = handler->GetBrowser();
            if ( browser.get() )
            {
                callbackMsg->GetArgumentList()->SetString(0, name);
                callbackMsg->GetArgumentList()->SetInt(1, retvalInt);
                
                callbackMsg->GetArgumentList()->SetDictionary(2, TrackInfo);
                browser->SendProcessMessage(PID_RENDERER, callbackMsg);
            }
        }
    });
    */
}

void getInstalledPlayers( std::string name, int retvalInt)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0), ^{
        
        @try {
            CefRefPtr<CefDictionaryValue> installedPlayers = CefDictionaryValue::Create();
            CefString cefKey = [@"iTunes" UTF8String];
            CefString cefValue;
            CFURLRef appURL = NULL;
            OSStatus result;
            
            //com.apple.QuickTimePlayer
            result = LSFindApplicationForInfo (kLSUnknownCreator, CFSTR("com.apple.iTunes"),NULL,NULL,&appURL);
            
            if(result == noErr)
                cefValue = [@"1" UTF8String];
            else
                cefValue = [@"0" UTF8String];
            
            installedPlayers->SetString(cefKey, cefValue);
            
            //the CFURLRef returned from the function is retained as per the docs so we must release it
            if(appURL)
                CFRelease(appURL);
            
            
            CefRefPtr<CefProcessMessage> callbackMsg = CefProcessMessage::Create("invokeCallback");
            CefRefPtr<CaffeineClientHandler> handler = AppGetMainHandler();
            if ( handler.get() && callbackMsg.get() )
            {
                CefRefPtr<CefBrowser> browser = handler->GetBrowser();
                if ( browser.get() )
                {
                    callbackMsg->GetArgumentList()->SetString(0, name);
                    callbackMsg->GetArgumentList()->SetInt(1, retvalInt);
                    
                    callbackMsg->GetArgumentList()->SetDictionary(2, installedPlayers);
                    browser->SendProcessMessage(PID_RENDERER, callbackMsg);
                }
            }
        }
        @catch (NSException *exception) {
            YLog(LOG_NORMAL, @"Exception when checking for installed players - %@", [exception description]);
        }
        @finally {
        }
    });

}
#endif  //ENABLE_MUSIC_SHARE

// wrapper to use NSLocalizedString in CPP files
std::wstring LocalizedWrapper( const std::wstring& textTitle, const std::wstring& defaultText )
{
    NSString* translated = NSLocalizedString([NSString stringWithwstring:textTitle], [NSString stringWithwstring: defaultText]);
    
    return [translated getwstring];
}


void mainWindowIsLoaded(bool isLoading)
{
    /*
    YLog(LOG_ONLY_IN_DEBUG, @"Main window loading = %d", isLoading);
    if ( isLoading == false )
    {
        YLog(LOG_NORMAL, @"Main window loading done");
    }
     */
}

bool getDefaultUserToken(std::string& usr, std::string& tok)
{
    NSString* defUser = [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultUserName];
    
    if ( defUser != nil )
    {
        YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
        NSString* token = [appDel getToken:defUser];
        if ( token != nil )
        {
            tok = [token UTF8String];
            usr = [defUser UTF8String];
            return true;
        }
    }
    return false;
}

#pragma mark ----- RTT2 glue calls

static YRTTManager* _rttManager = nil;


void createSocket(SOCKET s, const std::string host, UInt32 port, bool useSSL)
{
    if ( _rttManager == nil )
        _rttManager = [YRTTManager sharedManager];
    
    [_rttManager createSocket:[NSString stringWithUTF8String:host.c_str()] port:port useSSL:useSSL socket:s];
    
}

SOCKET createSocket(CefRefPtr<CefListValue> values )
{
    SOCKET s = values->GetInt(0);
    std::string host = values->GetString(1).ToString();
    uint32 port =  values->GetInt(2);
    bool useSSL =values->GetBool(3);
    createSocket(s, host, port, useSSL );
    return s;
}

void writeToSocket(SOCKET s, const std::string sdata)
{
    NSData* data = [NSData dataWithBytes:sdata.data() length:sdata.length()];
    [_rttManager writeToSocket:s data:data];
}

void writeToSocket(CefRefPtr<CefListValue> values)
{
    SOCKET s =  values->GetInt(0) ;
    std::string sdata = values->GetString(1);
    writeToSocket(s, sdata);
}

void closeSocket(SOCKET s)
{
    [_rttManager closeSocket:s];
}

void createCallback(SOCKET s, const char* callbackName, int errorCode, NSString* data)
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefProcessMessage> process_message = CefProcessMessage::Create("invokeSocketMethod");
        process_message->GetArgumentList()->SetInt(0, s);
        process_message->GetArgumentList()->SetString(1, callbackName);
        process_message->GetArgumentList()->SetInt(2, errorCode);
        
        if ( data != nil )
            process_message->GetArgumentList()->SetString(3, [data getwstring]);
        browser->SendProcessMessage(PID_RENDERER, process_message);
    }
    else
    {
        YLog(LOG_MAXIMUM, @"RTT2: error sending callback to socket %d - not default browser", s);
    }
}

void networkInterruption()
{
    if ( _rttManager != nil )
    {
        [ _rttManager netloss];
    }
}

#pragma mark -----  Bookmarks support ----------------------------

bool setDefaultDirectory(std::wstring dirName)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    NSString* dir = [appDel setPathDefaultDownloadBookmark];
    
    if ( dir == nil )
        return false;
    
    dirName = [dir getwstring];
    return true;
}

std::wstring getDefaultDirectory()
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    NSString* dir = [appDel getPathForDefaultDownload];
    return [dir getwstring];
}

bool saveFileDlg(std::vector<CefString>& file_paths)
{
    NSMutableArray* files = [[NSMutableArray alloc] init];
    
    for(std::vector<CefString>::const_iterator it = file_paths.begin(); it != file_paths.end(); it++)
    {
        std::wstring stype = *it;
        [files addObject: [NSString stringWithwstring: stype]];
    }
    
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    return  [appDel saveFilesToDownload:files];
}

#pragma mark ------ Files & Downloads ----------

std::wstring  getDownloadName(const std::wstring& file_name)
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    NSString* filePath = [NSString stringWithFormat:@"%@/%@",
                          [appDel getPathForDefaultDownload],
                          [NSString stringWithwstring:file_name]];
    
    YLog(LOG_NORMAL, @"GetDownloadName = %@", filePath);
    return [filePath getwstring];
}

std::wstring  setDownloadName(const std::wstring& file_name)
{
    //NSString* strFilePath = [NSString stringWithFormat:@"file://%@", [NSString stringWithwstring: file_name]];
    NSString* strFilePath = [NSString stringWithwstring: file_name];
    YLog(LOG_NORMAL, @"setDownloadName - set %@", strFilePath);
    
    /*
     YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
     
     
     //if ( appDel->inSandbox )
     {
         NSURL* folderURL = [NSURL URLWithString: strFilePath ];
         if ( strFilePath == nil )
         {
             YLog(LOG_NORMAL, @"Error setting NUSRL from %@", strFilePath);
         }
         else
         {
             YLog(LOG_NORMAL, @"Setting folder %@ as download default", folderURL);
             [appDel setDownloadBookmark: folderURL ] ;
         }
     }
    */
    return file_name;
}

bool openFileDlg(std::vector<CefString>& file_paths,
                 bool multiple,
                 bool allowDirectories,
                 const std::vector<CefString>& accept_types,
                 bool pickDirToSave)
{
    NSOpenPanel * openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:!allowDirectories];
    [openDlg setAllowsMultipleSelection:multiple];
    [openDlg setCanChooseDirectories:allowDirectories];
    [openDlg setCanCreateDirectories:TRUE];
    
    if ( pickDirToSave )
    {
        [openDlg setTitle:NSLocalizedString(@"Save", @"Save")];
        [openDlg setPrompt: NSLocalizedString(@"Save", @"Save") ];
    }
    
    NSMutableArray* fileTypes = [[NSMutableArray alloc] init];
    if ( accept_types.size() > 0 )
    {
        for(std::vector<CefString>::const_iterator it = accept_types.begin(); it != accept_types.end(); it++)
        {
            std::string stype = *it;
            NSString* type = [NSString stringWithUTF8String:stype.c_str()];
            if ( [type rangeOfString:@"image/*" options:NSCaseInsensitiveSearch].location != NSNotFound )
            {
                [fileTypes addObjectsFromArray: @[@"png", @"tiff", @"jpg", @"gif", @"jpeg"]];
            }
            else
            {
                [fileTypes addObject: type];
            }
            //YLog(LOG_NORMAL, @"openFileDlg type = %@", type);
        }
        
    }
    if ( [fileTypes count] > 0 )
        [openDlg setAllowedFileTypes:fileTypes];
    
    if ([openDlg runModal] == NSOKButton)
    {
        for (NSURL* url in openDlg.URLs )
        {
            NSString* file = [url path];
            file_paths.push_back([file getwstring]);
        }
        return true;
    }
    return false;
}


bool saveFileDlg(std::vector<CefString>& file_paths, std::wstring& default_file_name)
{
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    NSString* defFileName = [NSString stringWithwstring: default_file_name];
    
    [saveDlg setCanCreateDirectories:TRUE];
    [saveDlg setNameFieldStringValue: [defFileName lastPathComponent]];
    
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    NSString* downloads = [appDel getPathForDefaultDownload];
    
    NSURL* dirURL = [NSURL fileURLWithPath:downloads];
    [saveDlg setDirectoryURL: dirURL];
    
    YLog(LOG_NORMAL, @"Def file_name = %@, dirURL=%@", defFileName, [dirURL absoluteString]);
    
    if ([saveDlg runModal] == NSOKButton)
    {
        NSString* file = [[[saveDlg URL] path] lastPathComponent];
        NSString* directory = [[saveDlg directoryURL] path];
        
        YLog(LOG_NORMAL, @"File Save = %@ - directory = %@", file, directory);
        default_file_name = [file getwstring];
        file_paths.push_back([directory getwstring]);
        
        
        YLog(LOG_NORMAL, @"Setting folder %@ as download default", [saveDlg directoryURL]);
        [appDel setDownloadBookmark: [saveDlg directoryURL] ] ;
        
        return true;
    }
    return false;
}


#pragma mark --- RESOURCE URL -----

static NSString* lastResourceURL = nil;

void setLastResource(const std::string& url)
{
    lastResourceURL = [NSString stringWithUTF8String: url.c_str()];
}

NSString* getLastResource()
{
    return lastResourceURL;
}

// eof
