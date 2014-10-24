//
//  UIImageView+CaffeineAdditions.h
//  Sash
//
//  Created by Cynthia Maxwell on 6/12/13.
//  Copyright (c) 2013 Caffeine!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void(^NSImageViewCompletionBlock)();

@interface NSImageView (CaffeineAdditions)

- (void)replaceBlurredImageForImage:(NSImage*)original;
- (void)replaceBlurredImageForImage:(NSImage*)original callback:(NSImageViewCompletionBlock)callback;
- (void)replaceBlurredImageForImage:(NSImage*)original animated:(BOOL)animated callback:(NSImageViewCompletionBlock)callback;

- (void)replaceDownsampledImageForImage:(NSImage*)original;

- (void)setImageAsGif:(NSData *)data;

+ (NSImageView *)imageViewWithFrame:(NSRect)frame pathToGIF:(NSString *)path;
+ (NSImageView *)imageViewWithFrame:(NSRect)frame gifData:(NSData *)data;

@end
