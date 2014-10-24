//
//  NSString_Encode.m
//  McBrewery
//
//  Created by Fernando Pereira on 6/30/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import "NSString_Encode.h"


@implementation NSString (encode)

- (NSString *)encodeString:(NSStringEncoding)encoding
{
    return (NSString *) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)self,
                                                                                  (CFStringRef)@"#$",
                                                                                  (CFStringRef)@";?@&=+{}<>,",
                                                                CFStringConvertNSStringEncodingToEncoding(encoding)));
}  
@end