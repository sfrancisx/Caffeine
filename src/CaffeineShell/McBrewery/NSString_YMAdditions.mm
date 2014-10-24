//
//  NSString_YMAdditions.h
//  cesario/Brewery
//
//  Created by Ladd Van Tol on 3/1/05.
//  Modifed by FP
//  Copyright 2005,2014 Caffeine! Inc. All rights reserved.
//

#import "NSString_YMAdditions.h"

static BOOL initted = NO;
static NSDictionary *kYMHTMLEntities = nil;

@implementation NSString (YMAdditions)

+ (void)initialize {
	if (!initted && !kYMHTMLEntities) {
		initted = YES;
		kYMHTMLEntities = [NSDictionary dictionaryWithObjectsAndKeys: @"\"", @"&quot;",
																		@"'", @"&apos;",
																		@"&", @"&amp;",
																		@"<", @"&lt;",
																		@">", @"&gt;",
																		nil] ;
		
	}
}


+ (NSString *)stringWithPascalString:(unsigned char *)c {
    NSString* str = [[NSString alloc] initWithBytes: (c+1) length:(NSUInteger)c[0] encoding:NSUTF8StringEncoding];
	//return [NSString stringWithCString:(char *)(c+1) length:(int)c[0]];
    return str;
}

- (NSString *)stringByEncodingIllegalURLCharacters {
	// NSURL's stringByAddingPercentEscapesUsingEncoding: does not escape
	// some characters that should be escaped in URL parameters, like / and ?; 
	// we'll use CFURL to force the encoding of those
	//
	// We'll explicitly leave spaces unescaped now, and replace them with +'s
	//
	// Reference: http://www.ietf.org/rfc/rfc3986.txt
	
	NSString *resultStr = self;
	
	CFStringRef originalString = (__bridge CFStringRef)self;
	CFStringRef leaveUnescaped = CFSTR(" ");
	CFStringRef forceEscaped = CFSTR("!*'();:@&=+$,/?%#[]");
	
	CFStringRef escapedStr = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
																	 originalString,
																	 leaveUnescaped, 
																	 forceEscaped,
																	 kCFStringEncodingUTF8);
	
	if (escapedStr) {
		NSMutableString *mutableStr = [NSMutableString stringWithString:(__bridge NSString *)escapedStr];
		CFRelease(escapedStr);
		
		// replace spaces with plusses
		[mutableStr replaceOccurrencesOfString:@" "
									withString:@"+"
									   options:0
										 range:NSMakeRange(0, [mutableStr length])];
		resultStr = mutableStr;
	}
	
	return resultStr;
}

- (NSString *)stringByDecodingHTMLEntities {	
	NSMutableString *content = [[NSMutableString alloc] initWithString:self];
	NSEnumerator *en = [kYMHTMLEntities keyEnumerator];
	NSString *search = nil;
	NSString *returnValue = nil;
	
	while (search = [en nextObject]) {
		[content replaceOccurrencesOfString:search withString:[kYMHTMLEntities objectForKey:search] options:NSLiteralSearch range:NSMakeRange(0, [content length])];
	}
	
	returnValue = [content copy];
	
	return returnValue;
}

- (NSString *)stringByAddingJavascriptEscaping {
	NSMutableString *ret = [NSMutableString stringWithCapacity:[self length]];

	// derived from http://docs.sun.com/source/816-6409-10/ident.htm
	
	for (unsigned i = 0; i < [self length]; i++) {
		unichar c = [self characterAtIndex:i];
		
		switch (c) {
			case '\\':
				[ret appendString:@"\\\\"]; // note c escaping + javascript escaping
				break;
			case '\'':
				[ret appendString:@"\\\'"];
				break;
			case '\"':
				[ret appendString:@"\\\""];
				break;
			case '\n':
				[ret appendString:@"\\n"];
				break;
			case '\r':
				[ret appendString:@"\\r"];
				break;
			case '\t':
				[ret appendString:@"\\t"];
				break;
			default: {
				if (c > 127) {
					// use unicode escaping
					[ret appendFormat:@"\\u%04X", c];
				} else {
					[ret appendString:[NSString stringWithCharacters:&c length:1]];
				}
			}
			break;
		}
	}
	return [NSString stringWithString:ret];
}

- (NSString *)stringByAddingPercentEscapes {
	CFStringRef escapedString;
    
    escapedString = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)self, NULL, CFSTR("&="), kCFStringEncodingUTF8);
	
    NSString* rt = (__bridge NSString *)escapedString;
    CFRelease( escapedString );
    return  rt;
}

- (NSString *)stringByReplacingPercentEscapes {
	CFStringRef escapedString;
    
    escapedString = CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)self, CFSTR(""));
	
    NSString* rt = (__bridge NSString *)escapedString;
    CFRelease( escapedString );
    return  rt;
}

- (NSString *)stringByURLDecoding {
	NSMutableString *mutableString = [self mutableCopy];
	
	// The leading + is significant in the case of phone numbers like +971 4 3913640
	[mutableString replaceOccurrencesOfString:@"+" withString:@" " options:0 range:NSMakeRange(1, [self length]-1)];
	
	CFStringRef escapedString = CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)mutableString, CFSTR(""));
    NSString* rt = (__bridge NSString *)escapedString;
    CFRelease( escapedString );
    return  rt;
}

- (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet *)inSet {
	NSMutableString *mutableString = [self mutableCopy];
	NSRange searchRange = NSMakeRange( 0, [mutableString length] );
	NSRange characterRange = [mutableString rangeOfCharacterFromSet:inSet options:NSLiteralSearch range:searchRange];
	
	while (characterRange.location != NSNotFound) {
		[mutableString deleteCharactersInRange:characterRange];
		
		searchRange.location = characterRange.location;
		searchRange.length = [mutableString length] - characterRange.location;
		
		characterRange = [mutableString rangeOfCharacterFromSet:inSet options:NSLiteralSearch range:searchRange];
	}
	
	return [mutableString copy];
}

- (void)getPString:(Str255)outString {
    [self getCString:(char *)outString+1 maxLength:255 encoding:NSUTF8StringEncoding];
   // outString[0] = MIN((unsigned)255, [self cStringLength]);
    outString[0] = MIN((unsigned)255, [self lengthOfBytesUsingEncoding: NSUTF8StringEncoding]);
}

/*
- (NSString *)stringWithMD5Hash {
	return [[self dataUsingEncoding:NSUTF8StringEncoding] stringWithMD5Hash];
}

- (NSData *)md5Hash {
	return [[self dataUsingEncoding:NSUTF8StringEncoding] md5Hash];
}
*/
- (void)clearMemory {
	/*
	UniChar *chars = (UniChar *) CFStringGetCharactersPtr((CFStringRef) self);
	
	if (chars)
	{
		
	}
	 */
}

#pragma mark XML Helpers

+ (NSString *)stringWithXMLCharString:(const unsigned char *)string {
	return [NSString stringWithUTF8String:(const char *)string];
}

- (const unsigned char *)XMLCharString {
	return (const unsigned char *)[self UTF8String];
}
@end
