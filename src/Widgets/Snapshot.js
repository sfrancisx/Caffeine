/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function() {
"use strict";

	Caffeine.Ctrls = Caffeine.Ctrls || {};
/**
 * Snapshot control which allows to turn on web came and take a photo
 *
 * @module Widgets
 * @namespace Caffeine.Ctrls
 * @class Snapshot
 * @constructor
 * @params {parms} constructor parameters
 *
 * - parms.intf ici object to interact with parent interfaces
 * - parms.parent [Optional] Container element to which snapshot html fragment will be added. default - document.body
 * - parms.container [Optional] snapshot html fragment if it is already added to the page and need to be binded with JavaScript. Other wise snapshot html fragment will be created and added to the parent
 * - parms.data [Optional] optional data to be passed to the snapshot template.
 * - parms.isFull [Optional]  if true returns the whole image instead of the clipped area in guide circle
 * - parms.closeOnSnap if true closes the intf when the photo is taken
 * - parms.onBeforeShutter [Optional] - listener when user clicks button to take photo. Follows signature function(parms, cb) where parms is null. If it is used then make sure to call "cb" from the listener. cb accepts single argument and if that is === false no action being done on button click. Otherwise photo is taken and onSnap listener is called
 * - parms.onSnap [Optional] listener for captured photo. Listener is called with single argument which is an object with "imgUrl"(data url of the image captured), "clipSize"(size and position of the clipped area in guide circle), and "zoom"(clipped vs actual)
 * - parms.onClose [Optional] listener when the control is closed or cleaned up
 * - parms.isPopup true if the control being constructed as part of popupWindow call
 * - parms.frameCount [Optional] indicates how many frames of the cpaturing area makes a single canvas
 * - parms.title [Optional] window title
*
* - parms.cb callback which will be called after construction. It has signature function(err, instance) where instance is the instance created
*
* Instance methods
* - takeSnap - takes the photo. signature function(parms, cb). Note that onBeforeShutter and onSnap will not be called in this case 
* - getImage - returns capture image data. signature function(parms, cb). cb signature is function(err, data). image data is same as the one returned for onSnap listener.
* - close - cleansup and closes the interface
*/
	 Caffeine.Ctrls.Snapshot = function(parms, cb) {
		var parentEl = parms.parent || document.body,
			container = parms.container,
			data = parms.data,
			intf = parms.intf,
			isFull = parms.isFull,
			isPopup = parms.isPopup,
			frameCount = parms.frameCount,
			title = parms.title,
			closeOnSnap = parms.closeOnSnap,
			onBeforeShutter = parms.onBeforeShutter,
			onSnap = parms.onSnap,
			onClose = parms.onClose,
			video, videoUrl,
			constraints = { video: true, audio: false },
			instance,
			registrar = Ether.getRegistrar(),
			canvas, context, canvasWidth,
			framePos = 0,
			srcX, srcY, srcWidth, srcHeight,
			destX, destY, destWidth, destHeight,
			clipX, clipY, clipWidth, clipHeight,
			zoom,
			filterEl, filters = {};

		function successCB(mediaStream) {
			try {
				var tempCont,
					videoTracks = mediaStream.getVideoTracks();

				if(videoTracks.length === 0) {
					errorCB({ message: "No video track found" });
					return;
				}

				if(!container) {
					tempCont = document.createElement("div");
					Caffeine.Template.renderInto("Snapshot", data, tempCont);
					container = tempCont.firstChild;
					parentEl.appendChild(container);
				}

				video = container.querySelector("video");

				if(!video.getAttribute("autoplay")) {
					video.setAttribute("autoplay", "autoplay");
				}

				registrar.addEventListener(video, "error", onWebcamLoadError);
				registrar.addEventListener(video, "loadedmetadata", onWebcamLoadSucess);

				videoUrl = window.URL.createObjectURL(mediaStream);
				video.setAttribute("src", videoUrl);
			} catch(e) {
				errorCB(e);
			}
		}

		function errorCB(err) {
			Caffeine.Ctrls.Dialog({html: Caffeine.Intl.get("str_error_camera")});
			callInvokerCallback(err);
		}

		function onWebcamLoadError(err) {
			if(!instance) {
				callInvokerCallback(err);
			}
		}

		function onWebcamLoadSucess() {
			var guideEl, ratio,
				videoWidth, videoHeight;

			instance = {
				takeSnap: takeSnap,
				getImage: getImage,
				close: function() {
					close();
					intf.close();
				},
				pause: function() {
					video.pause();
				},
				play: function() {
					video.play();
				}
			};

			container.classList.add("ready");

			registrar.addEventListener(container.querySelector(".icn-shutter"), "click", takeShot);

			registrar.removeEventListener(video, "error", onWebcamLoadError);

			registrar.addEventListener(container.querySelector(".filterhack"), "click", onContextMenu);

			intf && registrar.on(intf, { "closed": close });

			video.style.marginLeft = "-"+ video.offsetWidth/2 +"px";

			videoWidth = video.videoWidth;
			videoHeight = video.videoHeight;

			guideEl = container.querySelector(".guide");
			ratio = video.offsetHeight/videoHeight;
			clipX = (guideEl.offsetLeft - video.offsetLeft)/ratio;
			clipY = (guideEl.offsetTop - video.offsetTop)/ratio;
			clipWidth = guideEl.offsetWidth/ratio;
			clipHeight = guideEl.offsetHeight/ratio;

			if(isFull) {
				srcX = destX = 0;
				srcY = destY = 0;
				srcWidth = destWidth = videoWidth;
				srcHeight = destHeight = videoHeight;
			} else {
				srcX = clipX;
				srcY = clipY;
				srcWidth = clipWidth;
				srcHeight = clipHeight;
				destX = 0;
				destY = 0;
				destWidth = clipWidth;
				destHeight = clipHeight;
			}

			zoom = destHeight / clipHeight;

			if(isPopup) {
				Caffeine.IPC.makeProxy(instance, finishCreate);
			} else {
				finishCreate(null, instance);
			}
		}

		function finishCreate(err, proxyInstance) {
			callInvokerCallback(err, proxyInstance);
		}

		function callInvokerCallback(err, data) {
			if(cb) {
				if(isPopup) {
					cb({ _windowState: "loaded", err: err }, data);
				} else {
					cb(err, data);
				}
			}
		}

		function takeShot() {
			if(onBeforeShutter) {
				onBeforeShutter(null, function(result) {
					if(result === false) {
						return;
					} else {
						afterShot();
					}
				});
			} else {
				afterShot();
			}
		}

		function afterShot() {
			if(onSnap) {
				takeSnap(null, function() {
					getImage(null, function(err, imgData) {
						onSnap(imgData); 
						if(closeOnSnap) {
							setTimeout(function() {
								intf.close();
							}, 200);
						}
					});
				});
			}
		}

		function takeSnap(parms, cb) {
			var dx = destX, dy = destY,
				imgData,
				filterKeys = Object.keys(filters),
				filterLen = filterKeys.length,
				filterXPos,
				index = 0;
			if(!canvas) {
				canvas = document.createElement("canvas");
				canvas.width = canvasWidth = frameCount ? frameCount * destWidth : destWidth;
				canvas.height = destHeight;
				context = canvas.getContext("2d");
				context.translate(canvasWidth, 0);
				context.scale(-1, 1);
			}

			if(frameCount) {
				if(framePos == frameCount) {
					framePos = 0;
				}
				framePos++;
				dx = destWidth*(frameCount - framePos);
			}

			context.drawImage(video, srcX, srcY, srcWidth, srcHeight, dx, destY, destWidth, destHeight);

			if(filterKeys.length) {
				filterXPos = canvasWidth - dx - destWidth;
				imgData = context.getImageData(filterXPos, destY, destWidth, destHeight);
				var pixels = imgData;
				for(; index < filterLen; index++) {
					pixels = Caffeine.Ctrls.ImageFilters[filterKeys[index]](pixels);
				}
				context.putImageData(pixels, filterXPos, destY);

			}

			container.setAttribute("data-flash", "true");

			cb();

			setTimeout(function() {
				container.setAttribute("data-flash", "false");
			}, 500);
		}

		function getImage(parms, cb) {
			cb(null, buildResponse(canvas.toDataURL("image/jpeg")));
		}

		function buildResponse(imgUrl) {
			return { 
				imgUrl: imgUrl,
				clipSize: { x: clipX, y: clipY, width: clipWidth, height: clipHeight },
				zoom: zoom
			};
		}

		function onContextMenu(e) {
			if(!filterEl) {
				filterEl = container.querySelector(".menu");
				registrar.addEventListener(filterEl, "click", applyFilter);
				registrar.addEventListener(container, "click", hideMenu);
			}

			filterEl.classList.remove("hidden");
			e.stopPropagation();
		}

		function applyFilter(e) {
			var srcEl = e.target,
				filter = srcEl.getAttribute("data-filter"),
				isOn = srcEl.getAttribute("data-on");

			if(isOn) {
				delete filters[filter];
				srcEl.removeAttribute("data-on");
			} else if(filter != "") {
				filters[filter] = 1;
				srcEl.setAttribute("data-on", "1");
			}

			applyCssFilter();

			e.stopPropagation();
		}

		function applyCssFilter() {
			var keys = Object.keys(filters),
				len = keys.length, i = 0,
				strFilter = "url('')";

			for(; i < len; i++) {
				if( i > 0)  {
					strFilter += " ";
				}
				strFilter += cssFilters[keys[i]];
			}

			video.style.webkitFilter = strFilter;
		}

		function hideMenu() {
			filterEl.classList.add("hidden");
		}

		function close() {
			registrar.cleanup();
			video.pause();
			video.setAttribute("src", "");
			window.URL.revokeObjectURL(videoUrl);
			canvas = null;
			context = null;
			onSnap = null;
			onBeforeShutter = null;
			instance = null;
			if(onClose) {
				onClose();
				onClose = null;
			}
		}

		if(isPopup) {
			cb && cb({ _windowState: "loading", _ipcState: "partial" }, null);
		}

		navigator.webkitGetUserMedia( constraints, successCB, errorCB);

		if(title) {
			intf.setTitle(title);
		}
	
	};


	var cssFilters = {
		"blur": "blur(2.5px)",
		"brightness": "brightness(1.5)",
		"contrast": "contrast(200%)",
		"grayscale": "grayscale(100%)",
		"invert": "invert(100%)",
		"saturate": "saturate(200%)",
		"sepia": "sepia(100%)",
		"sharpen": "url(./src/Assets/images/filter.svg#filter_sharpen)",
		"edge": "url(./src/Assets/images/filter.svg#filter_edge)"
	};
})();
