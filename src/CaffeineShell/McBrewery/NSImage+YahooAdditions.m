//
//  UIImage+CaffeineAdditions.m
//  Sash
//
//  Created by Srinivas Raovasudeva on 7/27/13.
//  Copyright (c) 2013 Caffeine!. All rights reserved.
//

#import "NSImage+CaffeineAdditions.h"
#import "NSImage+StackBlur.h"

@implementation NSImage (CaffeineAdditions)

- (NSImage *)cropImageToRect:(CGRect)rect
{
    /*
    CGImageRef imageRef = CGImageCreateWithNSImage([self CGImage], rect);
    NSImage *image = [NSImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return image;
     */
    return self;
}

// Keep this in for later when I will check it with
// ymagine to get theme color
//- (UIColor *)themeColor
//{
//    iosapi *api = [[iosapi alloc] init];
//    return [api themeColorForImage:self];
//}

NSImage* YWStackBlurImage(NSImage *image, NSUInteger rad)
{
    return [image stackBlur:rad];
}

+ (NSImage*) imageFromCGImageRef:(CGImageRef)image
{
    NSRect imageRect = NSMakeRect(0.0, 0.0, 0.0, 0.0);
    CGContextRef imageContext = nil;
    NSImage* newImage = nil; // Get the image dimensions.
    imageRect.size.height = CGImageGetHeight(image);
    imageRect.size.width = CGImageGetWidth(image);
    
    // Create a new image to receive the Quartz image data.
    newImage = [[NSImage alloc] initWithSize:imageRect.size];
    [newImage lockFocus];
    
    // Get the Quartz context and draw.
    imageContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextDrawImage(imageContext, *(CGRect*)&imageRect, image); [newImage unlockFocus];
    return newImage;
}



/* Mac version in NSImage+StackBlur

// quick image blur, algorithm from http://incubator.quasimondo.com/processing/fast_blur_deluxe.php
UIImage* YWStackBlurImage(UIImage *image, NSUInteger rad)
{
    int radius=rad;
    
    if (radius <1) {
        YOLog(kRTLogSeverityError,@"stack blur radius must be > 0");
        return nil;
    }
    if (image.size.width == 0 || image.size.height == 0) {
        YOLog(kRTLogSeverityError,@"zero pixel image passed to stack blur");
        return nil;
    }
    
    CGImageRef inImage = image.CGImage;
    if (CGImageGetBitsPerPixel(inImage) != 32) {
        YOLog(kRTLogSeverityError,@"stack blur image must be 32 bit image");
        return nil;
    }
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(inImage));
    UInt8 * pixels=malloc(CFDataGetLength(data));
    CFDataGetBytes(data, CFRangeMake(0,CFDataGetLength(data)), pixels);
    
	CGContextRef ctx = CGBitmapContextCreate(pixels,
											 CGImageGetWidth(inImage),
											 CGImageGetHeight(inImage),
											 CGImageGetBitsPerComponent(inImage),
											 CGImageGetBytesPerRow(inImage),
											 CGImageGetColorSpace(inImage),
											 CGImageGetBitmapInfo(inImage)
											 );
    
	int w=CGImageGetWidth(inImage);
	int h=CGImageGetHeight(inImage);
	int wm=w-1;
	int hm=h-1;
	int wh=w*h;
	int div=radius+radius+1;
    
	int *r=malloc(wh*sizeof(int));
	int *g=malloc(wh*sizeof(int));
	int *b=malloc(wh*sizeof(int));
	memset(r,0,wh*sizeof(int));
	memset(g,0,wh*sizeof(int));
	memset(b,0,wh*sizeof(int));
	int rsum,gsum,bsum,x,y,i,p,yp,yi,yw;
	int *vmin = malloc(sizeof(int)*MAX(w,h));
	memset(vmin,0,sizeof(int)*MAX(w,h));
	int divsum=(div+1)>>1;
	divsum*=divsum;
	int *dv=malloc(sizeof(int)*(256*divsum));
	for (i=0;i<256*divsum;i++){
		dv[i]=(i/divsum);
	}
    
	yw=yi=0;
    
	int *stack=malloc(sizeof(int)*(div*3));
	int stackpointer;
	int stackstart;
	int *sir;
	int rbs;
	int r1=radius+1;
	int routsum,goutsum,boutsum;
	int rinsum,ginsum,binsum;
	memset(stack,0,sizeof(int)*div*3);
    
	for (y=0;y<h;y++){
		rinsum=ginsum=binsum=routsum=goutsum=boutsum=rsum=gsum=bsum=0;
        
		for(int i=-radius;i<=radius;i++){
			sir=&stack[(i+radius)*3];
			int offset=(yi+MIN(wm,MAX(i,0)))*4;
			sir[0]=pixels[offset];
			sir[1]=pixels[offset+1];
			sir[2]=pixels[offset+2];
            
			rbs=r1-abs(i);
			rsum+=sir[0]*rbs;
			gsum+=sir[1]*rbs;
			bsum+=sir[2]*rbs;
			if (i>0){
				rinsum+=sir[0];
				ginsum+=sir[1];
				binsum+=sir[2];
			} else {
				routsum+=sir[0];
				goutsum+=sir[1];
				boutsum+=sir[2];
			}
		}
		stackpointer=radius;
        
		for (x=0;x<w;x++){
			r[yi]=dv[rsum];
			g[yi]=dv[gsum];
			b[yi]=dv[bsum];
            
			rsum-=routsum;
			gsum-=goutsum;
			bsum-=boutsum;
            
			stackstart=stackpointer-radius+div;
			sir=&stack[(stackstart%div)*3];
            
			routsum-=sir[0];
			goutsum-=sir[1];
			boutsum-=sir[2];
            
			if(y==0){
				vmin[x]=MIN(x+radius+1,wm);
			}
            
			int offset=(yw+vmin[x])*4;
			sir[0]=pixels[offset];
			sir[1]=pixels[offset+1];
			sir[2]=pixels[offset+2];
			rinsum+=sir[0];
			ginsum+=sir[1];
			binsum+=sir[2];
            
			rsum+=rinsum;
			gsum+=ginsum;
			bsum+=binsum;
            
			stackpointer=(stackpointer+1)%div;
			sir=&stack[((stackpointer)%div)*3];
            
			routsum+=sir[0];
			goutsum+=sir[1];
			boutsum+=sir[2];
            
			rinsum-=sir[0];
			ginsum-=sir[1];
			binsum-=sir[2];
            
			yi++;
		}
		yw+=w;
	}
	for (x=0;x<w;x++){
		rinsum=ginsum=binsum=routsum=goutsum=boutsum=rsum=gsum=bsum=0;
		yp=-radius*w;
		for(i=-radius;i<=radius;i++){
			yi=MAX(0,yp)+x;
            
			sir=&stack[(i+radius)*3];
            
			sir[0]=r[yi];
			sir[1]=g[yi];
			sir[2]=b[yi];
            
			rbs=r1-abs(i);
            
			rsum+=r[yi]*rbs;
			gsum+=g[yi]*rbs;
			bsum+=b[yi]*rbs;
            
			if (i>0){
				rinsum+=sir[0];
				ginsum+=sir[1];
				binsum+=sir[2];
			} else {
				routsum+=sir[0];
				goutsum+=sir[1];
				boutsum+=sir[2];
			}
            
			if(i<hm){
				yp+=w;
			}
		}
		yi=x;
		stackpointer=radius;
		for (y=0;y<h;y++){
			int offset=yi*4;
			pixels[offset]=dv[rsum];
			pixels[offset+1]=dv[gsum];
			pixels[offset+2]=dv[bsum];
			rsum-=routsum;
			gsum-=goutsum;
			bsum-=boutsum;
            
			stackstart=stackpointer-radius+div;
			sir=&stack[(stackstart%div)*3];
            
			routsum-=sir[0];
			goutsum-=sir[1];
			boutsum-=sir[2];
            
			if(x==0){
				vmin[y]=MIN(y+r1,hm)*w;
			}
			p=x+vmin[y];
            
			sir[0]=r[p];
			sir[1]=g[p];
			sir[2]=b[p];
            
			rinsum+=sir[0];
			ginsum+=sir[1];
			binsum+=sir[2];
            
			rsum+=rinsum;
			gsum+=ginsum;
			bsum+=binsum;
            
			stackpointer=(stackpointer+1)%div;
			sir=&stack[(stackpointer)*3];
            
			routsum+=sir[0];
			goutsum+=sir[1];
			boutsum+=sir[2];
            
			rinsum-=sir[0];
			ginsum-=sir[1];
			binsum-=sir[2];
            
			yi+=w;
		}
	}
	free(r);
	free(g);
	free(b);
	free(vmin);
	free(dv);
	free(stack);
	CGImageRef imageRef = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
    
	UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	CFRelease(data);
    free(pixels);
    return [UIImage imageWithCGImage:finalImage.CGImage scale:[UIScreen mainScreen].scale orientation:finalImage.imageOrientation];
}
*/
@end
