//
//  YRTTManager.h
//  McBrewery
//
//  Created by Fernando Pereira on 5/7/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MacSocketDefs.h"

@interface YRTTManager : NSObject

+ (id)sharedManager;

- (SOCKET)  createSocket:host port:(uint32)port useSSL:(bool)useSSL socket:(SOCKET)s;
- (void)    writeToSocket:(SOCKET)s data:(NSData*) data;
- (void)    closeSocket:(SOCKET) s;

- (void)    terminateRTT;

- (void)    netloss;

@end
