//
//  YWindow.h
//  McBrewery
//
//  Created by pereira on 4/4/13.
//  Copyright (c) 2014 Caffeine All rights reserved.
//
// Wraps CEF's UnderlayOpenGLHostingWindow or NSWindow
//  for use in YBreweryWindowController

#import <Cocoa/Cocoa.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#include "include/cef_base.h"
#pragma clang diagnostic pop
#import "include/cef_application_mac.h"


//@interface YWindow : NSWindow
@interface YWindow : UnderlayOpenGLHostingWindow

@end
