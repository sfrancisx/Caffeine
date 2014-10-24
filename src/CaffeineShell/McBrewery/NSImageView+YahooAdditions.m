//
//  UIImageView+CaffeineAdditions.m
//  Sash
//
//  Created by Cynthia Maxwell on 6/12/13.
//  Copyright (c) 2013 Caffeine!. All rights reserved.
//

#import "NSImage+CaffeineAdditions.h"
#import "NSImageView+CaffeineAdditions.h"
#import "YOCGImageUtilites.h"

//#import <ImageIO/ImageIO.h>

#define kDownsampleAmount 4

#define BLUR_JPEG_QUALITY 0.8

@implementation NSImageView (CaffeineAdditions)


- (NSImage *)resizeImage:(NSImage *)image width:(CGFloat)resizedWidth height:(CGFloat)resizedHeight
{
    //CGImageRef imageRef = [image CGImage];
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)[image TIFFRepresentation], NULL);
    CGImageRef imageRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(NULL, resizedWidth, resizedHeight, 8, 4 * resizedWidth, colorSpace, kCGImageAlphaPremultipliedFirst);
    CGContextDrawImage(bitmap, CGRectMake(0, 0, resizedWidth, resizedHeight), imageRef);
    CGImageRef ref = CGBitmapContextCreateImage(bitmap);
    NSImage *result = [NSImage imageFromCGImageRef:ref];
    
    
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(bitmap);
    CGImageRelease(ref);
    
    return result;
}

- (void)replaceBlurredImageForImage:(NSImage*)original
{
    [self replaceBlurredImageForImage:original callback:NULL];
}


- (void)replaceBlurredImageForImage:(NSImage*)original callback:(NSImageViewCompletionBlock)callback
{
    [self replaceBlurredImageForImage:original animated:NO callback:callback];
}

- (void)replaceBlurredImageForImage:(NSImage*)original animated:(BOOL)animated callback:(NSImageViewCompletionBlock)callback
{
    /*
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSImage *image = YWStackBlurImage(original, (NSUInteger)round(kBlurRadius / kBlurImageScale));
        dispatch_async(dispatch_get_main_queue(), ^{
            if (animated) {
                [NSView transitionWithView:self duration:kBlurAnimationDuration options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                    self.image = image;
                } completion:^(BOOL finished) {
                    if (callback != NULL) {
                        callback();
                    }
                }];
            } else {
                self.image = image;
                if (callback != NULL) {
                    callback();
                }
            }
        });
    }); 
     */
}

- (void)replaceDownsampledImageForImage:(NSImage*)original
{
    NSSize size = original.size;
    NSImage* smaller = [self resizeImage:original width:round(size.width/kDownsampleAmount) height:round(size.height/kDownsampleAmount)];
    [self setImage:smaller];
}

- (void)setImageAsGif:(NSData *)data
{
    if (!data)
    {
        return;
    }
    
    //[self stopAnimating];
    //self.animationImages = nil;
    
    NSMutableArray *imageFrames = nil;
    //CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)data, NULL);
    if (imageSource)
    {
        size_t imageCount = CGImageSourceGetCount(imageSource);
        imageFrames = [NSMutableArray arrayWithCapacity:imageCount];
        for (size_t i = 0; i < imageCount; i++)
        {
            CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, i, NULL);
            if (image)
            {
                NSImage* img = [NSImage imageFromCGImageRef:image];
                [imageFrames addObject:img];
                CGImageRelease(image);
            }
        }
        CFRelease(imageSource);
    }
    
    /*
    if (imageFrames.count > 0)
    {
        self.image = imageFrames[0];
    }
    self.animationImages = imageFrames;
    self.animationDuration = 0.25 * imageFrames.count; // each frame has 0.25 time.
    self.animationRepeatCount = 0; // infinite.
    
    [self startAnimating];
     */
}

+ (NSImageView *)imageViewWithFrame:(NSRect)frame pathToGIF:(NSString *)path
{
    NSData *data = [NSData dataWithContentsOfFile:path];
    return [NSImageView imageViewWithFrame:frame gifData:data];
}

+ (NSImageView *)imageViewWithFrame:(NSRect)frame gifData:(NSData *)data
{
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:frame];
    [imageView setImageAsGif:data];
    return imageView;
}

@end
