//
//  setYMSGR.m
//  setYMSGR
//
//  Created by Fernando Pereira on 8/1/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import "setYMSGR.h"

@implementation setYMSGR

// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
- (void)upperCaseString:(NSString *)aString withReply:(void (^)(NSString *))reply {
    NSString *response = [aString uppercaseString];
    reply(response);
}

@end
