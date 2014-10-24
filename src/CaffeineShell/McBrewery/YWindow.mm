//
//  YWindow.m
//  McBrewery
//
//  Created by pereira on 4/4/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#import "YWindow.h"

@implementation YWindow

/*

- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)windowStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)deferCreation
{
    if ((self = [super initWithContentRect:contentRect
                                 styleMask:windowStyle
                                 //styleMask:NSBorderlessWindowMask
                                   backing:bufferingType
                                     defer:deferCreation]))
    {
        [self setOpaque:NO];
  
        cefView = [[NSView alloc] initWithFrame: [self frame]];
        [self.contentView addSubview:cefView];
        
        NSRect titleFrame = [self frame];
        titleFrame.size.height = 20;
        
        titleBar = [[NSView alloc] initWithFrame: titleFrame];
        titleBar.alphaValue = 0.2;
        //[self.contentView addSubview:titleBar];
        
        //[self.contentView addSubview:titleBar positioned:NSWindowAbove relativeTo:nil];
        //[self.contentView addSubview:cefView positioned:NSWindowBelow relativeTo:titleBar];
 
    }
    return self;
}

- (NSView*) cefView
{
    return cefView;
}
*/

/*
Custom windows that use the NSBorderlessWindowMask can't become key by default. Override this method
so that controls in this window will be enabled.
 */

- (BOOL)canBecomeKeyWindow {
    
    return YES;
}

/*
 Start tracking a potential drag operation here when the user first clicks the mouse, to establish
 the initial location.
 */

/*
- (void)mouseDown:(NSEvent *)theEvent {
    
    YLog(LOG_NORMAL, @"mouse down");
    // Get the mouse location in window coordinates.
    initialLocation = [theEvent locationInWindow];
}
*/
 
/*
 Once the user starts dragging the mouse, move the window with it. The window has no title bar for
 the user to drag (so we have to implement dragging ourselves)
 */

/*
- (void)mouseDragged:(NSEvent *)theEvent {
    
    
    NSRect screenVisibleFrame = [[NSScreen mainScreen] visibleFrame];
    NSRect windowFrame = [self frame];
    NSPoint newOrigin = windowFrame.origin;
    
    // Get the mouse location in window coordinates.
    NSPoint currentLocation = [theEvent locationInWindow];
    // Update the origin with the difference between the new mouse location and the old mouse location.
    newOrigin.x += (currentLocation.x - initialLocation.x);
    newOrigin.y += (currentLocation.y - initialLocation.y);
    
    // Don't let window get dragged up under the menu bar
    if ((newOrigin.y + windowFrame.size.height) > (screenVisibleFrame.origin.y + screenVisibleFrame.size.height)) {
        newOrigin.y = screenVisibleFrame.origin.y + (screenVisibleFrame.size.height - windowFrame.size.height);
    }
    
    // Move the window to the new location
    [self setFrameOrigin:newOrigin];
}
*/

- (IBAction)performClose:(id)sender
{
    //YLog(LOG_NORMAL, @"performClose for YWindow");
    [super performClose:sender];
}

@end
