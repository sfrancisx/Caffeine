//
//  YLog.m
//  McBrewery
//
//  Created by Fernando Pereira on 3/13/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import "YLog.h"
#import "CommonDefs.h"
#import "YSysUtils.h"

#define STDERR_LOG              @"CaffeineErr.log"
#define kCrashReport            @"crashreport.log"
#define kTraceReport            @"tracereport.log"

#define MAXIMUM_Caffeine_LOG     9

int         gCurrentOS =          -1;
bool        gInDev0    =          false;

NSString*   kDiagDescription      = @"problemreport.txt";
NSString*   zipName               = @"CaffeineLogs.zip";
NSString*   screenshotFileName    = @"YIScreenshot.jpg";

extern bool inBrowserProcess;
extern int  masterLogEnabled;


static NSString* versionDesc = nil;
static NSString* crashReportLocation = nil;
static NSLocale* logLocale = nil;

static NSOutputStream*  logStream = nil;
static NSString*        logPath = nil;

static NSString*        logCounterFile = @"~/Library/Logs/CaffeineRef.log";
static NSUInteger       logCounter = 0;

#pragma mark --- channels ------------------------------

NSString* getUpdateChannel()
{
    if ( versionDesc != nil ) return versionDesc;
    
    NSString *url = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SUFeedURL"];
    
    // should be on format http://xxxxx-CHANNEL.json
    // example:
    // http://playground.Caffeinefs.com/Brewery/Caffeine-dev.json
    
    NSScanner* scanner = [NSScanner scannerWithString:url];
    NSString* buffer;
    if ( [scanner scanUpToString:@"Caffeine-" intoString:NULL] == NO )
    {
        return @"Mac: You should update your version from the installer!";
    }
    
    // scan past the Caffeinemessneger-
    [scanner scanString:@"Caffeine-" intoString:NULL];
    
    // find part until .json
    if ( [scanner scanUpToString:@".json" intoString:&buffer] == NO )
    {
        return @"Mac: You should update your version from the installer!";
    }
    versionDesc = [buffer capitalizedString];
    
    return versionDesc;
}

void setCurrentOS()
{
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_6) {
        gCurrentOS = OSX106;
        YLog(LOG_MAXIMUM, @"Current OS is Snow Leopard (%d)", gCurrentOS);
    }
    else if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_7) {
        gCurrentOS = OSX107;
        YLog(LOG_MAXIMUM, @"Current OS is Lion (%d)", gCurrentOS);
    } else if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_8) {
        gCurrentOS = OSX108;
        YLog(LOG_MAXIMUM, @"Current OS is Mountain Lion (%d)", gCurrentOS);
    } else //if ( floor(NSAppKitVersionNumber <= NSAppKitVersionNumber10_9 ))
    {
        // TODO: replace this when we got an updated API
        NSProcessInfo* currentProcess = [NSProcessInfo processInfo];
        NSString* version = [currentProcess operatingSystemVersionString];
        if ( [version rangeOfString:@"10.10"].location != NSNotFound )
        {
            gCurrentOS = OSX1010;
            YLog(LOG_MAXIMUM, @"Current OS is Yosemite or newer (%d)", gCurrentOS);
        }
        else
        {
            gCurrentOS = OSX109;
            YLog(LOG_MAXIMUM, @"Current OS is Mavericks (%d)", gCurrentOS);
        }
        
    } /*else
       {
       gCurrentOS = OSX1010;
       YLog(LOG_MAXIMUM, @"Current OS is Yosemite or newer (%d)", gCurrentOS);
       } */
}

// for use in ClientApp
long breweryGetpid()
{
    return getpid();
}

#pragma YLog -----------------------------------------------------------------

NSString* getLogFileName()
{
    if ( logStream != nil )
    {
        return [[NSString stringWithFormat:@"~/Library/Logs/%@", getCaffeineLogfile()] stringByExpandingTildeInPath];
    }
    else
    {
        return [[NSString stringWithFormat:@"~/Library/Logs/%@", STDERR_LOG] stringByExpandingTildeInPath];
    }
}

//#define FILE_SIZE_LIMIT 20971520
#define FILE_SIZE_LIMIT 10485760

bool isLogFileBiggerThenLimit ()
{
    if ( logStream == nil ) return false;
    
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:getLogFileName() error:nil] fileSize];
    
    if ( fileSize > FILE_SIZE_LIMIT )
        return true;
    
    return false;
}



void writeYLog(NSString* msg)
{
    if ( logStream != nil && [logStream hasSpaceAvailable] )
    {
        NSInteger bytesWritten = [logStream write:(const uint8_t*)[msg dataUsingEncoding:NSUTF8StringEncoding].bytes maxLength:msg.length];
        if ( bytesWritten <= 0 )
        {
            NSLog(@"ERROR writing to normal output log");
            [logStream close];
            logStream = nil;
            fprintf(stderr, "%s", [msg UTF8String]);
        }
    }
    else
    {
        fprintf(stderr, "%s", [msg UTF8String]);
    }
}

NSArray* getLogFiles()
{
    NSMutableArray* logFiles = [[NSMutableArray alloc] init];
    
    NSError* error = nil;
    NSArray* arrFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[@"~/Library/Logs" stringByExpandingTildeInPath] error:&error];
    for (NSString* fileName in arrFiles)
    {
        if ( [fileName rangeOfString:@"Caffeine"].location != NSNotFound )
        {
            [logFiles addObject: fileName];
        }
    }
    
    return logFiles;
}

static bool logIsCurrentlyInitializing = true;

void YLog(int level, NSString* format, ... )
{
    @try {
        static NSDateFormatter* dateFormatter = nil;
        static NSCalendar *calendar = nil;
        static NSData* counterData = nil;
        static NSString* helperID = nil;
        
        if ( helperID == nil )
        {
            if (inBrowserProcess)
                helperID = @"";
            else
                helperID = [NSString stringWithFormat:@"%d ", getpid()];
        }
        
        if ( (level == LOG_MAXIMUM || masterLogEnabled == LOG_ENABLED) &&
            
#ifndef DEBUG            // only logged in debug mode
            level != LOG_ONLY_IN_DEBUG
#else
            1
#endif
            
            )
        {
            if ( calendar == nil )
            {
                calendar = [NSCalendar currentCalendar];
            }
            
            NSString*	theStr =  nil;
            
            if ( level != LOG_JS )
            {
                va_list ap;
                va_start(ap, format);
                theStr = [[NSString alloc] initWithFormat: format arguments: ap];
                va_end(ap);
            }
            else
                theStr = format;
            
            if ( !logLocale )
            {
                logLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en-US"];
            }
            
            if ( dateFormatter == nil )
            {
                dateFormatter  = [[NSDateFormatter alloc] init];
                [dateFormatter setLocale:logLocale];
                [dateFormatter setTimeZone: [NSTimeZone timeZoneWithAbbreviation: @"PST"]];
                //[dateFormatter setTimeStyle:NSDateFormatterFullStyle];
                //[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
                [dateFormatter setDateFormat:@"HH:mm:ss.SSS"];
            }
            
            NSDate* now = [NSDate date];
            
            if ( inBrowserProcess )
            {
                /*
                 if ( isLogFileBiggerThenLimit() )
                 startLog();
                 */
                
                static NSDate* lastLogDate = nil;
                static NSDateComponents *componentsForLastLogDate = nil;
                
                bool ignoreDay = true;
                
                if ( lastLogDate == nil || componentsForLastLogDate == nil || logIsCurrentlyInitializing == true )
                {
                    lastLogDate = now;
                    componentsForLastLogDate = [calendar components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:lastLogDate];
                }
                else
                {
                    NSDateComponents *componentsForFirstDate = [calendar components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:now];
                    
                    if ( [componentsForFirstDate year] != [componentsForLastLogDate year] ||
                        [componentsForFirstDate month] != [componentsForLastLogDate month] ||
                        [componentsForFirstDate day] != [componentsForLastLogDate day]
                        )
                    {
                        ignoreDay = false;
                    }
                }
                
                lastLogDate = now;
                
                // 1st day or day change
                if ( ! ignoreDay )
                {
                    startLog();
                }
            }
            // helpers need to check if the log was changed by the browser process
            else if ( logPath != nil )
            {
                NSData* currData = [NSData dataWithContentsOfFile: [logCounterFile stringByExpandingTildeInPath]];
                if ( counterData == nil )
                    counterData = currData;
                else if ( ! [currData isEqualToData: counterData])
                {
                    startLog();
                    counterData = currData;
                }
            }
            
            NSString* msg;
            // replace \r\n with 2 spaces
            
            // JS timezones seem to be diff from native
            //if ( level != LOG_JS )
            msg = [[NSString stringWithFormat:
                    @"%s%@ %@%s\n",
                    
                    (level==LOG_JS ? "J " : (inBrowserProcess? "S ":"H ")),
                    
                    [dateFormatter stringFromDate: now],
                    //[[[NSDate date] descriptionWithLocale: logLocale] UTF8String],
                    //[[[NSDate date] descriptionWithCalendarFormat: nil timeZone:[NSTimeZone systemTimeZone] locale:logLocale] UTF8String],
                    
                    helperID,
                    
                    [theStr UTF8String]] stringByReplacingOccurrencesOfString: @"\r\n" withString: @"  "];
            
            /*
             else
             msg = [[NSString stringWithFormat:
             @"J %s\n",
             [theStr UTF8String]] stringByReplacingOccurrencesOfString: @"\r\n" withString: @"  "];
             */
            
            
            writeYLog(msg);            
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception ignored: %@", [exception description]);
    }
    @finally {
    }
}

#pragma mark ======  temporary/cache/log file locations ===

NSString *privateDataPath()
{
    @synchronized ([NSFileManager class])
    {
        static NSString *path = nil;
        if (!path)
        {
            //application support folder
            path = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
            
            //create the folder if it doesn't exist
            if (![[NSFileManager defaultManager] fileExistsAtPath:path])
            {
                [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            path = [[NSString alloc] initWithString:path];
        }
        return path;
    }
}

NSString *cacheDataPath()
{
    @synchronized ([NSFileManager class])
    {
        static NSString *path = nil;
        if (!path)
        {
            //cache folder
            path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
            
            
            //create the folder if it doesn't exist
            if (![[NSFileManager defaultManager] fileExistsAtPath:path])
            {
                [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            path = [[NSString alloc] initWithString:path];
        }
        return path;
    }
}



#pragma mark ----- Crash Reports -----------------------------------

NSString* getCrashReportLocation()
{
    if ( crashReportLocation == nil )
    {
        crashReportLocation = [[NSString stringWithFormat:@"~/Library/Logs/%@", kCrashReport] stringByExpandingTildeInPath];
    }
    return crashReportLocation;
}

NSString* getTraceDumpLocation()
{
    return [[NSString stringWithFormat:@"~/Library/Logs/%@", kTraceReport] stringByExpandingTildeInPath];
}


bool sendCrashReportIfExists()
{
    if ( [[NSFileManager defaultManager] fileExistsAtPath: getCrashReportLocation()] )
    {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath: getCrashReportLocation() error: NULL];
        if (  [attrs fileSize] > 1024 )
            return TRUE;
    }
    return FALSE;
}

#pragma  mark ---- log redirect -----

void renameOldLog(NSString* xlogPath)
{
    NSString* logPath = [xlogPath stringByExpandingTildeInPath];
    NSFileManager* fmgr = [NSFileManager defaultManager];
    if ( [fmgr fileExistsAtPath: logPath] )
    {
        NSError* err = nil;
        NSString* fileBak = nil;
        NSString* lastComponent = [logPath pathExtension];
        if ( [lastComponent compare:@"log"] == NSOrderedSame || [lastComponent compare:@""] == NSOrderedSame )
        {
            fileBak = [logPath stringByAppendingString:@".1"];
        }
        else
        {
            NSInteger numb = [lastComponent integerValue];
            if ( numb == 0 )
            {
                YLog(LOG_NORMAL, @"Error renaming filebackup from %@ - deleted", xlogPath);
                [fmgr removeItemAtPath:logPath error:&err];
                if ( err )
                {
                    YLog(LOG_NORMAL, @"Error removing %@ - %@", fileBak, [err description]);
                }
                return;
            }
            
            if ( ++ numb > MAXIMUM_Caffeine_LOG )
            {
                [fmgr removeItemAtPath:logPath error:&err];
                if ( err )
                {
                    YLog(LOG_NORMAL, @"Error removing %@ - %@", fileBak, [err description]);
                }
                return;
            }
            
            fileBak = [NSString stringWithFormat:@"%@.%ld", [logPath stringByDeletingPathExtension], (long)numb];
        }
        
        if ( [fmgr fileExistsAtPath: fileBak])
        {
            // rename it recursively
            renameOldLog(fileBak);
        }
        
        if ( fileBak != nil )
            [fmgr moveItemAtPath:logPath toPath:fileBak error:&err];
        else
            YLog(LOG_NORMAL, @"Error in renaming file - fileBak is nil");
        
        if ( err )
        {
            YLog(LOG_NORMAL, @"Error moving %@ to %@ - %@", logPath, fileBak, [err description]);
        }
    }
}


// deletes screenshot if it exists
void deleteScreenshot()
{
    NSString* imgFile = [NSString stringWithFormat:@"%@/%@", [@"~/Library/Logs" stringByExpandingTildeInPath], screenshotFileName];
    if ( [[NSFileManager defaultManager] fileExistsAtPath:imgFile] )
    {
        NSError* error;
        [[NSFileManager defaultManager] removeItemAtPath:imgFile error:&error];
    }
}

NSString* zippedLogFiles()
{
    NSString* tempDir = NSTemporaryDirectory();
    if ( tempDir == nil )
        tempDir = privateDataPath();
    NSString* zip = [NSString stringWithFormat:@"%@%@", tempDir, zipName];
    
    return [zip stringByExpandingTildeInPath];
}

void removeCrashReportIfItExists()
{
    [[NSFileManager defaultManager] removeItemAtPath:getCrashReportLocation() error:nil];
    [[NSUserDefaults standardUserDefaults] setFloat: [[NSDate date] timeIntervalSince1970] forKey: kLastCrashReport];
    
    /*
    if ( sendCrashReportIfExists() )
    {
    }
     */
}


NSString* compressLogFilesForEmail ()
{
    NSString* zipFile = zippedLogFiles();
    YLog(LOG_NORMAL, @"Compressing log file - %@", zipFile);
    fflush(stderr);
    
    NSTask *task = [NSTask new];
    [task setCurrentDirectoryPath:[@"~/Library/Logs" stringByExpandingTildeInPath]];
    [task setLaunchPath:@"/usr/bin/zip"];
    
    NSMutableArray* arguments = [NSMutableArray arrayWithObjects:
                                 @"-9",
                                 zipFile,
                                 @"SparkleUpdateLog.log",
                                 kCrashReport,
                                 screenshotFileName,
                                 kDiagDescription,
                                 nil];
    [arguments addObjectsFromArray: getLogFiles()];
    [task setArguments: arguments];
    
    YLog(LOG_NORMAL, @"Zip task dir = %@", [task currentDirectoryPath]);
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    [task launch];
    
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    YLog (LOG_NORMAL, @"Zip - %@ :\n%@",zipFile, string);
    
    // after the file is zipped, it's removed
    removeCrashReportIfItExists();
    deleteScreenshot();
    
    return zipFile;
}

void startLog()
{
    static NSDate* logStartDate = nil;
    
    bool redirectLogs = true;
    NSString* stdErrPath = [[NSString stringWithFormat:@"~/Library/Logs/%@", STDERR_LOG] stringByExpandingTildeInPath];

    gInDev0 = [@"Dev0" isEqualToString: getUpdateChannel()];
    
#ifdef DEBUG
   redirectLogs = false;
#else
    if (gInDev0)
        redirectLogs = false;
#endif
    
    if ( redirectLogs )
    {
        logPath = [[NSString stringWithFormat:@"~/Library/Logs/%@", getCaffeineLogfile()] stringByExpandingTildeInPath];
        
        // Only BROWSER process gets to rename/reset logs
        if ( inBrowserProcess )
        {
            renameOldLog(logPath);
            renameOldLog(stdErrPath);
        }
        
        if ( logStream != nil )
        {
            [logStream close];
            logStream = nil;
        }
        else
        {
            freopen([stdErrPath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
            NSLog(@"Redirecting stderr to %@", stdErrPath);
        }
        
        logStream = [NSOutputStream outputStreamToFileAtPath: logPath append:TRUE];
        [logStream open];
        
        if ( logStream != nil && [logStream hasSpaceAvailable] )
            NSLog(@"Redirecting logging to %@", logPath);
        else
            logStream = nil;
        
        NSData *data = [NSData dataWithBytes: &logCounter length: sizeof(logCounter)];
        [data writeToFile:[logCounterFile stringByExpandingTildeInPath] atomically:YES];
        logCounter ++;
    }

    if (inBrowserProcess)
    {
        logIsCurrentlyInitializing = true;
        
        NSDateFormatter* dfmt = [[NSDateFormatter alloc] init];
        [dfmt setLocale:logLocale];
        [dfmt setTimeZone: [NSTimeZone timeZoneWithAbbreviation: @"PST"]];
        [dfmt setDateStyle: NSDateFormatterFullStyle];
        [dfmt setTimeStyle:NSDateFormatterFullStyle];
        //[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        
        NSString* dmsg = [NSString stringWithFormat:@"%@ %@\n", [dfmt stringFromDate:[NSDate date]], [[NSTimeZone defaultTimeZone] description]];
        writeYLog(dmsg);
        
        if ( logStartDate == nil )
            logStartDate = [NSDate date];
        
        dmsg = [NSString stringWithFormat:@"Caffeine Start Date: %@\n",  [dfmt stringFromDate:logStartDate]];
        writeYLog(dmsg);
        writeYLog([NSString stringWithFormat:@"%@\n", kSeparator]);
        
        //YLog(LOG_MAXIMUM, kSeparator);
        YLog(LOG_MAXIMUM, @"%@ with redirect=%d and LogLevel=%ld PID=%ld", kAppTitle, redirectLogs, masterLogEnabled, getpid());
        
        YLog(LOG_MAXIMUM, @"PrivateApps=%@", privateDataPath());
        YLog(LOG_MAXIMUM, @"Cache=%@/%s", cacheDataPath(), getCaffeineCacheName());
        NSString* appPath = [[NSBundle mainBundle] bundlePath];
        YLog(LOG_MAXIMUM, @"App Directory is= %@", appPath);
        BOOL appDirHasRW = [[NSFileManager defaultManager] isWritableFileAtPath: appPath];
        YLog(LOG_MAXIMUM, @"App Directory is writable=%d  - ReadOnlyVolume: %d", appDirHasRW, isRunningOnReadOnlyVolume(appPath) );
        
        YLog(LOG_MAXIMUM, @"Starting Caffeine Build %@ ------------------------------",
             [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
        YLog(LOG_MAXIMUM, @"Current user is %@, host address is %@", NSUserName(), [[NSHost currentHost] name] );
        
        // Retrieve Local information
        NSProcessInfo* currentProcess = [NSProcessInfo processInfo];
        YLog(LOG_MAXIMUM, @"Host name is %@", [currentProcess hostName]);
        YLog(LOG_MAXIMUM, @"Mac %@ - RAM: %lld CPUs:%ld Up for %lf days",
             [currentProcess operatingSystemVersionString], [currentProcess physicalMemory], (unsigned long)[currentProcess processorCount],
             ([currentProcess systemUptime]/86400));
        //YLog(LOG_NORMAL, @"Current Environment %@", [currentProcess environment]);
        
        NSDictionary* environ = [[NSProcessInfo processInfo] environment];
        YLog(LOG_MAXIMUM, @"Sandboxing status = %d", (nil != [environ objectForKey:@"APP_SANDBOX_CONTAINER_ID"]));
        YLog(LOG_MAXIMUM, @"NSAppKitVersionNumber is %f", NSAppKitVersionNumber);
        
        // AppKit
        if ( gCurrentOS == -1 )
        {
            setCurrentOS();
        }
        
        NSArray* locales = [NSBundle preferredLocalizationsFromArray: [[NSBundle mainBundle] localizations]];
        if ( [locales count] > 0 )
            YLog(LOG_MAXIMUM, @"Current OS locale is :%@ ",  [locales objectAtIndex:0] );
        else
            YLog(LOG_MAXIMUM, @"Current OS locale undefined");
        YLog(LOG_MAXIMUM, @"Current time zone is %@", [[NSTimeZone defaultTimeZone] description]);
        
        YLog(LOG_MAXIMUM, @"Caffeine %@ - Update channel URL: %@",
             getUpdateChannel(),
             [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SUFeedURL"]);
        
        writeYLog([NSString stringWithFormat:@"%@\n", kSeparator]);
        
        logIsCurrentlyInitializing = false;
    }
}

void cleanOldLogs()
{
    NSString* logsDir = [@"~/Library/Logs" stringByExpandingTildeInPath];
    NSString* appName = [kCaffeineLog stringByDeletingPathExtension];
    
    NSError* error;
    [[NSFileManager defaultManager] removeItemAtPath:getCrashReportLocation() error:&error];
    
    NSDirectoryEnumerator*	enny = [[NSFileManager defaultManager] enumeratorAtPath: logsDir];
    
    for (NSString* logFile in enny)
    {
        if ([logFile rangeOfString: appName].location != NSNotFound )
        {
            NSString* fileExtension = [logFile pathExtension];
            if ( [fileExtension compare:@"log"] != NSOrderedSame )
            {
                NSString* fullPath = [logsDir stringByAppendingPathComponent: logFile];
                
                [[NSFileManager defaultManager] removeItemAtPath:fullPath error:&error];
                YLog(LOG_ONLY_IN_DEBUG, @"Removing old logfile: %@", logFile);
                
                if ( error )
                {
                    YLog(LOG_MAXIMUM, @"Error trying to delete file: %@ - %@", fullPath, [error description]);
                }
            }
        }
    }
    [[NSUserDefaults standardUserDefaults] setFloat: [[NSDate date] timeIntervalSince1970] forKey: kLastCrashReport];
}
