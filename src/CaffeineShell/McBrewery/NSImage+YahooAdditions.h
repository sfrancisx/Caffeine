//
//  UIImage+CaffeineAdditions.h
//  Sash
//
//  Created by Srinivas Raovasudeva on 7/27/13.
//  Copyright (c) 2013 Caffeine!. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (CaffeineAdditions)

// Planning to use this to treat the chat view navbar
- (NSImage *)cropImageToRect:(CGRect)rect;

// TODO: Uncomment once we bring in ymagine for themecolor
// If we can do that using the current color thief implementation
// then we may no longer need this and will remove it
// - (UIColor *)themeColor;

NSImage* YWStackBlurImage(NSImage *image, NSUInteger rad);

+ (NSImage*) imageFromCGImageRef:(CGImageRef)image;


@end
