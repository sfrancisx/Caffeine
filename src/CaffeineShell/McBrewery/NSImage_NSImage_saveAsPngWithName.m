//
//  NSImage_NSImage_saveAsPngWithName.m
//  McBrewery
//
//  Created by Fernando on 7/15/13.
//  Copyright (c) 2013 Caffeine. All rights reserved.
//

#import "NSImage_NSImage_saveAsPngWithName.h"


@implementation NSImage(saveAsPngWithName)

- (void) saveAsPngWithName:(NSString*) fileName
{
    // Cache the reduced image
    NSData *imageData = [self TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
    imageData = [imageRep representationUsingType:NSPNGFileType properties:imageProps];
    [imageData writeToFile:fileName atomically:NO];
}

@end

