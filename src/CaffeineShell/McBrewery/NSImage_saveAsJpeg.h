//
//  NSImage_saveAsJpeg.h
//  McBrewery
//
//  Created by Fernando Pereira on 11/11/13.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (saveAsJpegWithName)

- (void) saveAsJpegWithName:(NSString*) fileName;

@end
