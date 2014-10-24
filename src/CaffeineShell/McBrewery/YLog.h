//
//  YLog.h
//  McBrewery
//
//  Created by Fernando Pereira on 3/13/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>

//log levels
#define LOG_NORMAL          0
#define LOG_JS              15
#define LOG_ONLY_IN_DEBUG   20
#define LOG_MAXIMUM         100


#ifdef __cplusplus
extern "C" {
#endif
    
    // NSLog
    void	YLog( int level, NSString* format, ... );
    NSString* getLogFileName();
    
    // channels
    NSString* getUpdateChannel();
    
    void setCurrentOS();
    
    // Sets YLog for file, initializes diagnostic
    void startLog();
    
    NSString *privateDataPath();
    
    NSString *cacheDataPath();
    
    // quick hack to for log files to zip + mail
    NSString* zippedLogFiles();
    
    long breweryGetpid();
    
    NSString* getCrashReportLocation();
    NSString* getTraceDumpLocation();
    
    // compress log files
    NSString* compressLogFilesForEmail ( );
    
    void deleteScreenshot();
    bool sendCrashReportIfExists();
    void removeCrashReportIfItExists();
    
    void cleanOldLogs();

#ifdef __cplusplus
}
#endif
