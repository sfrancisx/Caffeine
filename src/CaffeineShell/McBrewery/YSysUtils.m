//
//  YSysUtils.m
//  McBrewery
//
//  Created by Fernando Pereira on 3/13/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#include <sys/resource.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <mach/task.h>
#include <mach/mach_error.h>
#import <sys/mount.h> // For statfs for isRunningOnReadOnlyVolume

#import "YSysUtils.h"
#include "YLog.h"
#import "CommonDefs.h"

#import <xpc/xpc.h>

extern bool inBrowserProcess;


#pragma mark ---- directory locations ----


const char* getCaffeineCacheName()
{
    NSString* path = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
    
    if ( [[path lastPathComponent] compare:@"Applications" options:NSCaseInsensitiveSearch] == NSOrderedSame )
    {
        //YLog(LOG_NORMAL, @"Caffeine is in /Applications, using %s as cache name", kCaffeineCache);
        return kCaffeineCache;
    }
    NSString* appCache = [NSString stringWithFormat:@"%s%@", kCaffeineCache, [path lastPathComponent]];
    //YLog(LOG_NORMAL, @"Caffeine isn't in /Applications, using %@ as cache name", appCache);
    return [appCache UTF8String];
}

NSString* getCaffeineLogfile()
{
    // removes Caffeine *HelperXX.app
    NSString* path = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
    
    if ( !inBrowserProcess )
    {
        // helpers are in Caffeine.app/Contents/Frameworks
        
        // removes Frameworks
        path = [path stringByDeletingLastPathComponent];
        // removes Contents
        path = [path stringByDeletingLastPathComponent];
        // removes Caffeine
        path = [path stringByDeletingLastPathComponent];
    }
    if ( [[path lastPathComponent] compare:@"Applications" options:NSCaseInsensitiveSearch] == NSOrderedSame )
    {
        //YLog(LOG_NORMAL, @"Caffeine is in /Applications, using %s as cache name", kCaffeineCache);
        return kCaffeineLog;
    }
    
    NSString* logName = [kCaffeineLog stringByDeletingPathExtension];
    
    NSString* appCache = [NSString stringWithFormat:@"%@%@.log", logName, [path lastPathComponent]];
    //YLog(LOG_NORMAL, @"Caffeine isn't in /Applications, using %@ as cache name", appCache);
    return appCache;
}


#pragma mark ---  file limits -----

static struct rlimit limit;

int getLimit()
{
    /* Get max number of files. */
    return getrlimit(RLIMIT_NOFILE, &limit);
}

int setLimit( int lim )
{
    limit.rlim_cur = lim;
    limit.rlim_max = lim;
    return setrlimit(RLIMIT_NOFILE, &limit);
}


#pragma mark === system utils ====


long getmem (unsigned long *rss, unsigned long *vs)
{
    //task_t task = MACH_PORT_NULL;
    struct task_basic_info t_info;
    mach_msg_type_number_t t_info_count = TASK_BASIC_INFO_COUNT;
    
    if (KERN_SUCCESS != task_info(mach_task_self(),
                                  TASK_BASIC_INFO, (task_info_t)&t_info, &t_info_count))
    {
        return -1;
    }
    *rss = t_info.resident_size;
    *vs  = t_info.virtual_size;
    return 0;
}

void report_memory(void)
{
    static vm_size_t last_resident_size=0;
    static vm_size_t greatest = 0;
    static vm_size_t last_greatest = 0;
    
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if( kerr == KERN_SUCCESS ) {
        int diff = (int)info.resident_size - (int)last_resident_size;
        vm_size_t latest = info.resident_size;
        if( latest > greatest   )   greatest = latest;  // track greatest mem usage
        vm_size_t greatest_diff = greatest - last_greatest;
        //vm_size_t latest_greatest_diff = latest - greatest;
        //YLog(LOG_NORMAL, @"Mem: %10lu (%10d) : %10lu :   greatest: %10lu (%lu)",
        YLog(LOG_NORMAL, @"Mem -> PID:%ld Current: %10lu (%10d) :  greatest: %10lu (%lu)",
             getpid(),
             info.resident_size, diff,
             //latest_greatest_diff,
             greatest, greatest_diff  );
    } else {
        YLog(LOG_NORMAL, @"Error with task_info(): %s", mach_error_string(kerr));
    }
    last_resident_size = info.resident_size;
    last_greatest = greatest;
}

void report_cpu(void)
{
    struct rusage    myUsage;
    static float totalTime = 0;

    if ( getrusage( RUSAGE_SELF, &myUsage ) == 0 )
    {
        totalTime = (myUsage.ru_utime.tv_usec + myUsage.ru_stime.tv_usec);
        YLog(LOG_NORMAL, @"CPU usage for this process: total:%f - whole seconds: user: %d sys: %d",
             totalTime / 1000000, myUsage.ru_utime.tv_sec , myUsage.ru_stime.tv_sec );
    }
    
}

/*
 #include <mach/mach.h>
 #include <mach/processor_info.h>
 #include <mach/mach_host.h>
 
 
 void report_cpu(void)
 {
    static processor_info_array_t cpuInfo, prevCpuInfo;
    static mach_msg_type_number_t numCpuInfo, numPrevCpuInfo;
    static unsigned numCPUs = 0;
    static NSLock *CPUUsageLock = nil;
    
    
    if ( CPUUsageLock == nil )
    {
        int mib[2U] = { CTL_HW, HW_NCPU };
        size_t sizeOfNumCPUs = sizeof(numCPUs);
        int status = sysctl(mib, 2U, &numCPUs, &sizeOfNumCPUs, NULL, 0U);
        if(status)
            numCPUs = 1;
        
        CPUUsageLock = [[NSLock alloc] init];
    }
    
    natural_t numCPUsU = 0U;
    kern_return_t err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo);
    if(err == KERN_SUCCESS) {
        [CPUUsageLock lock];
        
        float totalCPUinUse = 0;
        for(unsigned i = 0U; i < numCPUs; ++i) {
            float inUse, total;
            if(prevCpuInfo) {
                inUse = (
                         (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER]   - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER])
                         + (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM])
                         + (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE]   - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE])
                         );
                total = inUse + (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE] - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE]);
            } else {
                inUse = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER] + cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] + cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE];
                total = inUse + cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE];
            }
            
            YLog(LOG_ONLY_IN_DEBUG, @"Core CPU : %u Usage: %f %%",i,inUse / total);
            totalCPUinUse += inUse/total;
        }
        [CPUUsageLock unlock];
        YLog(LOG_NORMAL, @"CPU (%d) usage overall: %f", numCPUs, totalCPUinUse);
        
        if(prevCpuInfo) {
            size_t prevCpuInfoSize = sizeof(integer_t) * numPrevCpuInfo;
            vm_deallocate(mach_task_self(), (vm_address_t)prevCpuInfo, prevCpuInfoSize);
        }
        
        prevCpuInfo = cpuInfo;
        numPrevCpuInfo = numCpuInfo;
        
        cpuInfo = NULL;
        numCpuInfo = 0U;
    }
}
*/

#pragma mark ============== READ ONLY VOLUME ============================

BOOL isRunningOnReadOnlyVolume(NSString* path)
{
	struct statfs statfs_info;
	statfs([path fileSystemRepresentation], &statfs_info);
	return (statfs_info.f_flags & MNT_RDONLY);
}


#pragma mark ================= YMSGR links ================================


NSURL* getAppForYmsgr()
{
    CFURLRef appURL = nil;
    //NSString *extension = @"ymsgr";
    NSURL* url = [NSURL URLWithString: @"ymsgr:"];
    
    //OSStatus status =  LSGetApplicationForInfo(kLSUnknownType, kLSUnknownCreator, (__bridge CFStringRef)(extension), kLSRolesAll, nil, &appURL);
    OSStatus status =  LSGetApplicationForURL( (__bridge CFURLRef)url, kLSRolesViewer, nil, &appURL);
    
    if (status == noErr)
    {
        NSURL *url = (__bridge NSURL *)appURL;
        CFRelease(appURL);
        return url;
    }
    else
    {
        return nil;
    }
}

BOOL isCaffeineDefAppForYmsgr()
{
 //   NSURL* myURL = [
    NSString* urlString = [getAppForYmsgr() absoluteString];
    
    if ( [urlString rangeOfString:@"Caffeine%20Caffeine.app"].location != NSNotFound )
        return true;
    
    return false;
}



void setCaffeineDefAppForYmsgr(bool inSandbox)
{
    NSString* identif = [[NSBundle mainBundle] bundleIdentifier];

    if ( ! inSandbox )
    {
        NSString* uri = @"ymsgr";
        
        OSStatus status =  LSSetDefaultHandlerForURLScheme((__bridge CFStringRef)uri, (__bridge CFStringRef)identif);
        
        if ( status != noErr )
        {
            YLog(LOG_NORMAL, @"Error setting default handler for %@", uri);
        }
    }
    else
    {
        xpc_connection_t connection = xpc_connection_create(XPC_NAME, NULL);
        
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
            
            xpc_dictionary_apply(event, ^bool(const char *key, xpc_object_t value) {
                
                YLog(LOG_NORMAL, @"XPC %s: %s", key, xpc_string_get_string_ptr(value));
                return true;
            });
        });
        xpc_connection_resume(connection);
        
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(message, "bid", [identif UTF8String]);
        
        xpc_object_t response = xpc_connection_send_message_with_reply_sync(connection, message);
        xpc_type_t type = xpc_get_type(response);
        
        YLog(LOG_NORMAL, @"setCaffeineDefAppForYmsgr setting YMSGR default, result = %d", type);
    }    
}
