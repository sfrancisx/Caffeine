//
//  NSString_NSString_wstring.mm
//  McBrewery
//
//  Created by Fernando on 7/29/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#include "string"
#import "NSString_NSString_wstring.h"

@implementation NSString (string_wstring)

+(NSString*) stringWithwstring:(const std::wstring&)ws
{
    char* data = (char*)ws.data();
    unsigned long size = ws.size() * sizeof(wchar_t);
    
    NSString* result = [[NSString alloc] initWithBytes:data length:size
                                               encoding:NSUTF32LittleEndianStringEncoding] ;
    
    return result;
}

-(std::wstring) getwstring
{
    NSData* asData = [self dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
    return std::wstring((wchar_t*)[asData bytes], [asData length] /
                        sizeof(wchar_t));
}

@end

