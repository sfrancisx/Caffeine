//
//  NSImage_NSImage_Reflection.m
//  McBrewery
//
//  Created by Y.CORP.Caffeine.COM\pereira on 4/18/13.
//  Copyright (c) 2013 Caffeine. All rights reserved.
//
// NSImage extension: Generates an image reflection
//

#import "NSImage_NSImage_Reflection.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSImage(MKAddReflection)

- (NSImage*) addReflection:(CGFloat)percentage
{
    NSAssert(percentage > 0 && percentage <= 1.0, @"Please use percentage between 0 and 1");
    NSRect offscreenFrame = NSMakeRect(0, 0, self.size.width, self.size.height*(1.0+percentage));
    NSBitmapImageRep * offscreen = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                           pixelsWide:offscreenFrame.size.width
                                                                           pixelsHigh:offscreenFrame.size.height
                                                                        bitsPerSample:8
                                                                      samplesPerPixel:4
                                                                             hasAlpha:YES
                                                                             isPlanar:NO
                                                                       colorSpaceName:NSDeviceRGBColorSpace
                                                                         bitmapFormat:0
                                                                          bytesPerRow:offscreenFrame.size.width * 4
                                                                         bitsPerPixel:32];
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:offscreen]];
    
    [[NSColor clearColor] set];
    NSRectFill(offscreenFrame);
    
    NSGradient * fade = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.2] endingColor:[NSColor clearColor]];
    NSRect fadeFrame = NSMakeRect(0, 0, self.size.width, offscreen.size.height - self.size.height);
    [fade drawInRect:fadeFrame angle:270.0];
    
    NSAffineTransform* transform = [NSAffineTransform transform];
    [transform translateXBy:0.0 yBy:fadeFrame.size.height];
    [transform scaleXBy:1.0 yBy:-1.0];
    [transform concat];
    
    // Draw the image over the gradient -> becomes reflection
    [self drawAtPoint:NSMakePoint(0, 0) fromRect:NSMakeRect(0, 0, self.size.width, self.size.height) operation:NSCompositeSourceIn fraction:1.0];
    
    [transform invert];
    [transform concat];
    
    // Draw the original image
    [self drawAtPoint:NSMakePoint(0, offscreenFrame.size.height - self.size.height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    
    [NSGraphicsContext restoreGraphicsState];
    
    NSImage * imageWithReflection = [[NSImage alloc] initWithSize:offscreenFrame.size];
    [imageWithReflection setFlipped:YES];
    [imageWithReflection addRepresentation:offscreen];
    
    return imageWithReflection;
}

@end
