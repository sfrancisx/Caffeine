//
//  YLoginUtils.m
//  McBrewery
//
//  Created by Fernando on 9/5/13.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ServiceManagement/SMLoginItem.h>
#import <ServiceManagement/ServiceManagement.h>
#import "YLoginUtils.h"
#import "YLog.h"

extern int gCurrentOS;

#pragma mark ======= set auto login =========


BOOL willStartAtLogin ( NSURL *itemURL )
{
    Boolean foundIt=false;
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItems)
    {
        UInt32 seed = 0U;
        NSArray *currentLoginItems = [NSMakeCollectable(LSSharedFileListCopySnapshot(loginItems, &seed)) autorelease];
        for (id itemObject in currentLoginItems)
        {
            LSSharedFileListItemRef item = (LSSharedFileListItemRef)itemObject;
            
            UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
            CFURLRef URL = NULL;
            OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
            if (err == noErr) {
                foundIt = CFEqual(URL, itemURL);
                CFRelease(URL);
                
                if (foundIt)
                    break;
            }
        }
        CFRelease(loginItems);
    }
    return (BOOL)foundIt;
}


void setStartAtLogin( NSURL *itemURL, BOOL enabled)
{
    //OSStatus status;
    LSSharedFileListItemRef existingItem = NULL;
    
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItems)
    {
        UInt32 seed = 0U;
        NSArray *currentLoginItems = [NSMakeCollectable(LSSharedFileListCopySnapshot(loginItems, &seed)) autorelease];
        for (id itemObject in currentLoginItems) {
            LSSharedFileListItemRef item = (LSSharedFileListItemRef)itemObject;
            
            UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
            CFURLRef URL = NULL;
            OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
            if (err == noErr) {
                Boolean foundIt = CFEqual(URL, itemURL);
                CFRelease(URL);
                
                if (foundIt) {
                    existingItem = item;
                    break;
                }
            }
        }
        
        if (enabled && (existingItem == NULL))
        {
            YLog(LOG_NORMAL, @"Creating a new login item for %@", [itemURL absoluteString]);
            
            /*
            AuthorizationItem right[1] = {{"system.global-login-items.", 0, NULL, 0}};
            AuthorizationRights setOfRights = {1, right};
            AuthorizationRef auth = NULL;
            AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &auth);
            
            AuthorizationCopyRights(auth, &setOfRights, kAuthorizationEmptyEnvironment,
                                    (kAuthorizationFlagDefaults
                                     | kAuthorizationFlagInteractionAllowed
                                     | kAuthorizationFlagExtendRights), NULL);
            
            */
            
            if ( gCurrentOS > 0 ) // NOT 10.6
            {
                //NSString *loginItemBundleId = [[NSBundle mainBundle] bundleIdentifier];
                NSString *loginItemBundleId = @"com.Caffeine.Caffeine-Caffeine";
                if (loginItemBundleId == nil) {
                    YLog(LOG_NORMAL, @"Error getting bundle identifier");
                }
                else {
                    
                    if (!SMLoginItemSetEnabled((__bridge CFStringRef)loginItemBundleId, true)) {
                        YLog(LOG_NORMAL, @"Error creating login item");
                    }
                }
            }
            else
            {
                LSSharedFileListItemRef ourLoginItem = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst,
                                                                                     NULL, NULL, (CFURLRef)itemURL, NULL, NULL);
                
                if (ourLoginItem) {
                    CFRelease(ourLoginItem);
                } else {
                    YLog(LOG_NORMAL, @"Could not create a new global login item");
                }
            }
            
            /* LSSharedFileListInsertItemURL wont work for sandboxed apps
             
            AuthorizationItem right[1] = {{"system.global-login-items.", 0, NULL, 0}};
            AuthorizationRights setOfRights = {1, right};
            AuthorizationRef auth = NULL;
            AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &auth);
            
            AuthorizationCopyRights(auth, &setOfRights, kAuthorizationEmptyEnvironment,
                                    (kAuthorizationFlagDefaults
                                     | kAuthorizationFlagInteractionAllowed
                                     | kAuthorizationFlagExtendRights), NULL);
            
            LSSharedFileListItemRef ourLoginItem = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst,
                                          NULL, NULL, (CFURLRef)itemURL, NULL, NULL);
            
            if (ourLoginItem) {
                CFRelease(ourLoginItem);
            } else {
                YLog(LOG_NORMAL, @"Could not create a new global login item");
            }
            */
            
        }
        else if (!enabled && (existingItem != NULL))
            LSSharedFileListItemRemove(loginItems, existingItem);
        
        CFRelease(loginItems);
    }
}

NSBundle* getBundle()
{
    NSString* strPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Library/LoginItems/LoginHelper.app"];
    YLog(LOG_NORMAL, @"getBundle for LoginHelper = %@", strPath);
    NSBundle* bundle = [NSBundle bundleWithPath: [strPath stringByExpandingTildeInPath]];

    return bundle;
}


BOOL startAtLoginForSandboxed()
{
    NSBundle* bundle = getBundle();
    
    NSString *_identifier = [bundle bundleIdentifier];
    
    BOOL isEnabled  = NO;
    
    // the easy and sane method (SMJobCopyDictionary) can pose problems when sandboxed. -_-
    CFArrayRef cfJobDicts = SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
    NSArray* jobDicts = CFBridgingRelease(cfJobDicts);
    
    if (jobDicts && [jobDicts count] > 0) {
        for (NSDictionary* job in jobDicts) {
            if ([_identifier isEqualToString:[job objectForKey:@"Label"]]) {
                isEnabled = [[job objectForKey:@"OnDemand"] boolValue];
                break;
            }
        }
    }
    
    return isEnabled;
}

void setStartAtLoginForSandboxed(BOOL flag)
{
    NSBundle* bundle = getBundle();
    
    NSString *_identifier = [bundle bundleIdentifier];
    //NSURL* url            = [[NSBundle mainBundle] bundleURL];
    
    if (!SMLoginItemSetEnabled((__bridge CFStringRef)_identifier, (flag) ? true : false)) {
        YLog(LOG_NORMAL, @"SMLoginItemSetEnabled failed!");
    }
}


