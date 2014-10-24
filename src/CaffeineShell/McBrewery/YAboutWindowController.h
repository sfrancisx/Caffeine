//
//  YAboutWindowController.h
//  McBrewery
//
//  Created by Y.CORP.Caffeine.COM\pereira on 4/18/13.
//  Copyright (c) 2013 Caffeine. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface YAboutWindowController : NSWindowController {
    //NSImageView *imageReflection;
    IBOutlet NSTextField *buildNumber;
    IBOutlet NSTextField *updateChannel;
    //NSImageView *mainImage;
    
    NSImage* backImg;
}

- (IBAction) done:(id) sender;


@end
