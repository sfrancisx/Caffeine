//
//  YBreweryDockView.h
//  McBrewery
//
//  Created by Fernando Pereira on 3/15/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface YBreweryDockView : NSView

@property (nonatomic) NSUInteger        numberOfMessages;
@property (nonatomic) BOOL              bRequest;

@property (nonatomic) BOOL              anUpdateIsAvailable;
@property (nonatomic) float             updateProgress;

@property (nonatomic) BOOL              isConnected;

- (id) copyWithZone:(NSZone *)zone;
- (void) changeDefIconBundle:(NSBundle*) bundle;

@end
