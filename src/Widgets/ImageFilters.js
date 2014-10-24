/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function() {

	var tempContext;
	
	function grayscale(imgData) {
		var pixels = imgData.data,
			l = pixels.length,
			i = 0,
			r, g, b, 
			v;

		for(; i<l; i+=4) {
			r = pixels[i];
			g = pixels[i+1];
			b = pixels[i+2];

			v = 0.2126*r + 0.7152*g + 0.0722*b;

			pixels[i] = pixels[i+1] = pixels[i+2] = v;
		}

		return imgData;
	}

	function brightness(imgData) {
		var pixels = imgData.data,
			l = pixels.length,
			i =  0;
		for(; i < l; i+=4) {
			pixels[i] += 0.5*pixels[i];
			pixels[i+1] += 0.5*pixels[i+1];
			pixels[i+2] += 0.5*pixels[i+2];
		}

		return imgData;
	}

	function threshold(imgData) {
		var pixels = imgData.data,
			l = pixels.length,
			i = 0,
			threshold = 128,
			r, g, b, v;

		for(; i < l; i+=4) {
			r = pixels[i];
			g = pixels[i+1];
			b = pixels[i+2];
			v = (0.2126*r + 0.7152*g + 0.0722*b >= threshold) ? 255: 0;
			pixels[i] = pixels[i+1] = pixels[i+2] = v;
		}

		return imgData;
	}

	function invert(imgData) {
		var pixels = imgData.data,
			l = pixels.length,
			i = 0,
			r, g, b, v;

		for(; i < l; i+=4) {
			r = pixels[i];
			g = pixels[i+1];
			b = pixels[i+2];
			pixels[i] = 255 - r;
			pixels[i+1] = 255 - g;
			pixels[i+2] = 255 - b;
		}

		return imgData;
	}

	var cf = 2.5, cno = (255*259*cf - 259*255)/(259+255*cf);
	function contrast(imgData) {
		var pixels = imgData.data,
			l = pixels.length,
			i = 0,
			r, g, b, v;

		for(; i < l; i+=4) {
			r = pixels[i];
			g = pixels[i+1];
			b = pixels[i+2];
			pixels[i] = cf * (r - cno) + cno;
			pixels[i+1] = cf * (g - cno) + cno;
			pixels[i+2] = cf * (b - cno) + cno;
		}

		return imgData;
	}

	function saturate(imgData) {
		var pixels = imgData.data,
			satAmt = 2,
			l = pixels.length,
			i = 0,
			r, g, b,
			or, og, ob, y;

		for(; i < l; i+=4) {
			r = pixels[i];
			g = pixels[i+1];
			b = pixels[i+2];

			y = 0.30*r + 0.59*g + 0.11*b;
			or = 0.70*r - 0.59*g - 0.11*b;
			og = -0.30*r + 0.41*g - 0.11*b;
			ob = -0.30*r - 0.59*g + 0.89*b;

			or = or * satAmt + y;
			og = og * satAmt + y;
			ob = ob * satAmt + y;

			if(or < 0) {
				or = 0;
			} else if(or > 255) {
				or = 255;
			}

			if(og < 0) {
				og = 0;
			} else if(og > 255) {
				og = 255;
			}

			if(ob < 0) {
				ob = 0;
			} else  if(ob > 255) {
				ob = 255;
			}

			pixels[i] = or;
			pixels[i+1] = og;
			pixels[i+2] = ob;
		}

		return imgData;

	}



	
	function sepia(imgData) {
		var pixels = imgData.data,
			l = pixels.length,
			i = 0,
			r, g, b;

		for(; i < l; i+=4) {
			r = pixels[i];
			g = pixels[i+1];
			b = pixels[i+2];
			pixels[i] = Math.min( ((r * 0.393) + (g * 0.769) + (b * 0.189)), 255);
			pixels[i+1] = Math.min( ((r * 0.349) + (g * 0.686) + (b * 0.168)), 255 );
			pixels[i+2] = Math.min( ((r * 0.272) + (g * 0.534) + (b * 0.131)), 255 );
		}

		return imgData;
	}


	function createImageData(w, h) {
		var canvas;
		if(!tempContext) {
			canvas = document.createElement("canvas");
			tempContext = canvas.getContext("2d");
		}

		return tempContext.createImageData(w, h);
	}

	function convolute (imgData, weights, opaque) {
		var side = Math.round(Math.sqrt(weights.length));
	    var halfSide = Math.floor(side/2);
		var src = imgData.data;
		var sw = imgData.width;
		var sh = imgData.height;
		// pad output by the convolution matrix
		var w = sw;
		var h = sh;
		var output = createImageData(w, h);
		var dst = output.data;
		// go through the destination image pixels
		var alphaFac = opaque ? 1 : 0;
		for (var y=0; y<h; y++) {
			for (var x=0; x<w; x++) {
				var sy = y;
				var sx = x;
				var dstOff = (y*w+x)*4;
				// calculate the weighed sum of the source image pixels that
				// fall under the convolution matrix
				var r=0, g=0, b=0, a=0;
				for (var cy=0; cy<side; cy++) {
					for (var cx=0; cx<side; cx++) {
						var scy = sy + cy - halfSide;
						var scx = sx + cx - halfSide;
						if (scy >= 0 && scy < sh && scx >= 0 && scx < sw) {
							var srcOff = (scy*sw+scx)*4;
							var wt = weights[cy*side+cx];
							r += src[srcOff] * wt;
							g += src[srcOff+1] * wt;
							b += src[srcOff+2] * wt;
							a += src[srcOff+3] * wt;
						}
					}
				}
				dst[dstOff] = r;
				dst[dstOff+1] = g;
				dst[dstOff+2] = b;
				dst[dstOff+3] = a + alphaFac*(255-a);
			}
		}
		return output;
	}

	function sharpen(imgData) {
		return convolute(imgData, [ 0, -1, 0, -1, 5, -1, 0, -1, 0]);
	}

	function blur(imgData) {
		return convolute(imgData, [ 
			1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81,
			1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81,
			1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81,
			1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81,
			1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81,
			1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81,
			1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81,
			1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81,
			1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81, 1/81
		 ]);
	}

	function edge(imgData) {
		return convolute(imgData, [-1, -1, -1, -1, 7, -1, -1, -1, -1], 1);
	}

	Caffeine.Ctrls = Caffeine.Ctrls || {};

	Caffeine.Ctrls.ImageFilters = {
		blur: blur,
		brightness: brightness,
		contrast: contrast,
		edge: edge,
		grayscale: grayscale,
		invert: invert,
		saturate: saturate,
		sepia: sepia,
		sharpen: sharpen
	};
})();
