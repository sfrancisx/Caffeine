//
//  YBreweryApplication.m
//  McBrewery
//
//  Created by pereira on 3/12/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#import "YBreweryApplication.h"
#import "YAppDelegate.h"

#import <sys/types.h>
#import <sys/sysctl.h>
#import <ExceptionHandling/NSExceptionHandler.h>

#include <sstream>
#include <string>
#include "CaffeineClientApp.h"
#include "CaffeineClientUtils.h"
#include "include/cef_runnable.h"
#include "app_decl.h"
#include "mac_util.h"
#include <signal.h>
#import "YLog.h"
#import "YSysUtils.h"
#import "YMKeyChain.h"
#import "YPreferencesManager.h"


// uses cache_path parameter +
/// removes it BlastCache == 1
//  removes it if cache is bigger then MAX_CACHE_SIZE
#define USE_PERM_CACHE  1


@interface YBreweryApplication ()

@end

#define MAX_CACHE_SIZE      2147483648           // 2Gb


#pragma mark ---------  Global definitions ---------------------------------

// Main Nib:
NSNib *mainNib;

NSString* logfile = @"~/Library/Logs/console.log";
NSString* tracefile = @"~/Library/Logs/trace.txt";

// setup in YLog
extern bool        gInDev0;

#pragma mark ----- independent functions -------------------

void setUserAgentVersion();

void loadLocalPreferences()
{
    NSNumber* logs = nil;
    if (  [@"stable" compare: getUpdateChannel() ] == NSOrderedSame )
    {
        logs = [NSNumber numberWithInteger: LOG_DISABLED];
    }
    else
    {
        logs = [NSNumber numberWithInteger: LOG_ENABLED];
    }
    
    NSDictionary* defaults = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSString stringWithUTF8String:defaultPathValue], kDefaultPath,
                              [NSNumber numberWithBool:FALSE], kBlastCacheOnExit,
                              [NSNumber numberWithBool:TRUE], kEnableWebGL,
                              
                              // CEF preferences
                              [NSNumber numberWithBool:TRUE], kSortName,
                              [NSNumber numberWithBool:FALSE], kSortPresence,
                              [NSNumber numberWithBool:TRUE], kViewOffline,
                              [NSNumber numberWithBool:TRUE], kViewGroups,
                              
                              // Auto start brewery
                              [NSNumber numberWithBool:TRUE], kShouldAutoStart,
                              
                              logs, kShellLogLevel,
                              
                              nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


void removeCache()
{
    YLog(LOG_NORMAL, @"Removing the cache ---------- ");
    // if remove cache is on
    NSError* error = nil;
    NSString* cache = [NSString stringWithFormat:@"%@/%s", cacheDataPath(), getCaffeineCacheName() ];
    [[NSFileManager defaultManager] removeItemAtPath:cache error:&error];
    if ( error )
    {
        YLog(LOG_NORMAL, @"Error removing cache %@", [error localizedDescription]);
    }
}


NSUInteger getCacheSize()
{
    NSUInteger sz = 0;
    NSError* error = nil;
    
    NSString* cache = [NSString stringWithFormat:@"%@/%s", cacheDataPath(), getCaffeineCacheName() ];
    NSFileManager* fm = [NSFileManager defaultManager];
    sz = [[fm attributesOfItemAtPath:cache error:&error] fileSize];
    if ( !error )
    {
        NSURL* cacheURL = [NSURL fileURLWithPath: cache];
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:cacheURL includingPropertiesForKeys:[NSArray arrayWithObject:NSURLFileSizeKey] options:0 errorHandler:nil];
        
        for (NSURL *url in enumerator)
        {
            NSNumber* sizeNumber;
            if ([url getResourceValue:&sizeNumber forKey:NSURLFileSizeKey error:&error])
                sz += [sizeNumber unsignedLongLongValue];
        }
    }
    
    return sz;
}

//
// BROWSER (only) main function
//

int MyApplicationMain(int argc, const char **argv )
{
    @autoreleasepool
    {
        // set limits
        getLimit();
        setLimit(open_files_needed_by_msgr);
        
        // Main Process
        inBrowserProcess = true;
        NSString* channel = getUpdateChannel();

        loadLocalPreferences();
        
        // initialize store
        [YPreferencesManager sharedManager];
        
        BOOL blastCache = [[NSUserDefaults standardUserDefaults] boolForKey:kBlastCacheOnExit];
        if ( blastCache == TRUE && [channel hasPrefix:@"Dev"] == TRUE )
        {
#ifdef USE_PERM_CACHE
            removeCache();
#endif
            NSString* defUser = [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultUserName];
            if ( defUser )
            {
                // remove def user
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultUserName];
                
                // remove from keychain
                YMKeyChain* kc = [YMKeyChain sharedInstance];
                [kc removeTokenForUserName: defUser];
            }
            
            // clear blast cache
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kBlastCacheOnExit];
            
            //removeAllPersistentValues();
            YPreferencesManager* mgr = [YPreferencesManager sharedManager];
            [mgr removeAllPrefs];
            mgr = nil;
        }
        else
        {
            // check and unset var for incorrect exit
            NSNumber* closedCorrectly = [[NSUserDefaults standardUserDefaults] valueForKey:kCorrectClose];
            
            // if the flag EXISTS and it's FALSE, remove the cache
            if (closedCorrectly != nil && [closedCorrectly boolValue] == FALSE)
            {
                YLog(LOG_NORMAL, @"Detected an incorrect/incomplete program exit - removing the appcache");
                removeCache();
            }
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:FALSE] forKey:kCorrectClose];
        
        masterLogEnabled = [[[NSUserDefaults standardUserDefaults] valueForKey:kShellLogLevel] intValue];
        
        // Log initializtion - logs are reset IF there wasn't a previous crash
        // YLog start - reset and redirect log messages
        // we have to do here
        startLog();
        
        // this will crash the program, for Crash testing
        //((char *)NULL)[1] = 0;
        
        // ----------------------------------------------------
#ifdef DEBUG
        YLog(LOG_NORMAL, @"Shell Command Arguments:");
        for (int i = 0; i< argc; i++)
        {
            YLog(LOG_NORMAL, @"Arg %d, %s", i, argv[i]);
        }
        //YLog(LOG_NORMAL, @"Original file limit is %d, changed it to %d", currlimit, open_files_needed_by_msgr);
#endif
      
#ifdef  USE_PERM_CACHE
        if ( !gInDev0 )
        {
            NSUInteger cacheSz = getCacheSize();
            YLog(LOG_NORMAL, @"AppCache size = %ld - %.02lf%% of maximum", cacheSz, cacheSz/(float)MAX_CACHE_SIZE * 100);
            
            if ( cacheSz >= MAX_CACHE_SIZE )
            {
                YLog(LOG_MAXIMUM, @"Appcache size at %ld was larger then the maximum at %ld - removing it", cacheSz, MAX_CACHE_SIZE);
                removeCache();
            }
        }
#endif
        // ---------------------------------------------------
        // Initialize CEF
        // CEF Arguments
        CefMainArgs main_args(argc, (char**)argv);
        // -------------------------------------------
        // CEF3
        // CEF 3.1916.1662
        int exit_code = CefExecuteProcess(main_args, app.get(), NULL);
        if (exit_code >= 0)
        {
            return exit_code;
        }
        
        // initialize User agent string:
        setUserAgentVersion();
        
        // initialize BA
        [YBreweryApplication sharedApplication];

        // Parse command line arguments.
        AppInitCommandLine(argc, argv);
        
        CefSettings base_settings;
        {
            if ( gInDev0 ) // dont allow dev tools
                ;
            
            else if ( [channel compare:@"devJS" options:NSCaseInsensitiveSearch] == NSOrderedSame )
                
                base_settings.remote_debugging_port = 6747;
            
            else if (
                [channel compare:@"dev" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
                [channel compare:@"dogfood" options:NSCaseInsensitiveSearch] == NSOrderedSame)
                
                base_settings.remote_debugging_port = 6748;
            
                // disable command line for non-dev
            else if ( [channel hasPrefix:@"Dev"] )
            {
                base_settings.remote_debugging_port = 6747;
            }
            else
                base_settings.command_line_args_disabled = true;
        }
#ifdef USE_PERM_CACHE
        if ( ! gInDev0 )
            CefString(&base_settings.cache_path) = [[NSString stringWithFormat:@"%@/%s", cacheDataPath(), getCaffeineCacheName() ] UTF8String];
#endif
        CefString(&base_settings.user_agent) = userAgent;
        base_settings.log_severity = LOGSEVERITY_ERROR;
        base_settings.no_sandbox = TRUE;
        
        // single process is only for testing purpose
        //base_settings.single_process = TRUE;
        // CEF 3.1916.1662
        CefInitialize(main_args, base_settings, app.get(), NULL);
        
        // initialize NSApplication
        YBreweryApplication *applicationObject = (YBreweryApplication*)[YBreweryApplication sharedApplication];
        
        mainNib = [[NSNib alloc] initWithNibNamed:@"MainMenu" bundle:[NSBundle mainBundle]];
        NSArray* nibObjects = nil;
        
        if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_7) // OSX 10.6 & 10.7
            [mainNib CaffeineiateNibWithOwner:applicationObject topLevelObjects:&nibObjects];
        else
            [mainNib CaffeineiateWithOwner:applicationObject topLevelObjects:&nibObjects];
        
        // Initializing video plugins
        // set CEF to use our internal Plugins directory 
        NSURL* url = [[NSBundle mainBundle] builtInPlugInsURL];
        std::string pluginsPath ([url.path cStringUsingEncoding:NSUTF8StringEncoding]);
        CefAddWebPluginDirectory(pluginsPath);
        CefRefreshWebPlugins();
        
        [applicationObject startCEF];
        [applicationObject closeCEF];
    }
	return 0;
}


@implementation YBreweryApplication

- (void) reportException:(NSException *)exception
{
    @try
    {
        YLog(LOG_MAXIMUM, kSeparator);
        YLog(LOG_MAXIMUM, @"YBreweryApplication - report exception:");
        YLog(LOG_MAXIMUM, @"Exception: %@ (reason: %@)\nUser Info: %@",
             [exception name], [exception reason], [exception userInfo]);
        
        for (__strong NSString *s in [exception callStackSymbols] )
            YLog(LOG_MAXIMUM, @"-- %@", s);
        
        YLog(LOG_MAXIMUM, kSeparator);
        
        YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
        if (  [appDel isTheAppTerminating] || appDel->theAppReceivedAPowerOff )
        {
            //[super reportException:exception];
            [self terminate:nil];
        }
        else
        {
            // if the crash was NOT in a worker thread, crash the app
            if ( [[[exception callStackSymbols] lastObject] rangeOfString:@"start_wqthread"].location != NSNotFound
                &&
                [[exception name] compare:NSAccessibilityException ] != NSOrderedSame
                )
            {
                YLog(LOG_MAXIMUM, @"Full crash log in %@", getCrashReportLocation());
                FILE* fp = fopen([getCrashReportLocation() UTF8String], "a+");
                if ( fp )
                {
                    NSDateFormatter* dfmt = [[NSDateFormatter alloc] init];
                    [dfmt setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en-US"]];
                    [dfmt setTimeZone: [NSTimeZone timeZoneWithAbbreviation: @"PST"]];
                    [dfmt setDateStyle: NSDateFormatterFullStyle];
                    [dfmt setTimeStyle:NSDateFormatterFullStyle];
                    //[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
                    
                    NSString* dmsg = [NSString stringWithFormat:@"%@ %@\n", [dfmt stringFromDate:[NSDate date]], [[NSTimeZone defaultTimeZone] description]];
                    
                    fprintf(fp, "%s\n", [dmsg UTF8String]);
                    
                    for (__strong NSString *s in [exception callStackSymbols] )
                        fprintf(fp, "-- %s\n", [s UTF8String]);
                    
                    fclose(fp);
                }
                
                //YLog(LOG_MAXIMUM, @"Logged exception and continue - sent to system reporter");
                //[super reportException:exception];
                
                /*
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText: NSLocalizedString(kAppTitle, kAppTitle)];
                [alert setInformativeText: NSLocalizedString(@"rendercrash", @"There was an unexpected error. Please restart Caffeine")];
                [alert addButtonWithTitle:@"Ok"];
                [alert runModal];
                alert = nil;
                [self terminate:nil];
                */
            }
            else
            {
            }
        }
    }
    @catch (NSException *e) {
        // Suppress any exceptions raised in the handling
    }
}


#pragma mark --- CEF required functions ------------
- (BOOL)isHandlingSendEvent {
    return handlingSendEvent_;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
    handlingSendEvent_ = handlingSendEvent;
}

- (void)sendEvent:(NSEvent*)event {
    CefScopedSendingEvent sendingEventScoper;
    [super sendEvent:event];
}


#pragma  ---- end the program, cleanup -----

void AppQuitMessageLoop()
{
    @try
    {
        CefQuitMessageLoop();
    } @catch (NSException *e) {
        // Suppress any exceptions raised in the handling
    }
}

- (void) startCEF
{
    cefClosed = false;
    CefRunMessageLoop();
}

- (void) closeCEF
{
    if ( cefClosed ) return;
    
    @try
    {
        cefClosed = true;
        CefQuitMessageLoop();
        CefShutdown();
        
    } @catch (NSException *e) {
        // Suppress any exceptions raised in the handling
        NSLog(@"Exception on exit: %@", [e description]);
    }
}

- (void)terminate:(id)sender
{
    @try
    {
        [self closeCEF];
        [super terminate:sender];
        
    } @catch (NSException *e) {
        // Suppress any exceptions raised in the handling
        NSLog(@"Exception on exit: %@", [e description]);
    }
}

@end
