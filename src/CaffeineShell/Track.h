//
//  Track.h
//  iTunesNowPlaying
//
//  Created by David  Leroy on 6/24/13.
//  Copyright (c) 2014 Yahoo!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iTunes.h"

@interface Track : NSObject <SBApplicationDelegate>


+ (BOOL) isITunesOn;
- (NSMutableDictionary *)getTrackInfo;

@end
