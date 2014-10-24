//
//  YAttachedView.h
//  McBrewery
//
//  Created by Fernando on 9/4/13.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface YAttachedView : NSView {
    
    // key monitor
    id       _eventMonitor;
    
};


- (void) startKeyMonitor:(NSInteger)postToWindow;
- (void) stopKeyMonitor;

@end
