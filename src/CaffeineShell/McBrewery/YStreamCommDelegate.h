//
//  YStreamCommDelegate.h
//  McBrewery
//
//  Created by Fernando Pereira on 5/7/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol YStreamCommDelegate <NSObject>

- (void) sendReadCallback:(SOCKET)s data:(NSString*) data;
- (void) sendErrorCallback:(SOCKET)s error:(NSError*) error ;

@end
