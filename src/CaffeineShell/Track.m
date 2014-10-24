//
//  Track.m
//  iTunesNowPlaying
//
//  Created by David  Leroy on 6/24/13.
//  Copyright (c) 2014 Yahoo!. All rights reserved.
//

#import "Track.h"
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import "YLog.h"

static iTunesApplication *iTunes = nil;


void resetITunes()
{
    iTunes = nil;
}

@interface Track () {
    
    NSMutableDictionary*    trackInfo;
    
}

- (NSString *)getCurrentTrack;
- (NSString *)getSong;
- (NSString *)getAlbum;
- (NSString *)getArtist;
-(NSString *)getShowName;
-(NSString *)getVideoKind;
-(NSString *)getCurrentStreamTitle;
-(long)getPlayerPosition;
- (double)getTimeUntilEnd;
-(NSInteger)getSeasonNumber;
-(NSInteger)getEpisodeNumber;
-(NSString *)getGenre;
-(NSString *)getPlayerState;

@end

@implementation Track


- (id) init
{
    self = [super init];
    if ( self ) {
        trackInfo = nil;
    }
    return self;
}


+ (BOOL) isITunesOn
{
    NSArray *runningApps =[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.iTunes"];
    if([runningApps count])
        return TRUE;
    else
        return FALSE;

}

-(NSString *)getPlayerState
{
    if ( iTunes == nil ) return @"NotPlaying";
    
    switch ( iTunes.playerState) {
        case iTunesEPlSPlaying:
            return @"Play";
            break;
        case iTunesEPlSPaused:
            return @"Paused";
            break;
        case iTunesEPlSStopped:
            return @"Stopped";
            break;
        case iTunesEPlSFastForwarding:
            return @"FastForward";
            break;
        case iTunesEPlSRewinding:
            return @"Rewind";
            break;
        default:
            return @"NotPlaying";
            break;
    }
    return @"NotPlaying";
    
}

-(NSString *)getCurrentTrack
{
    NSString *nowPlaying = nil;
    
    if (iTunes != nil && [iTunes isRunning] &&  iTunes.playerState == iTunesEPlSPlaying)
    {
        nowPlaying = @"'";
        nowPlaying = [nowPlaying stringByAppendingString:[iTunes.currentTrack name]];
        nowPlaying = [nowPlaying stringByAppendingString:@"'"];
        nowPlaying = [nowPlaying stringByAppendingString:@" - "];
        nowPlaying = [nowPlaying stringByAppendingString:[iTunes.currentTrack artist]];
    }
    
    return nowPlaying;
}

-(NSString *)getSong
{
    NSString *currSong = nil;

    if (iTunes != nil && [iTunes isRunning] && iTunes.playerState == iTunesEPlSPlaying)
    {
        currSong = [iTunes.currentTrack name];
    }
    
    return currSong;
    
}

-(NSString *)getAlbum
{
    NSString *currAlbum = nil;

    if (iTunes != nil && [iTunes isRunning] && iTunes.playerState ==iTunesEPlSPlaying)
    {
        currAlbum = [iTunes.currentTrack album];
    }
    
    return currAlbum;
    
}

-(NSString *)getArtist
{
    NSString *currArtist = nil;

    if (iTunes != nil && [iTunes isRunning] && iTunes.playerState==iTunesEPlSPlaying)
    {
        currArtist = [iTunes.currentTrack artist];
    }
    
    return currArtist;

}

-(double)getTimeUntilEnd
{
    double TimeUntilEnd = 0.0;

    
    if (iTunes != nil && [iTunes isRunning] && iTunes.playerState==iTunesEPlSPlaying)
    {
        TimeUntilEnd = [iTunes.currentTrack duration];
    }
    
    return TimeUntilEnd;
    
}

-(long)getPlayerPosition
{
    long playerPosition = 0.0;


    if (iTunes != nil && [iTunes isRunning] && iTunes.playerState==iTunesEPlSPlaying)
    {
        playerPosition = iTunes.playerPosition;
    }
    
    return playerPosition;
    
}

-(NSString *)getShowName
{
    NSString *showName = nil;

    if (iTunes != nil && [iTunes isRunning] && iTunes.playerState==iTunesEPlSPlaying)
    {
        showName = [iTunes.currentTrack show];
    }
    
    return showName;
    
}

-(NSString *)getVideoKind
{
    iTunesEVdK videoKind = iTunesEVdKNone;

    if (iTunes != nil && [iTunes isRunning] && iTunes.playerState==iTunesEPlSPlaying)
    {
        videoKind = [iTunes.currentTrack videoKind];
    }
    
    switch (videoKind)
    {
        case iTunesEVdKNone:
            return @"unknown";
            break;
            
        case iTunesEVdKMovie:
            return @"movie";
            break;
            
        case iTunesEVdKMusicVideo:
            return @"musicVideo";
            break;
            
        case iTunesEVdKTVShow:
            return @"TVShow";
            break;
        
        case iTunesEVdKHomeVideo:
            return @"homeVideo";
            break;
        default:
            return @"unknown";
            break;
    }
    
}

-(NSString *)getCurrentStreamTitle
{
    NSString *currentStreamTitle = nil;

    if (iTunes != nil && [iTunes isRunning] && iTunes.playerState==iTunesEPlSPlaying)
    {
        currentStreamTitle = iTunes.currentStreamTitle;
    }
    
    return currentStreamTitle;
    
}

-(NSInteger)getSeasonNumber
{

    if (iTunes != nil && [iTunes isRunning] && iTunes.playerState==iTunesEPlSPlaying)
    {
        return [iTunes.currentTrack seasonNumber];
    }
    
    return -1;
}

-(NSInteger)getEpisodeNumber
{

    if (iTunes != nil && [iTunes isRunning] && iTunes.playerState==iTunesEPlSPlaying)
    {
        return  [iTunes.currentTrack episodeNumber];
    }
    
    return -1;
}

-(NSString *)getGenre
{
    NSString *currGenre = nil;
    
    if ( iTunes != nil &&
        [iTunes isRunning] &&
        iTunes.playerState==iTunesEPlSPlaying
        )
    {
        currGenre = [iTunes.currentTrack genre];
    }
    
    return currGenre;
}



-(NSMutableDictionary *)getTrackInfo
{
    /*
    static NSTimeInterval lastTimeChecked = 0;
    NSTimeInterval curTime = [NSDate timeIntervalSinceReferenceDate];
    
    // prevents checks to be done in less then 3 seconds of each other
    if ( lastTimeChecked == 0 || curTime - lastTimeChecked > 3 )
    {
        trackInfo = nil;
    }
    else
    {
        YLog(LOG_NORMAL, @"getTrackInfo called with an interval of only %f - returning previous value instead", curTime - lastTimeChecked);
        return trackInfo;
    }
    */
    
    @try
    {
        if ( iTunes == nil && [Track isITunesOn] )
        {
            iTunes = [SBApplication applicationWithBundleIdentifier: @"com.apple.iTunes"];
            if ( iTunes )
            {
                //YLog(LOG_NORMAL, @"iTunes Version: %@ ", iTunes.version);
                iTunes.delegate = self;
            }
            else
            {
                YLog(LOG_NORMAL, @"Failed to initialize the iTunes variable");
            }
        }
        if (iTunes != nil  && [iTunes isRunning] && iTunes.playerState==iTunesEPlSPlaying && iTunes.currentTrack != nil )
        {
            trackInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                         
                         @"1", @"isITunesOn",
                         
                         @"Play", @"playerState",
                         iTunes.currentTrack.name, @"song",
                         iTunes.currentTrack.album, @"album",
                         iTunes.currentTrack.artist, @"artist",
                         iTunes.currentTrack.show, @"showName",
                         @"unknown", @"videoKind",  // unused?
                         iTunes.currentStreamTitle, @"currentStreamTitle",
                         @"0.0", @"playerPosition",  // unused?
                         @"0.0", @"timeUntilEnd", // unused?
                         @"0", @"seasonNumber",
                         @"0", @"episodeNumber",
                         @"", @"genre",  // unused?
                         nil];
            
            
            /*
            [trackInfo setValue:@"1" forKey:@"isITunesOn"];
            [trackInfo setValue:[self getPlayerState] forKey:@"playerState"];
            [trackInfo setValue:[self getSong] forKey:@"song"];
            [trackInfo setValue:[self getAlbum] forKey:@"album"];
            [trackInfo setValue:[self getArtist] forKey:@"artist"];
            [trackInfo setValue:[self getShowName] forKey:@"showName"];
            [trackInfo setValue:[self getVideoKind] forKey:@"videoKind"];
            [trackInfo setValue:[self getCurrentStreamTitle] forKey:@"currentStreamTitle"];
            [trackInfo setValue:[[NSNumber numberWithLong:[self getPlayerPosition]]   stringValue] forKey:@"playerPosition"];
            [trackInfo setValue:[[NSNumber numberWithDouble:[self getTimeUntilEnd]]   stringValue] forKey:@"timeUntilEnd"];
            [trackInfo setValue:[[NSNumber numberWithInteger:[self getSeasonNumber]]  stringValue] forKey:@"seasonNumber"];
            [trackInfo setValue:[[NSNumber numberWithInteger:[self getEpisodeNumber]] stringValue] forKey:@"episodeNumber"];
            [trackInfo setValue:[self getGenre] forKey:@"genre"];
            */
            
            // update lastTimeChecked to prevent multiple calls
            //lastTimeChecked = [NSDate timeIntervalSinceReferenceDate];
        }
        
        if ( trackInfo == nil )
        {
            trackInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                         @"0", @"isITunesOn",
                         @"NotPlaying", @"playerState",
                         @"", @"song",
                         @"", @"album",
                         @"", @"artist",
                         @"", @"showName",
                         @"unknown", @"videoKind",
                         @"", @"currentStreamTitle",
                         @"0.0", @"playerPosition",
                         @"0.0", @"timeUntilEnd",
                         @"0", @"seasonNumber",
                         @"0", @"episodeNumber",
                         @"", @"genre", nil];
        }
        
        
    }
    @catch (NSException *e)
    {
        YLog(LOG_NORMAL, @"Exception:%@", e);
        iTunes = nil;
    }
    	
    return trackInfo;
}

- (id)eventDidFail:(const AppleEvent *)event withError:(NSError *)error
{
    if ( iTunes )
        iTunes = nil;
    
    YLog(LOG_MAXIMUM, @"iTunes Event failed: %@", [error description]);
    return  nil;
}

@end

