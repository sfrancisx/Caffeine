// Copyright (c) 2007,2014 Caffeine! Inc. All Rights Reserved.
// http://www.Caffeine.com/
//
// This source code and specific concepts contained herein are confidential
// information and property of Caffeine! Inc.  Distribution is prohibited
// without written permission.

#import <Security/Security.h>
#import "YMKeyChain.h"
#ifndef NO_GROWL_NOTIFICATIONS
#ifndef HELPER_APP
#import "YBreweryNotification.h"
#endif
#endif

#import "CommonDefs.h"

// for 10.6 use
NSString* defUsr = @"yusrnm";
NSString* deftok = @"yusrtk";


@interface YMKeyChain(PrivateMethods)
- (SecKeychainItemRef)_tokenReferenceForUserName:(NSString*)userName;
@end

static YMKeyChain* _instance = nil;
static bool userDeniedAccess = false;

@implementation YMKeyChain

+ (YMKeyChain*)sharedInstance {
	return (_instance ? _instance : [[self alloc] init]);
}

- (void)setToken:(NSString*)token forUserName:(NSString*)userName
{
    if ( userDeniedAccess ) return;
    
    //YLog(LOG_NORMAL, @"Saving token for %@", userName);
	if (userName && [userName length]) {
		SecKeychainItemRef itemRef = [self _tokenReferenceForUserName:userName];

		if (token && [token length]) {
			if (itemRef) {
				(void)SecKeychainItemModifyContent(itemRef, NULL, (UInt32)[token length], [token UTF8String]);
			} else {
				(void)SecKeychainAddGenericPassword(NULL, (UInt32)[kAppTitle length], [kAppTitle UTF8String],
						(UInt32)[userName length], [userName UTF8String],
						(UInt32)[token length], [token UTF8String], NULL);
			}
		} else {
			[self removeTokenForUserName:userName];
		}
	}
}

- (NSString *)tokenForUserNamewithNoInteraction:(NSString *)userName errorCode:(OSStatus*) status
{
	NSString *token = nil;
	if (userName && [userName length]) {
        //NSString *kAppTitle = [[NSProcessInfo processInfo] processName];
		UInt32 tokenLength;
		void *tokenPtr;
        
        SecKeychainSetUserInteractionAllowed( false );
		*status = SecKeychainFindGenericPassword(NULL, (UInt32)[kAppTitle length], [kAppTitle UTF8String]
                                                         , (UInt32)[userName length], [userName UTF8String], &tokenLength, &tokenPtr, NULL);
        SecKeychainSetUserInteractionAllowed( true );
        
        if (*status == noErr) {
			token = [[NSString alloc] initWithBytes:tokenPtr length:tokenLength encoding:NSUTF8StringEncoding];
			SecKeychainItemFreeContent(NULL, tokenPtr);
		}
    }
	return token;
}

- (NSString *)tokenForUserName:(NSString *)userName
{
    if ( userDeniedAccess ) return nil;
    
	NSString *token = nil;
	if (userName && [userName length])
    {
        //NSString *kAppTitle = [[NSProcessInfo processInfo] processName];
		UInt32 tokenLength;
		void *tokenPtr;
        
		OSStatus status = SecKeychainFindGenericPassword(NULL, (UInt32)[kAppTitle length], [kAppTitle UTF8String]
				, (UInt32)[userName length], [userName UTF8String], &tokenLength, &tokenPtr, NULL);
        
        if ( status == errSecAuthFailed) {
            YLog(LOG_NORMAL, @"KC: User denied access to the keychain or user has no access permissions");
            userDeniedAccess = true;
        }
		else if (status == noErr) {
			token = [[NSString alloc] initWithBytes:tokenPtr length:tokenLength encoding:NSUTF8StringEncoding];
			SecKeychainItemFreeContent(NULL, tokenPtr);
		}
        else if ( status != errSecItemNotFound )
        {
            YLog(LOG_NORMAL, @"KC: tokenForUserName failed with error code=%d", status);
        }
    }
	return token;
}

- (void)removeTokenForUserName:(NSString*)userName
{
    if ( userDeniedAccess ) return;
	if (userName && [userName length]) {
		SecKeychainItemRef itemRef = [self _tokenReferenceForUserName:userName];
		if (itemRef)
			SecKeychainItemDelete(itemRef);
	}
}

- (SecKeychainItemRef)_tokenReferenceForUserName:(NSString *)userName
{
	SecKeychainItemRef itemRef = NULL;
    OSStatus status = SecKeychainFindGenericPassword(NULL, (UInt32)[kAppTitle length], [kAppTitle UTF8String],
                                                     (UInt32)[userName length], [userName UTF8String], NULL, NULL, &itemRef);
    if (status == errSecItemNotFound )
        return  NULL; // not found
    else if (status != noErr)
    {
        YLog(LOG_NORMAL, @"KC: _tokenReferenceForUserName failed with error code=%d", status);
    }
	return ((status == noErr) ? itemRef : NULL);
}

- (NSDictionary*) getAllTokens
{
    return nil;
    /*
    if ( userDeniedAccess ) return nil;
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) @{
                                                                       (__bridge id) kSecClass:                 (__bridge id) kSecClassGenericPassword,
                                                                       (__bridge id) kSecAttrService:                         kAppTitle,
                                                                       (__bridge id) kSecReturnAttributes:      (__bridge id) kCFBooleanTrue,
                                                                       (__bridge id) kSecMatchLimit:            (__bridge id) kSecMatchLimitAll,
                                                                       },
                                          &result);
    if (status != errSecSuccess)
    {
        if ( status != -25300 ) {
            CFStringRef errorMsg =SecCopyErrorMessageString(status, NULL);
            YLog(LOG_NORMAL, @"SecItemCopyMatching failed with error code=%d - %@", status,  (__bridge NSString *)errorMsg);
            CFRelease(errorMsg);
        }
        if ( result != NULL )
            CFRelease(result);
        return nil;
    }
    
    NSArray* items = (__bridge_transfer NSArray *)result;
    
    if ( items == nil )
        return nil;
    
    NSMutableDictionary *resultItems = [[NSMutableDictionary alloc] init];
    for (NSDictionary *itemDict in items)
    {
        NSData *data = [itemDict objectForKey:kSecValueData];
        NSString *password = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *account = [itemDict objectForKey:kSecAttrAccount];
        
        [resultItems setObject:password forKey:account];
    }
    //CFRelease(result);
    return resultItems;
     
    */
}

@end
