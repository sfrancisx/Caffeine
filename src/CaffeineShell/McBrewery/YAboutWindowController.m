//
//  YAboutWindowController.m
//  McBrewery
//
//  Created by Y.CORP.Caffeine.COM\pereira on 4/18/13.
//  Copyright (c) 2013 Caffeine. All rights reserved.
//

#import "YAboutWindowController.h"
#import "CommonDefs.h"

@interface YAboutWindowController ()

@end

@implementation YAboutWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        backImg = [NSImage imageNamed:@"contactlist-bg.jpg"];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    CALayer *rootLayer = [CALayer layer];
    rootLayer.contents = backImg;
    [self.window.contentView setLayer:rootLayer];
    [self.window.contentView setWantsLayer:YES];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    //NSImage* img = [self.mainImage image];
    //self.imageReflection.image = [img addReflection:0.2];
    
    NSDictionary *appInfo = [[NSBundle mainBundle] infoDictionary];

    NSString* versionDesc = nil;
    NSString *url = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SUFeedURL"];
    
    // should be on format http://xxxxx-CHANNEL.json
    // example:
    // http://playground.Caffeinefs.com/Brewery/CaffeineCaffeineNext-dev.json
    NSScanner* scanner = [NSScanner scannerWithString:url];
    NSString* buffer;
    if ( [scanner scanUpToString:@"CaffeineCaffeineNext-" intoString:NULL] == NO )
    {
        versionDesc =  @"You should update your version from the installer!";
    }
    // scan past the Caffeinemessneger-
    [scanner scanString:@"CaffeineCaffeineNext-" intoString:NULL];
    // find part until .json
    if ( [scanner scanUpToString:@".json" intoString:&buffer] == NO )
    {
       versionDesc =  @"You should update your version from the installer!";
    }
    if ( versionDesc == nil )
        versionDesc = [NSString stringWithFormat:@"%@ update channel", [buffer uppercaseString]];
    
    if ( [[NSUserDefaults standardUserDefaults] boolForKey:kEnableAutoUpdate] == FALSE )
    {
        versionDesc = @"AUTO-UPDATES ARE DISABLED";
    }
    [updateChannel setStringValue:versionDesc];
    
    //NSString *versionStr = [NSString stringWithFormat:@"%@ (%@)",
    NSString *versionStr = [NSString stringWithFormat:@"BUILD Number: %@",
                            //[appInfo objectForKey:@"CFBundleShortVersionString"],
                            [appInfo objectForKey:@"CFBundleVersion"]];
    
    [buildNumber setStringValue:versionStr];
    
    //[self.window setTitle: [appInfo objectForKey:@"CFBundleName"]];
    [self.window display];
}

- (IBAction) done:(id) sender
{
    [[self window] close];
}

@end
