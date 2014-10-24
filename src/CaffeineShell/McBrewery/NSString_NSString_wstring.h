//
//  NSString_NSString_wstring.h
//  McBrewery
//
//  Created by Fernando on 7/29/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (string_wstring)

+(NSString*) stringWithwstring:(const std::wstring&)string;
-(std::wstring) getwstring;

@end
