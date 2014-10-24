//
//  YSysUtils.h
//  McBrewery
//
//  Created by Fernando Pereira on 3/13/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

    // read and set limits
    int getLimit();
    int setLimit( int lim );
    
    // memory usage
    void report_memory(void);
    void report_cpu(void);
    
    // filenames
    const char* getCaffeineCacheName();
    NSString* getCaffeineLogfile();
    
    // read only volumes
    BOOL isRunningOnReadOnlyVolume(NSString* path);
    
    // YMSGR
    NSURL* getAppForYmsgr();
    BOOL isCaffeineDefAppForYmsgr();
    void setCaffeineDefAppForYmsgr(bool inSandbox);
    
#ifdef __cplusplus
}
#endif


