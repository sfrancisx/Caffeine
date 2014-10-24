//
//  YOCGImageUtilites.h
//  Sash
//
//  Created by Cynthia Maxwell on 6/16/13.
//  Copyright (c) 2013 Caffeine!. All rights reserved.
//
//  Modifed for Mac
//    Fernando Pereira

#ifndef Sash_YOCGImageUtilites_h
#define Sash_YOCGImageUtilites_h

CGFloat DegreesToRadians(CGFloat degrees);

//NOTE: for camera maybe just move these into th
void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size);
OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut);
CGContextRef CreateCGBitmapContextForSize(CGSize size);

CGImageRef rotateAndScaleImageCreate(const CGImageRef cgImage, const CGFloat radians,const CGFloat scalefactor);

// NOTE: general
CGImageRef resizedImageCreate(CGImageRef cgImage, CGFloat width, CGFloat height);

#endif
