//
//  YStreamComm.h
//  McBrewery
//
//  Created by Fernando Pereira on 2/19/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import "MacSocketDefs.h"
#import "YStreamCommDelegate.h"

#define YSTREAM_MAX_BUFFER_SIZE 2048

@interface YStreamComm : NSObject

@property (atomic, weak) id <YStreamCommDelegate> delegate;

- (id) initWithHost:(SOCKET)sid host:(NSString*)host andPort:(UInt32) port;

- (BOOL) startConnection:(BOOL)useSSL completion:(void (^)(BOOL success))connectionBlock;
- (void) closeConnection:(void (^) (void))doneBlock;

- (void) gotWriteData:(NSData*)data completion:(void (^) (BOOL success))writeCallback;

@end
