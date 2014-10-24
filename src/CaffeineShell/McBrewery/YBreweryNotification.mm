//
//  YBreweryNotification.m
//  McBrewery
//
//  Created by Fernando on 10/7/13.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import "YBreweryNotification.h"
#import "YAppDelegate.h"


@implementation YBreweryNotification

#pragma mark -- Growl notifications

#ifndef NO_GROWL_NOTIFICATIONS

+ (void) showSimpleNotification:(NSString*) title description:(NSString*)description context:(NSDictionary*)context
{
    [GrowlApplicationBridge notifyWithTitle:title // This is the most important method, you notify with a title
                                description:description // a description (keep it short and sweet)
                           notificationName:@"receivedMessageNotification" // The name of the notification, as it appears in your Growl registration dictionary.
                                   iconData:nil // Pass nil to display your apps icon. Pass an empty NSData object to display no icon.
                                   priority:0 // -2 == Low priority. +2 == High Priority. 0 == Neutral. Use wisely. Not all notification styles support priorities.
                                   isSticky:NO // Sticky notifications stick around (sorry) until they're manually dismissed by the user. Don't abuse.
                               clickContext:context]; // LOG_NORMALly a string which is passed to the growlNotificationWasClicked: delegate method to determine what to do when a notification was clicked.
}

#endif

@end
