//
//  NSString_YMAdditions.h
//  cesario/Brewery
//
//  Created by Ladd Van Tol on 3/1/05.
//  Modifed by FP
//  Copyright 2005,2014 Caffeine! Inc. All rights reserved.
//

@interface NSString (YMAdditions)
//+ (NSString *)stringWithUUID;
+ (NSString *)stringWithPascalString:(unsigned char *)c;
- (NSString *)stringByAddingJavascriptEscaping;
- (NSString *)stringByEncodingIllegalURLCharacters;
- (NSString *)stringByDecodingHTMLEntities;
- (NSString *)stringByAddingPercentEscapes;
- (NSString *)stringByReplacingPercentEscapes;
- (NSString *)stringByURLDecoding;
- (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet *)inSet;
- (void)getPString:(Str255)outString;

//- (NSString *)stringWithMD5Hash;
//- (NSData *)md5Hash;

- (void)clearMemory;

// XML helpers
+ (NSString *)stringWithXMLCharString:(const unsigned char *)string;
- (const unsigned char *)XMLCharString;
@end
