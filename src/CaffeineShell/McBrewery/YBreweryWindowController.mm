//
//  YBreweryWindowController.m
//  McBrewery
//
//  Created by pereira on 3/21/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#import <QuartzCore/CoreAnimation.h>
#import "YBreweryWindowController.h"
#include <sstream>
#import "CommonDefs.h"
#import "mac_util.h"
#include "CaffeineClientApp.h"
#include "CaffeineClientUtils.h"
#import "MAAttachedWindow.h"
#import "YWindow.h"
#import <objc/runtime.h>
#import "NSImage_NSImage_saveAsPngWithName.h"
#import "YCefView.h"
#import "YAppDelegate.h"


// this window controller can be used with 3 different types of windows
// MAIN window
NSString* mainWindowNIB = @"YBreweryMainWindowController";

// popupWindow (Conversation, Video, etc)
NSString* conversationWindowNIB = @"YBreweryWindowController";
NSString* conversationWindowNRNIB = @"YBreweryWindowNRController";

// docked window
NSString* dockableWindowNIB = @"YBreweryDockingWindowController";

// frameless window
NSString* framelessWindowNIB = @"YBreweryWindowFrameless";

extern std::string mainUUID;
extern CefRefPtr<CaffeineClientApp> app;
NSString* getJSFilePath();
extern int gCurrentOS;


// docked window default values:
#define ATTACHED_WINDOW_TOP_BORDER  20.0
#define ATTACHED_WINDOW_MIN_HEIGHT  80.0
#define ATTACHED_MARGIN_HEIGHT      2.0
#define ATTACHED_BORDER_WIDTH       2.0
#define ATTACHED_CORNER_RADIUS      4.0

#define HIDDEN_FRAME_SIZE   0


//////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --- TABS (attached Window) configuration
#define ATTACHED_WINDOW_ALPHA   0.9
//#define ATTACHED_WINDOW_ALPHA   1.0

// defined default background for ATTACHED
static NSColor* backgroundColor = [NSColor colorWithCalibratedRed:37/255.0 green:42/255.0 blue:50/255.0 alpha:ATTACHED_WINDOW_ALPHA];
//static NSColor* backgroundColor = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];

// if the attached window is opaque or no (NO is the one used with the grey
#define ATTACHED_WINDOW_OPAQUE  NO
//#define ATTACHED_WINDOW_OPAQUE  YES
//////////////////////////////////////////////////////////////////////////////////////////////////////////////



// private definitions for YBreweryWindowController
@interface YBreweryWindowController ()

- (void) setOption:(id)sender optionName:(NSString*)optionName;

- (void) createCEFWindow:(NSView*)cefView target:(const std::string&) target;

- (void) drawRectOriginal:(NSRect)rect;
- (void) drawRect:(NSRect)rect;

- (void) loadBackgroundImage;

- (NSImage*) expCVImage:(NSView*)cv;

- (void) masterWindowDidResize:(NSNotification *)note;
- (void) masterWindowActivated:(NSNotification *)note;
- (void) masterWindowInactivated:(NSNotification *)note;

- (NSPoint) getClickPointForEvent:(NSEvent*)event inView:(NSView*) xview;

- (void)windowDidMoveNotification:(NSNotification *)note;
- (void)displayChanged:(NSNotification *)note;

- (NSArray*) subviews; // dummy function due to the Frame replacement

- (CGFloat) changeWindowMaxWidthBecauseOfDock:(NSRect)newFrame;
- (void) resizeMainWindowIfNeeded;

@end


// elimnate the warnings caused by the custom frame
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation YBreweryWindowController

// Initialization procedure
- (id) initWithWindowNibName:(NSString *)windowNibName target:(NSString*)target
{
    self = [super initWithWindowNibName:windowNibName];
    if (self) {
        //[self.window setFrameAutosaveName: target];
        windowCreationTime = [NSDate timeIntervalSinceReferenceDate];
        windowFirstShowTime = 0; // must be 0 for show check
        
        // Initialization code here.
        isFrameless = FALSE;
        isDocked = FALSE;
        
        isMainWindow = FALSE;
        windowIsHidden = TRUE;
        
        attachedWindow = nil;
        attachedView = nil;
        
        initArg = nil;
        
        self.lastTitle = @"Window";
    }
    YLog(LOG_NORMAL, @"Initializing Main Window with %@ and target %@", windowNibName, target);
    return self;
}

- (id) initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if ( self )
    {
        windowCreationTime = [NSDate timeIntervalSinceReferenceDate];
        windowFirstShowTime = 0; // must be 0 for show check
        
        isMainWindow = FALSE;
        windowIsHidden = true;
        
        attachedWindow = nil;
        attachedView = nil;

        isFrameless = FALSE;
        isDocked = FALSE;
        
        if ( [window styleMask] & NSBorderlessWindowMask )
            isFrameless = TRUE;
        
        if ( window == nil )
            isDocked = TRUE;
        
        self.lastTitle = @"Window";
    }
    return self;
}


// called after the window is loaded, but before anything is donew with CEF
- (void)windowDidLoad
{
    [super windowDidLoad];
    // NIB file ws loaded - non-OS activity starting
    
    targetUuid = "";
    
    bIsCurrentActive = true;
    closeWindowWithoutWaitingForCEF = false;
    
    dockedMinTop = ATTACHED_WINDOW_TOP_BORDER;
    dockedMinBottom = ATTACHED_WINDOW_TOP_BORDER;
    
    backgroundImage = nil;
    
    if ( isMainWindow )
    {
        [self.window display];
        
        NSString* strPath = [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultPath];
        if ( [strPath compare:[NSString stringWithUTF8String:defaultPathValue]] == NSOrderedSame )
        {
            [filesLocation setStringValue:@"Default"];
        }
        else
        {
            [filesLocation setStringValue:strPath];
        }
        
        BOOL blastCache = [[NSUserDefaults standardUserDefaults] boolForKey:kBlastCacheOnExit];
        if ( blastCache == TRUE )
            [removeCacheOnExit setState: NSOnState];
        else
            [removeCacheOnExit setState: NSOffState];
        
        if ( [[NSUserDefaults standardUserDefaults] boolForKey:kEnableWebGL] == TRUE )
        {
            [enableWebGL setState:NSOnState];
        }
        else
        {
            [enableWebGL setState:NSOffState];
        }
    }
    
    //[self customizeFrame];
}

- (bool) isDocked
{
    return isDocked;
}

- (bool) isMain;
{
    return isMainWindow;
}


#pragma mark ----- notifications ------------------

- (void)windowDidMoveNotification:(NSNotification *)note
{
    if (app->m_WindowHandler[uuid].get())
    {
        app->m_WindowHandler[uuid]->CreateAndDispatchCustomEvent("move");
    }
}

- (void)displayChanged:(NSNotification *)note
{
    //YLog(LOG_NORMAL, @"Received notification of display change - sending it a resize");
    // TODO: recalculate the windows sizes/positions without having to change the size
    
    // force resize
    NSRect mwin = [[attachedWindow parentWindow] frame];
    mwin.size.height += 10;
    mwin.size.width += 10;
    [[attachedWindow parentWindow] setFrame:mwin display:TRUE animate:FALSE];
    
    // restore
    mwin.size.height -= 10;
    mwin.size.width -= 10;
    [[attachedWindow parentWindow] setFrame:mwin display:TRUE animate:FALSE];
    //[mainView setNeedsDisplay:TRUE];
    //[self masterWindowDidResize:note];
}

// if the current controller is a docked window controller,
// this function should be called when the Master window (conversation) resizes
// and the size (height) should be changed 
- (void)masterWindowDidResize:(NSNotification *)note
{
    NSWindow* mainWin = [attachedWindow parentWindow];
    NSRect mainFrame = [mainWin frame];
    NSRect viewFrame = [attachedView frame];
    
    viewFrame.size.height = mainFrame.size.height - (dockedMinTop + dockedMinBottom);
    if ( viewFrame.size.height < ATTACHED_WINDOW_MIN_HEIGHT ) viewFrame.size.height  = ATTACHED_WINDOW_MIN_HEIGHT;
    viewFrame.origin.y = mainFrame.origin.y - dockedMinTop;
    
    // Changes view size based on sent info
    [attachedView setFrame:viewFrame];
    //[attachedWindow setFrame:viewFrame display:TRUE];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidResizeNotification object:attachedWindow];
    [attachedWindow display];
}

- (void) masterWindowActivated:(NSNotification *)note
{
    //[self getHandler]->CreateAndDispatchCustomEvent( "activated" );
}


- (void) activateOrDeactivate:(bool) activation
{
    if ( activation && ![NSApp isActive])
        activation = false;
    
    bIsCurrentActive = activation;
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel activateOrDeactivate:activation uuid:uuid];
}


- (void) masterWindowInactivated:(NSNotification *)note
{
    //[self getHandler]->CreateAndDispatchCustomEvent( "deactivated" );
}


// displays a native alert message
- (void)alert:(NSString*)title withMessage:(NSString*)message
{
    NSAlert *alert = [NSAlert alertWithMessageText:title
                                     defaultButton:@"OK"
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", message];
    [alert runModal];
}

// auxilary function for converting coordinates
// between Native and CEF JS
- (NSPoint)getClickPointForEvent:(NSEvent*)event inView:(NSView*) xview
{
    NSPoint windowLocal = [event locationInWindow];
    NSPoint contentLocal = [xview convertPoint:windowLocal fromView:nil];
    
    NSPoint point;
    point.x = contentLocal.x;
    point.y = [xview frame].size.height - contentLocal.y;  // Flip y.
    return point;
}

// Window becomes active
- (void)windowDidBecomeKey:(NSNotification*)notification
{
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    if (handler.get() && handler->GetBrowser().get() && handler->GetBrowserId())
    {
        // Give focus to the browser window.
        handler->GetBrowser()->GetHost()->SetFocus(true);
        handler->GetBrowser()->GetHost()->SendFocusEvent(true);

        [self activateOrDeactivate:true];
        
        /*
        // with a docked window, we want it to behave as if it's part of the conversation window
        // so when the window becomes key, we create a second key event and send it to CEF
        // to simulate a user clicking
        // to solve "Need 2 clicks to select a tab" problem
        if ( isDocked )
        {
            NSPoint mouseLoc;
            mouseLoc = [NSEvent mouseLocation]; //get current mouse position in screen coordinates
            //YLog(LOG_NORMAL, @"Docked Tab click - Mouse location: %f %f", mouseLoc.x, mouseLoc.y);
            
            NSPoint contentLocal = [attachedWindow convertScreenToBase: mouseLoc];
            
            CefMouseEvent mouseEvent;
            mouseEvent.x = contentLocal.x;
            mouseEvent.y = [attachedWindow frame].size.height - contentLocal.y; // flip y
            //YLog(LOG_NORMAL, @"Docked Tab click - Converted to - Mouse location: %d %d", mouseEvent.x, mouseEvent.y);
            
            mouseEvent.modifiers  = EVENTFLAG_LEFT_MOUSE_BUTTON;
            if (handler.get())
            {
                handler->GetBrowser()->GetHost()->SendMouseClickEvent(mouseEvent, MBT_LEFT, false, 1);
                handler->GetBrowser()->GetHost()->SendMouseClickEvent(mouseEvent, MBT_LEFT, true, 2);
            }
            
            //[attachedWindow orderWindow:NSWindowBelow relativeTo:[self.window windowNumber]];
        }
         */
    }
    
    /*
    if ( !isDocked )
        [self updateFrame];
    */
}

- (void) sendMouseMovement: (NSWindow*) winMouse
{
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    if (handler.get() && handler->GetBrowser().get() && handler->GetBrowserId())
    {
        NSPoint mouseLoc;
        mouseLoc = [NSEvent mouseLocation]; //get current mouse position in screen coordinates
        //YLog(LOG_NORMAL, @"Docked Tab click - Mouse location: %f %f", mouseLoc.x, mouseLoc.y);
        
        //NSPoint contentLocal = [winMouse convertScreenToBase: mouseLoc];
        NSRect mouseRect = NSMakeRect(mouseLoc.x, mouseLoc.y, 1, 1);
        NSRect localRect = [winMouse convertRectFromScreen: mouseRect];
        
        CefMouseEvent mouseEvent;
        mouseEvent.x = localRect.origin.x;
        mouseEvent.y = [winMouse frame].size.height - localRect.origin.y; // flip y
        //YLog(LOG_NORMAL, @"Docked Tab click - Converted to - Mouse location: %d %d", mouseEvent.x, mouseEvent.y);
        
        //mouseEvent.modifiers  = EVENTFLAG_LEFT_MOUSE_BUTTON;
        if (handler.get())
        {
            handler->GetBrowser()->GetHost()->SendMouseMoveEvent(mouseEvent, false);
            handler->GetBrowser()->GetHost()->SendMouseMoveEvent(mouseEvent, true);
        }
    }
}

// update the frame
- (void) updateFrame
{
    NSView* frameView = [[self.window contentView] superview];
    [frameView setNeedsDisplay:YES];
}

// window loses focus
- (void)windowDidResignKey:(NSNotification *)notification {
    
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    if (handler.get() && handler->GetBrowser().get() && handler->GetBrowserId())
    {
        handler->GetBrowser()->GetHost()->SetFocus(false);
        handler->GetBrowser()->GetHost()->SendFocusEvent(false);

        //YLog(LOG_NORMAL, @"Window %s lost keyWindow", uuid.c_str());
        [self activateOrDeactivate:false];        
    }
    
    //[self updateFrame];
}

- (void) hide
{
    windowIsHidden = true;
    //YLog(LOG_NORMAL, @"Hide: for windows %s", uuid.c_str());
    if ( !isDocked )
    {
        [self.window orderOut:self];
        [self.window setExcludedFromWindowsMenu:YES];
    }
    else if ( attachedWindow != nil )
    {
        YLog(LOG_NORMAL, @"Hiding DOCKED window %s", uuid.c_str());
        [self setAttachedTransparency:0.0];
    }
    
    [self activateOrDeactivate:false];
}

- (bool) windowWasShownFromJS
{
    if ( windowFirstShowTime == 0 ) return  false;
    return true;
}

- (void) show
{
    if ( windowFirstShowTime == 0 )
    {
        windowFirstShowTime = [NSDate timeIntervalSinceReferenceDate];
        YLog(LOG_NORMAL, @"Window Creation Timing: %s - time from Window creation to first show call: %f seconds",
             uuid.c_str(), windowFirstShowTime - windowCreationTime);
        
        [NSApp addWindowsItem:self.window title:self.lastTitle filename:FALSE];
    }

    if ( !isDocked )
    {
        // note: without this, when starting the Mac with auto start for Msg - as Hidden - will crash when receiving a showWindow from JS without being properly initialized
        if ( [self.window canBecomeMainWindow] )
            return;
    }
    else if ( attachedWindow != nil )
    {
        YLog(LOG_NORMAL, @"Showing DOCKED window %s", uuid.c_str());
    }
    
    //YLog(LOG_NORMAL, @"Show: for windows %s", uuid.c_str());
    windowIsHidden = false;
    
    // there are 3 types of windows:
    //  main for the main (contacts window)
    //  docked for the dockedwindow
    //  and all others
    if ( !isDocked)
    {
        // makes it the key window to accept input in the window, and puts it in the front
        // this causes a window opened due to someone sending the user a message to popop in front of the user
        [self.window makeKeyAndOrderFront:self];
        
        // shows in the all windows menu
        //[win.window setExcludedFromWindowsMenu:NO];
    }
    else
    {
        [self setAttachedTransparency:ATTACHED_WINDOW_ALPHA];
    }
    
    if ( isMainWindow )
    {
        [self.window makeMainWindow];
        [self.window makeKeyAndOrderFront:self];
    }
}

- (bool) isHidden
{
    //YLog(LOG_NORMAL, @"IsHidden: for windows %s - %d", uuid.c_str(), windowIsHidden);
    return windowIsHidden;
}

- (MAAttachedWindow*) getAttachedWindow
{
    return attachedWindow;
}

- (void) setAttachedTransparency:(float) value
{
    if ( attachedView )
    {
        [attachedView setAlphaValue:value];
    }
    if ( attachedWindow )
    {
        [attachedWindow setAlphaValue:value];
        
        if ( value == 0 )
        {
            [attachedWindow setBorderColor:[NSColor clearColor]];
            [attachedWindow setBackgroundColor:[NSColor clearColor]];
        }
        else
        {
            [attachedWindow setBorderColor:backgroundColor];
            [attachedWindow setBackgroundColor:backgroundColor];
            
            // redo dock when it becomes visible
            [attachedWindow displayChanged:nil];
        }
    }
    [self resizeMainWindowIfNeeded];
}

// CEF Messager Handler calls
- (IBAction)goBack:(id)sender {
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    if (handler.get() && handler->GetBrowserId())
        handler->GetBrowser()->GoBack();
}

- (IBAction)goForward:(id)sender {
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    if (handler.get() && handler->GetBrowserId())
        handler->GetBrowser()->GoForward();
}

- (IBAction)reload:(id)sender {
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    if (handler.get() && handler->GetBrowserId())
        handler->GetBrowser()->Reload();
}

- (IBAction)stopLoading:(id)sender {
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    if (handler.get() && handler->GetBrowserId())
        handler->GetBrowser()->StopLoad();
}

- (IBAction)takeURLStringValueFrom:(NSTextField *)sender {
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    if (!handler.get() || !handler->GetBrowserId())
        return;
    
    NSString *url = [sender stringValue];
    
    // if it doesn't already have a prefix, add http. If we can't parse it,
    // just don't bother rather than making things worse.
    NSURL* tempUrl = [NSURL URLWithString:url];
    if (tempUrl && ![tempUrl scheme])
        url = [@"http://" stringByAppendingString:url];
    
    std::string urlStr = [url UTF8String];
    handler->GetBrowser()->GetMainFrame()->LoadURL(urlStr);
}

- (void)notifyConsoleMessage:(id)object {
    /*
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    std::stringstream ss;
    ss << "Console messages will be written to " << handler->GetLogFile();
    */
}

- (void)notifyDownloadComplete:(id)object {
    /*
    std::stringstream ss;
    ss << "File \"" << "download " << //handler->m_LastDownloadFile <<
    "\" downloaded successfully.";
    NSString* str = [NSString stringWithUTF8String:(ss.str().c_str())];
    [self alert:@"File Download" withMessage:str];
     */
}

- (void)notifyDownloadError:(id)object {
     /*
    std::stringstream ss;
    ss << "File \"" << "download " << //handler->m_LastDownloadFile <<
    "\" failed to download.";
    NSString* str = [NSString stringWithUTF8String:(ss.str().c_str())];
    [self alert:@"File Download" withMessage:str];
      */
}

- (void)reloadStopAndPage
{
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    if (handler.get() && handler->GetBrowserId())
    {
        handler->GetBrowser()->StopLoad();
        handler->GetBrowser()->Reload();
    }
}

- (void) removeAttachedWindowFromHierarchy
{
    // validate if we have an attached window
    for (NSWindow* child in self.window.childWindows)
    {
        if ( [child isKindOfClass:[MAAttachedWindow class]])
        {
            // remove docked window from this window hierarchy
            [self.window removeChildWindow:child];
            YLog(LOG_NORMAL, @"Found a child window that was removed from the hierarchy");
            
            // if the JS sends a close, we won't need this
            // send notification - to clear controller for docked window's window member
            //[[NSNotificationCenter defaultCenter] postNotificationName:CSDockedWindowCloseNotification object:child];
        }
    }
}

// the window process
// this function should only be called AFTER the JS code
// had a change to run the unload event 
- (void)windowWillClose:(NSNotification *)notification
{
    YLog(LOG_NORMAL, @"windowWillClose window %s", uuid.c_str());
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if ( !isDocked )
    {
        [self removeAttachedWindowFromHierarchy];
    }
    
    // notify the appdelegate that we are closing
    NSString* strUUID = [NSString stringWithUTF8String: uuid.c_str()];
    [[NSNotificationCenter defaultCenter] postNotificationName:CSWindowCloseNotification object:strUUID];
}

// start the 2-step CEF window closing process!
- (BOOL) startClosingCEF
{
    YLog(LOG_NORMAL, @"startClosingCEF called for window=%s", uuid.c_str());
    CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
    if (handler.get() && !handler->IsClosing())
    {
        CefRefPtr<CefBrowser> browser = handler->GetBrowser();
        if (browser.get())
        {
            // Notify the browser window that we would like to close it. This
            // will result in a call to ClientHandler::DoClose() if the
            // JavaScript 'onbeforeunload' event handler allows it.
            browser->GetHost()->CloseBrowser(false);
            
            return NO;
        }
    }
    return YES;
}

- (BOOL)windowShouldClose:(id)window
{
    YLog(LOG_NORMAL, @"windowShouldClose called for window=%s", uuid.c_str());
    // closeWindowWithoutWaitingForCEF is only set on reset caffeine
    if ( closeWindowWithoutWaitingForCEF == true ) return true;
    
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    if ( appDel->theAppHasToTerminateNow || appDel->theAppReceivedAPowerOff ||appDel->theAppReceivedUpdateNOW ) return YES;
    
    if ( uuid == mainUUID && ! [appDel isTheAppTerminating] )
    {
        CefRefPtr<CaffeineClientHandler> handler = [self getHandler];
        if (handler.get() && handler->IsClosing())
        {
            return YES;
        }
        [appDel hideWindow: uuid];
        return NO;        
    }
    return [self startClosingCEF];
}

- (void) closesAttachedWindow
{
    YLog(LOG_NORMAL, @"closesAttachedWindow called for window=%s", uuid.c_str());
    if ( attachedWindow == nil ) return;
    
    [attachedView stopKeyMonitor];
    
    [attachedWindow removeParentWindowForCleaning];
    self.window = nil;
    
    // calls CEF to close itself
    // performClose on the attached window, after being removed from the parent, won't
    // call the controller windowShouldClose
    [self startClosingCEF];
    
    //app->m_WindowHandler.erase(uuid);
}


// Deletes itself.
- (void)cleanup:(id)window {
}

#pragma mark --- preferences sheet --------------
- (IBAction)hideDrawer:(id)sender
{
    [drawer close];
}

- (IBAction)showDrawer:(id)sender
{
    if ( drawer.state == NSDrawerOpenState )
    {
        [drawer close];
    }
    else
    {
        [drawer openOnEdge:NSMaxXEdge];
    }
}

- (IBAction)setDefaultPath:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithUTF8String:defaultPathValue] forKey:kDefaultPath];
    [filesLocation setStringValue:[NSString stringWithUTF8String: defaultPathValue]];
}

- (IBAction)setOthertPath:(id)sender
{
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:NO];    
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:NO];
    
    // Display the dialog.  If the OK button was pressed,
    // process the files.
    if ( [panel runModalForDirectory:nil file:nil] == NSOKButton )
    {
        // Get an array containing the full filenames of all
        // files and directories selected.
        NSArray* files = [panel filenames];

        if ( [files count] == 1 )
        {
            NSString* newPath = [files objectAtIndex:0];
            [[NSUserDefaults standardUserDefaults] setObject:newPath forKey:kDefaultPath];
            [filesLocation setStringValue:newPath];
        }
    }
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
}

#pragma mark --- UUID & CaffeineClientHandler handling ------------------------


- (void) createCEFWindow:(NSView*)contentView target:(const std::string&) target
{
    CefTime startTime;
    startTime.Now();
    
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    windowTargetType = target;
    
    // Create the handler.
    CefRefPtr<CaffeineClientHandler> handler = new CaffeineClientHandler();
    handler->SetMainHwnd(contentView);
   
    // setup the handler
    handler->uuid = uuid;    
    app->m_WindowHandler[uuid] = handler;
    
    // Create the browser view.
    CefWindowInfo window_info;
    CefBrowserSettings browser_settings;
    
    if ( target != "ymail" )
    {
        // if target is a browser window - YMAL - do NOT disable security
        // instead, use default flags
        
        browser_settings.universal_access_from_file_urls = STATE_ENABLED;
        //browser_settings.file_access_from_file_urls = STATE_ENABLED;
        browser_settings.web_security = STATE_DISABLED;
        browser_settings.local_storage = STATE_ENABLED;
        browser_settings.application_cache = STATE_DISABLED;
        browser_settings.javascript_open_windows = STATE_DISABLED;
        browser_settings.java = STATE_DISABLED;
    }
    
    BOOL useWebGL = true;   //[[NSUserDefaults standardUserDefaults] boolForKey:kEnableWebGL];
    
    /*
    if ( appDel->macWithWithResolutionDisplay == false && gCurrentOS >= OSX109 )
    {
        YLog(LOG_NORMAL, @"We didn't detect a Retina display, disabling webGL");
        browser_settings.webgl = STATE_DISABLED;
        //browser_settings.accelerated_compositing = STATE_ENABLED;
    }
    else 
    */
    {
        if (gCurrentOS <= OSX107)
        {
            YLog(LOG_NORMAL, @"We are in OSX: %d - disabling webGL - version = %f", gCurrentOS, NSAppKitVersionNumber);
            useWebGL = false;
        }
        
        //changing this might affect the rMBP with 10.7 (as we saw before) - commenting this out for extra testing first
        if ( useWebGL == true )
        {
            browser_settings.webgl = STATE_ENABLED;
            //browser_settings.accelerated_compositing = STATE_ENABLED;
        }
        else
        {
            browser_settings.webgl = STATE_DISABLED;
            //browser_settings.accelerated_compositing = STATE_DISABLED;
        }
    }
    
    YLog(LOG_NORMAL, @"WebGL is %d retinaMac:%d", useWebGL, appDel->macWithWithResolutionDisplay);
    NSString* spath = [@"file:" stringByAppendingString:getJSFilePath()];
    YLog(LOG_NORMAL, @"JS File Path is %@", spath);
    std::string path = [spath UTF8String];
    
    if ( uuid ==  mainUUID )
    {
        path = path + "/stub.html";
        if ( AppGetCommandLine()->HasSwitch( "querystring" ) )
        {
            std::string str = AppGetCommandLine()->GetSwitchValue("querystring");
            //YLog(LOG_NORMAL, @"QUERYSTRING  is (%s)", str.c_str());
            path = path  + "?" + str ;
        }
    }
    else
    {
        if ( initArg != nil )
        {
            handler->browserInitArg = [initArg cStringUsingEncoding:NSUTF8StringEncoding];
        }
        path =  path + "/stub2.html";
    }
    
    
    handler->m_MainBrowser = NULL;
    window_info.SetAsChild(handler->GetMainHwnd(), 0, 0, contentView.frame.size.width, contentView.frame.size.height);
    
    // CEF 3.1916.1662+
    handler->m_MainBrowser = CefBrowserHost::CreateBrowserSync( window_info, handler.get(), path, browser_settings, NULL );
    
    [[[self.window contentView] superview] setNeedsDisplay:YES];
    
    if ( uuid == mainUUID )
    {
        [appDel updateRenderer:handler->m_MainBrowser];
    }
    
    int currentProcess = [[NSProcessInfo processInfo] processIdentifier];
    CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("setBrowserPID");
    message->GetArgumentList()->SetInt(0, currentProcess);
    if ( handler->GetBrowser().get() )
        handler->GetBrowser()->SendProcessMessage(PID_RENDERER, message);
    
    if ( (uuid ==  mainUUID) && (handler->GetBrowser().get()) )
    {
        CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("mainWindowCreationTime");
        CefRefPtr<CefBinaryValue> timeVal = CefBinaryValue::Create(&startTime, sizeof(CefTime));
        message->GetArgumentList()->SetBinary(0, timeVal);
        handler->GetBrowser()->SendProcessMessage(PID_RENDERER, message);
    }
    
    if ( ! isDocked ) {
        windowIsHidden = false;
    }
    
    YLog(LOG_NORMAL, @"Finished loading %s window", uuid.c_str());
}

// ----------------------------------------
// Initializes CEF window / UUID
// this function is ONLY to be used for
//   MAIN and Conversation(popup) windows
//   NOT to be used with docked windows that need a different initialization
- (void) setUUID:(const std::string&) u initArg:(const char*) ia  target:(const std::string&) target
{
    uuid = u;
    if ( ia != NULL )
        initArg = [NSString stringWithUTF8String: ia];
    else
    {
        if ( initArg != nil )
        {
            initArg = nil;
        }
    }
    
    // these are only used in DOCKED windows
    attachedWindow = nil;
    attachedView = nil;
    
    self.window.delegate = self;
    NSView* contentView = [self.window contentView];
    [self.window setReleasedWhenClosed:NO];

    [self createCEFWindow:contentView target:target];
    
    if ( target == "yinc")
    {
        [self show];
        targetUuid = target;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidMoveNotification:)
                                                 name:NSWindowDidMoveNotification
                                               object:nil];
}

// --------------------------------------------------------------------------------------------
// Initializes CEF window / UUID
// this function is ONLY to be used for
//   DOCKED WINDOWS
- (void) setUUID:(const std::string &)u initArg:(const char *)ia attachedTo:(NSWindow*) mainWindow width:(int)width top:(int)minTop bottom:(int)minBottom
{
    uuid = u;
    dockedMinTop = minTop;
    dockedMinBottom = minBottom;
    
    if ( ia != NULL )
        initArg = [NSString stringWithUTF8String: ia];
    else
    {
        if ( initArg != nil )
        {
            initArg = nil;
        }
    }
    
    // determines original dock window size
    NSRect mainFrame = [mainWindow frame];
    NSRect viewFrame;
    
    // because of the corners, we add 20 to the width, and put them
    // underneath the conversation window
    viewFrame.size.width = width + HIDDEN_FRAME_SIZE;
    viewFrame.size.height = mainFrame.size.height - (dockedMinTop + dockedMinBottom + ATTACHED_MARGIN_HEIGHT);
    if ( viewFrame.size.height < ATTACHED_WINDOW_MIN_HEIGHT ) viewFrame.size.height  = ATTACHED_WINDOW_MIN_HEIGHT;
    viewFrame.origin.y = mainFrame.origin.y - dockedMinTop - ATTACHED_MARGIN_HEIGHT;
    viewFrame.origin.x = 0;

    // diffy - magic point!
    // the MAAttachedWindow code is designed to have a point to anchor to
    // with optionally an arrow, etc to that point
    // this diffy is the magic point, and these values work with the parameters we send below
    CGFloat diffy = mainFrame.size.height - viewFrame.size.height - 10;
    NSPoint buttonPoint = NSMakePoint(0, diffy);
    
    // Changes view size based on sent info
    attachedView = [[YAttachedView alloc] initWithFrame:viewFrame];
    
    attachedWindow = [[MAAttachedWindow alloc] initWithView:attachedView
                                                 attachedToPoint:buttonPoint
                                                        inWindow: mainWindow
                                                          onSide:MAPositionLeftTop
                                                      atDistance:0];
    
    // for DOCKED Windows, self.window is the CONVERSATION, not tab
    self.window = nil ; // this will be set when the DOCKED window is first sent a SHOW_WINDOW

    // set up delegate
    attachedWindow.delegate = self;
    
    [attachedWindow setHasArrow:FALSE];
    [attachedWindow setArrowHeight:0];
    [attachedWindow setBorderWidth:ATTACHED_BORDER_WIDTH];
    [attachedWindow setBorderColor:[NSColor clearColor]];
    [attachedWindow setViewMargin:ATTACHED_MARGIN_HEIGHT];
    [attachedWindow setCornerRadius:ATTACHED_CORNER_RADIUS];
    [attachedWindow setBackgroundColor:backgroundColor];
    [attachedWindow setOpaque:ATTACHED_WINDOW_OPAQUE];
    
    [attachedWindow showRightCorner:FALSE];
    
    [self setAttachedTransparency:0.0];  // creating it hidden
    
    [attachedView startKeyMonitor: mainWindow.windowNumber];
    
    [self createCEFWindow:attachedView target:""];
    
    // the dock is created as a child for the conversation window
    [mainWindow addChildWindow:attachedWindow ordered:NSWindowBelow];
    
    // Subscribe to notifications for when we change size.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(masterWindowDidResize:)
                                                 name:NSWindowDidResizeNotification
                                               object:mainWindow];

    
    // Subscribe to notifications for when master window gets active/inactive
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(masterWindowActivated:)
                                                 name:CSDockedWindowConvIsActive
                                               object:mainWindow];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(masterWindowInactivated:)
                                                 name:CSDockedWindowConvIsInactive
                                               object:mainWindow];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(displayChanged:)
                                                 name: CSDisplayChange
                                               object: nil];
    
}

- (NSWindow*) currWindow
{
    return self.window;
}

- (std::string&) getUUID
{
    return uuid;
}

- (CefRefPtr<CaffeineClientHandler> ) getHandler
{
    return (app->m_WindowHandler[uuid] );
}

- (void) customizeFrame
{
	// Get window's frame view class
    NSView* frameView = [[self.window contentView] superview];
	id sclass = [frameView class];
    
	// Exchange draw rect
    Method mtest = class_getInstanceMethod(sclass, @selector(drawRectOriginal:));
    if ( mtest == nil )
    {
        Method m0 = class_getInstanceMethod([self class], @selector(drawRect:));
        class_addMethod(sclass, @selector(drawRectOriginal:), method_getImplementation(m0), method_getTypeEncoding(m0));
        
        Method m1 = class_getInstanceMethod(sclass, @selector(drawRect:));
        Method m2 = class_getInstanceMethod(sclass, @selector(drawRectOriginal:));
        
        method_exchangeImplementations(m1, m2);
    }
    
    [frameView setNeedsDisplay:YES];
}

// creates a NSImage
// based on what the NSView is currently displaying in screen
- (NSImage*) expCVImage:(NSView*)cv
{
    NSRect windowRect = [cv frame];
    NSSize imgSize = NSMakeSize( windowRect.size.width, windowRect.size.height );
    
    NSBitmapImageRep *bir = [cv bitmapImageRepForCachingDisplayInRect:windowRect];
    [bir setSize:imgSize];
    [cv cacheDisplayInRect:windowRect toBitmapImageRep:bir];
    
    NSImage* image = [[NSImage alloc]initWithSize:imgSize];
    [image addRepresentation:bir];
    
    return image;
}

#define HEIGHT_SRC  4
#define HEIGHT_IMG  24

// draw rect is to be used for the frame
// and replace the original drawRect
- (void)drawRect:(NSRect)rect
{
	[self drawRectOriginal:rect];
    
    NSObject* parentID = [self window];
    if ( isDocked || ![parentID isKindOfClass: [NSWindow class]])
    {
        return;
    }
    
    bool hasYCefView = false;

#pragma GCC diagnostic ignored "-Wobjc-method-access"
    for ( NSView* subv in [self subviews] )
#pragma GCC diagnostic warning "-Wobjc-method-access"
    {
        if ( [subv isKindOfClass:[YCefView class]])
        {
            hasYCefView = true;
            break;
        }
        //NSString *className = NSStringFromClass([subv class]);
        //YLog(LOG_NORMAL, @"frame subv is %@", className);
    }
    if (hasYCefView == false) return;
    
    NSWindow* parent = (NSWindow*) parentID;
    
    // Update the frame IF a CEF window
    // with active/inactive images
    NSRect windowRect;
    windowRect = [parent frame];
	windowRect.origin = NSMakePoint(0, windowRect.size.height - HEIGHT_IMG);
    windowRect.size.height = HEIGHT_IMG;
    
    NSImage* image;
    float fraction = 1.0;
    
    bool hasChildThatIsADockAndItsKey = false;
    for ( NSWindow* subWindow in [parent childWindows])
    {
        if ( [subWindow isKindOfClass:[MAAttachedWindow class]] && [subWindow isKeyWindow])
        {
            hasChildThatIsADockAndItsKey = true;
            break;
        }
    }
    
    if ([parent isKeyWindow] || hasChildThatIsADockAndItsKey)
    {
        image = [NSImage imageNamed:@"img-active.png"];
        fraction = 1.0;
    }
    else
    {
        image = [NSImage imageNamed:@"img-inactive.png"];
        fraction = 1.0;
    }
	[image drawInRect:windowRect fromRect:NSZeroRect operation:NSCompositeSourceAtop fraction:fraction];
}

#pragma mark --- options support --------------------------------

- (void) setOption:(id)sender optionName:(NSString*)optionName
{
    NSNumber* alphaval;
    if ( [sender state] == NSOnState )
        alphaval = [NSNumber  numberWithBool: TRUE];
    else
        alphaval = [NSNumber  numberWithBool: FALSE];
    
    [[NSUserDefaults standardUserDefaults] setObject:alphaval forKey:optionName];
    //YLog(LOG_NORMAL, @"Setting %@ for %ld", optionName, (long)[alphaval integerValue]);
}

- (IBAction)setEnableWebGL:(id)sender
{
    [self setOption:sender optionName:kEnableWebGL];
}

- (IBAction)setRemoveCacheOnExit:(id)sender
{
    [self setOption:sender optionName:kBlastCacheOnExit];
}


#pragma mark -------- ZOOM support ----------

- (BOOL) windowShouldZoom:(NSWindow *)window toFrame:(NSRect)newFrame
{
    return TRUE;
}

- (CGFloat)changeWindowMaxWidthBecauseOfDock:(NSRect)newFrame
{
    CGFloat dockWidth = 0;
    for ( NSWindow* nwin in [self.window childWindows] )
    {
        if ( [nwin isKindOfClass:[MAAttachedWindow class]] && [nwin alphaValue] != 0 )
        {
            dockWidth = [nwin frame].size.width;
            
        }
    }
    return dockWidth;
}

- (void) resizeMainWindowIfNeeded
{
    NSWindow* parent = [attachedWindow parentWindow];
    
    if ( attachedWindow && parent )
    {
        NSRect screenFrame = [[NSScreen mainScreen] frame];
        CGFloat dockWidth = [attachedWindow frame].size.width;
        NSRect wframe = [parent frame];
        
        if ( attachedWindow.alphaValue > 0 && wframe.size.width > (screenFrame.size.width - dockWidth) )
        {
            wframe.origin.x += dockWidth;
            wframe.size.width -= dockWidth;
        }
        /* TODO - find a good way to see if the window was zoomed or not
        else if ( attachedWindow.alphaValue == 0 && wframe.size.width == (screenFrame.size.width + dockWidth) )
        {
            wframe.origin.x -= dockWidth;
            wframe.size.width += dockWidth;
        }
         */
        else if ( attachedWindow.alphaValue > 0 && wframe.origin.x < dockWidth )
        {
            wframe.origin.x += dockWidth;
            wframe.size.width -= dockWidth; // ?
        }
        
        [self.window setFrame:wframe display:TRUE];
    }
}

- (bool) windowHasAttachedDock
{
    for ( NSWindow* nwin in [self.window childWindows] )
    {
        if ( [nwin isKindOfClass:[MAAttachedWindow class]] )
            return true;
    }
    return false;
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame
{
    YLog(LOG_NORMAL, @"Zooming to pos=%f,%f sz=%f,%f  original=%f,%f ",
          newFrame.origin.x, newFrame.origin.y,
          newFrame.size.width, newFrame.size.height,
          self.window.frame.size.width, self.window.frame.size.height);
    
    NSRect screenFrame = [[NSScreen mainScreen] frame];
    if ( [self windowHasAttachedDock] )
    {
        // reserve space for the dock
        CGFloat dockWidth = [self changeWindowMaxWidthBecauseOfDock: newFrame];
        CGFloat maxWidth = screenFrame.size.width - dockWidth;
        if ( newFrame.size.width > maxWidth )
        {
            newFrame.size.width = maxWidth;
            newFrame.origin.x = dockWidth;
        }
    }
    
    else
    {
        if (screenFrame.size.width > newFrame.size.width )
        {
            CGFloat newX = self.window.frame.origin.x;
            CGFloat excess = (newX + newFrame.size.width) - screenFrame.size.width;
            if ( excess > 0 )
            {
                newX -= excess;
            }
            newFrame.origin.x = newX;
        }
    }
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* key = [NSString stringWithFormat:@"NSWindow OldFrame %s", windowTargetType.c_str()];
    
    if ( newFrame.size.height == self.window.frame.size.height &&
         newFrame.size.width == self.window.frame.size.width )
    {
        NSString* val = [defaults stringForKey:key];
        if ( val )
        {
            return NSRectFromString( val );
        }
    }
    
    else 
    {
        NSString* val = NSStringFromRect( self.window.frame );
        [defaults setValue:val forKey:key];
    }
    
    return newFrame;
}

- (IBAction) checkForUpdates:(id)sender
{
    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    [appDel checkForUpdates];
    
    if ( drawer.state == NSDrawerOpenState )
    {
        [drawer close];
    }    
}


- (void) shakeWindow
{
    static int numberOfShakes = 3;
    static float durationOfShake = 0.5f;
    static float vigourOfShake = 0.1f;
    
    YLog(LOG_NORMAL, @"Shaking window with %d shakes, duration=%f, vigour=%f",
         numberOfShakes, durationOfShake, vigourOfShake);
    
    CGRect frame=[self.window frame];
    CAKeyframeAnimation *shakeAnimation = [CAKeyframeAnimation animation];
    
    CGMutablePathRef shakePath = CGPathCreateMutable();
    CGPathMoveToPoint(shakePath, NULL, NSMinX(frame), NSMinY(frame));
    for (NSInteger index = 0; index < numberOfShakes; index++){
        CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) - frame.size.width * vigourOfShake, NSMinY(frame));
        CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) + frame.size.width * vigourOfShake, NSMinY(frame));
    }
    CGPathCloseSubpath(shakePath);
    shakeAnimation.path = shakePath;
    shakeAnimation.duration = durationOfShake;
    CGPathRelease(shakePath);
    
    [self.window setAnimations:[NSDictionary dictionaryWithObject: shakeAnimation forKey:@"frameOrigin"]];
    [[self.window animator] setFrameOrigin:[self.window frame].origin];
    
    if ( attachedWindow != nil )
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidResizeNotification object:attachedWindow];
        [attachedWindow display];
    }
}

@end
