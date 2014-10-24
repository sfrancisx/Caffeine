//
//  setYMSGR.h
//  setYMSGR
//
//  Created by Fernando Pereira on 8/1/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "setYMSGRProtocol.h"

// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
@interface setYMSGR : NSObject <setYMSGRProtocol>
@end
