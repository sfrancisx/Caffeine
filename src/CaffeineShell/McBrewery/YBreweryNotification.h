//
//  YBreweryNotification.h
//  McBrewery
//
//  Created by Fernando on 10/7/13.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YBreweryNotification : NSObject

#ifndef NO_GROWL_NOTIFICATIONS

// Creates a Growl Notitication
+ (void) showSimpleNotification:(NSString*)title description:(NSString*)description context:(NSDictionary*)context;

#endif

@end
