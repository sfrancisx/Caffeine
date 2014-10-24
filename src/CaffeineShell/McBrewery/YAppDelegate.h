//
//  YAppDelegate.h
//  McBrewery
//
//  Created by pereira on 3/12/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#include "string"
#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>
#import "YBreweryWindowController.h"
#import "YReportProblemWindowController.h"
#import "Reachability.h"

#ifndef NO_GROWL_NOTIFICATIONS
#import <Growl/Growl.h>
#endif

extern NSString* mainWindowNIB ;
extern NSString* conversationWindowNIB ;
extern NSString* conversationWindowNRNIB ;
extern NSString* dockableWindowNIB ;
extern NSString* framelessWindowNIB ;


extern std::string mainUUID;

@class MAAttachedWindow;

#ifndef NO_SPARKLE_UPDATES
@class SUUpdater;
#endif

@interface YAppDelegate : NSObject <NSApplicationDelegate,

#ifndef NO_GROWL_NOTIFICATIONS

                                    GrowlApplicationBridgeDelegate,
#endif

                                    NSMenuDelegate,
                                    NSUserNotificationCenterDelegate,
                                    CLLocationManagerDelegate>
{
    // Container for all YBreweryController objects created
    // this includes Main, Popup and Dockable windows
    NSMutableDictionary*            windows;
 
    // regulr menu items
    IBOutlet NSMenuItem*            preferencesMenuItem; // user OPTIONS ONLY
    IBOutlet NSMenuItem*            sendDiagnosticsMenuItem;
    IBOutlet NSMenuItem*            sendFeedbackMenuItem;

    IBOutlet NSMenuItem*            logoutMenuItem;
    IBOutlet NSMenuItem*            globalLogoutMenuItem;
    IBOutlet NSMenuItem*            VideoMenuItem;

    IBOutlet NSMenuItem*            conversationHistoryMenuItem;
    IBOutlet NSMenuItem*            PreferencesMenuItem;
    IBOutlet NSMenuItem*            profileSettingsMenuItem;

    IBOutlet NSMenuItem*            ShowMap;
    
    IBOutlet NSMenuItem*            showOfflineContactsMenuItem;
    IBOutlet NSMenuItem*            showGroupsMenuItem;
    IBOutlet NSMenuItem*            sortByPresenceMenuItem;
    IBOutlet NSMenuItem*            sortByNameMenuItem;
    IBOutlet NSMenuItem*            addContactMenuItem;
    IBOutlet NSMenuItem*            viewBlockedContactsItem;
    IBOutlet NSMenuItem*            viewMenu;
    IBOutlet NSMenuItem*            showMainWindowItem;
    IBOutlet NSMenuItem*            contactsMenu;

    IBOutlet NSMenuItem*            CorporateEmail;
    IBOutlet NSMenuItem*            CaffeineEmail;

    IBOutlet NSMenuItem*            startAtLoginMenuItem;
    IBOutlet NSMenuItem*            setAsDefaultForYmsgr;
    
    IBOutlet NSMenuItem*            loggingEnabledMenuItem;
    IBOutlet NSMenuItem*            openLogFileItem;
    
    YReportProblemWindowController* reportIssue;
    
    // for crash reporting tool
    // if previous crash was detected, this flag is set
    BOOL                            sendReportsOnStartup;
    
    BOOL                            insideCorpNetwork;
    
@private
    
    BOOL                            theRendererHasCrashed;
    
    // Closing the APP:
    // we need this flag to make sure we give time for JS to logout
    BOOL                            theAppIsTerminating;
    
    //
    //                              set to true if it has been activated once; prevents show window for never activated app (started as Hidden)
    BOOL                            theAppHasBeenActivatedAtLeastOnce;
    
    // sleep mode
    NSTimeInterval                  sleepStartTime;
    
    // Reachability
    Reachability*                   hostReach;
    Reachability*                   internetReach;
    Reachability*                   wifiReach;
    
    // Location
    CLLocationManager*              locationManager;
    bool                            userDeniedLocation;
    bool                            forceSendingOfLocation;
    
    // ymsgr links received when user isn't logged in
    NSMutableArray*                 ymsgrPending;
    
@public
    // system settings locale
    NSString*                       currentLocale;
    BOOL                            inSandbox;
    
    NSString*                       feedbackLink;
        
    // logged in
    BOOL                            isTheAppLoggedIn;
    BOOL                            theAppHasLoggedAtLeastOnce;
    
    BOOL                            theAppHasToTerminateNow;
    
    BOOL                            theAppReceivedAPowerOff;
    
    //                              SPARKLE: user selected UpdateNOW
    BOOL                            theAppReceivedUpdateNOW;
 
#ifdef ENABLE_MUSIC_SHARE
    // iTunes stats
    NSDictionary*                   iTunesPlayerStat;
#endif
    
    BOOL                            macWithWithResolutionDisplay;
}

#ifdef ENABLE_MUSIC_SHARE
- (NSDictionary*)   getCurrentiTunesPlayerStat;
#endif

// Creates a new Popup Window
- (YBreweryWindowController*) createWindow:(const std::string&) uuid
                                   initArg:(const char*)initArg
                                      size:(NSRect*)sz
                                 frameless:(bool)frameless
                                 resizable:(bool)resizable
                                    target:(const std::string&) target
                                  minWidth:(const int) minWidth
                                 minHeight:(const int) minHeight;

// Creates a new Dockable Window
- (YBreweryWindowController*) createDockable:(const std::string&) uuid
                                     initArg:(const char*)initArg
                                      target:(const std::string&) targetUUID
                                       width:(int)width
                                         top:(int)minTop
                                      bottom:(int)minBottom;

// returns window controller by UUID
- (YBreweryWindowController*) getWindowBy:(const std::string&) uuid;

// returns docked window by conversation
- (YBreweryWindowController*) getDockedWindow:(YBreweryWindowController*) conversation;

// returns the main (Contacts) window
- (NSWindow*) getMainWindow;

// moves and/or resizes a window
- (void) moveOrResizeWindow:(const std::string&) uuid sizeAndPosition:(NSRect*)sz;

// View Menus
- (void) showOrHideViewMenu:(bool)value;

// CEF functions
- (void) handleException:(NSException*) exception;

// state changes
- (void) sessionLoggedInStateChange:(bool) value;
- (void) enableSessionMenus: (bool) value;

// Window visibility
- (void) showWindow:(const std::string&) uuid;
- (void) hideWindow:(const std::string&) uuid;
- (void) setsRendererUUID:(YBreweryWindowController*) win;
- (void) changeWindowTitle:(CefRefPtr<CefBrowser>) browser newTitle:(NSString*) title;

- (void) activateOrDeactivate:(bool) activation;
- (void) activateOrDeactivate:(bool) activation uuid:(std::string&)uuid;

- (void) shakeWindow: (const std::string&)uuid;

// Menu items
- (IBAction) preferences:(id)sender;
- (IBAction) showMainWindow:(id)sender;
- (IBAction) about:(id)sender;
- (IBAction) videoSettings:(id)sender;
- (IBAction) videoConference:(id)sender;
- (IBAction) conversationHistory:(id)sender;
- (IBAction) Preferences:(id)sender;
- (IBAction) profilePreferences:(id)sender;
- (IBAction) userFeedback:(id)sender;
- (IBAction) logout:(id)sender;
- (IBAction) globalLogout:(id)sender;
- (IBAction) reportIssue:(id)sender;
- (IBAction) terminateApp:(id)sender;
- (IBAction) addContact:(id)sender;
- (IBAction) ShowMapMenu:(id)sender;
- (IBAction) closeActiveWindow:(id)sender;
- (IBAction) bringAllWindowsToFront:(id)sender;
- (IBAction) viewBlockedContacts:(id)sender;
- (IBAction) debugCookies:(id)sender;
- (IBAction) checkForUpdates:(id)sender;

- (void) sendDiagsIfLoggedIn;

// view menus
- (IBAction) viewMenusChange: (id)sender;
- (void) setUpViewMenus: (bool) value;
- (void) setUpViewMenu:(NSMenuItem*) menuItem action:(NSString*) action;

- (IBAction) showMailWindow:(id)sender;
- (IBAction) openYMailWindow:(id)sender;

- (IBAction) autoStartLogin:(id)sender;
- (IBAction) setAsDefaultYMSGR:(id)sender;

- (IBAction) enableLogging:(id)sender;
- (IBAction) openLogFile:(id)sender;

- (IBAction) showHelp:(id)sender;

// login/preferences menus
- (void) setSessionMenus:(bool) value;

- (void) checkForUpdates;

// convert RECT y from JS to Mac Coocoa coordinates
- (void) convertRECTfromJS:(NSRect*)rect;

// location
- (bool) isLocationAvailable;
- (void) startLocation;
- (void) stopLocation;
- (void) sendCurrentLocation: (CLLocation*) location;

// consistency
- (void) resetCaffeine;
- (void) rendererHasCrashed:(CefRefPtr<CefBrowser>) browser;
- (void) terminateDueToUnexpectedError;

// get keyUUID
- (BOOL) getKeyWindow:(std::string&) keyUUID;

// get UUID from CefBrowser
- (BOOL) getUUID:(std::string&)keyUUID fromBrowser:(CefRefPtr<CefBrowser>) browser;

// keychain
- (void) setKCFromRenderer:(NSString*)token forUser:(NSString*)usr;
- (void) clearToken:(NSString *)usr;
- (void) clearTokens;
- (NSString*) getToken:(NSString*)user;

// Update Renderer Process with native data:
// location, keychain, etc
- (void) updateRenderer:(CefRefPtr<CefBrowser> )browser;

- (BOOL) insideCorpNetwork;

- (void) openPendingLinks;

- (BOOL) isTheAppTerminating;

- (void) submitDone:(BOOL) status;

- (void) setMsgCount: (NSUInteger) nmsgs bRequest: (BOOL) bRequest;

- (void) incomingMessage:(NSString*) from displayName:(NSString*) displayName msg:(NSString*) msg convId:(NSString*) convId;

- (void) mainFinishedLoading;

// support for NSURLBookmarks
- (bool) setDownloadBookmark: (NSURL*) folderURL;
- (NSString*) setPathDefaultDownloadBookmark;
- (NSString*) getPathForDefaultDownloadBookmark;
- (NSString*) getPathForDefaultDownload;

- (bool) getDefaultDownloadBookmark;
- (bool) saveFilesToDownload:(NSArray*) files;


@end
