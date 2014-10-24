//
//  CommonDefs.h
//  McBrewery
//
//  Created by pereira on 3/22/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#ifndef McBrewery_CommonDefs_h
#define McBrewery_CommonDefs_h

#import "YLog.h"

static NSString *const CSWindowCloseNotification = @"CSWindowClose";
static NSString *const CSDockedWindowCloseNotification = @"CSDockedWindowClose";
static NSString *const CSDockedWindowConvIsActive = @"CSDockedConversationActive";
static NSString *const CSDockedWindowConvIsInactive = @"CSDockedConversationIsnactive";
static NSString *const CSDisplayChange = @"CSDisplayChange";
static NSString *const CSNetworkLoss = @"CSNetworkLoss";


// path value for alternative path 
extern const char* defaultPathValue;

#define kDefaultPath        @"defaultPath"
#define kBlastCacheOnExit   @"BlastCache"
#define kEnableWebGL        @"WebGL"

#define kSortName           @"sort-name"
#define kSortPresence       @"sort-presence"
#define kViewOffline        @"view-offline"
#define kViewGroups         @"view-groups"

#define kDefaultUserName    @"defuser"
#define kDefaultAutoLogin   @"defautologin"
#define kDefaultAvatar      @"defavatar"
#define kGlobalPrefs        @"globalPrefs"

#define kShouldAutoStart    @"autostart"

#define kShellLogLevel      @"logLevel"

#define kPlayedYodel        @"yodel"

#define kCorrectClose       @"correctClose"

#define kLastCrashReport    @"LastCashReportDate"


#define LOG_DISABLED        0
#define LOG_ENABLED         1

// directory paths
#define kCaffeineCache ("Caffeine-app-cache")

// caffeine log
#define kCaffeineLog   @"Caffeine.log"


#define OSX106              0
#define OSX107              1
#define OSX108              2
#define OSX109              3
#define OSX1010             4

#define   kMemoryUsageReportingInterval  1800

#define kAppTitle           @"Caffeine"

#define kSeparator      @"================================================================================"

#define kLogFilesZip    @"~/Downloads/CaffeineLogs"


#define XPC_NAME                "com.Caffeine.setYMSGR"
#define XPC_READ_CRASH_LOGS     "com.Caffeine.XPCcrashReport"


#endif
