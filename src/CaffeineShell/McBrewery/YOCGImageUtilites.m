//
//  YOCGImageUtilities.m
//  Sash
//
//  Created by Cynthia Maxwell on 6/16/13.
//  Copyright (c) 2013 Caffeine!. All rights reserved.
//

#import "YOCGImageUtilites.h"

CGFloat DegreesToRadians(CGFloat degrees)
{
    return degrees * M_PI / 180;
}

void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size)
{
	CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)pixel;
	CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
	CVPixelBufferRelease( pixelBuffer );
}

OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut)
{
	OSStatus err = noErr;
	OSType sourcePixelFormat;
	size_t width, height, sourceRowBytes;
	void *sourceBaseAddr = NULL;
	CGBitmapInfo bitmapInfo;
	CGColorSpaceRef colorspace = NULL;
	CGDataProviderRef provider = NULL;
	CGImageRef image = NULL;
	
	sourcePixelFormat = CVPixelBufferGetPixelFormatType( pixelBuffer );
	if ( kCVPixelFormatType_32ARGB == sourcePixelFormat )
		bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst;
	else if ( kCVPixelFormatType_32BGRA == sourcePixelFormat )
		bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
	else
		return -95014; // only uncompressed pixel formats
	
	sourceRowBytes = CVPixelBufferGetBytesPerRow( pixelBuffer );
	width = CVPixelBufferGetWidth( pixelBuffer );
	height = CVPixelBufferGetHeight( pixelBuffer );
	
	CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
	sourceBaseAddr = CVPixelBufferGetBaseAddress( pixelBuffer );
	
	colorspace = CGColorSpaceCreateDeviceRGB();
    
	CVPixelBufferRetain( pixelBuffer );
	provider = CGDataProviderCreateWithData( (void *)pixelBuffer, sourceBaseAddr, sourceRowBytes * height, ReleaseCVPixelBuffer);
	image = CGImageCreate(width, height, 8, 32, sourceRowBytes, colorspace, bitmapInfo, provider, NULL, true, kCGRenderingIntentDefault);
	
bail:
    {
        if ( err && image ) {
            CGImageRelease( image );
            image = NULL;
        }
        if ( provider ) CGDataProviderRelease( provider );
        if ( colorspace ) CGColorSpaceRelease( colorspace );
        *imageOut = image;
    }
	return err;
}

CGContextRef CreateCGBitmapContextForSize(CGSize size)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapBytesPerRow;
	
    bitmapBytesPerRow = (size.width * 4);
	
    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (NULL,
									 size.width,
									 size.height,
									 8,      // bits per component
									 bitmapBytesPerRow,
									 colorSpace,
									 kCGImageAlphaPremultipliedLast);
	CGContextSetAllowsAntialiasing(context, NO);
    CGColorSpaceRelease( colorSpace );
    return context;
}

CGImageRef resizedImageCreate(CGImageRef cgImage, CGFloat width, CGFloat height)
{
    // create context, keeping original image properties
    CGContextRef context = CreateCGBitmapContextForSize(CGSizeMake(width, height));
    if(context == NULL)
        return nil;
    
    // draw image to context (resizing it)
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    // extract resulting image from context
    CGImageRef imgRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    return imgRef;
}

CGImageRef rotateAndScaleImageCreate(const CGImageRef cgImage, const CGFloat radians,const CGFloat scalefactor)
{
    BOOL isFrontFacing = TRUE;
    
    CGImageRef rotatedImageRef = NULL;
    
    const CGFloat originalWidth = CGImageGetWidth(cgImage)*scalefactor;
    const CGFloat originalHeight = CGImageGetHeight(cgImage)*scalefactor;
    
    const CGRect imgRect = (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = originalWidth, .size.height = originalHeight};
    const CGRect rotatedRect = CGRectApplyAffineTransform(imgRect, CGAffineTransformMakeRotation(radians));
    
    /// Create an ARGB bitmap context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bmContext = CGBitmapContextCreate (NULL, originalWidth, originalHeight, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (!bmContext)
    {
        return nil;
    }
    
    /// Rotation happen here
    CGContextTranslateCTM(bmContext, +(rotatedRect.size.width * 0.5f), +(rotatedRect.size.height * 0.5f));
    CGContextRotateCTM(bmContext, radians);
    
    if (isFrontFacing)
    {
        CGContextScaleCTM(bmContext, -1, 1);
        /*
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                CGContextScaleCTM(bmContext, 1,-1);
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                CGContextScaleCTM(bmContext, 1,-1);
                break;
            case UIDeviceOrientationLandscapeLeft:
                CGContextScaleCTM(bmContext, -1, 1);
                break;
            case UIDeviceOrientationLandscapeRight:
                CGContextScaleCTM(bmContext, 1, 1);
                break;
            case UIDeviceOrientationFaceUp:
            case UIDeviceOrientationFaceDown:
                break;
            default:
                break;
        }
        */
    }
    
    /// Draw the image in the bitmap context
    CGContextDrawImage(bmContext, (CGRect){.origin.x = -originalWidth * 0.5f, .origin.y = -originalHeight * 0.5f, .size.width = originalWidth, .size.height = originalHeight}, cgImage);
    
    /// Create an image object from the context
    rotatedImageRef = CGBitmapContextCreateImage(bmContext);
    
    /// Cleanup
    CGContextRelease(bmContext);
    
    return rotatedImageRef;
}
