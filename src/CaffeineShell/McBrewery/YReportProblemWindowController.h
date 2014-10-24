//
//  YReportProblemWindowController.h
//  McBrewery
//
//  Created by pereira on 5/2/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <string>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#include "include/cef_base.h"
#pragma clang diagnostic pop
#include "CaffeineClientApp.h"
#include "CaffeineClientHandler.h"

@interface YReportProblemWindowController : NSWindowController {
    
    IBOutlet NSTextView *messageText;
    IBOutlet NSTextField *crashWarning;
    IBOutlet NSButton    *sendScreenshot;
    
    CefRefPtr<CefURLRequest> url_request;
}


- (IBAction)sendMailList:(id)sender;
- (IBAction)cancel:(id)sender;

- (void) uploadCrash;
- (void) crashWasUploaded:(BOOL) status;

- (void) cantSendLogs;

@end
