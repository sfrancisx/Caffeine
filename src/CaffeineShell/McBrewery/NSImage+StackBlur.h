//
//  NSImage+StackBlur.h
//  McBrewery
//
//  Created by Fernando on 6/14/13.
//  Copyright (c) 2013 Y.CORP.Caffeine.COM\pereira. All rights reserved.
//
//  Ported from iOS from the following code:
// 
//  Created by Thomas LANDSPURG on 07/02/12.
//  Copyright 2012 Digiwie. All rights reserved.
//
// iOS code is at:
//  https://github.com/tomsoft1/StackBluriOS
//
// a StackBlur implementation for iOS based on the algorithm of:
// http://incubator.quasimondo.com/processing/fast_blur_deluxe.php
//
// by Mario Klingemann
//
// iOS version: thomas.landspurg@gmail.com
//
// License: New BSD license.


#import <Cocoa/Cocoa.h>

@interface NSImage (StackBlur)

- (CGImageRef) CGImageCreateWithNSImage;
- (NSImage*) stackBlur:(NSUInteger)radius;
- (NSImage *) normalize ;
+ (void) applyStackBlurToBuffer:(UInt8*)targetBuffer width:(const int)w height:(const int)h withRadius:(NSUInteger)inradius;

@end
