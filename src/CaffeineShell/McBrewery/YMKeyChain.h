// Copyright (c) 2007,2014 Caffeine! Inc. All Rights Reserved.
// http://www.Caffeine.com/
//
// This source code and specific concepts contained herein are confidential
// information and property of Caffeine! Inc.  Distribution is prohibited
// without written permission.




@interface YMKeyChain : NSObject {
}

+ (YMKeyChain*)sharedInstance;

- (void)setToken:(NSString *)token forUserName:(NSString *)userName;

- (NSString *)tokenForUserName:(NSString *)userName;
- (NSString *)tokenForUserNamewithNoInteraction:(NSString *)userName errorCode:(OSStatus*) status;

- (void)removeTokenForUserName:(NSString *)userName;

- (NSDictionary*) getAllTokens;

@end
