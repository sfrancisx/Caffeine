//
//  YBreweryDockView.m
//  McBrewery
//
//  Created by Fernando Pereira on 3/15/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import "YBreweryDockView.h"


// indent for icon
const float kIconIndent = 10.0f;


// -- BADGE
// The fraction of the size of the dock icon that the badge is.
const float kBadgeFraction = 0.4f;

// The indentation of the badge.
const float kBadgeIndent = 1.0f;


// -- UPDATE indicator
// The fraction of the Update signa;.
const float kUpdateSignalFraction = 0.2f;

// The indentation of the Update signal.
const float kUpdateSignalIndent = 3.0f;


// not connected
const float kNotConnectedFraction = 0.2f;

// The indentation of the Update signal.
const float kNotConnectedIndent = 3.0f;



@interface YBreweryDockView()

@property (assign, nonatomic) NSBundle* iconBundle;

@end


@implementation YBreweryDockView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        
        self.numberOfMessages = 0;
        self.bRequest= FALSE;
        self.anUpdateIsAvailable = FALSE;
        self.updateProgress = 0.0f;
        self.isConnected = FALSE;
        self.iconBundle = nil;
    }
    return self;
}


- (void) changeDefIconBundle:(NSBundle*) bundle
{
    self.iconBundle = bundle;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if ( self.iconBundle == nil )
        self.iconBundle = [NSBundle mainBundle];
    
    NSImage* appIcon = nil;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *dockOrientation = [[defaults persistentDomainForName:@"com.apple.dock"] valueForKey:@"orientation"];
    
    NSRect visFrame = [[NSScreen mainScreen] visibleFrame];
    NSRect fullFrame = [[NSScreen mainScreen] frame];
    
    CGFloat dockHeight = fullFrame.size.height - visFrame.size.height;
    CGFloat dockWidth = fullFrame.size.height - visFrame.size.height;
    
    if ( [dockOrientation compare:@"bottom" options:NSCaseInsensitiveSearch] == NSOrderedSame )
    {
        if ( dockHeight > 100)
            appIcon = [[NSImage alloc] initWithContentsOfFile:[self.iconBundle pathForResource:@"ymsgr_large" ofType:@"png"]];
        else
            appIcon = [[NSImage alloc] initWithContentsOfFile:[self.iconBundle pathForResource:@"ymsgr_noname" ofType:@"png"]];
    }
    else
    {
        if ( dockWidth > 125)
            appIcon = [[NSImage alloc] initWithContentsOfFile:[self.iconBundle pathForResource:@"ymsgr_large" ofType:@"png"]];
//            appIcon = [NSImage imageNamed:@"ymsgr_large.png"];
        else
            appIcon = [[NSImage alloc] initWithContentsOfFile:[self.iconBundle pathForResource:@"ymsgr_noname" ofType:@"png"]];
    }
    if ( appIcon == nil )
        appIcon = [NSImage imageNamed: NSImageNameApplicationIcon];
    
    if ( appIcon == nil )
    {
        NSLog(@"Couldn't load custom icon");
        [super drawRect:dirtyRect];
        return;
    }
    
    NSRect iconRect = dirtyRect;//[self bounds];
    iconRect.origin.x += kIconIndent;
    iconRect.origin.y += kIconIndent;
    iconRect.size.height -= 2 * kIconIndent;
    iconRect.size.width -= 2 * kIconIndent;
    
    [appIcon drawInRect:iconRect
               fromRect:NSZeroRect
              operation:NSCompositeSourceOver
               fraction:1.0];
    
    if ( self.anUpdateIsAvailable && self.updateProgress > 0 )
    {
        NSRect badgeRect = [self bounds];
        
        badgeRect.size.height = (int)(kUpdateSignalFraction * badgeRect.size.height);
        
        int newWidth = kUpdateSignalFraction * NSWidth(badgeRect);
        
        badgeRect.origin.x = kUpdateSignalIndent;
        badgeRect.size.width = newWidth;
        
        badgeRect.origin.y = dirtyRect.size.height - badgeRect.size.height - 2 * kUpdateSignalIndent ;
        
        NSPoint badgeCenter = NSMakePoint(NSMidX(badgeRect), NSMidY(badgeRect));
        CGFloat badgeRadius = NSMidY(badgeRect);
        
        // Background
        NSColor* backgroundColor = [NSColor colorWithCalibratedRed:0.85  green:0.85  blue:0.85 alpha:1.0];

        NSColor* backgroundHighlight = [backgroundColor blendedColorWithFraction:0.85   ofColor:[NSColor whiteColor]];
        
        NSGradient* backgroundGradient = [[NSGradient alloc] initWithStartingColor:backgroundHighlight
                                                                       endingColor:backgroundColor];
        
        NSBezierPath* badgeEdge = [NSBezierPath bezierPathWithOvalInRect:badgeRect];
        {
            [badgeEdge addClip];
            [backgroundGradient drawFromCenter:badgeCenter
                                        radius:0.0
                                      toCenter:badgeCenter
                                        radius:badgeRadius
                                       options:0];
        }
        
        // Slice
        //if (self.updateProgress >= 0.1 )
        {
            /*
            NSColor* sliceColor = [NSColor colorWithCalibratedRed:0.45
                                                            green:0.8
                                                             blue:0.25
                                                            alpha:1.0];
            */
            NSColor* sliceColor = [NSColor colorWithCalibratedRed:0.4
                                                            green:0.0
                                                             blue:0.8
                                                            alpha:1.0];
            
            NSColor* sliceHighlight =[sliceColor blendedColorWithFraction:0.4 ofColor:[NSColor whiteColor]];
            
            NSGradient* sliceGradient = [[NSGradient alloc] initWithStartingColor:sliceHighlight endingColor:sliceColor];
            
            NSBezierPath* progressSlice;
            if (self.updateProgress >= 1.0)
            {
                progressSlice = [NSBezierPath bezierPathWithOvalInRect:badgeRect];
            }
            else
            {
                CGFloat endAngle = 90.0 - 360.0 * self.updateProgress;
                if (endAngle < 0.0)
                    endAngle += 360.0;
                progressSlice = [NSBezierPath bezierPath];
                [progressSlice moveToPoint:badgeCenter];
                [progressSlice appendBezierPathWithArcWithCenter:badgeCenter
                                                          radius:badgeRadius
                                                      startAngle:90.0
                                                        endAngle:endAngle
                                                       clockwise:YES];
                [progressSlice closePath];
            }
            NSGraphicsContext* gc = [NSGraphicsContext currentContext];
            [gc saveGraphicsState];
            [progressSlice addClip];
            [sliceGradient drawFromCenter:badgeCenter
                                   radius:0.0
                                 toCenter:badgeCenter
                                   radius:badgeRadius
                                  options:0];
            
            [gc restoreGraphicsState];
        }
        
        /*
        // Edge
        {
            [[NSColor whiteColor] set];
            NSShadow* shadow = [[NSShadow alloc] init];
            
            [shadow setShadowOffset:NSMakeSize(0, -2)];
            [shadow setShadowBlurRadius:2];
            [shadow set];
            [badgeEdge setLineWidth:2];
            [badgeEdge stroke];
        }
        */
        
        /*
        //---
        NSGraphicsContext* gc = [NSGraphicsContext currentContext];
        [gc saveGraphicsState];
        
        NSBezierPath* circlePath = [NSBezierPath bezierPath];
        [circlePath appendBezierPathWithOvalInRect: badgeRect];
        
        [[NSColor blackColor] setStroke];
        
        CGFloat alpha = 1.0;
        if ( self.updateProgress > 0.3 && self.updateProgress <= 1.0 )
            alpha = self.updateProgress;
        else
            alpha = 0.3;
        
        NSColor* dotColor;

        if ( self.updateProgress < 1.0 )
        {
            // light grey - dark grey
#define LIGHT_GREY  211
#define DARK_GREY   150
            
            CGFloat greyness = ((DARK_GREY + (LIGHT_GREY - DARK_GREY) * (1.0 - self.updateProgress)))/255.0 ;
            dotColor = [NSColor colorWithCalibratedRed:greyness
                                                 green:greyness
                                                  blue:greyness
                                                 alpha:alpha];
        }
        else
        {
            dotColor = [NSColor colorWithCalibratedRed:0
                                                 green:.85
                                                  blue:0.25
                                                 alpha:0.7];
        }
        
        [dotColor setFill];
        [circlePath stroke];
        [circlePath fill];
        
        [gc restoreGraphicsState];
         */
    }
    
    if ( self.isConnected == FALSE )
    {
        NSImage* connected = [NSImage imageNamed:@"connection.png"];
        NSRect badgeRect = [self bounds];
        
        badgeRect.size.height = kNotConnectedFraction * NSHeight(badgeRect);
        badgeRect.size.width = kNotConnectedFraction * NSWidth(badgeRect);
        
        badgeRect.origin.x = NSWidth(dirtyRect) - badgeRect.size.width - kNotConnectedIndent ;
        badgeRect.origin.y = dirtyRect.size.height - badgeRect.size.height - 2 * kNotConnectedIndent;
        
        [connected drawInRect:badgeRect
                   fromRect:NSZeroRect
                  operation:NSCompositeSourceOver
                   fraction:1.0];
    }
    
    
    if (self.numberOfMessages > 0)
    {
        NSRect badgeRect = dirtyRect;//[self bounds];
        
        badgeRect.size.height = (int)(kBadgeFraction * badgeRect.size.height);
        
        int newWidth = kBadgeFraction * NSWidth(badgeRect);
        
        badgeRect.origin.x = NSWidth(badgeRect) - newWidth;
        badgeRect.size.width = newWidth;
        
        CGFloat badgeRadius = NSMidY(badgeRect);
        
        badgeRect.origin.x -= kBadgeIndent;
        //badgeRect.origin.y += kBadgeIndent;
        badgeRect.origin.y = dirtyRect.size.height - 2 * badgeRadius - kBadgeIndent;
        
        NSPoint badgeCenter = NSMakePoint(NSMidX(badgeRect), NSMidY(badgeRect));
        
        // Background
        //NSColor* backgroundColor = [NSColor colorWithCalibratedRed:0.85  green:0.85  blue:0.85 alpha:1.0];
        NSColor* backgroundColor = [NSColor colorWithCalibratedRed:1  green:0.0  blue:0.0 alpha:1.0];
        
        if (self.bRequest) {
            backgroundColor = [NSColor colorWithCalibratedRed:0  green:0  blue:0 alpha:1.0];
        }
        
        //NSColor* backgroundHighlight = [backgroundColor blendedColorWithFraction:0.85   ofColor:[NSColor whiteColor]];
        NSColor* backgroundHighlight = backgroundColor;
        
        NSGradient* backgroundGradient = [[NSGradient alloc] initWithStartingColor:backgroundHighlight
                                                                       endingColor:backgroundColor];
        
        NSBezierPath* badgeEdge = [NSBezierPath bezierPathWithOvalInRect:badgeRect];
        {
            [badgeEdge addClip];
            [backgroundGradient drawFromCenter:badgeCenter
                                        radius:0.0
                                      toCenter:badgeCenter
                                        radius:badgeRadius
                                       options:0];
        }

        /*
        // Edge
        {
            [[NSColor whiteColor] set];
            NSShadow* shadow = [[NSShadow alloc] init];
            
            [shadow setShadowOffset:NSMakeSize(0, -2)];
            [shadow setShadowBlurRadius:2];
            [shadow set];
            [badgeEdge setLineWidth:2];
            [badgeEdge stroke];
        }
        */

        NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
        NSString* countString = [formatter stringFromNumber:[NSNumber numberWithInteger: self.numberOfMessages]];
        
        NSShadow* countShadow = [[NSShadow alloc] init];
        [countShadow setShadowBlurRadius:3.0];
        [countShadow setShadowColor:[NSColor whiteColor]];
        [countShadow setShadowOffset:NSMakeSize(0.0, 0.0)];
        
        NSMutableDictionary* countAttrsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                               //[NSColor blackColor], NSForegroundColorAttributeName,
                                               [NSColor whiteColor], NSForegroundColorAttributeName,
                                               countShadow, NSShadowAttributeName,
                                               nil];
        
        CGFloat countFontSize = badgeRadius;
        NSSize countSize = NSZeroSize;
        NSAttributedString* countAttrString = nil;
        
        while (1) {
            NSFont* countFont = [NSFont userFontOfSize: countFontSize];
            
            // Continued failure would generate an NSException.
            if (!countFont)
                break;
            
            [countAttrsDict setObject:countFont forKey:NSFontAttributeName];
            countAttrString = [[NSAttributedString alloc] initWithString:countString attributes:countAttrsDict];
            
            countSize = [countAttrString size];
            
            if (countSize.width > badgeRadius * 1.5) {
                countFontSize -= 1.0;
            } else {
                break;
            }
        }
        
        if ( countAttrString )
        {
            NSPoint countOrigin = badgeCenter;
            countOrigin.x -= countSize.width / 2;
            countOrigin.y -= countSize.height / 2.2;  // tweak; otherwise too low
            
            [countAttrString drawAtPoint:countOrigin];
        }        
    }
}

- (id) copyWithZone:(NSZone *)zone
{
    return self;
}


@end
