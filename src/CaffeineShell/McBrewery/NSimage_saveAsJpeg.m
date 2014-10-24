//
//  NSimage_saveAsJpeg.m
//  McBrewery
//
//  Created by Fernando Pereira on 11/11/13.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSImage_saveAsJpeg.h"

@implementation NSImage(saveAsJpegWithName)

- (void) saveAsJpegWithName:(NSString*) fileName
{
    // Cache the reduced image
    NSData *imageData = [self TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
    
    imageData = [imageRep representationUsingType:NSJPEGFileType properties:imageProps];
    [imageData writeToFile:fileName atomically:NO];
}

@end
