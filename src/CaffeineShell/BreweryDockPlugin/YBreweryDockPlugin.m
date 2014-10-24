//
//  YBreweryDockPlugin.m
//  McBrewery
//
//  Created by Fernando Pereira on 4/18/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import "YBreweryDockPlugin.h"
#import "YBreweryDockView.h"

@interface YBreweryDockPlugin ()

@property (nonatomic, copy) YBreweryDockView* dockView;

@end

@implementation YBreweryDockPlugin

- (void)setDockTile:(NSDockTile *)dockTile
{
    //NSLog(@"Setting up custom dock for Caffeine Caffeine");
    if ( dockTile != nil )
    {
        self.dockView = [[YBreweryDockView alloc] init];
        [self.dockView changeDefIconBundle: [NSBundle bundleForClass:[self class]]];
        [dockTile setContentView: self.dockView];
        [dockTile display];
    }
    else
    {
        self.dockView = nil;
    }
}


@end
