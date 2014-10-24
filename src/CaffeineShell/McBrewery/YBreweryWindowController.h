//
//  YBreweryWindowController.h
//  McBrewery
//
//  Created by pereira on 3/21/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <string>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#include "include/cef_base.h"
#pragma clang diagnostic pop
#include "CaffeineClientHandler.h"
#import "CommonDefs.h"
#import "YAttachedView.h"


@class MAAttachedWindow;

@interface YBreweryWindowController : NSWindowController <NSWindowDelegate, NSDrawerDelegate>
{
    // DEV preferences
    IBOutlet NSDrawer           *drawer;
    IBOutlet NSTextField        *filesLocation;
    IBOutlet NSButton           *removeCacheOnExit;
    IBOutlet NSButton           *enableWebGL;
    
@private
    // window unique id
    std::string                       uuid;
    NSString*                         initArg;
    
    bool                              isMainWindow;
    bool                              isDocked;
    bool                              isFrameless;
    
    bool                              windowIsHidden; // set by hide/show
    
    int                               dockedMinTop;
    int                               dockedMinBottom;
    
    NSImage*                          backgroundImage;

    bool                              bIsCurrentActive;
    
    NSTimeInterval                    windowCreationTime;
    NSTimeInterval                    windowFirstShowTime;

@public
    
    bool                              closeWindowWithoutWaitingForCEF;
    
    std::string                       targetUuid;
    std::string                       windowTargetType;
    
    MAAttachedWindow*                 attachedWindow;
    YAttachedView*                    attachedView;
}

@property (nonatomic,copy) NSString*  lastTitle;

- (id) initWithWindowNibName:(NSString *)windowNibName target:(NSString*)target;

- (bool) isDocked;
- (bool) isMain;
- (bool) isHidden;

- (void) updateFrame;
- (BOOL) startClosingCEF;

- (void) hide;
- (void) show;
- (bool) windowWasShownFromJS;

- (void) setAttachedTransparency:(float) value;
- (void) closesAttachedWindow;
- (void) removeAttachedWindowFromHierarchy;
- (MAAttachedWindow*) getAttachedWindow;

- (NSWindow*) currWindow;

- (IBAction)setRemoveCacheOnExit:(id)sender;
- (IBAction)setDefaultPath:(id)sender;
- (IBAction)setOthertPath:(id)sender;
- (IBAction)setEnableWebGL:(id)sender;
- (IBAction)checkForUpdates:(id)sender;

- (void)alert:(NSString*)title withMessage:(NSString*)message;
- (IBAction)showDrawer:(id)sender;
- (IBAction)hideDrawer:(id)sender;

- (IBAction)goBack:(id)sender;
- (IBAction)goForward:(id)sender;
- (IBAction)reload:(id)sender;
- (IBAction)stopLoading:(id)sender;
- (IBAction)takeURLStringValueFrom:(NSTextField *)sender;


- (void)notifyConsoleMessage:(id)object;
- (void)notifyDownloadComplete:(id)object;
- (void)notifyDownloadError:(id)object;

- (void) setUUID:(const std::string&)u initArg:(const char*) ia target:(const std::string&) target;
- (void) setUUID:(const std::string &)u initArg:(const char *)ia attachedTo:(NSWindow*) mainWindow width:(int)width top:(int)minTop bottom:(int)minBottom;
- (std::string&) getUUID;
- (CefRefPtr<CaffeineClientHandler> ) getHandler;

- (void)reloadStopAndPage;

- (void) customizeFrame;
- (bool) windowHasAttachedDock;

- (void) sendMouseMovement: (NSWindow*) winMouse;

- (void) activateOrDeactivate:(bool) activation;

- (void) shakeWindow;

@end
