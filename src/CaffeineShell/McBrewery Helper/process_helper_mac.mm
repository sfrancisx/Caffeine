//
//  process_helper_mac.cpp
//  McBrewery
//
//  Created by pereira on 3/16/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#include "include/cef_base.h"
#pragma clang diagnostic pop
#include "include/cef_app.h"
#include "CaffeineClientApp.h"  // NOLINT(build/include)

#include "../McBrewery/app_decl.h"  // global declarations shared with the Browser process
#import "CommonDefs.h"
#import "YLog.h"
#import "YSysUtils.h"


void setUserAgentVersion();


// Process entry point.
int main(int argc, char* argv[])
{
    @autoreleasepool {
        
        @try {
            // TODO: does this affects this:
            // for - ipc_channel_posix.cc(933)] pipe error (3): Message too long?
            // https://code.google.com/p/chromium/issues/detail?id=151039
            // set limits
            getLimit();
            setLimit(open_files_needed_by_msgr);
            
            // rendeerer/gpu/etc helper process
            inBrowserProcess = false;
            masterLogEnabled = LOG_ENABLED;
            
            // YLog start
            NSLog(@"Starting %s", argv[0]);
            startLog();
            YLog(LOG_MAXIMUM, @"Starting Helper process pid=(%ld): %s", getpid(), argv[0]);
            
            if ( memcmp(argv[1], "--type=gpu-process", sizeof("--type=gpu-process")) == 0 )
            {
                YLog(LOG_NORMAL, @"Helper (%d) is GPU process", getpid());
            }
            
            // initialize User agent string:
            setUserAgentVersion();
            
#ifdef DEBUG
            for (int i=1; i<argc; i++)
            {
                YLog(LOG_NORMAL, @"Arg %d - %s", i, argv[i]);
            }
#endif
            CefTime startTime;
            startTime.Now();
            
            app->SetRenderProcessCreationTime(startTime);
            
            /* Uncomment this block if we need stats on memory usage again
             
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0), ^{
                @try {
                    while (true) {
                        report_memory();
                        report_cpu();
                        [NSThread sleepForTimeInterval: kMemoryUsageReportingInterval];
                    }
                }
                @catch (NSException *exception) {
                    YLog(LOG_NORMAL, @"Exceptin when checking for helper memory - %@", [exception description]);
                }
                @finally {
                }
            });
            */
                        
            // Initialize CEF render process
            CefMainArgs main_args(argc, argv);
            
            // Execute the secondary process.
            // CEF 3.1916.1662+
            int rc = CefExecuteProcess(main_args, app.get(),NULL);
            
            return rc;
        }
        @catch (NSException* exception) {
            YLog(LOG_MAXIMUM, @"=== Exception in helper process: %@", [exception description]);
        }
        @finally {
        }
    }
}

#pragma mark ------ mac_util.mm stubs ------------------------------------------

// The render process doesn't include AppKit or any UI code
// empty function stubs for the helper app (no dock icon,etc)

CefWindowHandle AppGetMainHwnd() {
    return NULL;
}

bool getDefaultUserToken(std::string& usr, std::string& tok) { return false; }


// --- eof ------------

