//
//  YCefView.m
//  McBrewery
//
//  Created by Fernando on 6/13/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#import "YCefView.h"

@implementation YCefView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        /*
        // Initialization code here.
        NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                                    options: NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingInVisibleRect | NSTrackingActiveInActiveApp
                                                                      owner:self
                                                                   userInfo:nil];
        [self addTrackingArea:trackingArea];
         
         */
    }
    
    return self;
}


- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

/*

- (void) mouseEntered:(NSEvent*)theEvent {
    // Mouse entered tracking area.
    if ( [self.window isKeyWindow] == FALSE )
    {
        //YLog(LOG_NORMAL, @"YCefView - mouseEntered when inactive - changing it");
        [self.window makeKeyWindow];
    }
}

- (void) mouseExited:(NSEvent*)theEvent {
    // Mouse exited tracking area.
}

- (void) mouseMoved:(NSEvent *)theEvent {
    
    if ( [self.window isKeyWindow] == FALSE )    {
        //YLog(LOG_NORMAL, @"YCefView - mouseMoved when inactive - changing it");
        [self.window makeKeyWindow];
    }
}
 
*/

- (void)drawRect:(NSRect)dirtyRect
{
    NSColor* background = [NSColor colorWithCalibratedRed:95.0/255 green:166.0/255 blue:124.0/255 alpha:1.0];
    
    [background set];
    //[[NSColor blackColor] set];
    NSRectFill(dirtyRect);
}

@end
