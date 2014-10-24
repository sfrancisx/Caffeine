//
//  YBreweryApplication.h
//  McBrewery
//
//  Created by pereira on 3/12/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

// YBreweryApplication
//
// CEF requires a custom NSApplication (this isn't usual in Cocoa programming)
//


#import <Cocoa/Cocoa.h>
#include <string>
#include <sstream>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#include "include/cef_base.h"
#pragma clang diagnostic pop
#include "include/cef_app.h"
#import "include/cef_application_mac.h"

@interface YBreweryApplication : NSApplication <CefAppProtocol>
{
@private
    bool handlingSendEvent_;
    bool cefClosed;
}

- (void) startCEF;
- (void) closeCEF;
- (void) terminate:(id)sender;

@end
