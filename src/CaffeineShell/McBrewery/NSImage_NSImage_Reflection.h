//
//  NSImage_NSImage_Reflection.h
//  McBrewery
//
//  Created by Y.CORP.Caffeine.COM\pereira on 4/18/13.
//  Copyright (c) 2013 Caffeine. All rights reserved.
//
// NSImage extension: Generates an image reflection
//

#import <Cocoa/Cocoa.h>


@interface NSImage (MKAddReflection)

- (NSImage*) addReflection:(CGFloat)percentage;

@end
