//
//  YAppDelegate.m
//  McBrewery
//
//  Created by pereira on 3/12/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//


// -------------------------------------------------------------------------------------------------------------
//
//  NO_SPARKLE_UPDATES is used for the DEV0 and for the Mac App Store
//  NO_GROWL_NOTIFICATIONS is used for the Mac App Store (10.8 and later don't need Growl for notifications)

//#define NO_GROWL_NOTIFICATIONS  1

// -------------------------------------------------------------------------------------------------------------


#import "YAppDelegate.h"
#import <ExceptionHandling/ExceptionHandling.h>
#import "YBreweryApplication.h"
#import "CommonDefs.h"

#include "CaffeineClientApp.h"
#include "CaffeineClientHandler.h"

#import "mac_util.h"
#import "MAAttachedWindow.h"
#import "YLoginUtils.h"
#import "YMKeyChain.h"
#import "QzUtils.h"
#import "NSImage_saveAsJpeg.h"
#import "NSString_YMAdditions.h"
#import "DBAccess.h"
#import "YWindow.h"
#import "YCefView.h"
#import "YLog.h"
#import "YSysUtils.h"
#import "YBreweryDockView.h"

#import "CaffeineWindowCommon.h"

#import "LanguageDefs.h"

#ifndef NO_SPARKLE_UPDATES
#import <Sparkle/Sparkle.h>
#import "PFMoveApplication.h"
#endif


#ifndef NO_GROWL_NOTIFICATIONS
#import "YBreweryNotification.h"
#endif

#ifdef ENABLE_MUSIC_SHARE
#import "Track.h"
#endif

// iTunes
//#define ENABLE_ITUNES_TRACKING  1

// uncomment to activate core location tracking
//#define ENABLE_CORE_LOCATION    1


#pragma mark ----- external global declarations -------------

extern int              gCurrentOS;
extern bool             gInDev0;
extern NSString*        screenshotFileName;

// CEF App
extern CefRefPtr<CaffeineClientApp> app;


// Command to open/start Conversation Windows
static NSString* openConvByYID                = @"Caffeine.AppLogic.startConversation('%@');";
static NSString* openConvFmtByConvId          = @"Caffeine.UserUtils.startConversationById('%@');";
static NSString* openConvTextFmt              = @"Caffeine.AppLogic.startConversationWithText('%@','%@');";

// host for reachability test
static NSString* host4ReachTest             = @"www.Caffeine.com";

// to time the exit
static NSTimeInterval appExitCallTime = 0;

extern "C" {
    void resetITunes();
}

NSString* getPreferencesDBFile();

static NSString* bookmarkDefaultDirectoryName   = @"defDir.bookmark";

NSString* getLastResource();

void networkInterruption();

#pragma mark ------------------- YAppDelegate private methods -------------------------------------

@interface YAppDelegate()
{
    NSTimer*            memoryReporting;
    NSWindow*           splashWnd;
    NSTimeInterval      splashStarted;
    YBreweryDockView*   dockView;
    
#ifndef NO_SPARKLE_UPDATES
    // Updater
    SUUpdater*             updater;
    NSTimeInterval         lastTimeUpdateWasChecked;
    NSTimer*               installAfterQuitTimer;
#endif
    
    bool noAuthorizationForKeychainAccess;
    
    // NSURLBookmark data for default downloads

    NSData* downloadBookmarkData;
}

- (BOOL) shouldTerminateAppNow;

- (void) receivedNotification:(NSNotification *) notification;
- (void) receiveSleepNote: (NSNotification*) note;
- (void) receiveWakeNote: (NSNotification*) note;
- (void) reachabilityChanged: (NSNotification* )note;
- (void) screenSaverStarted: (NSNotification*) note;
- (void) screenSaverStoped: (NSNotification*) note;
- (void) powerOffNotification: (NSNotification*) note;
- (void) screenIsLocked:(NSNotification*) note;
- (void) screenIsUnLocked:(NSNotification*) note;

#ifdef ENABLE_MUSIC_SHARE
- (void) updateTrackInfo:(NSNotification *)notification;
- (void) iTunesLaunched:(NSNotification *)notification;
- (void) iTunesTerminated:(NSNotification *)notification;
#endif

- (void) screenParametersChanged: (NSNotification *)notification;

- (void) displayToast:(NSDictionary*) values;

- (void) validateInternalNetwork;
- (void) activateNextWindow;

- (void) memoryReportTimer: (NSTimer*) t;

#ifndef NO_SPARKLE_UPDATES

- (void) updateAvailableNotification: (NSTimer*) t;
- (void) doUpdate:(NSInvocation*) invocation restart:(BOOL)restart;

#endif

- (void) retryGettingDefUserToken;

// read Apple crash reports
- (void) submitDone:(BOOL) status;
- (void) importAppleCrashReports;

@end

static BOOL inDeveloperChannel = FALSE;


#pragma mark ------------------- YAppDelegate implementation ---------------------------------------

@implementation YAppDelegate


- (BOOL) shouldTerminateAppNow
{
    YLog(LOG_NORMAL, @"shouldTerminateAppNow called with theAppIsTerminating=%d", theAppIsTerminating);
    
    if ( ! theAppIsTerminating )
    {
        // theAppIsTerminating is NEEDED to prevent an hide window instead of a real close
        theAppIsTerminating = TRUE; // NEEDS To be set
        [self terminateApp:self];
        return YES;
    }

    static int terminatingCounter = 0;
    static bool doOnceDone = false;
    if ( !doOnceDone )
    {
        NSDocumentController* docCtrl = [NSDocumentController sharedDocumentController];

        for (NSDocument* doc in docCtrl.documents )
        {
            [doc close];
        }
        doOnceDone = true;
    }
    
    if ( reportIssue != nil )
    {
        [reportIssue.window performClose:self];
        reportIssue = nil;
    }
    
    for ( YBreweryWindowController* win in [windows allValues])
    {
        if ( ! terminatingCounter ) // dont send close twice
        {
            std::string uuid = [win getUUID];
            if ( ![win isDocked] )
            {
                YLog(LOG_NORMAL, @"Removing attached window from %s (if it exists)", uuid.c_str());
                [win removeAttachedWindowFromHierarchy];
            }
            
            // docked window stays after conversation is gone for a visible time
            if ( [win isDocked] && ![win isHidden])
            {
                YLog(LOG_NORMAL, @"shouldTerminateAppNow - Hiding dock window");
                [win hide];
            }
            
            // closing windows
            if ( win->windowTargetType == "ymail" || win->windowTargetType == "bugview" )
            {
                [win.window performClose:self];
            }
            else if ( uuid == mainUUID )
            {
                YLog(LOG_NORMAL, @"shouldTerminateAppNow - sending a close to the %s Window", uuid.c_str());
                [win startClosingCEF];
            }
        }
    }
    
    YLog(LOG_NORMAL, @"shouldTerminateAppNow - closing first step thereAreNoCEFWindows=%d, terminatingCounter=%d",
         ([windows allValues] == 0 ?0:1), terminatingCounter);
    terminatingCounter++;
    
    // returns thereAreNOcefWindows = true if there are no cef windows
    return ([windows allValues] == 0 ?0:1);
}

- (BOOL) isTheAppTerminating
{
    return theAppIsTerminating;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if ( appExitCallTime == 0 )
        appExitCallTime = [NSDate timeIntervalSinceReferenceDate];
    
    YLog(LOG_NORMAL, @"terminateApp - applicationShouldTerminate powerOff=%d updateNOW=%d ",  theAppReceivedAPowerOff, theAppReceivedUpdateNOW);
    
    if ( theAppHasToTerminateNow || theAppReceivedAPowerOff || theAppReceivedUpdateNOW ) return NSTerminateNow;
    
    if ( theAppIsTerminating == FALSE )
    {
        [self terminateApp:nil];
        return NSTerminateLater;
    }
    
    if ([self shouldTerminateAppNow] == FALSE )
    {
        YLog(LOG_NORMAL, @"terminateApp - applicationShouldTerminate there are still CEF windows open, returning NSTerminateLater");
        return NSTerminateLater;
    }
    return NSTerminateNow;
}

// terminating
- (void) applicationWillTerminate:(NSNotification *)notification
{
    YLog(LOG_NORMAL, @"terminateApp - applicationWillTerminate");
    if ( memoryReporting != nil )
    {
        [memoryReporting invalidate];
        memoryReporting = nil;
    }
    
    // removing itself from notification center
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    [dnc removeObserver:self];
    
    // closing location if active
    [self stopLocation];
    
    // stop listening for display changes
    endListeningForDisplayChanges();
    
#ifndef NO_SPARKLE_UPDATES
    if ( installAfterQuitTimer != nil )
    {
        if ( theAppReceivedAPowerOff == FALSE && theAppHasToTerminateNow == FALSE)
        {
            NSInvocation* inv = (NSInvocation*) installAfterQuitTimer.userInfo;
            [self doUpdate:inv restart:FALSE];
            return;
        }
        else
        {
            [installAfterQuitTimer invalidate];
            installAfterQuitTimer = nil;
        }
    }
#endif
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:TRUE] forKey:kCorrectClose];
    
    NSTimeInterval tmInt = [NSDate timeIntervalSinceReferenceDate] - appExitCallTime;
    YLog(LOG_NORMAL, @"Brewery exiting now. Total time since user selected Quit = %f", tmInt);
}


// terminate the App, but give a chance for the MAIN window to close
- (IBAction) terminateApp:(id)sender
{
    if ( appExitCallTime == 0 )
        appExitCallTime = [NSDate timeIntervalSinceReferenceDate];
    YLog(LOG_NORMAL, @"terminateApp called - - LoggedIn=%d powerOFF=%d", isTheAppLoggedIn, theAppReceivedAPowerOff);
    
    theAppIsTerminating = TRUE;
    
    YBreweryWindowController* mainWin = [self getWindowBy: mainUUID];
    if ( mainWin )
    {
        [mainWin.window performClose: self];
    }
}


-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    if ( theAppReceivedAPowerOff || theAppIsTerminating || theAppHasToTerminateNow || theAppReceivedUpdateNOW )
        return YES;
    return NO;
}

// initialization
// run before the actual app finished loading
- (void) applicationWillFinishLaunching:(NSNotification *)notification
{
    splashWnd = nil;

#ifndef NO_SPARKLE_UPDATES
    lastTimeUpdateWasChecked = [NSDate timeIntervalSinceReferenceDate];
#endif
    
    theAppHasBeenActivatedAtLeastOnce = FALSE;
    theRendererHasCrashed = FALSE;
    theAppHasToTerminateNow = FALSE;

    NSDictionary* environ = [[NSProcessInfo processInfo] environment];
    inSandbox = (nil != [environ objectForKey:@"APP_SANDBOX_CONTAINER_ID"]);
    
    isTheAppLoggedIn = FALSE;
    theAppHasLoggedAtLeastOnce = FALSE;
    
    forceSendingOfLocation = TRUE;
    memoryReporting = nil;
#ifdef ENABLE_MUSIC_SHARE
    iTunesPlayerStat = nil;
#endif //ENABLE_MUSIC_SHARE
    noAuthorizationForKeychainAccess = false;
    
    // Handling YMSGR
    ymsgrPending = [[NSMutableArray alloc] init];
    // Apple Events: replying to GetURL
    NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    
    NSExceptionHandler *handler = [NSExceptionHandler defaultExceptionHandler];
    [handler setExceptionHandlingMask: NSLogAndHandleEveryExceptionMask];
    [handler setDelegate:self];
    
    
    ///////////////////////////////////////////
    // setting up location
    userDeniedLocation = false;
    app->shellHasLocationData = true;
    
	locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = self;
    if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_7)
    {
        if ( [CLLocationManager locationServicesEnabled] )
        {
            locationManager.purpose = NSLocalizedString(@"locpurpose", @"why we share location");
            YLog(LOG_NORMAL, @"Location enabled - purpose %@", locationManager.purpose);
        }
    }
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [self startLocation];
    
    //These notifications are filed on NSWorkspace's notification center, not the default
    // notification center. You will not receive sleep/wake notifications if you file
    //with the default notification center.
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(receiveSleepNote:)
                                                               name: NSWorkspaceWillSleepNotification object: NULL];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(receiveWakeNote:)
                                                               name: NSWorkspaceDidWakeNotification object: NULL];

    // power off
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(powerOffNotification:)
                                                               name: NSWorkspaceWillPowerOffNotification object: NULL];
    
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(screenIsLocked:)
                                                            name:@"com.apple.screenIsLocked"
                                                          object:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(screenIsUnLocked:)
                                                            name:@"com.apple.screenIsUnlocked"
                                                          object:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(screenSaverStarted:)
                                                            name:@"com.apple.screensaver.didstart"
                                                          object:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(screenSaverStoped:)
                                                            name:@"com.apple.screensaver.didstop"
                                                          object:nil];
#ifdef ENABLE_MUSIC_SHARE
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(iTunesLaunched:)
                                                               name:NSWorkspaceDidLaunchApplicationNotification
                                                             object:nil];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(iTunesTerminated:)
                                                               name:NSWorkspaceDidTerminateApplicationNotification
                                                             object:nil];
    

#ifdef ENABLE_ITUNES_TRACKING
    // iTunes notifications
    [dnc addObserver:self selector:@selector(updateTrackInfo:) name:@"com.apple.iTunes.playerInfo" object:nil];
#endif
#endif //ENABLE_ITUNES_SHARE
    
    // set up as observer for notifications
    // window close notification - required for cleanup
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receivedNotification:)
                                                 name: CSWindowCloseNotification
                                               object: nil];
    // docked window should close
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receivedNotification:)
                                                 name: CSDockedWindowCloseNotification
                                               object: nil];
     
    
    if ( gCurrentOS >= OSX108 )
    {
        // 10.8 + notifications
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
#ifndef NO_GROWL_NOTIFICATIONS
    else
    {
        // setting growl deleagate (Notficitions)
        [GrowlApplicationBridge setGrowlDelegate:self];
    }
#endif
    
    // dock changed
    [dnc addObserver:self selector:@selector(screenParametersChanged:) name:@"com.apple.dock.prefchanged" object:nil];
    
    // Observe the kNetworkReachabilityChangedNotification. When that notification is posted, the
    // method "reachabilityChanged" will be called.
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) name: kReachabilityChangedNotification object: nil];
    
    //Change the host name here to change the server your monitoring
	hostReach = [Reachability reachabilityWithHostName: host4ReachTest];
	[hostReach startNotifier];
 
    internetReach = [Reachability reachabilityForInternetConnection];
	[internetReach startNotifier];
    
    wifiReach = [Reachability reachabilityForLocalWiFi];
	[wifiReach startNotifier];
    
    // view menu
    //[[viewMenu menu] setAutoenablesItems: NO];
    [[sortByNameMenuItem menu] setAutoenablesItems: NO];
    [[sortByPresenceMenuItem menu] setAutoenablesItems: NO];
    [[showGroupsMenuItem menu] setAutoenablesItems: NO];
    [[showOfflineContactsMenuItem menu] setAutoenablesItems: NO];
    
    // setting up Dock Icon
    // to disable custom dock icon, set dockView = nil instead
    dockView = [[YBreweryDockView alloc] init];
    [[NSApp dockTile] setContentView: dockView];
    [[NSApp dockTile] display];
    
#ifndef NO_SPARKLE_UPDATES
    {
        // setting up UPDATER
        updater = [SUUpdater sharedUpdater];
        updater.delegate = self;
        [updater clearLog];
        
        NSString *verStr = [[NSProcessInfo processInfo] operatingSystemVersionString];
        
        NSString* userAgent = [NSString stringWithFormat:@"YCaffeine/%@ (%@)",
                               [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],  verStr ];
        
        [updater setUserAgentString:userAgent];
        [updater setSendsSystemProfile:TRUE];
        [updater setAutomaticallyChecksForUpdates:TRUE];
        [updater setAutomaticallyDownloadsUpdates:TRUE];
        
        NSTimeInterval updInterval = 800; // 15min
        if ( !inDeveloperChannel )
            updInterval = 3600; // 1 hour
        [updater setUpdateCheckInterval: updInterval];
    }

    installAfterQuitTimer = nil;
#endif
#ifdef ENABLE_MUSIC_SHARE
#ifdef ENABLE_ITUNES_TRACKING
    if ( [Track isITunesOn] && iTunesPlayerStat == nil)
    {
        Track* track = [[Track alloc] init];
        iTunesPlayerStat = [track getTrackInfo];
    }
#endif
#endif
}

- (void) setAutoStartCheck: (BOOL) shouldStartAtLogin
{
    if ( shouldStartAtLogin )
        [startAtLoginMenuItem setState:NSOnState];
    else
        [startAtLoginMenuItem setState:NSOffState];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    YLog(LOG_NORMAL, @"YMSGR link app is %@ - %d", getAppForYmsgr(), isCaffeineDefAppForYmsgr() );
    
    if ( isCaffeineDefAppForYmsgr() )
        [setAsDefaultForYmsgr setState: NSOnState];
    else
        [setAsDefaultForYmsgr setState: NSOffState];
    
    
    macWithWithResolutionDisplay = false;
    if ([[NSScreen mainScreen] respondsToSelector:@selector(backingScaleFactor)]) {
    
        if ( [[NSScreen mainScreen] backingScaleFactor ] >= 2.0 )
        {
            macWithWithResolutionDisplay = true;
        }
    }
    YLog(LOG_NORMAL, @"Mac with high resolution display: %d - Number of Screens: %d", macWithWithResolutionDisplay, [[NSScreen screens] count]);
    
    int countScreens = 0;
    for (NSScreen* scrn in [NSScreen screens])
    {
        YLog(LOG_NORMAL, @"Display %d - backingScaleFactor = %f - description: %@",
             countScreens++,
             [scrn backingScaleFactor],
             [scrn deviceDescription]);
    }
    
    /*
    if ( !gInDev0 )
    {
        // splash smiley
        splashWnd = [[YWindow alloc]
                     initWithContentRect:NSMakeRect(100, 100, 300, 300)
                     styleMask: NSBorderlessWindowMask
                     backing:NSBackingStoreBuffered
                     defer:NO];
        
        [splashWnd center];
        
        NSImageView* vw = [[NSImageView alloc ] initWithFrame: NSMakeRect(0, 0, 300, 300)];
        vw.imageScaling = NSImageScaleProportionallyUpOrDown;
        
        //vw.image = [NSImage imageNamed:@"cesario.icns"];
        //vw.image = [NSImage imageNamed:@"ymsgr_noname.png"];
        vw.image = [NSImage imageNamed:@"ymsgr.icns"];
        NSString* loading = @"Loading...";
        NSMutableDictionary* countAttrsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                               [NSColor whiteColor], NSForegroundColorAttributeName,
                                               nil];
        [vw.image lockFocus];
        [loading drawAtPoint:NSMakePoint(50, 50) withAttributes:countAttrsDict];
        [vw.image unlockFocus];
        
        [[splashWnd contentView] addSubview: vw];
        [splashWnd makeKeyAndOrderFront:self];
        
        splashStarted = [NSDate timeIntervalSinceReferenceDate];
    }
    */
    
    theAppIsTerminating = FALSE;
    theAppReceivedAPowerOff = FALSE;
    theAppReceivedUpdateNOW = FALSE;
    feedbackLink = nil;
    
    inDeveloperChannel = FALSE;
    if ( [[NSString stringWithUTF8String: app->GetUpdateChannel()] rangeOfString:@"Dev" options:NSCaseInsensitiveSearch].location != NSNotFound )
        inDeveloperChannel = TRUE;
    [preferencesMenuItem setHidden: ! inDeveloperChannel];
    
    // sets to nil the ReportIssue/About dialog (for lazy loading)
    reportIssue = nil;
    
    // look into currentlocalizations
    // msg setting up locale as "Caffeine.Intl.setLocale({'locale':'fr-FR'},null);",
    NSArray* locales = [NSBundle preferredLocalizationsFromArray: [[NSBundle mainBundle] localizations]];
    if ( [locales count] > 0 )
        currentLocale = [locales objectAtIndex:0];
    else
        currentLocale = @"en";
    YLog(LOG_NORMAL, @"Current lang/locale is %@", currentLocale);
    
    NSString* convLocal = [langEquiv objectForKey:currentLocale];
    if ( convLocal )
        currentLocale = convLocal;

    app->currentLocale = [currentLocale UTF8String];
    YLog(LOG_NORMAL, @"Modified lang/locale for use in JS is %@", currentLocale);
    
    BOOL shouldStartAtLogin = [[NSUserDefaults standardUserDefaults] boolForKey:kShouldAutoStart];
    // -----------------------------------
    // Set up startup on login
    if ( inSandbox == true )
    {
        @try {
            if (  startAtLoginForSandboxed() !=  shouldStartAtLogin )
                setStartAtLoginForSandboxed( shouldStartAtLogin );
        }
        @catch (NSException *exception) {
            YLog(LOG_NORMAL, @"Exception when trying to set up auto-startup - %@", [exception description]);
        }
    }
    
    // initializing Windows dictionary to hold the NSWindows to be created
    // container for all the window controllers, including NSWindows + ClientHandler objects
    windows = [[NSMutableDictionary alloc] init];
    
    // creates main window (Contacts List)
    YBreweryWindowController* win = [self createWindow:mainUUID initArg:NULL size:NULL  frameless:false resizable:true target:mainUUID minWidth:0 minHeight:0];
    if ( win == nil )
    {
        YLog(LOG_NORMAL, @"Critical Error - failed to create main window!!");
    }
    
    // required to correctly detect display changes - resolution, external monitors, etc
    // and redraw any docked window
    startListeningForDisplayChanges();
    
#ifndef NO_SPARKLE_UPDATES
    YLog(LOG_NORMAL, @"Caffeine - Update channel URL: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SUFeedURL"]);
    {
        [self checkForUpdates];
    }
#endif
    
    YLog(LOG_NORMAL, @"Wifi reachability status is %d", [wifiReach currentReachabilityStatus]);
    YLog(LOG_NORMAL, @"Internet reachability status is %d", [internetReach currentReachabilityStatus]);
    YLog(LOG_NORMAL, @"Host %@ reachability status is %d", host4ReachTest, [hostReach currentReachabilityStatus]);
    
    // TEST for crash handling
	//[self performSelector:@selector(badAccess) withObject:nil afterDelay:1];
    //return;
    // CRASH TEST
    //((char *)NULL)[1] = 0;
    
    // Register local key handler, passing a block as a callback function to handle command tilde
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^(NSEvent *event) {
        NSUInteger flags = [event modifierFlags] & NSDeviceIndependentModifierFlagsMask;
        //YLog(LOG_NORMAL, @"Event monitor for keys %ld, keycode# =%d Command=%d", event.type,event.keyCode,(flags == NSCommandKeyMask));
        
        if ( flags == NSCommandKeyMask && event.keyCode == 50 ) // Command Tilde
        {
            [self activateNextWindow];
        }
        return event;
    }];

    /* //Uncomment this block if we need stats on memory usage again
    report_memory();
    report_cpu();
    memoryReporting = [NSTimer scheduledTimerWithTimeInterval:kMemoryUsageReportingInterval
                                                       target:self
                                                     selector:@selector(memoryReportTimer:)
                                                     userInfo:nil
                                                      repeats:YES];
     
     */

    // initialize logout menu
    // we should avoid changing menus at startup, so defaults should be for logged in = FALSE
    // hide VIDEO menu
    //[VideoMenuItem setHidden:TRUE];
    
    [self sessionLoggedInStateChange:false];
    
    if ( !inSandbox )
    {
        [startAtLoginMenuItem setHidden:TRUE];
    }
    else
    {
        [self setAutoStartCheck:shouldStartAtLogin];
    }
    
    [loggingEnabledMenuItem setState: (masterLogEnabled? NSOnState: NSOffState )];
        
    if ( inDeveloperChannel )
        [openLogFileItem setHidden: FALSE];
    
    // this tries to send a message to the helper apps, to set the flag, so, it should be called after the first window is created
    [self validateInternalNetwork];
    
	// Offer to the move the Application if necessary.
	// Note that if the user chooses to move the application,
	// this call will never return. Therefore you can suppress
	// any first run UI by putting it after this call.
	
#ifndef NO_SPARKLE_UPDATES
    // if NOT in dev0 and in SANDBOX mode
    if ( !gInDev0 && inSandbox )
    {
        PFMoveToApplicationsFolderIfNecessary();
    }
#endif
    
    // load NSURLBookmark data for default download location, if it exists
    if ( [self getDefaultDownloadBookmark] == false )
    {
        downloadBookmarkData = nil;
    }
    
    // checking if there are Apple crash diagnostics
    // comment if you want to disable the "new" crash reporting
    if ( [self doWeHaveNewCrashReports] )
    {
        YLog(LOG_NORMAL, @"Trying to import Apple's crash reports");
        [self importAppleCrashReports];
    }
}

// log memory consumption
- (void) memoryReportTimer: (NSTimer*) t
{
    if ( memoryReporting.timeInterval != kMemoryUsageReportingInterval)
    {
        report_cpu();
    }
    else
    {
        report_memory();
        report_cpu();
    }

    if ( theAppHasLoggedAtLeastOnce && memoryReporting.timeInterval != kMemoryUsageReportingInterval )
    {
        YLog(LOG_NORMAL, @"Switching CPU reporting to %d", kMemoryUsageReportingInterval);
        [memoryReporting invalidate];
        memoryReporting = nil;
        
        memoryReporting = [NSTimer scheduledTimerWithTimeInterval:kMemoryUsageReportingInterval
                                                           target:self
                                                         selector:@selector(memoryReportTimer:)
                                                         userInfo:nil
                                                          repeats:YES];
        
    }
}

- (void) terminateDueToUnexpectedError
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: NSLocalizedString(kAppTitle, kAppTitle)];
    [alert setInformativeText: NSLocalizedString(@"rendercrash", @"There was an unexpected error. Please restart Caffeine")];
    [alert addButtonWithTitle:@"Ok"];
    [alert runModal];
    alert = nil;
    
    if ( isTheAppLoggedIn )
        [self reportIssue:nil];
    else
    {
        // terminate the app?
        theAppIsTerminating = TRUE;
        isTheAppLoggedIn = FALSE;
        [NSApp terminate:self];
    }
}

- (BOOL) insideCorpNetwork
{
    return insideCorpNetwork;
}

- (void) setUpViewMenus: (bool) value
{
    [contactsMenu setHidden: ! value];
    [viewMenu setHidden: ! value];
    if ( value == TRUE )
    {
        [self setUpViewMenu: sortByNameMenuItem action:kSortName];
        [self setUpViewMenu: sortByPresenceMenuItem action:kSortPresence];
        [self setUpViewMenu: showGroupsMenuItem action:kViewGroups];
        [self setUpViewMenu: showOfflineContactsMenuItem action:kViewOffline];
        
    }
    [addContactMenuItem setEnabled:value];
    [viewBlockedContactsItem setEnabled:value];
}

- (void) setUpViewMenu:(NSMenuItem*) menuItem action:(NSString*) action
{
    BOOL currValue = [[NSUserDefaults standardUserDefaults] boolForKey:action];
    
    if ( currValue == TRUE )
        [menuItem setState:NSOnState];
    else
        [menuItem setState:NSOffState];
    
    [menuItem setEnabled: isTheAppLoggedIn];
    
    if ( isTheAppLoggedIn == TRUE )
    {
        // change CEF preferences to reflect shell values
        NSString* cmd = nil;
        if ( menuItem == showOfflineContactsMenuItem )
            cmd = [NSString stringWithFormat:@"Caffeine.preferences.set({name:\"contactList.showOffline\", value: %s});",
                   (currValue? "true" : "false")];
        
        else if ( menuItem == showGroupsMenuItem )
            cmd = [NSString stringWithFormat:@"Caffeine.preferences.set({name:\"contactList.viewGroups\", value: %s});",
                   (currValue? "true" : "false")];
        
        else if ( menuItem == sortByNameMenuItem && currValue == TRUE )
            cmd = [NSString stringWithFormat:@"Caffeine.preferences.set({name:\"contactList.sortModes\", value: \"name\"});"];
        
        else if ( menuItem == sortByPresenceMenuItem && currValue == TRUE )
            cmd = [NSString stringWithFormat:@"Caffeine.preferences.set({name:\"contactList.sortModes\", value: \"presence\"});"];
        
        
        if ( cmd != nil )
        {
            YLog(LOG_ONLY_IN_DEBUG, @"Updating option-> %@", cmd);
            CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
            CefRefPtr<CefFrame> frame = browser->GetMainFrame();
            frame->ExecuteJavaScript([cmd UTF8String],frame->GetURL(), 0 );
        }
    }    
}

- (void) setSessionMenus:(bool) value
{
    YLog(LOG_NORMAL, @"Setting session menus to %d", value);
    // these can be set by either LOG IN/OUT
    // or by MPOP, etc
    [PreferencesMenuItem setEnabled:value]; // APP PREFERENCES
    [profileSettingsMenuItem setEnabled:value]; // APP PREFERENCES
    [logoutMenuItem setEnabled:value];
    [globalLogoutMenuItem setEnabled:value];
    [conversationHistoryMenuItem setEnabled:value];
    
    // these can only be set by log in
    //[ShowMap setEnabled: isTheAppLoggedIn];
    
    //[CaffeineEmail setEnabled:isTheAppLoggedIn && insideCorpNetwork];
    [CaffeineEmail setEnabled:isTheAppLoggedIn];
}

#pragma mark ----- At least one session is LOGGED IN ---------------------

// set by the JS when user logs out from sessions
- (void) sessionLoggedInStateChange:(bool) value
{
    YLog(LOG_NORMAL, @"Logged in state changed to %d - theAppIsTerminating=%d", value, theAppIsTerminating);
    
    isTheAppLoggedIn = value;
    
    if ( theAppIsTerminating && theAppReceivedAPowerOff && !isTheAppLoggedIn)
    {
        YLog(LOG_ONLY_IN_DEBUG, @"receivedNotification: replyToApplicationShouldTerminate: YES");
        [[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
    }
    
    // changing dock view
    if ( dockView )
    {
        dockView.isConnected = value;
        [[NSApp dockTile] display];
    }
    
    // changing state for the App (used by location, and notifications)
    if ( value == TRUE && theAppHasLoggedAtLeastOnce == FALSE )
    {
        theAppHasLoggedAtLeastOnce = TRUE;
        
        // CRASH TEST
        //((char *)NULL)[1] = 0;
    }
    
    if ( theAppIsTerminating == FALSE && theAppHasLoggedAtLeastOnce == TRUE && value == FALSE && ![NSApp isActive] && gCurrentOS >= OSX108 )
        // 10.8 later use native notifications
    {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = kAppTitle;
        notification.informativeText =  NSLocalizedString(@"disconnected", @"You were disconnected from Caffeine");
        notification.userInfo = nil;
        notification.soundName = NSUserNotificationDefaultSoundName;
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification: notification];
    }
    
    if ( value == TRUE && theAppIsTerminating == FALSE )
    {
        if ( !userDeniedLocation )
        {
            forceSendingOfLocation = TRUE;
            YLog(LOG_NORMAL, @"Sending current location");
            [self sendCurrentLocation:nil];
        }
        else
        {
            YLog(LOG_NORMAL, @"User denied location access");
        }
        
        // - send ymgsr pending links if any
        // changed to send pending ymgsr after stub is loaded
        [self openPendingLinks];
        
        //* TODO tested in LOGIN.JS
        if ( sendCrashReportIfExists() )
        {
            [self reportIssue:nil];
        }

#ifdef ENABLE_MUSIC_SHARE
        // TODO: something needs to be changed in music.js to allow for setting the music asap
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0), ^{
            
            @try {
                [NSThread sleepForTimeInterval: 2];
                // force an itunes event
                if ( [Track isITunesOn] )
                {
                    if ( AppGetMainHandler().get() )
                    {
                        AppGetMainHandler()->CreateAndDispatchCustomEvent("iTunesStatusChanged");
                    }
                }
            }
            @catch (NSException *exception) {
                YLog(LOG_NORMAL, @"exception when sending info to music.js");
            }
            @finally {
            }

        });
#endif //ENABLE_MUSIC_SHARE
    }

    [self setUpViewMenus:value];
    [self setSessionMenus:value];
    
    if ( isTheAppLoggedIn == false )
    {
        [self setMsgCount: 0 bRequest: FALSE];
    }
}

- (void) enableSessionMenus: (bool) value
{
    [self setUpViewMenus:value];
    [self setSessionMenus:value];    
}

- (void) handleException:(NSException*) exception
{
    YLog(LOG_NORMAL, @"Exception in the Sparkle thread");
}

#pragma mark ---- SPARKLE delegate ------

- (void) checkForUpdates
{    
#ifndef NO_SPARKLE_UPDATES
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    lastTimeUpdateWasChecked = [NSDate timeIntervalSinceReferenceDate];
    [updater checkForUpdatesInBackground];
#endif
}

#ifndef NO_SPARKLE_UPDATES

- (SUAppcastItem *)bestValidUpdateInAppcast:(SUAppcast *)appcast forUpdater:(SUUpdater *)bundle
{
    NSString* buildNo = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    int build = [buildNo intValue];
    YLog(LOG_NORMAL, @"Testing Sparkle update - current build is %d", build);
    
    for ( SUAppcastItem* item in appcast.items )
    {
        int itemNr = [item.versionString intValue];
        YLog(LOG_NORMAL, @"There is an update with version %d", itemNr);
        
        if ( itemNr > build )
            return item;
    }
    
    return nil;
}

- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update
{
    YLog(LOG_NORMAL, @"Sparkle found a new update version=%@", [update versionString]);
    //lastTimeUpdateWasChecked = [NSDate timeIntervalSinceReferenceDate];
    
    if ( dockView && inDeveloperChannel )
    {
        dockView.anUpdateIsAvailable = TRUE;
        dockView.updateProgress = 0.0f;
        
        [[NSApp dockTile] display];
    }
    
    /*
    if ( gCurrentOS >= OSX108 )
    {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = kAppTitle;
        notification.informativeText =  NSLocalizedString(@"startingDownloadingUpdate", @"A new update is available to be installed, but you have to quit the application");
        notification.userInfo = nil;
        notification.soundName = nil;
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification: notification];
    }
    */
}

- (void)updaterDidNotFindUpdate:(SUUpdater *)update
{
    YLog(LOG_NORMAL, @"Sparkle didn't found any new version");
    //lastTimeUpdateWasChecked = [NSDate timeIntervalSinceReferenceDate];
}

- (void)updaterCloseTheApp:(SUUpdater *)updater
{
    YLog(LOG_NORMAL, @"Sparkle is asking to close the app ---- ");
    theAppReceivedUpdateNOW = TRUE;
    [self terminateApp:self];
}

- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)bundle
{
    return NO;
}

- (float)downloadDelay:(SUUpdater *)updater
{
    /*
    float delay = 60;
    if (
        [getUpdateChannel() compare:@"stable"] == NSOrderedSame ||
        [getUpdateChannel() compare:@"dogfood"] == NSOrderedSame ||
        [getUpdateChannel() compare:@"beta"] == NSOrderedSame
        )
        delay = 10;
    */
    
    float delay = 0;
    YLog(LOG_NORMAL, @"Setting a download delay for Sparkle of %f seconds", delay);
    return delay;
}

static CGFloat updateSize = 47185920; //45Mb

- (void) updateStarted:(SUUpdater *)updater estimatedSize:(NSUInteger) estimatedSize
{
    YLog(LOG_NORMAL, @"Sparkle: estimated file size is %d", estimatedSize);

    updateSize = estimatedSize;
    
    if ( dockView && inDeveloperChannel )
    {
        dockView.anUpdateIsAvailable = TRUE;
        dockView.updateProgress = 0.0f;
        
        [[NSApp dockTile] display];
    }
}

- (void) dataReceived:(SUUpdater *)updater currLen:(NSUInteger)currLen
{
    YLog(LOG_ONLY_IN_DEBUG, @"Sparkle: currently downloaded size is %d - %% = %f", currLen, (float)currLen / updateSize);
    
    if ( dockView && inDeveloperChannel )
    {
        dockView.anUpdateIsAvailable = TRUE;
        dockView.updateProgress = (float)currLen / updateSize;
        [[NSApp dockTile] display];
    }
}

- (void) updateAvailableNotification: (NSTimer*) t
{
    if ( gCurrentOS >= OSX108 && ![NSApp isActive] )
    {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = kAppTitle;
        notification.informativeText =  NSLocalizedString(@"updateAvailable", @"A new update is available to be installed, but you have to quit the application");
        notification.userInfo = nil;
        notification.soundName = NSUserNotificationDefaultSoundName;
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification: notification];
    }
    
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:kAppTitle];
    [alert setInformativeText: NSLocalizedString(@"updateNeedsRestart", @"A new update is available to be installed, want to install it now?") ];
    [alert addButtonWithTitle:NSLocalizedString(@"Ok",@"Ok")];
    [alert addButtonWithTitle:NSLocalizedString(@"Wait",@"Wait")];
    
    theAppIsTerminating = TRUE;
    
    if ( [alert runModal] == NSAlertFirstButtonReturn )
    {
        if ( t.userInfo != nil )
        {
            YLog(LOG_NORMAL, @"User selected update later");
            NSInvocation* inv = (NSInvocation*) t.userInfo;
            [self doUpdate:inv restart:TRUE];
        }
        else
        {
            YLog(LOG_NORMAL, @"User selected update NOW");
            theAppReceivedUpdateNOW = TRUE;
            [NSApp terminateApp:nil];
        }
    }
}

- (void) doUpdate:(NSInvocation*) invocation restart:(BOOL)restart
{
    theAppReceivedUpdateNOW = TRUE;
    if (isTheAppLoggedIn )
        [self logout:nil];
    
    if ( installAfterQuitTimer != nil )
    {
        [installAfterQuitTimer invalidate];
        installAfterQuitTimer = nil;
    }
    
    [((YBreweryApplication*) NSApp) closeCEF];
    
    [invocation setArgument:&restart atIndex:2];
    [invocation invoke];
}

- (void)updater:(SUUpdater *)updater willInstallUpdateOnQuit:(SUAppcastItem *)update immediateInstallationInvocation:(NSInvocation *)invocation;
{
    YLog(LOG_NORMAL, @"Update downloaded: Updater will install on quit");
    if ( dockView && inDeveloperChannel )
    {
        dockView.anUpdateIsAvailable = TRUE;
        dockView.updateProgress = 1.0;
        [[NSApp dockTile] display];
    }
    
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:kAppTitle];
    if ( isTheAppLoggedIn )
        [alert setInformativeText: NSLocalizedString(@"updateNeedsRestart", @"A new update is available to be installed, want to install it now?") ];
    else
        [alert setInformativeText: NSLocalizedString(@"updateNeedsRestart2", @"A new update is available to be installed, press OK to install and restart") ];
    [alert addButtonWithTitle:NSLocalizedString(@"Ok",@"Ok")];
    
    if ( isTheAppLoggedIn )
        [alert addButtonWithTitle:NSLocalizedString(@"Wait",@"Wait")];
    
    if ( [alert runModal] == NSAlertFirstButtonReturn )
    {
        [self doUpdate:invocation restart:TRUE];
    }
    else
    {
        installAfterQuitTimer = [NSTimer scheduledTimerWithTimeInterval:1800 // 30 min
                                                                 target:self
                                                               selector:@selector(updateAvailableNotification:)
                                                               userInfo:invocation
                                                                repeats:YES];
    }
    
}

#endif

#pragma mark -- window Handling ------

// will be modified after the main window creation, if needed
static int frameHeaderSize = 22;

- (void) convertRECTfromJS:(NSRect*)rect
{
    NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
    YLog(LOG_NORMAL, @"Screen origin(%f, %f) Screen Width=%f Screen Height=%f",
         screenFrame.origin.x, screenFrame.origin.y, screenFrame.size.width, screenFrame.size.height);
    
    rect->size.height += frameHeaderSize;  // JS only handles content view - frame view
    rect->origin.y -= frameHeaderSize;
    rect->origin.y = screenFrame.size.height - rect->origin.y - rect->size.height;
}

- (YBreweryWindowController*) createWindow:(const std::string&)uuid
                                   initArg:(const char*)initArg
                                      size:(NSRect*)sz
                                 frameless:(bool)frameless
                                 resizable:(bool)resizable
                                    target:(const std::string&) target
                                    minWidth:(const int)minWidth
                                 minHeight:(const int)minHeight
{
    NSTimeInterval createWindowStart = [NSDate timeIntervalSinceReferenceDate];
    YLog(LOG_NORMAL,
         @"AppDelegate: received request to create window %s -withframe = %d,resizable = %d target=%s",
          uuid.c_str(), frameless, resizable, target.c_str());
    
    // create a window controller object - this initializes the basic Cocoa window object
    NSString* frameAutoSave = nil;

    NSString* defUsr = [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultUserName];
    NSString* nTarget = [NSString stringWithUTF8String: target.c_str()];
    
    if ( uuid == mainUUID || defUsr == nil )
        frameAutoSave = nTarget;

    else
        frameAutoSave = nil;

    /*
    else if ( [[nTarget lowercaseString] rangeOfString:@"unnamed"].location != NSNotFound )
    {
        frameAutoSave = nil;
    }
    
    else
        frameAutoSave = [NSString stringWithFormat:@"%@~%@", defUsr, nTarget];
    */
    
    NSRect winRT = NSMakeRect(100, 100, 300, 600);
    
    if (  uuid != mainUUID )
    {
        if ( sz != NULL )
        {
            YLog(LOG_ONLY_IN_DEBUG, @"create window request with dimensions=(%f,%f,%f,%f)", sz->origin.x, sz->origin.y, sz->size.width, sz->size.height);
            [self convertRECTfromJS:sz];
            winRT = *sz;
        }
        /*
        NSString* frameKey = [NSString stringWithFormat:@"NSWindow Frame %@", frameAutoSave];
        NSString* val = [[NSUserDefaults standardUserDefaults] stringForKey: frameKey];
        if ( sz != NULL && (val == nil || resizable == false || frameAutoSave != nil ) )
        {
            YLog(LOG_ONLY_IN_DEBUG, @"create window request with dimensions=(%f,%f,%f,%f)", sz->origin.x, sz->origin.y, sz->size.width, sz->size.height);
            [self convertRECTfromJS:sz];
            winRT = *sz;
        }
        
        else if ( val != nil )
        {
            winRT = NSRectFromString( val );
        }
        */
         
    }
    YLog(LOG_NORMAL, @"create window will use dimensions=(%f,%f,%f,%f) sz widht,height=(%f,%f)",
         winRT.origin.x, winRT.origin.y, winRT.size.width, winRT.size.height, (sz==NULL? 0:sz->size.width), (sz==NULL? 0:sz->size.height));
    
    YBreweryWindowController* win = nil;
    if ( uuid == mainUUID )
    {
        bool firstRun = true;
        if ( [[NSUserDefaults standardUserDefaults] stringForKey: @"NSWindow Frame main"] != nil )
            firstRun = false;
        
        win = [[YBreweryWindowController alloc] initWithWindowNibName:mainWindowNIB target:frameAutoSave] ;

        [win.window setContentMinSize: NSMakeSize(MAIN_WINDOW_MIN_WIN_WIDTH,MAIN_WINDOW_MIN_WIN_HEIGHT)];
        [win.window setContentMaxSize: NSMakeSize(500, 2000)];
        
        frameHeaderSize = win.window.frame.size.height - [win.window.contentView frame].size.height;
        YLog(LOG_ONLY_IN_DEBUG, @"Header frame size is %d", frameHeaderSize);
        
        if ( firstRun )
        {
            NSRect mframe = [win.window frame];
            mframe.origin.y = [[NSScreen mainScreen] frame].size.height - mframe.size.height - 100;
            mframe.origin.x = 100;
            [win.window setFrame: mframe display:TRUE];
        }
        
        // NSWindowCollectionBehaviorCanJoinAllSpaces will make the window appear in all the spaces
        //[win.window setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces ];//]
        [win.window setCollectionBehavior: NSWindowCollectionBehaviorDefault ];

        YLog(LOG_NORMAL, @"Main Window position and size is: %@", NSStringFromRect( [win.window frame]));
        YLog(LOG_NORMAL, @"Default Screen visible frame  is: %@", NSStringFromRect([[NSScreen mainScreen] visibleFrame]));
        YLog(LOG_NORMAL, @"Default Screen Full    frame  is: %@", NSStringFromRect([[NSScreen mainScreen] frame]));

        if ( gCurrentOS >= OSX1010 )
        {
            NSUInteger style = [win.window styleMask] | NSFullSizeContentViewWindowMask ;
            [win.window setStyleMask: style];
            win.window.titlebarAppearsTransparent = TRUE;
        }
        
        // disabling alpha on conv window
        //[win.window setAlphaValue:0.0];
    }
    else
    {
        // select main window
        NSUInteger style;
        
        if ( frameless == true )
        {
            style = NSTexturedBackgroundWindowMask |
                    NSBorderlessWindowMask;
        }
        else if ( resizable == false )
        {
            style = NSTitledWindowMask |
                    NSClosableWindowMask |
                    NSMiniaturizableWindowMask |
                    NSTexturedBackgroundWindowMask;
        }
        else
        {
            style = NSTitledWindowMask |
                    NSClosableWindowMask |
                    NSMiniaturizableWindowMask |
                    NSResizableWindowMask |
                    NSTexturedBackgroundWindowMask;
        }
        NSScreen* screen = nil;
        if ( [windows count] > 0 )
        {
            NSWindow* mainWin = [self getMainWindow];
            screen = [mainWin screen];
            
            if ( screen != nil )
            {
                YLog(LOG_NORMAL, @"Main Window: is in ActiveSpace: %d", [mainWin isOnActiveSpace]);
            }
            else
            {
                YLog(LOG_NORMAL, @"Main Window: couldn't get NSScreen info yet");
                screen = [NSScreen mainScreen];
            }
        }
        
        if ( gCurrentOS >= OSX1010 )
            style |= NSFullSizeContentViewWindowMask;
        
        NSWindow* wnd = [[YWindow alloc]
                         initWithContentRect: winRT
                             styleMask:style
                             backing:NSBackingStoreBuffered
                             defer:NO
                         screen:screen];
        
        if ( gCurrentOS >= OSX1010 )
            wnd.titlebarAppearsTransparent = TRUE;
        
        [wnd setContentView: [[YCefView alloc] init]];
        
        [wnd setMinSize: NSMakeSize(minWidth, minHeight)];
        [wnd setReleasedWhenClosed:NO];

        win = [[YBreweryWindowController alloc] initWithWindow: wnd];
        [wnd setDelegate:win];
        
        if ( frameAutoSave != nil && [win.window setFrameAutosaveName: frameAutoSave] == NO )
            YLog(LOG_ONLY_IN_DEBUG, @"Failed to set frame AutoSave as %@", frameAutoSave);
        
        else if ( frameAutoSave == nil )
            [win.window setFrame:winRT display:TRUE];
        
        if ( resizable )
        {
            [win.window setCollectionBehavior: NSWindowCollectionBehaviorDefault ];
            //[win.window setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary ];
        }
    }
    
    // stores it in a dictionary object - it includes an automatic retain
    [windows setValue:win forKey: [NSString stringWithUTF8String:uuid.c_str()]];
    
    // creating window hidden
    // main is already created with alpha 0
    //[win.window orderOut:self];
    
    // setUUID initializes and configures CEF
    // inside the window object created above
    [win setUUID: uuid initArg:initArg target:target];
    
    // if we got a valid position + size in a RECT object
    // this should be set AFTER the window is created BUT
    // before the window is first displayed

    // only add window to menu after 1st show Window
    //[NSApp addWindowsItem:win.window title:@"Window" filename:FALSE];
    
    if ( uuid != mainUUID)
    {
        [win.window setExcludedFromWindowsMenu:YES];
        [self setsRendererUUID:win];
        
        // creating the window has hidden
        // this way a pre-created window wont be shown accidentally
        [win hide];
    }
    
    // setup internal network flag
    CefRefPtr<CefBrowser> browser = [win getHandler]->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("changeInternalNetworkFlag");
        message->GetArgumentList()->SetBool(0, insideCorpNetwork);
        browser->SendProcessMessage(PID_RENDERER, message);
    }
    
    YLog(LOG_ONLY_IN_DEBUG, @"Leaving createWindow frame frame=(%lf, %lf, %lf, %lf)",
         [win.window frame].origin.x,
         [win.window frame].origin.y,
         [win.window frame].size.width,
         [win.window frame].size.height
         );
    
    NSTimeInterval lastTimeCreating = [NSDate timeIntervalSinceReferenceDate] - createWindowStart;
    YLog(LOG_NORMAL, @"Window Creation Timing: Time to create window %s was %f", uuid.c_str(), lastTimeCreating);
    return win;
}

- (void) setsRendererUUID:(YBreweryWindowController*) win
{
    // sets current window UUID in renderer
    CefRefPtr<CefBrowser> browser = [win getHandler]->GetBrowser();
    if ( browser.get())
    {
        CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("setUUID");
        message->GetArgumentList()->SetString(0, [win getUUID]);
        browser->SendProcessMessage(PID_RENDERER, message);
    }
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
    if ( ! [self getMainWindow].isVisible )
        [self showWindow:mainUUID];
    return TRUE;
}

- (void) changeWindowTitle:(CefRefPtr<CefBrowser>)browser newTitle:(NSString *)title
{
    NSView* view = (NSView*)browser->GetHost()->GetWindowHandle();
    NSWindow* window = [view window];
    
    if ( ! [window isKindOfClass:[MAAttachedWindow class]])
    {
        for (YBreweryWindowController* ywin in [windows allValues])
        {
            if ( ywin.window == window )
            {
                ywin.lastTitle = title;
                if ( [ywin windowWasShownFromJS ] )
                {
                    [NSApp changeWindowsItem:window title:title filename:FALSE];
                }
                break;
            }
        }
    }
}

- (void) mainFinishedLoading
{
    YLog(LOG_ONLY_IN_DEBUG, @"mainwin stub finished loading");
    
    // if we didn't have keychain authorization, ask it now, and if
    // we get a user/pwd, then re-do setup
    
    if ( noAuthorizationForKeychainAccess == true )
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0), ^{

            [self retryGettingDefUserToken];
        });        
    }
}

- (void) showWindow:(const std::string&) uuid
{
    static bool firstTimeShowMainWindow = true;
    // if the app has never been activated, we should show Window (launched as hidden)
    // prevents crash from auto start in login items as hidden
    if ( ! theAppHasBeenActivatedAtLeastOnce ) return;
    
    // if the application is hidden, we shouldn't showWindow
    if ( [[NSApplication sharedApplication] isHidden] ) return;
    
    YBreweryWindowController* ywin = [self getWindowBy:uuid];
    
    if ( firstTimeShowMainWindow )
    {
        YLog(LOG_NORMAL, @"First time showWindow was called - uuid:%s", uuid.c_str());
        firstTimeShowMainWindow = false;
        
        // disabling alpha on conv window
        //[ywin.window setAlphaValue:1.0];
        
        if ( splashWnd != nil )
        {
            NSTimeInterval splashTime = [NSDate timeIntervalSinceReferenceDate] - splashStarted;
            
            if ( splashTime > 1 )
            {
                [splashWnd orderOut:self];
                splashWnd = nil;
            }
            else
            {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0), ^{
                    
                    //[NSThread sleepForTimeInterval: 1];
                    [NSThread sleepForTimeInterval: (1-splashTime)];
                    [splashWnd orderOut:self];
                    splashWnd = nil;
                });
            }
        }
    }
    
    if (ywin == nil)
    {
        YLog( (theAppIsTerminating ? LOG_ONLY_IN_DEBUG : LOG_MAXIMUM),
             @"ERROR: showWindow for %s - can't find window controller - exiting", uuid.c_str());
        
        if ( theAppIsTerminating )
        {
            YLog(LOG_NORMAL, @"Not finding %s window controller while terminating - closing the app", uuid.c_str());
            [NSApp terminate:self];
        }
        else
        {
            [NSApp terminate:self];
        }
        return;
    }
    
    if ( [ywin isDocked]  &&  ywin.window == nil )
    {
        YBreweryWindowController* ymain = [self getWindowBy: ywin->targetUuid];
        if ( ymain.window )
        {
            // if MPOP Dormant - tiles.js sends a show this will make it appear: right now, this will cause the conv window to show
            // even in MPOP dormant - as it seems that the tiles don't respect mpop
            // but if we uncomment this, we can remove the showWindow for the conv window when the dock is created
            //  (this causes a quick white flickr)
            if ( ymain.isHidden)
                [ymain show];
            
            [ymain.window addChildWindow:[ywin getAttachedWindow] ordered:NSWindowBelow];
            ywin.window = ymain.window;
        }
    }
    else
    {
        [NSApp addWindowsItem:ywin.window title:ywin.lastTitle filename:FALSE];
    }
    
    [ywin show];
    
    if ( uuid == mainUUID )
    {
        [showMainWindowItem setHidden:TRUE];
    }
}

- (void) hideWindow:(const std::string&) uuid
{
    if (theAppIsTerminating || theAppReceivedAPowerOff || theAppReceivedUpdateNOW )
    {
        [[self getWindowBy:uuid].window setAlphaValue:0.0];
        return;
    }
    [[self getWindowBy:uuid] hide];

    if ( uuid == mainUUID )
    {
        [showMainWindowItem setHidden:FALSE];
    }
}

// moves and/or resizes a window
- (void) moveOrResizeWindow:(const std::string&) uuid sizeAndPosition:(NSRect*)sz
{
    if ( sz == nil ) return;
    YLog(LOG_NORMAL, @"moveOrResizeWindow %s  - before conversion -  dimensions=(%f,%f,%f,%f)", uuid.c_str(), sz->origin.x, sz->origin.y, sz->size.width, sz->size.height);
    
    [self convertRECTfromJS:sz];
    
    YLog(LOG_NORMAL, @"moveOrResizeWindow %s  -  dimensions=(%f,%f,%f,%f)",uuid.c_str(), sz->origin.x, sz->origin.y, sz->size.width, sz->size.height);
    
    YBreweryWindowController* win = [self getWindowBy:uuid];
    if ( win == nil ) return;
    
    [win.window setFrame:*sz display:FALSE];
    
    MAAttachedWindow* attached = [win getAttachedWindow];
    // if there is an attached window, we need to update it
    if ( attached != nil )
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidResizeNotification object:attached];
        [attached display];
    }
}

- (YBreweryWindowController*) createDockable:(const std::string&) uuid initArg:(const char*)initArg  target:(const std::string&) targetUUID
                                       width:(int)width top:(int) minTop bottom:(int)minBottom
{
    NSTimeInterval createWindowStart = [NSDate timeIntervalSinceReferenceDate];
    YLog(LOG_NORMAL, @"AppDelegate: received request to create DOCKABLE window %s with target UUID=%s", uuid.c_str(), targetUUID.c_str());

    // retrieves information of the conversation window, by UUID
    YBreweryWindowController* mainCtrl = [self getWindowBy:targetUUID];
    NSWindow* mainWin = mainCtrl.window;
    if ( mainWin == nil )
    {
        YLog(LOG_NORMAL, @"AppDelegage: an attempt was made to create a dockwindow to a non-existant conversation window, with uuid=%s", targetUUID.c_str());
        return nil;
    }
    
    // for now, prevent a 2nd docked window to be created
    // in case an atempt was done, just reuse the existant dock
    NSString* repeatedDock = nil;
    for (YBreweryWindowController* ctrl in [windows allValues])
    {
        if ( [ctrl isDocked] )
        {
            YLog(LOG_NORMAL, @"AppDelegage: an attempt was made to create MORE THEN ONE dockwindow");
            repeatedDock = [NSString stringWithUTF8String:[ctrl getUUID].c_str()];
            break;
        }
    }
    if ( repeatedDock != nil )
    {
        [windows removeObjectForKey:repeatedDock];
        repeatedDock = nil;
    }
    
    // Create a new DOCKED window
    YBreweryWindowController* win = [[YBreweryWindowController alloc] initWithWindow:nil];
    [windows setValue:win forKey: [NSString stringWithUTF8String:uuid.c_str()]];
    
    // ------------------------------------
    // important: call win.window to force NIB loading
    // otherwise, due to lazy loading, setUUID below won't have a NSWindow already created
    if ( win.window == nil )
    {
        //YLog(LOG_NORMAL, @"Error - window needs to be non-nil");
    }
    
    // now we can load CEF
    [win setUUID: uuid initArg:initArg attachedTo:mainWin width:width top:minTop bottom:minBottom];
    
    // NOTE: we don't make the actual dockwindow key -
    // we set up the conversation window as key
    //[mainWin makeKeyWindow];
    
    win->targetUuid = targetUUID;
    [self setsRendererUUID:win];
    
    // hide the dock from the all windows menu
    [[win getAttachedWindow] setExcludedFromWindowsMenu:YES];
    //[win setAttachedTransparency:0.9];
    NSTimeInterval lastTimeCreating = [NSDate timeIntervalSinceReferenceDate] - createWindowStart;
    YLog(LOG_NORMAL, @"Window Creation Timing: time to create DOCKED window %s was %f", uuid.c_str(), lastTimeCreating);
    return win;
}

- (NSWindow*) getMainWindow
{
    YBreweryWindowController* win = [windows valueForKey: [NSString stringWithUTF8String:mainUUID.c_str()]];
    if ( win == nil ) return  nil;
    return win.window;
}

- (YBreweryWindowController*) getWindowBy:(const std::string&) uuid
{
    NSString* strUUID = [NSString stringWithUTF8String:uuid.c_str()];
    
    YBreweryWindowController* win = [windows valueForKey: strUUID];
    
    if ( win == nil )
    {
        YLog(LOG_NORMAL, @"AppDelegate: received request for window %s - but it wasn't found", uuid.c_str());
    }
    return win;
}

- (YBreweryWindowController*) getDockedWindow:(YBreweryWindowController*) conversation
{
    return nil;
}

- (void) activateNextWindow
{
    std::string currentWindow;
    std::string nextWindow = "";
    bool previousWindowIsActive = false;
    if ( ! [self getKeyWindow:currentWindow] )
    {
        nextWindow = mainUUID;
    }
    else
    {
        for ( NSString* uuid in [windows allKeys])
        {
            if ( [self getWindowBy: [uuid UTF8String]].isDocked )
                ; // skip
            
            else if ( [[self getWindowBy:[uuid UTF8String]] isHidden] )
                ; // skip
            
            else if ( previousWindowIsActive )
            {
                nextWindow = [uuid UTF8String];
                break;
            }
            else
            {
                if ( currentWindow == [uuid UTF8String])
                {
                    previousWindowIsActive = true;
                }
            }
        }
    }
    if ( !previousWindowIsActive || nextWindow == "" )
    {
        nextWindow = mainUUID;
    }
    //YLog(LOG_NORMAL, @"Activate nextWindow - current=%s next=%s", currentWindow.c_str(), nextWindow.c_str());

    // activate the window
    YBreweryWindowController* ctrl = [self getWindowBy:nextWindow];
    if ( ctrl == nil ) return ;
    [ctrl updateFrame];
    [ctrl.window makeKeyAndOrderFront: ctrl.window];
    
}

- (void) shakeWindow: (const std::string&)uuid
{
    YBreweryWindowController* win = [self getWindowBy:uuid];
    
    if ( win != nil )
    {
        [win shakeWindow];
    }
}

#pragma mark ----- Notifications ---------------

- (void) rendererHasCrashed:(CefRefPtr<CefBrowser>) browser
{
    std::string uuid = "unknown";
    [self getUUID: uuid fromBrowser:browser ];
        
    YLog(LOG_MAXIMUM, @"Renderer has crashed ==================== TERMINATING THE APP ===================");
    
    YLog(LOG_MAXIMUM, @"Crashed Browser GetIdentifier=%d, UUID=%s isTheAppLoggedIn=%d", browser->GetIdentifier(), uuid.c_str(), isTheAppLoggedIn);
    YLog(LOG_MAXIMUM, @"Wifi reachability status is %d", [wifiReach currentReachabilityStatus]);
    YLog(LOG_MAXIMUM, @"Internet reachability status is %d", [internetReach currentReachabilityStatus]);
    YLog(LOG_MAXIMUM, @"Host %@ reachability status is %d", host4ReachTest, [hostReach currentReachabilityStatus]);
    YLog(LOG_MAXIMUM, @"Last Resource loaded: %@", getLastResource());
    YLog(LOG_MAXIMUM, @"=======================================");
    
    theRendererHasCrashed = TRUE;
    
    theAppIsTerminating = TRUE;
    [self terminateDueToUnexpectedError];
}

- (BOOL) getUUID:(std::string&)keyUUID fromBrowser:(CefRefPtr<CefBrowser>) browser
{
    for ( NSString* uuid in [windows allKeys] )
    {
        std::string sUUID = [uuid UTF8String];
        if ( app->m_WindowHandler[ sUUID ].get() && app->m_WindowHandler[ sUUID ]->m_MainBrowser.get() )
        {
            if ( app->m_WindowHandler[ sUUID ]->m_MainBrowser->GetIdentifier() == browser->GetIdentifier() )
            {
                keyUUID = sUUID;
                return TRUE;
            }
        }
    }
    return FALSE;
}

// get keyUUID
- (BOOL) getKeyWindow:(std::string&) keyUUID;
{
    for (YBreweryWindowController* ywin in [windows allValues])
    {
        if ( [[ywin currWindow] isKeyWindow] && ![ywin isDocked])
        {
            keyUUID = [ywin getUUID];
            return TRUE;
        }
    }
    return FALSE;
}

- (void) activateOrDeactivate:(bool) activation
{
    if ( activation == false )
    {
        for (YBreweryWindowController* ywin in [windows allValues])
        {
            [self activateOrDeactivate:false uuid:[ywin getUUID]];
        }
    }
    else
    {
        std::string keyWindow;
        if ( [self getKeyWindow:keyWindow] )
        {
            [self activateOrDeactivate:activation uuid:keyWindow];
        }
    }
}

- (void) activateOrDeactivate:(bool) activation uuid:(std::string&)keyWindow
{
    if ( activation && ![NSApp isActive])
        activation = false;
    
    if ( app->m_WindowHandler[ keyWindow ].get() && app->m_WindowHandler[ keyWindow ]->m_MainBrowser.get() )
    {
        CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("setKeyWindow");
        message->GetArgumentList()->SetBool(0, [NSApp isActive]);
        app->m_WindowHandler[ keyWindow ]->m_MainBrowser->SendProcessMessage(PID_RENDERER, message);
        
        app->m_WindowHandler[ keyWindow ]->CreateAndDispatchCustomEvent( (activation ? "activated" : "deactivated") );
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
    if ( ! theAppHasBeenActivatedAtLeastOnce )
    {
        theAppHasBeenActivatedAtLeastOnce = TRUE;
    }
    else
    {
        YBreweryWindowController* ymain  = [self getWindowBy:mainUUID];
        NSUInteger nrWindows = [windows count];
        if ( !theAppIsTerminating && ymain && ymain.isHidden && nrWindows == 1 )
        {
            [ymain show];
        }
    }
    
    /*
    YBreweryWindowController* ymain  = [self getWindowBy:mainUUID];
    if ( ! theAppHasBeenActivatedAtLeastOnce )
    {
        theAppHasBeenActivatedAtLeastOnce = TRUE;
        if ( !userDeniedLocation && locationManager.location )
        {
            [self sendCurrentLocation:nil];
        }
        [self showWindow:mainUUID];
    }
    
    NSUInteger nrWindows = [windows count];
    if ( !theAppIsTerminating && ymain && ymain.isHidden && nrWindows == 1 )
    {
        [ymain show];
    }
     */
}

- (void)applicationWillUnhide:(NSNotification *)aNotification
{
}

- (void)applicationDidResignActive:(NSNotification *)aNotification
{
}

- (void)applicationDidHide:(NSNotification *)aNotification
{
}

// NOTE: these all program notifications, sent between different program classes, not user notifications
//
// it listens to:
// CSDockedWindowCloseNotification - docked window is closing
// CSWindowCloseNotification - popup is closing
// and ensures cleaning up of their respective objects
//

- (void) receivedNotification:(NSNotification *) notification
{
    YLog(LOG_ONLY_IN_DEBUG, @"Received notification %@", notification.name);
    if ([[notification name] isEqualToString:CSDockedWindowCloseNotification])
    {
        MAAttachedWindow* attach = (MAAttachedWindow*) notification.object;
        for (YBreweryWindowController* ctrl in [windows allValues])
        {
            if ( [ctrl isDocked] && ctrl->attachedWindow == attach )
            {
                YLog(LOG_NORMAL, @"Found docked window %s that needs to be closed ", [ctrl getUUID].c_str());
                [ctrl closesAttachedWindow];
                
                break;
            }
        }
    }
    
    else if ([[notification name] isEqualToString:CSWindowCloseNotification])
    {
        NSString* strUUID = (NSString*) notification.object;
        std::string browser_id ([strUUID UTF8String]);
        
        YLog(LOG_NORMAL, @"Finish cleaning for closing window = %@ windows.count=%d hanlers=%d",
             strUUID, [windows count], app->m_WindowHandler.size());
        
        [windows removeObjectForKey:strUUID];
        app->m_WindowHandler.erase(browser_id);
        
        if ( browser_id == mainUUID )    // window closed is the MAIN window
        {
            for ( NSString* uuid in [windows allKeys] )
            {
                YLog(LOG_NORMAL, @"After main window closed, we are force closing this orphan window: %@", uuid);
                [windows removeObjectForKey:uuid];
                
                std::string strUuid = [uuid UTF8String];
                app->m_WindowHandler.erase( strUuid );
            }
            
            // Close the APP
            if ( theAppIsTerminating )
            {
                YLog(LOG_NORMAL, @"receivedNotification: replyToApplicationShouldTerminate: YES");
                [[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
            }
        }
    }
}

- (void) receiveSleepNote: (NSNotification*) note
{
    if ( theAppIsTerminating )
    {
        YLog(LOG_NORMAL, @"We are terminating but got a sleep notification - forcing app close");
        theAppHasToTerminateNow = TRUE;
        [NSApp terminate:self];
        return;
    }
    
    for (YBreweryWindowController* ywin in [windows allValues])
    {
        if (app->m_WindowHandler[[ywin getUUID]].get())
        {
            app->m_WindowHandler[[ywin getUUID]]->CreateAndDispatchCustomEvent("suspend");
        }
    }
    YLog(LOG_NORMAL, @"receiveSleepNote: %@", [note name]);
    sleepStartTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void) receiveWakeNote: (NSNotification*) note
{
    NSTimeInterval wakeTime = [NSDate timeIntervalSinceReferenceDate];
    YLog(LOG_NORMAL, @"Waking up after %f", wakeTime - sleepStartTime);

    // updating location afer wake
    forceSendingOfLocation = TRUE;
    [self startLocation];
    
    for (YBreweryWindowController* ywin in [windows allValues])
    {
        if (app->m_WindowHandler[[ywin getUUID]].get())
        {
            app->m_WindowHandler[[ywin getUUID]]->CreateAndDispatchCustomEvent("resume");
        }
    }
 }

- (void) screenIsLocked:(NSNotification*) note
{
    for (YBreweryWindowController* ywin in [windows allValues])
    {
        if (app->m_WindowHandler[[ywin getUUID]].get())
        {
            app->m_WindowHandler[[ywin getUUID]]->CreateAndDispatchCustomEvent("os:locked");
        }
    }
}

- (void) screenIsUnLocked:(NSNotification*) note
{
    for (YBreweryWindowController* ywin in [windows allValues])
    {
        if (app->m_WindowHandler[[ywin getUUID]].get())
        {
            app->m_WindowHandler[[ywin getUUID]]->CreateAndDispatchCustomEvent("os:unlocked");
        }
    }
}

- (void) powerOffNotification: (NSNotification*) note
{
    YLog(LOG_NORMAL, @"theAppIsTerminating - powerOffNotification received, closing");

    if ( appExitCallTime == 0 )
        appExitCallTime = [NSDate timeIntervalSinceReferenceDate];
    
    theAppReceivedAPowerOff = TRUE;
    
    [self terminateApp:nil];
    
#ifndef NO_SPARKLE_UPDATES
    // todo: should we try cancelling? this will require a new public interface in Sparkle I think
    if ( [updater updateInProgress] )
    {
    }
#endif
    
    if ( reportIssue != nil )
    {
        [reportIssue.window performClose:self];
        reportIssue = nil;
    }
 }

- (void) screenSaverStarted: (NSNotification*) note
{
    if ( AppGetMainHandler().get() )
    {
        AppGetMainHandler()->CreateAndDispatchCustomEvent("startIdle");
    }
}

- (void) screenSaverStoped: (NSNotification*) note
{
    if ( AppGetMainHandler().get() )
    {
        AppGetMainHandler()->CreateAndDispatchCustomEvent("stopIdle");
    }
}

#define MINIMUM_INTERVAL_TO_CHECK_NET_CHANGES   1

- (void) validateInternalNetwork
{
    static NSTimeInterval lastTimeCheckedForNetChange = 0;
    
    NSTimeInterval currentTimeIs = [NSDate timeIntervalSinceReferenceDate];
    if ( lastTimeCheckedForNetChange == 0 || (currentTimeIs - lastTimeCheckedForNetChange) > MINIMUM_INTERVAL_TO_CHECK_NET_CHANGES )
    {
        lastTimeCheckedForNetChange = currentTimeIs;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0), ^{
            
            @try {
                bool oldInsideNetwork = insideCorpNetwork;
                insideCorpNetwork = FALSE;
                NSHost* host = [NSHost currentHost];
                for ( NSString* nm in [host names]) {
                    YLog(LOG_NORMAL, @"Host name = %@", nm);
                    if ( [nm rangeOfString:@"corp.Caffeine.com"].location != NSNotFound )
                    {
                        insideCorpNetwork = TRUE;
                        break;
                    }
                }
                
                if ( insideCorpNetwork != oldInsideNetwork )
                {
                    dispatch_async( dispatch_get_main_queue(), ^{
                        
                        for (YBreweryWindowController* win in [windows allValues] )
                        {
                            CefRefPtr<CefBrowser> browser = [win getHandler]->GetBrowser();
                            if ( browser.get())
                            {
                                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("changeInternalNetworkFlag");
                                message->GetArgumentList()->SetBool(0, insideCorpNetwork);
                                browser->SendProcessMessage(PID_RENDERER, message);
                            }
                        }
                        
                    });
                    
                }
               YLog(LOG_NORMAL, @"Checking for internal corp at %lf - value is %d", lastTimeCheckedForNetChange, insideCorpNetwork);
            }
            @catch (NSException *exception) {
                YLog(LOG_NORMAL, @"Exception when trying check for internal network");
            }
            @finally {
            }
        });
    }
    else
    {
        YLog(LOG_NORMAL, @"Skipping Checking for internal corp at %lf - minium time interval to check is %d", currentTimeIs, MINIMUM_INTERVAL_TO_CHECK_NET_CHANGES);
    }
}

//Called by Reachability whenever status changes.
- (void) reachabilityChanged: (NSNotification* )note
{
	Reachability* curReach = [note object];
	NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    
    NSString* typeNot = @"--";
    if(curReach == hostReach)
	{
        typeNot = host4ReachTest;
    }
	if(curReach == internetReach)
	{
        typeNot = @"Internet";
	}
	if(curReach == wifiReach)
	{
        typeNot = @"WiFi";
	}
    
    if ( NotReachable ==  [curReach currentReachabilityStatus] )
    {
        YLog(LOG_NORMAL, @"Reachability Notification: %@ is not reachable right now", typeNot);
        
        if ( theAppIsTerminating )
        {
            YLog(LOG_NORMAL, @"We are terminating but lost the network communication - forcing app close");
            theAppHasToTerminateNow = TRUE;
            [NSApp terminate:self];
            return;
        }
        
        //if ( curReach == internetReach )
        if ( curReach == hostReach )
        {
            if ( AppGetMainHandler().get() )
                AppGetMainHandler()->CreateAndDispatchCustomEvent("os:offline");
            
            [[NSNotificationCenter defaultCenter] postNotificationName:CSNetworkLoss object:nil];
            networkInterruption();
        }
        
        if ( curReach == hostReach && userDeniedLocation == false)
        {
            YLog(LOG_NORMAL, @"Reachability changed - stopping location");
            [self stopLocation];
        }
        if ( curReach == hostReach )
        {
            YLog(LOG_NORMAL, @"Host not reachable - setting insideCorpNetwork to FALSE");
            insideCorpNetwork = FALSE;
        }
    }
    else
    {
        YLog(LOG_NORMAL, @"Reachability Notification: %@ is now reachable", typeNot);
        [self validateInternalNetwork];
        
#ifndef NO_SPARKLE_UPDATES
        NSTimeInterval curTime = [NSDate timeIntervalSinceReferenceDate];
        if ( curTime - lastTimeUpdateWasChecked > 60 ) // if 1 min
        {
            YLog(LOG_NORMAL, @"Checking if we ther is an update running - %d", [updater updateInProgress]);
            if ( ! [updater updateInProgress] )
            {
                [self checkForUpdates];
            }
        }
#endif

        if ( curReach == hostReach && userDeniedLocation == false )
        {
            YLog(LOG_NORMAL, @"Reachability changed - starting location again");
            forceSendingOfLocation = TRUE;
            [self startLocation];
            
        }
        
        //if ( curReach == internetReach )
        if ( curReach == hostReach )
        {
            if ( AppGetMainHandler().get() )
                AppGetMainHandler()->CreateAndDispatchCustomEvent("os:online");
        }
    }
}

- (void) resetCaffeine
{
    for (YBreweryWindowController* ywin in [windows allValues])
    {
        if ( [ywin getUUID] != mainUUID )
        {
            std::string uuid = [ywin getUUID];
            ywin->closeWindowWithoutWaitingForCEF = true;
            [[ywin window] close];
            
            [windows removeObjectForKey:[NSString stringWithUTF8String:uuid.c_str()]];
            app->m_WindowHandler.erase(uuid);
        }
    }
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    browser->ReloadIgnoreCache();
}

#ifdef ENABLE_MUSIC_SHARE
-(void) iTunesLaunched:(NSNotification *)notification
{
#ifdef ENABLE_ITUNES_TRACKING
    NSRunningApplication *runApp = [[notification userInfo] valueForKey:@"NSWorkspaceApplicationKey"];
    if ([runApp.bundleIdentifier isEqualToString:@"com.apple.iTunes"])
    {
        YLog(LOG_NORMAL, @"itunes started");
        iTunesPlayerStat = nil;
        
        NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
        [dnc addObserver:self selector:@selector(updateTrackInfo:) name:@"com.apple.iTunes.playerInfo" object:nil];
        
        if ( AppGetMainHandler().get() )
        {
            AppGetMainHandler()->CreateAndDispatchCustomEvent("iTunesStatusChanged");
        }
    }
#endif
}

-(void) iTunesTerminated:(NSNotification *)notification
{
#ifdef ENABLE_ITUNES_TRACKING
    NSRunningApplication *runApp = [[notification userInfo] valueForKey:@"NSWorkspaceApplicationKey"];
    if ([runApp.bundleIdentifier isEqualToString:@"com.apple.iTunes"])
    {
        YLog(LOG_NORMAL, @"itunes has terminated");
        resetITunes();
        
        NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
        [dnc removeObserver:self name:@"com.apple.iTunes.playerInfo" object:nil];
        //[dnc removeObserver:self];
        
        iTunesPlayerStat = nil;
    }
#endif
}

- (NSDictionary*)   getCurrentiTunesPlayerStat
{
    return iTunesPlayerStat;
}

- (void) updateTrackInfo:(NSNotification *)notification
{
#ifdef ENABLE_ITUNES_TRACKING
    // clear old data
    if (  iTunesPlayerStat != nil )
        iTunesPlayerStat = nil;

    NSDictionary *information = [notification userInfo];
    YLog(LOG_ONLY_IN_DEBUG, @"track information: %@", information);
    
    //"Player State" = Paused;
    NSString* playerState = [information objectForKey:@"Player State"];
    if ( AppGetMainHandler().get() )
    {
        if  ( [playerState compare: @"Paused"] == NSOrderedSame || [playerState compare: @"Stopped"] == NSOrderedSame )
        {
            AppGetMainHandler()->CreateAndDispatchCustomEvent("iTunesTerminated");
        }
        else
        {
            iTunesPlayerStat = [NSDictionary dictionaryWithObjectsAndKeys:
                                
                                @"1", @"isITunesOn",
                                @"Play", @"playerState",
                                
                                [information objectForKey:@"Name"], @"song",
                                [information objectForKey:@"Album"], @"album",
                                [information objectForKey:@"Album Artist"], @"artist",
                                [information objectForKey:@"Show"], @"showName",
                                
                                @"unknown", @"videoKind",  // unused?
                                
                                [information objectForKey:@"currentStreamTitle"], @"currentStreamTitle",
                                @"0.0", @"playerPosition",  // unused?
                                @"0.0", @"timeUntilEnd", // unused?
                                @"0", @"seasonNumber",
                                @"0", @"episodeNumber",
                                @"", @"genre",  // unused?
                                nil];
            
            AppGetMainHandler()->CreateAndDispatchCustomEvent("iTunesStatusChanged");
        }
        
        if ( iTunesPlayerStat == nil )
        {
            iTunesPlayerStat = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"0", @"isITunesOn",
                                @"NotPlaying", @"playerState",
                                @"", @"song",
                                @"", @"album",
                                @"", @"artist",
                                @"", @"showName",
                                @"unknown", @"videoKind",
                                @"", @"currentStreamTitle",
                                @"0.0", @"playerPosition",
                                @"0.0", @"timeUntilEnd",
                                @"0", @"seasonNumber",
                                @"0", @"episodeNumber",
                                @"", @"genre", nil];
        }
    }
#endif
}
#endif // ENABLE_MUSIC_SHARE
- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotification
{
    YLog(LOG_ONLY_IN_DEBUG, @"applicationDidChangeScreenParameters: %@", aNotification);
}


- (void) screenParametersChanged:(NSNotification *)aNotification
{
    YLog(LOG_ONLY_IN_DEBUG, @"screenParametersChanged: %@", aNotification);
    [[NSApp dockTile] display];
}



#pragma  mark ----- NSUserDelegate (Message Notifications) ---------------------

// YES: presents notifications to the user even if the app is the key app
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification
{
    YLog(LOG_ONLY_IN_DEBUG, @"Notification %@ was delivered", notification.title);
}

- (void) displayToast:(NSDictionary *)values
{
    if ( !isTheAppLoggedIn )
    {
        return;
    }
    
    NSString* convId = [values objectForKey:@"convId"];
    NSString* cmd = nil;
    //NSString* senderId = nil;
    
    if ([convId length] > 0)
    {
        cmd = [NSString stringWithFormat:openConvFmtByConvId, convId];
        //senderId = convId;
    } else
    {
        cmd = [NSString stringWithFormat:openConvByYID, [values objectForKey:@"from"] ];
        //senderId = [values objectForKey:@"from"];
    }
    
    //YLog(LOG_NORMAL, @"Notification %@ was delivered - activation type=%ld - from %@", notification.title, (long)notification.activationType, senderId);
    
    
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
        {
            frame->ExecuteJavaScript([cmd UTF8String],frame->GetURL(), 0 );
        }
    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    if ( notification.userInfo != nil && [notification.userInfo objectForKey:@"convId"] != nil )
        [self displayToast:notification.userInfo];
}

#pragma mark ---------  Message Notifications --------------------------------

- (void) incomingMessage:(NSString*) from displayName:(NSString*) displayName msg:(NSString*) msg convId:(NSString*) convId
{
    [[NSApplication sharedApplication] requestUserAttention:NSInformationalRequest];
    
   if ( gCurrentOS >= OSX108 ) // 10.8 later use native notifications
    {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = displayName;
        notification.informativeText = msg;
        notification.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                 convId, @"convId",
                                 from, @"from",
                                 nil
                                 ];
        notification.soundName = NSUserNotificationDefaultSoundName;
        
        /*
         // show a reply button
         notification.hasActionButton = TRUE;
         notification.hasReplyButton = TRUE;
         notification.actionButtonTitle = NSLocalizedString(@"Reply", @"Reply");
         notification.responsePlaceholder = NSLocalizedString(@"Reply", @"Reply");
         */
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification: notification];
        
    }
#ifndef NO_GROWL_NOTIFICATIONS
    // olders OSes, use Growl
    else
    {
        NSDictionary* context = [NSDictionary dictionaryWithObjectsAndKeys: convId, @"convId", from, @"from", nil];
        [YBreweryNotification showSimpleNotification:displayName
                                         description:msg
                                             context:context];
        
    }
#endif
}



#ifndef NO_GROWL_NOTIFICATIONS

// click on a notification - call the appropriate window?
-(void)growlNotificationWasClicked:(id)clickContext{
    NSDictionary* dictionary = clickContext;
    [self displayToast:dictionary];
}

#endif /// end of growl notifications


#pragma mark ------ MENU Options ------------------

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    return TRUE;
}

- (IBAction) showMainWindow:(id)sender
{
    [NSApp activateIgnoringOtherApps:TRUE];
    [self showWindow:mainUUID];
}

- (IBAction)about:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.Header.aboutWindow();",frame->GetURL(), 0 );
    }
}

- (IBAction) openYMailWindow:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.Header.openYMail();",frame->GetURL(), 0 );
    }
}

- (IBAction)videoSettings:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.Media.Config.openUI();", frame->GetURL(), 0 );
    }
    
}

- (IBAction)videoConference:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.Media.Conference.openUI();", frame->GetURL(), 0 );
    }
}

- (IBAction)conversationHistory:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.UserUtils.openConversationHistory();", frame->GetURL(), 0 );
    }
}

- (IBAction) Preferences:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.UserUtils.openPreferences();", frame->GetURL(), 0 );
    }
}

- (IBAction) profilePreferences:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.SettingsUI.toggleShow();", frame->GetURL(), 0 );
    }
    
}

- (IBAction)userFeedback:(id)sender
{
    YLog(LOG_NORMAL, @"Calling feedback with URL=%@", feedbackLink);
    if ( feedbackLink != nil )
    {
        [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: feedbackLink]];
    }
}

- (IBAction)logout:(id)sender
{
    YLog(LOG_NORMAL, @"local logout initiated");
    bool success=false;
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
        {
            frame->ExecuteJavaScript("Caffeine.Utils.logoutAndReload(false);", frame->GetURL(), 0 );
            success = true;
        }
    }
    // if we fail to logout, then stte is uncertain
    if ( ! success )
    {
        isTheAppLoggedIn = FALSE;
        YLog(LOG_NORMAL, @"====> logout wasn't possible (main browser or frame not valid)");
    }
}


- (IBAction)globalLogout:(id)sender
{
    YLog(LOG_NORMAL, @"global logout initiated");
    bool success=false;
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
        {
            frame->ExecuteJavaScript("Caffeine.Utils.logoutAndReload(true);", frame->GetURL(), 0 );
            success = true;
        }
    }
    // if we fail to logout, then stte is uncertain
    if ( ! success )
    {
        isTheAppLoggedIn = FALSE;
        YLog(LOG_NORMAL, @"====> logout wasn't possible (main browser or frame not valid)");
    }
}

- (IBAction)reportIssue:(id)sender
{
    bool calledJSDiag = false;
    
    /*  when the window is closed the renderer process dies and it wont finish the submit
    if ( isTheAppLoggedIn )
    {
        CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
        if ( browser.get() ) {
            CefRefPtr<CefFrame> frame = browser->GetMainFrame();
            if ( frame.get() ) {
                frame->ExecuteJavaScript("Caffeine.UserUtils.openLogUploader();", frame->GetURL(), 0 );
                calledJSDiag = true;
            }
        }
    }
    */
    
    if ( !calledJSDiag )
    {
        BOOL isRetina = TRUE;
        if ( gCurrentOS == 0 )
            isRetina = FALSE;
        else
        {
            if ( [[NSScreen mainScreen] backingScaleFactor] < 2  )
                isRetina = FALSE;
        }
        
        // don't send a screenshot IF the sender is NIL
        // those are automatically called from a crash in the PREVIOUS change
        if ( sender )
        {
            NSImage* img = nil;
            CGImageRef screenshot = CGDisplayCreateImage( CGMainDisplayID() );
            
            //NSRect imageRect = [self getMainWindow].frame;
            NSRect imageRect = NSMakeRect(0.0, 0.0, 0.0, 0.0);
            imageRect.size.height = CGImageGetHeight(screenshot);
            imageRect.size.width = CGImageGetWidth(screenshot);
            
            CGFloat imageScaling = 0.2;
            
            if ( ! isRetina )
            {
                imageScaling = 0.4;
            }
            imageRect.size.height *= imageScaling;
            imageRect.size.width *= imageScaling;
            
            // Create a new image to receive the Quartz image data.
            img = [[NSImage alloc] initWithSize:imageRect.size];
            [img lockFocus];
            
            // Get the Quartz context and draw.
            CGContextRef imageContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
            CGContextDrawImage(imageContext, *(CGRect*)&imageRect, screenshot); [img unlockFocus];
            
            NSString* imgFile = [NSString stringWithFormat:@"%@/%@", [@"~/Library/Logs" stringByExpandingTildeInPath], screenshotFileName];
            [img saveAsJpegWithName:imgFile];
            
            if ( screenshot )
                CFRelease(screenshot);
        }
        
        
        if ( reportIssue == nil )
        {
            reportIssue = [[YReportProblemWindowController alloc] initWithWindowNibName:@"YReportProblemWindowController"];
        }
        [reportIssue showWindow: [reportIssue window]];
    }
}

- (void) sendDiagsIfLoggedIn
{
    if ( isTheAppLoggedIn || insideCorpNetwork )
    {
        [self reportIssue:nil];
    }
}

- (IBAction) preferences:(id)sender
{
    YBreweryWindowController* ctrl = [self getWindowBy:mainUUID];
    [ctrl showDrawer:nil];
    
    [ctrl.window makeKeyAndOrderFront:self];
}

- (IBAction) closeActiveWindow:(id)sender
{
    //YLog(LOG_NORMAL, @"Close Active window");
    for (YBreweryWindowController* ywin in [windows allValues])
    {
        if ( ywin.isDocked == FALSE && [ywin.window isKeyWindow] )
        {
            if ( ywin.isMain == TRUE )
            {
                [ywin hide];
            }
            else
            {
                [ywin.window performClose:self];
            }
        }
    }
}

- (IBAction) ShowMapMenu:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.UserUtils.openMap();", frame->GetURL(), 0 );
    }
    
}

- (IBAction) bringAllWindowsToFront:(id)sender
{
    //[NSApp activateIgnoringOtherApps:TRUE];
    for (YBreweryWindowController* ywin in [windows allValues])
    {
        if ( [ywin isHidden] == false && [ywin isDocked] == false )
            [ywin.window makeKeyAndOrderFront:self];
    }
}

- (IBAction) addContact:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.EditContactUI({type:'add'}, null);", frame->GetURL(), 0 );
    }
}

- (IBAction) viewBlockedContacts:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.UserUtils.openBlockedContacts();", frame->GetURL(), 0 );
    }
}

- (IBAction) showMailWindow:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.Header.openCorporateMail();",frame->GetURL(), 0 );
    }
}

- (void) showOrHideViewMenu:(bool)value
{
    [sortByNameMenuItem setEnabled:value];
    [sortByPresenceMenuItem setEnabled:value];
    [showGroupsMenuItem setEnabled:value];
    [showOfflineContactsMenuItem setEnabled:value];
}


- (IBAction) viewMenusChange: (id)sender
{
/*
 setting view option menus and updating the JS status
 case 'sort-name':
 case 'sort-presence':
 case 'view-offline':
 case 'view-groups':
*/
    
    NSString* action = NULL;
    NSNumber* alphaval;

    NSMenuItem* item = (NSMenuItem*)sender;
    
    NSUInteger currState = [sender state];
    if ( currState  == NSOnState )
    {
        [item setState: NSOffState];
        alphaval = [NSNumber  numberWithBool: FALSE];
    }
    else
    {
        [item setState: NSOnState];
        alphaval = [NSNumber  numberWithBool: TRUE];
    }
    
    if ( sender == showOfflineContactsMenuItem )
    {
        action = kViewOffline;
    }
    else if ( sender == showGroupsMenuItem )
    {
        action = kViewGroups;
    }
    else if ( sender == sortByPresenceMenuItem )
    {
        action = kSortPresence;
    }
    else if ( sender == sortByNameMenuItem )
    {
        action = kSortName;
    }
    
    // saving shell preferences
    [[NSUserDefaults standardUserDefaults] setObject:alphaval forKey:action];
    
    // update CEF
    NSString* cmd = [NSString stringWithFormat:@"Caffeine.Header.setListPrefs('%@');", action];
    
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    CefRefPtr<CefFrame> frame = browser->GetMainFrame();
    frame->ExecuteJavaScript([cmd UTF8String],frame->GetURL(), 0 );
    
    // reverse option in case of mutually exclusive (sorts)
    NSMenuItem* reverse = nil;
    if ( sender == sortByPresenceMenuItem )
    {
        reverse = sortByNameMenuItem;
        action = kSortName;
        
    }
    else if ( sender == sortByNameMenuItem )
    {
        reverse = sortByPresenceMenuItem;
        action = kSortPresence;
    }
    
    if ( reverse != nil )
    {
        if ( [alphaval boolValue] )
        {
            alphaval = [NSNumber numberWithBool:FALSE];
        }
        else
        {
            alphaval = [NSNumber numberWithBool:TRUE];
        }
        
        [reverse setState: NSOffState];
        [[NSUserDefaults standardUserDefaults] setObject:alphaval forKey:action];
    }
    
}


- (IBAction) showHelp:(id)sender
{
    NSString* help = [NSString stringWithFormat:@"http://help.Caffeine.com/kb/index?page=product&y=PROD_Caffeine_DESK&locale=%@&actp=productlink",
                      [currentLocale stringByReplacingOccurrencesOfString:@"-" withString:@"_"]
                      ];
    
    YLog(LOG_NORMAL, @"Calling help %@", help);
    
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: help]];
}

- (IBAction) autoStartLogin:(id)sender
{
    NSUInteger currState = [sender state];
    if ( currState == NSOnState )
        currState = NSOffState;
    else
        currState = NSOnState;
    
    BOOL autoStart = (currState  == NSOnState);

    YLog(LOG_NORMAL, @"Current auto start check = %lu autoStart=%d current=%d", (unsigned long)currState, autoStart, startAtLoginForSandboxed() );
    [[NSUserDefaults standardUserDefaults] setValue: [NSNumber numberWithBool:autoStart] forKey:kShouldAutoStart];
    
    if (  autoStart != startAtLoginForSandboxed() )
    {
        setStartAtLoginForSandboxed(autoStart);
        [self setAutoStartCheck:autoStart];
    }
}

- (IBAction) setAsDefaultYMSGR:(id)sender
{
    NSUInteger currState = [sender state];
    
    if (currState  == NSOffState )
    {
        setCaffeineDefAppForYmsgr(inSandbox);
        
        if ( isCaffeineDefAppForYmsgr() )
            [sender setState: NSOnState];
    }
    else
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText: NSLocalizedString(kAppTitle, kAppTitle)];
        [alert setInformativeText: NSLocalizedString(@"setDefaultForYmsgr", @"Caffeine is already the default handler for YMSGR links")];
        [alert addButtonWithTitle:@"Ok"];
        [alert runModal];
        alert = nil;
    }
}

- (IBAction) enableLogging:(id)sender
{
    NSUInteger currState = [sender state];
    if ( currState == NSOnState )
        currState = NSOffState;
    else
        currState = NSOnState;
 
    if (currState  == NSOnState)
        masterLogEnabled = LOG_ENABLED;
    else
        masterLogEnabled = LOG_DISABLED;
    
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:masterLogEnabled] forKey:kShellLogLevel];
    [loggingEnabledMenuItem setState: (masterLogEnabled? NSOnState: NSOffState )];
    
    for ( NSString* uuid in [windows allKeys])
    {
        std::string sUuid = [uuid UTF8String];
        CefRefPtr<CefBrowser> browser = app->m_WindowHandler[sUuid]->GetBrowser();
        if ( browser.get() )
        {
            CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("setLoggingLevelFrom");
            message->GetArgumentList()->SetInt(0, masterLogEnabled);
            browser->SendProcessMessage(PID_RENDERER, message);
        }
    }
}


- (IBAction) openLogFile:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:getLogFileName()];
}

- (IBAction) debugCookies:(id)sender
{
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
            frame->ExecuteJavaScript("Caffeine.Header.openDebugCookies();",frame->GetURL(), 0 );
    }
}

- (IBAction) checkForUpdates:(id)sender
{
#ifndef NO_SPARKLE_UPDATES
    if ( [updater updateInProgress] )
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText: NSLocalizedString(kAppTitle, kAppTitle)];
        [alert setInformativeText: NSLocalizedString(@"updateIsRunning", @"Caffeine is already trying to download an update")];
        [alert addButtonWithTitle:@"Ok"];
        [alert runModal];
        alert = nil;
    }
    else
    {
        [self checkForUpdates];
        
        //lastTimeUpdateWasChecked = [NSDate timeIntervalSinceReferenceDate];
        //[updater checkForUpdates:self];
    }
#endif
}

#pragma mark ---- LOCATION ------


#define LL_DELTA    100.0 // meters
    
    
- (void)locationManager:(CLLocationManager *)manager
	didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    if ( theAppIsTerminating || theAppReceivedAPowerOff || theAppReceivedUpdateNOW || newLocation == nil ) return;
    
    //YLog(LOG_NORMAL, @"Received location update=%f,%f",  newLocation.coordinate.latitude,  newLocation.coordinate.longitude);
    if ( oldLocation != nil )
	{
        CLLocationDistance distance = [newLocation distanceFromLocation:oldLocation];

        if ( distance < LL_DELTA && !forceSendingOfLocation )
        {
            //YLog(LOG_NORMAL, @"Location difference is %f, skipping setLocation", distance);
            return;
        }
        
        YLog(LOG_NORMAL, @"Current location is latitude=%f, longitude=%f - old loc =%f,%f, delta is %f",
             newLocation.coordinate.latitude,  newLocation.coordinate.longitude,
             oldLocation.coordinate.latitude, oldLocation.coordinate.longitude,
             distance );
        
	}
    
    
    // NOTE - we don't need to be logged in to send location but if we send too early, the JS code isn't ready for us
    if ( theAppHasBeenActivatedAtLeastOnce )
    {
        [self sendCurrentLocation: newLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager   didFailWithError:(NSError *)error
{
    switch([error code])
    {
        case kCLErrorLocationUnknown: // location is currently unknown, but CL will keep trying
            break;
            
        case kCLErrorDenied: // CL access has been denied (eg, user declined location use)
            userDeniedLocation = true;
            break;
            
        case kCLErrorNetwork: // general, network-related error
        default:
            YLog(LOG_NORMAL, @"%@", [NSString stringWithFormat:  NSLocalizedString(@"Location manager failed with error: %@", nil), [error localizedDescription] ]);
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if ( status != kCLAuthorizationStatusAuthorized )
    {
        userDeniedLocation = true;
        app->shellHasLocationData = false;
    }
    else
    {
        userDeniedLocation = false;
        app->shellHasLocationData = true;
    }
    YLog(LOG_MAXIMUM, @"Location manager changed authorization status to %d (userDeniedLocation=%d)", status, userDeniedLocation);
    
    if ( theAppHasLoggedAtLeastOnce && AppGetMainHandler() )
    {
        CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
        if ( browser.get() )
        {
            CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("setLocationServices");
            
            if ( status != kCLAuthorizationStatusAuthorized ) {
                message->GetArgumentList()->SetBool(0, false);
            }
            else
            {
                message->GetArgumentList()->SetBool(0, true);
            }
            browser->SendProcessMessage(PID_RENDERER, message);            
        }
    }
    
    if ( app->m_WindowHandler[mainUUID].get() )
        app->m_WindowHandler[mainUUID]->CreateAndDispatchCustomEvent("shellHasLocationChange");
}

- (void) sendCurrentLocation: (CLLocation*) location
{
    if ( userDeniedLocation == true || theAppIsTerminating == true ) return;
    
    CLLocation *currentLocation = nil;
    if ( location == nil )
        currentLocation = locationManager.location;
    else
        currentLocation = location;
    
    NSString* cmd = nil;
    
    if ( theAppHasLoggedAtLeastOnce )
        cmd = [NSString stringWithFormat: @"Caffeine.Comms.Presence.setLocation({latitude: %f, longitude: %f});",
                     currentLocation.coordinate.latitude,  currentLocation.coordinate.longitude ];
    else
    {
        cmd = [NSString stringWithFormat: @"setTimeout(function(){ Caffeine.Comms.Presence.setLocation({latitude: %f, longitude: %f});}, 3000);",
               currentLocation.coordinate.latitude,  currentLocation.coordinate.longitude ];
    }
    
    if ( currentLocation != nil && AppGetMainHandler().get() )
    {
        CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
        if ( browser.get()) {
            CefRefPtr<CefFrame> frame = browser->GetMainFrame();
            if ( frame.get() )
            {
                frame->ExecuteJavaScript([cmd UTF8String],frame->GetURL(),0);
                YLog(LOG_NORMAL, @"Sending location command: %@", cmd);
            }
        }
    }
    
    if ( forceSendingOfLocation ) forceSendingOfLocation = FALSE;
    
#ifdef DEBUG
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:currentLocation completionHandler:^(NSArray *placemarks, NSError *error)
     {
         if ( error == nil )
         {
             if ( [placemarks count] > 0 ) {
                 CLPlacemark* place = [placemarks objectAtIndex:0];
                 YLog(LOG_NORMAL, @"location geocoder = %@, %@", place.locality, place.country);
             }
         }
     }];
#endif
}

- (bool) isLocationAvailable
{
    return ! userDeniedLocation;
}

- (void) startLocation
{
#ifndef ENABLE_CORE_LOCATION
    // disabling location
    userDeniedLocation = true;
    return;
#else
    
#ifndef DEBUG
    if ( gInDev0 )
    {
        YLog(LOG_NORMAL, @"Dev0 = ignoring location");
        userDeniedLocation = true;
    }
    else
#endif
    {
        YLog(LOG_NORMAL, @"Starting location (userDeniedLocation=%d)", userDeniedLocation);
        if ( ! userDeniedLocation )
        {
            [locationManager startUpdatingLocation];
        }
    }
#endif
}

- (void) stopLocation
{
    {
        [locationManager stopUpdatingLocation];
    }
}


// updating renderer app with keychain info/location

- (void) updateRenderer:(CefRefPtr<CefBrowser> )browser
{        
    // Location availability or not
    if ( browser.get())
    {
        CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("setLocationServices");
        message->GetArgumentList()->SetBool(0, ! userDeniedLocation);
        browser->SendProcessMessage(PID_RENDERER, message);
        
        if ( !userDeniedLocation )
            [self sendCurrentLocation:nil];
    }
}

#pragma mark ----- KEYCHAIN -----

- (void) setKCFromRenderer:(NSString*)token forUser:(NSString *)usr
{
    if ( noAuthorizationForKeychainAccess ) return;
    [[NSUserDefaults standardUserDefaults] setValue:usr forKey:kDefaultUserName];
    YMKeyChain* kc = [YMKeyChain sharedInstance];
    [kc setToken:token forUserName:usr];
    YLog(LOG_ONLY_IN_DEBUG, @"KC: Saved token %@ for user %@", token, usr);
}

- (void) clearTokens
{
    if ( noAuthorizationForKeychainAccess ) return;
    NSString* defUsr = [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultUserName];
    if ( defUsr )
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultUserName];
        YMKeyChain* kc = [YMKeyChain sharedInstance];
        [kc removeTokenForUserName:defUsr];
    }
}

- (void) clearToken:(NSString *)usr
{
    if ( noAuthorizationForKeychainAccess ) return;
    YMKeyChain* kc = [YMKeyChain sharedInstance];
    [kc removeTokenForUserName:usr];
    YLog(LOG_ONLY_IN_DEBUG, @"KC: Removed token for user %@", usr);
    
    NSString* defUsr = [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultUserName];
    if ( [defUsr compare: usr] == NSOrderedSame )
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultUserName];
    }
}

- (NSString*) getToken:(NSString*)user
{
    YMKeyChain* kc = [YMKeyChain sharedInstance];
    NSString* token = nil;
    noAuthorizationForKeychainAccess = false;
    
    if ( user != nil )
    {
        //NSString* token = [kc tokenForUserName:defUsr];
        OSStatus status;
        token = [kc tokenForUserNamewithNoInteraction:user errorCode:&status];
        
        if ( status == errSecAuthFailed )
        {
            YLog(LOG_NORMAL, @"KC: Didn't get authorization, will retry later");
            noAuthorizationForKeychainAccess = true;
            return nil;
        }
    }
    
    return token;
}

- (void) retryGettingDefUserToken
{
    static bool onlyRunOnce = false;
    if ( onlyRunOnce ) return;
    onlyRunOnce = true;
    
    YMKeyChain* kc = [YMKeyChain sharedInstance];
    NSString* defUsr = [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultUserName];
    
    NSString* token = [kc tokenForUserName:defUsr];
    // this flag needs to be set AFTER KC access
    noAuthorizationForKeychainAccess = false;

    YLog(LOG_ONLY_IN_DEBUG, @"KC: retry getting token for defuser: %@", defUsr);

    if ( token != nil && isTheAppLoggedIn == false )
    {
        CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
        if ( browser.get() && defUsr )
        {
            YLog(LOG_NORMAL, @"KC: Found a token, updating setup");
            CefRefPtr<CefProcessMessage> process_message = CefProcessMessage::Create("setDefUserToken");
            
            process_message->GetArgumentList()->SetString(0, [defUsr UTF8String]);
            process_message->GetArgumentList()->SetString(1, [token UTF8String]);
            
            browser->SendProcessMessage(PID_RENDERER, process_message);
            
            CefRefPtr<CefFrame> frame = browser->GetMainFrame();
            if ( frame.get() )
            {
                NSString* cmd = [NSString stringWithFormat:@"Caffeine.LoginUI.setUserTokenAsValid('%@');", token];
                frame->ExecuteJavaScript([cmd UTF8String],frame->GetURL(),0);
            }
        }
    }
    else
        YLog(LOG_NORMAL, @"KC: No token saved for %@", defUsr);
}

#pragma mark --- URL schemas

//static NSString* ymsgrSchema = @"ymsgr://";
static NSString* ymsgrSchema = @"ymsgr:";

//static NSString* openConvFmt  = @"Caffeine.Comms.User.getUser({id:'%@', network:'Caffeine',session:Caffeine.Comms.Session.getCurrentSession()},\
function(err, ct){UserUtils.openConversation({participant: ct, session: Caffeine.Comms.Session.getCurrentSession(), isUserRequestedAction: true});});";



- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    // Extract the URL from the Apple event and handle it here.
    YLog(LOG_NORMAL, @"AppleEvent called - GetURL");
    if ( theAppIsTerminating ) return;
    [NSApp activateIgnoringOtherApps:TRUE];
    
    [event paramDescriptorForKeyword:keyDirectObject] ;
    
    NSString *urlStr = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    
    // Now you can parse the URL and perform whatever action is needed
    YLog(LOG_NORMAL, @"URL: %@", urlStr);
    
    // Parsing for format
    // ymsgr://SendIM?randallcamp
    // ymsgr:SendIM?randallcamp
    
    NSScanner* scanner = [NSScanner scannerWithString:urlStr];
    NSString* buffer;
    
    // scan past the ymsgrSchema
    [scanner scanString:ymsgrSchema intoString:NULL];

    // scan past // if present
    [scanner scanString:@"//" intoString:NULL];
    
    // find IM command
    if ( [scanner scanUpToString:@"?" intoString:&buffer] == NO )
    {
        YLog(LOG_NORMAL, @"Error - unexpected format - no %@<COMMAND>?", ymsgrSchema);
    }
    
    if ( [buffer compare:@"SendIM" options:NSCaseInsensitiveSearch] == NSOrderedSame )
    {
        // move past the ?
        [scanner scanString:@"?" intoString:NULL];
        
        // scan target name
        if ( [scanner scanUpToString:ymsgrSchema intoString:&buffer] )
        {
            /* not escaping the YID
            NSString* escapedBuffer = [buffer stringByEncodingIllegalURLCharacters];
            
            if ( [buffer compare:escapedBuffer] != NSOrderedSame )
            {
                YLog(LOG_NORMAL, @"Escaped yid (%@) is different from original one (%@) - ignoring it", escapedBuffer, buffer);
            }
            else
             */
            {
                //YLog(LOG_NORMAL, @"Found target IM = %@ - is Logged in=%d", escapedBuffer, isTheAppLoggedIn);
                //NSString* cmd = [NSString stringWithFormat:openConvFmt, buffer];
                NSString* cmd = [NSString stringWithFormat:@"Caffeine.pendingYIDs.push(\"%@\");", buffer];
                
                if ( isTheAppLoggedIn )
                {
                    YLog(LOG_NORMAL, @"Executing %@", cmd);
                    
                    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
                    if ( browser.get() )
                    {
                        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
                        if ( frame.get() )
                            frame->ExecuteJavaScript([cmd UTF8String],frame->GetURL(), 0 );
                    }
                }
                else
                {
                    [ymsgrPending addObject:cmd];
                }
            }
        }
        else
        {
            YLog(LOG_NORMAL, @"Error: didn't find target");
        }
    }
    else
    {
        YLog(LOG_NORMAL, @"Unknown command %@ ", buffer);
    }
}

- (void) openPendingLinks
{
    if ( !isTheAppLoggedIn || [ymsgrPending count] == 0 || theAppIsTerminating ) return;
    
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    if ( browser.get() )
    {
        CefRefPtr<CefFrame> frame = browser->GetMainFrame();
        if ( frame.get() )
        {
            for (NSString* vals in ymsgrPending )
            {
                //NSString* cmd = [NSString stringWithFormat:@"setTimeout(function(){%@;},200);", vals];
                YLog(LOG_NORMAL, @"Executing %@", vals);
                frame->ExecuteJavaScript([vals UTF8String],frame->GetURL(), 0 );
            }
        }
    }
    [ymsgrPending removeAllObjects];
}

#pragma mark ============ crash report sent =======


- (void) submitDone:(BOOL) status
{
    if ( reportIssue != nil )
    {
        [reportIssue crashWasUploaded: status];
        cleanOldLogs();
    }
    if ( theRendererHasCrashed )
    {
        theAppIsTerminating = TRUE;
        isTheAppLoggedIn = FALSE;
        [NSApp terminate:self];
    }
}

- (bool) doWeHaveNewCrashReports
{
    NSTimeInterval	lastCrashReportInterval = [[NSUserDefaults standardUserDefaults] floatForKey: kLastCrashReport];
    if ( lastCrashReportInterval == 0 )
    {
        lastCrashReportInterval = [[NSDate date] timeIntervalSince1970];
        [[NSUserDefaults standardUserDefaults] setFloat:lastCrashReportInterval  forKey: kLastCrashReport];
    }
    NSDate*	lastTimeCrashReported = [NSDate dateWithTimeIntervalSince1970: lastCrashReportInterval];
    
    YLog(LOG_NORMAL, @"Last time crash reported was %@", lastTimeCrashReported);
    
    NSURL *appSupportURL = [[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:@"CrashReporter"];
    
    NSDirectoryEnumerator*	enny = [[NSFileManager defaultManager] enumeratorAtPath: [appSupportURL path]];
    for (NSString* crashFile in enny)
    {
        if ( [crashFile rangeOfString: kAppTitle].location != NSNotFound )
        {
            NSDictionary *attributes = [enny fileAttributes];
            NSDate *lastModificationDate = [attributes objectForKey:NSFileModificationDate];
            
            if (lastTimeCrashReported == nil ||  [lastTimeCrashReported earlierDate:lastModificationDate] == lastTimeCrashReported)
            {
                YLog(LOG_NORMAL, @"Found a new crash report - %@", crashFile);
                return true;
            }
        }
    }
    return false;
}

- (void) importAppleCrashReports
{
    if ( ! inSandbox )
    {
        YLog(LOG_NORMAL, @"importAppleCrashReports is not implemented for non-sandboxed apps");
    }
    else
    {
        xpc_connection_t connection = xpc_connection_create(XPC_READ_CRASH_LOGS, NULL);
        
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
            
            xpc_dictionary_apply(event, ^bool(const char *key, xpc_object_t value) {
                
                YLog(LOG_NORMAL, @"XPC %s: %s", key, xpc_string_get_string_ptr(value));
                return true;
            });
        });
        xpc_connection_resume(connection);
        
        NSTimeInterval	lastCrashReportInterval = [[NSUserDefaults standardUserDefaults] floatForKey: kLastCrashReport];
        
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_double (message, "time", lastCrashReportInterval);
        xpc_dictionary_set_string(message,  "name", [kAppTitle UTF8String]);

        /*
        // if there eis no crashreport.log file, we need to create one BEFORE creating a bookmark
        if ( ! [[NSFileManager defaultManager] fileExistsAtPath: getCrashReportLocation()] )
        {
            NSString* dataStr = @"CrashReport\n";
            [[NSFileManager defaultManager] createFileAtPath:getCrashReportLocation() contents:[dataStr dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
        }
        
        NSError* theError = nil;
        NSURL* crashURL = [NSURL fileURLWithPath:getCrashReportLocation()];
        // NSURLBookmarkCreationWithSecurityScope
        NSData* bookmark = [crashURL bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile
                         includingResourceValuesForKeys:nil
                                          relativeToURL:nil
                                                  error:&theError];
        
        if ( theError || (bookmark == nil)) {
            // Handle any errors.
            YLog(LOG_MAXIMUM, @"Couldn't get a bookmark to the %@ file", getCrashReportLocation());
            return;
        }
        YLog(LOG_NORMAL, @"Bookmarking file %@ lenght=%lu", getCrashReportLocation(), [bookmark length]);
        xpc_dictionary_set_data(message, "path", [bookmark bytes], [bookmark length]);
        */
        
        xpc_dictionary_set_string(message,  "file", [getCrashReportLocation() UTF8String]);
        
        xpc_object_t response = xpc_connection_send_message_with_reply_sync(connection, message);
        xpc_type_t type = xpc_get_type(response);
        
        if ( type == XPC_TYPE_ERROR )
        {
            YLog(LOG_MAXIMUM, @"Error comunicating with %s", XPC_READ_CRASH_LOGS);
        }
        else
        {
            YLog(LOG_NORMAL, @"%s reading crash logs", XPC_READ_CRASH_LOGS);
        }
        
        [[NSUserDefaults standardUserDefaults] setFloat: [[NSDate date] timeIntervalSince1970] forKey: kLastCrashReport];
    }
}


#pragma mark NSExceptionHandler Delegate Methods

- (BOOL) exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(NSUInteger)aMask
{
    @try
    {
        if ( theAppIsTerminating || theAppHasToTerminateNow )
            return NO;
        
        YLog(LOG_MAXIMUM, @"Exception Handler - Log (%d): %@ %@",
             theAppIsTerminating,[exception description], [exception reason]);
        
        if ( [[exception name] isEqualToString:NSAccessibilityException] )
            return NO;
        
        // Create a string based on the exception
        NSString *exceptionMessage = [NSString stringWithFormat:@"%@\nReason: %@\nUser Info: %@",
                                      [exception name], [exception reason], [exception userInfo]];
        // Always log to console for history
        YLog(LOG_MAXIMUM, @"Exception raised (%d):\n%@", theAppIsTerminating, exceptionMessage);
        
    } @catch (NSException *e) {
        // Suppress any exceptions raised in the handling
    }
    
    return YES;
}

- (BOOL) exceptionHandler:(NSExceptionHandler *)sender shouldHandleException:(NSException *)exception mask:(NSUInteger)aMask
{
    @try
    {
        if ( theAppIsTerminating || theAppReceivedUpdateNOW || theAppReceivedAPowerOff )
        {
            theAppHasToTerminateNow = TRUE;
            [NSApp terminate:nil];
            return YES;
        }
        else
        {
            YLog(LOG_MAXIMUM, @"Exception Handler - Hang (%d): %@ %@",theAppIsTerminating,[exception description], [exception reason]);
            
#ifdef ENABLE_MUSIC_SHARE
#ifdef ENABLE_ITUNES_TRACKING
            resetITunes();
#endif
#endif  //ENABLE_MUSIC_SHARE            
        }
        
    } @catch (NSException *e) {
        // Suppress any exceptions raised in the handling
    }
    
    // NO just uses the default Apple's crash reporter
    return NO;
}

#pragma mark ---- update DOCK icon -------


- (void) setMsgCount:(NSUInteger) nmsgs bRequest: (BOOL) bRequest
{
    if ( dockView )
    {
        dockView.numberOfMessages = nmsgs;
        dockView.bRequest = bRequest;
        [[NSApp dockTile] display];
    }
    else if ( ! bRequest || nmsgs == 0 )
    {
        NSString* badgeText;
        
        if ( nmsgs > 0 )
            badgeText = [NSString stringWithFormat:@"%lu", (unsigned long)nmsgs];
        else
            badgeText = @"";
        
        [[[NSApplication sharedApplication] dockTile]setBadgeLabel:badgeText];
    }
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
    static NSMenu *dynamicMenu = nil;
    
    if ( dynamicMenu == nil )
    {
        dynamicMenu = [[NSMenu alloc] init];
        
        [dynamicMenu addItemWithTitle:NSLocalizedString(@"about", @"About")
                               action: @selector(about:) keyEquivalent:@""];
    }
    
    if ( isTheAppLoggedIn )
    {
        [dynamicMenu addItemWithTitle:NSLocalizedString(@"disconnect", @"Sign Out")
                               action: @selector(logout:) keyEquivalent:@""];
        [dynamicMenu addItemWithTitle:NSLocalizedString(@"disconnectAll", @"Sign Out - Everywhere")
                               action: @selector(globalLogout:) keyEquivalent:@""];
    }
    
    return dynamicMenu;
}

#pragma mark === setting download defaults ======

- (bool) setDownloadBookmark: (NSURL*) folderURL
{
    NSError* error;
    downloadBookmarkData = [folderURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                               includingResourceValuesForKeys:nil
                                                relativeToURL:nil
                                                        error:&error];
    if ( error )
    {
        YLog(LOG_MAXIMUM, @"ERROR creating bookmakeData - %@", [error description]);
        return false;
    }
    else
    {
        YLog(LOG_NORMAL, @"Sucessfully created a bookmark for URL=%@", folderURL);
    }
    
    NSURL* appSupportURL = [[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:kAppTitle];
    NSURL* saveBookmarkURL = [appSupportURL URLByAppendingPathComponent:bookmarkDefaultDirectoryName];
    
    if ( error )
    {
        YLog(LOG_MAXIMUM, @"ERROR creating bookmark data - %@", [error description]);
        return false;
    }
    
    [downloadBookmarkData writeToURL:saveBookmarkURL atomically:YES];
    YLog(LOG_NORMAL, @"setDefaultDirectory selection: %@", folderURL);
    return true;
}


- (NSString*) setPathDefaultDownloadBookmark
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setResolvesAliases:YES];
    
    if ( [openPanel runModal] == NSOKButton )
    {
        NSArray* urls = [openPanel URLs];
        NSURL* folderURL = [urls objectAtIndex:0];
        YLog(LOG_NORMAL, @"setPathDefaultDownloadBookmark - for %@", folderURL);
        
        if ( [self setDownloadBookmark: folderURL] == false )
            return nil;
        
        return [folderURL path];
    }
    return nil;
}

- (NSString*) getPathForDefaultDownload
{
    NSString* downloads = [self getPathForDefaultDownloadBookmark];
    
    if ( downloads == nil )
        downloads = [@"~/Downloads" stringByExpandingTildeInPath];
    
    return downloads;
}

- (bool) getDefaultDownloadBookmark
{
    NSURL* appSupportURL = [[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:kAppTitle];
    NSURL* saveBookmarkURL = [appSupportURL URLByAppendingPathComponent:bookmarkDefaultDirectoryName];
    
    NSError* error;
    if ( [saveBookmarkURL checkResourceIsReachableAndReturnError:&error] == NO )
    {
        YLog(LOG_ONLY_IN_DEBUG, @"No bookmark data - %@", [error description]);
        return false;
    }

    downloadBookmarkData = [NSData dataWithContentsOfURL: saveBookmarkURL];
    if ( !downloadBookmarkData ) return false;

    YLog(LOG_NORMAL, @"Download bookmark data restored from %@", [saveBookmarkURL path]);

    [self getPathForDefaultDownloadBookmark];
    return true;
}

- (NSString*) getPathForDefaultDownloadBookmark
{
    if ( !downloadBookmarkData ) return nil;
    
    BOOL isStale;
    NSError* error;
    NSURL* saveFolder = [NSURL URLByResolvingBookmarkData:downloadBookmarkData
                                                  options:NSURLBookmarkResolutionWithSecurityScope
                                            relativeToURL:nil
                                      bookmarkDataIsStale:&isStale
                                                    error:&error];
    if ( error )
    {
        YLog(LOG_MAXIMUM,  @"getDefaultDownloadBookmark error: %@", [error localizedDescription]);
        return nil;
    }
    YLog(LOG_NORMAL, @"Download save folder is %@ (stale=%d)", [saveFolder path], isStale);
    
    // bookmark is invalid!
    if ( isStale )
    {
        // remove bookmark
        NSURL* appSupportURL = [[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:kAppTitle];
        NSURL* saveBookmarkURL = [appSupportURL URLByAppendingPathComponent:bookmarkDefaultDirectoryName];

        [[NSFileManager defaultManager] removeItemAtURL:saveBookmarkURL error:&error];
        
        if ( error )
        {
            YLog(LOG_MAXIMUM, @"Error removing stale bookmark from %@", [saveBookmarkURL path]);
        }
        
        downloadBookmarkData = nil;
        return nil;
    }
    
    return [saveFolder path];
}

- (bool) saveFilesToDownload:(NSArray*) files
{
    // TODO: add ~/Downloads support?
    if ( downloadBookmarkData == nil )
        return false;
    
    BOOL isStale;
    NSError* error;
    NSURL* saveFolder = [NSURL URLByResolvingBookmarkData:downloadBookmarkData
                                                  options:NSURLBookmarkResolutionWithSecurityScope
                                            relativeToURL:nil
                                      bookmarkDataIsStale:&isStale
                                                    error:&error];
    
    if ( error )
    {
        YLog(LOG_MAXIMUM,  @"saveFilesToDownload error: %@", [error localizedDescription]);
        return false;
    }
    
    BOOL success = [saveFolder startAccessingSecurityScopedResource];
    YLog(LOG_NORMAL, @"saveFilesToDownload %d - stale=%d", success, isStale);
    
    // Move the file somewhere else
    NSWorkspace* workspace = [NSWorkspace sharedWorkspace];
    NSInteger operationTag;
    
    for (NSString* fullPath in files)
    {
        NSString* dirName = [fullPath stringByDeletingLastPathComponent];
        NSString* fileName = [fullPath lastPathComponent];
        
        BOOL copied = [workspace performFileOperation:NSWorkspaceMoveOperation
                                               source:dirName
                                          destination:[saveFolder path]
                                                files:[NSArray arrayWithObject:fileName]
                                                  tag:&operationTag];
        
        YLog(LOG_ONLY_IN_DEBUG, @"Moved (%d) %@ - %@ to saveFolder", copied, dirName, fileName);
    }
    
    [saveFolder stopAccessingSecurityScopedResource];
    
    return true;
}

@end
