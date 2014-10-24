//
//  YAttachedView.m
//  McBrewery
//
//  Created by Fernando on 9/4/13.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import "YAttachedView.h"
#import "YBreweryWindowController.h"

@implementation YAttachedView

- (id)initWithFrame:(NSRect)frame
{
    //    options: NSTrackingMouseMoved | NSTrackingInVisibleRect | NSTrackingActiveInKeyWindow
    //    NSTrackingMouseEnteredAndExited   NSTrackingActiveInActiveApp   NSTrackingActiveAlways

    self = [super initWithFrame:frame];
    if (self) {
        NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                                    options: NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingInVisibleRect | NSTrackingActiveInActiveApp
                                                                      owner:self
                                                                   userInfo:nil];
        [self addTrackingArea:trackingArea];
        _eventMonitor = nil;
    }
    
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

- (BOOL) acceptsFirstResponder
{
    return YES;
}

- (void) startKeyMonitor:(NSInteger)postToWindow
{
    /*
    static bool sendOnce = true;

    //NSWindow* mainWindow = [self.window parentWindow];
    NSAssert(_eventMonitor == nil, @"_eventMonitor should not be created yet");
    
//    _eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDown|NSKeyUp|NSFlagsChanged handler:^(NSEvent* incomingEvent) {
//    _eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask | NSRightMouseDownMask | NSOtherMouseDownMask | NSKeyDownMask
    _eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask: NSKeyDownMask
                                                          handler:^(NSEvent* incomingEvent) {
        
        //YLog(LOG_NORMAL, @"Event monitor for keys %ld, windowd# =%ld postTo=%ld", incomingEvent.type, (long)incomingEvent.window.windowNumber, (long)postToWindow);
                                                              
        if ( (incomingEvent.type == NSKeyDown || incomingEvent.type == NSKeyUp || incomingEvent.type == NSFlagsChanged ) &&
            [incomingEvent window].windowNumber != postToWindow )
        {
            
            NSEvent* newEvent = [NSEvent keyEventWithType:incomingEvent.type
                                                 location:  NSZeroPoint //incomingEvent.locationInWindow
                                            modifierFlags:incomingEvent.modifierFlags
                                                timestamp: [NSDate timeIntervalSinceReferenceDate]
                                             windowNumber:postToWindow
                                                  context:nil  //incomingEvent.context
                                               characters:incomingEvent.characters
                              charactersIgnoringModifiers:incomingEvent.charactersIgnoringModifiers
                                                isARepeat:incomingEvent.isARepeat
                                                  keyCode:incomingEvent.keyCode];
            
            if ( sendOnce ) {
                sendOnce = false;
                [NSApp postEvent:newEvent atStart:TRUE];
            }
            //return (NSEvent*)nil;
        }
        return incomingEvent;
        
    }];
    */
}

- (void) stopKeyMonitor
{
    if (_eventMonitor) {
        [NSEvent removeMonitor:_eventMonitor];
        _eventMonitor = nil;
    }
}

- (void) mouseEntered:(NSEvent*)theEvent {
    // Mouse entered tracking area.
    if ( [self.window isKeyWindow] == FALSE && [self alphaValue] > 0 )
    {
        //YLog(LOG_NORMAL, @"YAttachedView - mouseEntered when inactive - changing it");
        [self.window makeKeyWindow];
    }
}

- (void) mouseExited:(NSEvent*)theEvent {
    // Mouse exited tracking area.
    if ( [self.window isKeyWindow] == TRUE && [self alphaValue] > 0 )
    {
        //NSWindow* mainWindow = [self.window parentWindow];
        //[mainWindow makeKeyWindow];
    }
}

- (void) mouseMoved:(NSEvent *)theEvent {
    
    if ( [self.window isKeyWindow] == FALSE && [self alphaValue] > 0 )
    {
        //YLog(LOG_NORMAL, @"YAttachedView - mouseMoved when inactive - changing it");
        //[self.window makeKeyWindow];
        
        YBreweryWindowController* ctrl = (YBreweryWindowController*) [self.window delegate];
        [ctrl sendMouseMovement:self.window];
    }
    
}


@end
