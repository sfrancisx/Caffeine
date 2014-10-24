//
//  NSImage+StackBlur.m
//  McBrewery
//
//  Created by Fernando on 6/14/13.
//  Copyright (c) 2013 Y.CORP.Caffeine.COM\pereira. All rights reserved.
//
//  Ported from iOS from the following code:
//  Created by Thomas LANDSPURG on 07/02/12.
//  Copyright 2012 Digiwie. All rights reserved.
//
// StackBlur implementation on iOS
//
//  Created by Thomas LANDSPURG on 07/02/12.
//  Copyright 2012 Digiwie. All rights reserved.
//
// iOS code is at:
//  https://github.com/tomsoft1/StackBluriOS
//
// a StackBlur implementation for iOS based on the algorithm of:
// http://incubator.quasimondo.com/processing/fast_blur_deluxe.php
//
// by Mario Klingemann
//
// iOS version: thomas.landspurg@gmail.com
//
// License: New BSD license.


#import "NSImage+StackBlur.h"

#define SQUARE(i) ((i)*(i))
inline static void zeroClearInt(int* p, size_t count) { memset(p, 0, sizeof(int) * count); }

@implementation  NSImage (StackBlur)


- (CGImageRef) CGImageCreateWithNSImage
{
    NSSize imageSize = [self size];
    
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, imageSize.width, imageSize.height, 8, 0, [[NSColorSpace genericRGBColorSpace] CGColorSpace], kCGBitmapByteOrder32Host|kCGImageAlphaPremultipliedFirst);
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmapContext flipped:NO]];
    [self drawInRect:NSMakeRect(0, 0, imageSize.width, imageSize.height) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease(bitmapContext);
    return cgImage;
}

// Stackblur algorithm
// from
// http://incubator.quasimondo.com/processing/fast_blur_deluxe.php
// by  Mario Klingemann

- (NSImage*) stackBlur:(NSUInteger)inradius
{
	if (inradius < 1){
		return self;
	}
    // Suggestion xidew to prevent crash if size is null
    CGSize cgsize = NSSizeToCGSize(self.size);
	if (CGSizeEqualToSize(cgsize, CGSizeZero)) {
        return self;
    }
    
    //	return [other applyBlendFilter:filterOverlay  other:self context:nil];
	// First get the image into your data buffer
    CGImageRef inImage = [self CGImageCreateWithNSImage];
    int nbPerCompt = CGImageGetBitsPerPixel(inImage);
    if(nbPerCompt != 32){
        NSImage *tmpImage = [self normalize];
        inImage = [tmpImage CGImageCreateWithNSImage];
    }
    CFMutableDataRef m_DataRef = CFDataCreateMutableCopy(0, 0, CGDataProviderCopyData(CGImageGetDataProvider(inImage)));
    UInt8 * m_PixelBuf=malloc(CFDataGetLength(m_DataRef));
    CFDataGetBytes(m_DataRef,
                   CFRangeMake(0,CFDataGetLength(m_DataRef)) ,
                   m_PixelBuf);
	
	CGContextRef ctx = CGBitmapContextCreate(m_PixelBuf,
											 CGImageGetWidth(inImage),
											 CGImageGetHeight(inImage),
											 CGImageGetBitsPerComponent(inImage),
											 CGImageGetBytesPerRow(inImage),
											 CGImageGetColorSpace(inImage),
											 CGImageGetBitmapInfo(inImage)
											 );
	
    // Apply stack blur
    const int imageWidth  = CGImageGetWidth(inImage);
	const int imageHeight = CGImageGetHeight(inImage);
    [self.class applyStackBlurToBuffer:m_PixelBuf
                                 width:imageWidth
                                height:imageHeight
                            withRadius:inradius];
    
    // Make new image
	CGImageRef imageRef = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	
    NSSize finalSize = NSMakeSize(imageWidth, imageHeight);
    NSImage* finalImage = [[NSImage alloc] initWithCGImage:imageRef size:finalSize];
	CGImageRelease(imageRef);
	CFRelease(m_DataRef);
    free(m_PixelBuf);
	return finalImage;
}


+ (void) applyStackBlurToBuffer:(UInt8*)targetBuffer width:(const int)w height:(const int)h withRadius:(NSUInteger)inradius {
    // Constants
	const int radius = inradius; // Transform unsigned into signed for further operations
	const int wm = w - 1;
	const int hm = h - 1;
	const int wh = w*h;
	const int div = radius + radius + 1;
	const int r1 = radius + 1;
	const int divsum = SQUARE((div+1)>>1);
    
    // Small buffers
	int stack[div*3];
	zeroClearInt(stack, div*3);
    
	int vmin[MAX(w,h)];
	zeroClearInt(vmin, MAX(w,h));
    
    // Large buffers
	int *r = malloc(wh*sizeof(int));
	int *g = malloc(wh*sizeof(int));
	int *b = malloc(wh*sizeof(int));
	zeroClearInt(r, wh);
	zeroClearInt(g, wh);
	zeroClearInt(b, wh);
    
    const size_t dvcount = 256 * divsum;
    int *dv = malloc(sizeof(int) * dvcount);
	for (int i = 0;i < dvcount;i++) {
		dv[i] = (i / divsum);
	}
    
    // Variables
    int x, y;
	int *sir;
	int routsum,goutsum,boutsum;
	int rinsum,ginsum,binsum;
	int rsum, gsum, bsum, p, yp;
	int stackpointer;
	int stackstart;
	int rbs;
    
	int yw = 0, yi = 0;
	for (y = 0;y < h;y++) {
		rinsum = ginsum = binsum = routsum = goutsum = boutsum = rsum = gsum = bsum = 0;
		
		for(int i = -radius;i <= radius;i++){
			sir = &stack[(i + radius)*3];
			int offset = (yi + MIN(wm, MAX(i, 0)))*4;
			sir[0] = targetBuffer[offset];
			sir[1] = targetBuffer[offset + 1];
			sir[2] = targetBuffer[offset + 2];
			
			rbs = r1 - abs(i);
			rsum += sir[0] * rbs;
			gsum += sir[1] * rbs;
			bsum += sir[2] * rbs;
			if (i > 0){
				rinsum += sir[0];
				ginsum += sir[1];
				binsum += sir[2];
			} else {
				routsum += sir[0];
				goutsum += sir[1];
				boutsum += sir[2];
			}
		}
		stackpointer = radius;
		
		for (x = 0;x < w;x++) {
			r[yi] = dv[rsum];
			g[yi] = dv[gsum];
			b[yi] = dv[bsum];
			
			rsum -= routsum;
			gsum -= goutsum;
			bsum -= boutsum;
			
			stackstart = stackpointer - radius + div;
			sir = &stack[(stackstart % div)*3];
			
			routsum -= sir[0];
			goutsum -= sir[1];
			boutsum -= sir[2];
			
			if (y == 0){
				vmin[x] = MIN(x + radius + 1, wm);
			}
			
			int offset = (yw + vmin[x])*4;
			sir[0] = targetBuffer[offset];
			sir[1] = targetBuffer[offset + 1];
			sir[2] = targetBuffer[offset + 2];
			rinsum += sir[0];
			ginsum += sir[1];
			binsum += sir[2];
			
			rsum += rinsum;
			gsum += ginsum;
			bsum += binsum;
			
			stackpointer = (stackpointer + 1) % div;
			sir = &stack[(stackpointer % div)*3];
			
			routsum += sir[0];
			goutsum += sir[1];
			boutsum += sir[2];
			
			rinsum -= sir[0];
			ginsum -= sir[1];
			binsum -= sir[2];
			
			yi++;
		}
		yw += w;
	}
    
	for (x = 0;x < w;x++) {
		rinsum = ginsum = binsum = routsum = goutsum = boutsum = rsum = gsum = bsum = 0;
		yp = -radius*w;
		for(int i = -radius;i <= radius;i++) {
			yi = MAX(0, yp) + x;
			
			sir = &stack[(i + radius)*3];
			
			sir[0] = r[yi];
			sir[1] = g[yi];
			sir[2] = b[yi];
			
			rbs = r1 - abs(i);
			
			rsum += r[yi]*rbs;
			gsum += g[yi]*rbs;
			bsum += b[yi]*rbs;
			
			if (i > 0) {
				rinsum += sir[0];
				ginsum += sir[1];
				binsum += sir[2];
			} else {
				routsum += sir[0];
				goutsum += sir[1];
				boutsum += sir[2];
			}
			
			if (i < hm) {
				yp += w;
			}
		}
		yi = x;
		stackpointer = radius;
		for (y = 0;y < h;y++) {
			int offset = yi*4;
			targetBuffer[offset]     = dv[rsum];
			targetBuffer[offset + 1] = dv[gsum];
			targetBuffer[offset + 2] = dv[bsum];
			rsum -= routsum;
			gsum -= goutsum;
			bsum -= boutsum;
			
			stackstart = stackpointer - radius + div;
			sir = &stack[(stackstart % div)*3];
			
			routsum -= sir[0];
			goutsum -= sir[1];
			boutsum -= sir[2];
			
			if (x == 0){
				vmin[y] = MIN(y + r1, hm)*w;
			}
			p = x + vmin[y];
			
			sir[0] = r[p];
			sir[1] = g[p];
			sir[2] = b[p];
			
			rinsum += sir[0];
			ginsum += sir[1];
			binsum += sir[2];
			
			rsum += rinsum;
			gsum += ginsum;
			bsum += binsum;
			
			stackpointer = (stackpointer + 1) % div;
			sir = &stack[stackpointer*3];
			
			routsum += sir[0];
			goutsum += sir[1];
			boutsum += sir[2];
			
			rinsum -= sir[0];
			ginsum -= sir[1];
			binsum -= sir[2];
			
			yi += w;
		}
	}
    
	free(r);
	free(g);
	free(b);
    free(dv);
}


- (NSImage *) normalize {
    int width = self.size.width;
    int height = self.size.height;
    CGColorSpaceRef genericColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef thumbBitmapCtxt = CGBitmapContextCreate(NULL,
                                                         width,
                                                         height,
                                                         8, (4 * width),
                                                         genericColorSpace,
                                                         kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(genericColorSpace);
    CGContextSetInterpolationQuality(thumbBitmapCtxt, kCGInterpolationDefault);
    CGRect destRect = CGRectMake(0, 0, width, height);
    CGContextDrawImage(thumbBitmapCtxt, destRect, [self CGImageCreateWithNSImage]);
    CGImageRef tmpThumbImage = CGBitmapContextCreateImage(thumbBitmapCtxt);
    CGContextRelease(thumbBitmapCtxt);
    
    NSSize finalSize = NSMakeSize(width, height);
    NSImage* result = [[NSImage alloc] initWithCGImage:tmpThumbImage size:finalSize];
    
    CGImageRelease(tmpThumbImage);
    
    return result;
}


@end
