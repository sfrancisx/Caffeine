//
//  Qzutils.c
//  McBrewery
//
//  Created by Fernando Pereira on 10/23/13.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/Graphics/IOGraphicsLib.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/Graphics/IOGraphicsLib.h>
#import "CommonDefs.h"


#pragma mark Quartz displauy change notifications


void MyDisplayReconfigurationCallBack(CGDirectDisplayID display,
                                      CGDisplayChangeSummaryFlags flags,
                                      void *userInfo)
{
    if (flags & kCGDisplaySetModeFlag)
    {
        NSArray* screens = [NSScreen screens];
        YLog(LOG_NORMAL, @"Display %d is going to change (total displays: %lu)", display, (unsigned long)[screens count]);
        [[NSNotificationCenter defaultCenter] postNotificationName:CSDisplayChange object:nil];
    }
}




#pragma mark -- Public API ----


void startListeningForDisplayChanges()
{
    CGError err = CGDisplayRegisterReconfigurationCallback(MyDisplayReconfigurationCallBack, NULL);
    if(err == kCGErrorSuccess)
    {
        YLog(LOG_NORMAL, @"Success starting to listen for display changes");
    }
    else
    {
        YLog(LOG_NORMAL, @"Error starting to listen for display changes: %d", err);
    }
    
}

void endListeningForDisplayChanges()
{
    CGDisplayRemoveReconfigurationCallback(MyDisplayReconfigurationCallBack, NULL);
}


