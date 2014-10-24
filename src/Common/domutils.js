/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

/**
  * DOM Helper Methods
  *
  * @module Common
  * @namespace Caffeine
  * @class DomUtils
  * @static
  */

(function(){
	var fontFamily = null;
	Caffeine.DomUtils =
	{
		/*******************************************************
		* Adds a class name
		* Deprecated - Use "el.classList.add" method instead
		*
		* @method addClass
		* @param {HTMLElement | String} el		element
		* @param {String | Array} className*	class name(s) to add
		********************************************************/
		addClass: function(el/*, className*/)
		{
			var classes, className = "", i;

			if (!el) {
				if (typeof arguments[1] == "string")
					className = arguments[1];
				console.error("Dom Util: addClass - undefined element param for class " + className);
				return;
			}

			if (typeof el == "string")
				el = document.getElementById(el);

			for (i = 1; i < arguments.length; i++)
			{
				className = arguments[i];
				if (typeof className == "string")
					className = [className];

				className.forEach(function(name)
					{
						el.classList.add(name);
					});
			}
		},

		/*******************************************************
		* Removes a class name
		* Deprecated - Use "el.classList.remove" method instead
		*
		* @method removeClass
		* @param {HTMLElement | String} el		element
		* @param {String | Array} className*	class name(s) to remove
		********************************************************/
		removeClass: function(el/*, className*/)
		{
			var i, idx, className= "", j;

			if (!el) {
				if (typeof arguments[1] == "string")
					className = arguments[1];
				console.error("Dom Util: removeClass - undefined element param for class " + className);
				return;
			}

			if (typeof el == "string")
				el = document.getElementById(el);

			for (j = 1; j < arguments.length; j++)
			{
				className = arguments[j];

				if (typeof className == "string")
					className = [className];

				for (i = 0; i < className.length; i++)
				{
					el.classList.remove(className[i]);
				}
			}
		},

		/*******************************************************
		* Checks if a DOM element has the class name
		* Deprecated - Use "el.classList.contains" instead
		*
		* @method hasClass
		* @param {HTMLElement} el	element
		* @param {String} className class name to search for
		* @return {Boolean} true if the element has the classname
		*
		********************************************************/
		hasClass: function(el, className)
		{
			if (!el) {
				console.error("Dom Util: hasClass - undefined element param");
				return false;
			}

			return el && el.classList && el.classList.contains(className);
		},

		/*******************************************************
		* Toggles the class name. If the class name doesn't exist
		* it is removed; otherwise, it is added to the element
		* Deprecated - Use "el.classList.toggle" instead
		*
		* @method toggleClass
		* @param {HTMLElement} el element
		* @param {String} className class name to search for
		* @return {Boolean} true if the class was added
		*
		********************************************************/
		toggleClass: function(el, className)
		{
			var add = !el.classList.contains(className);

			if (add)
				el.classList.add(className);
			else
				el.classList.remove(className);

			return add;
		},
		/*******************************************************
		* Determine if an element is a parent of another elment
		*
		* @method toggleClass
		* @param {HTMLElement} el 		Element to examine
		* @param {HTMLElement} elParent Element to test to see if it is the parent of el
		* @param {HTMLElement} elStop 	Search until we hit this el.  if not provided, we will search up to document.body
		* @return {Boolean} true if elParent is a parent of el
		*
		********************************************************/
		isParent: function(el, elParent, elStop) {
			if (!elStop) 
				elStop = document.body;
			while(el && el != elParent && el != elStop) {
				if (el.parentNode == elParent)
					return true;
				el = el.parentNode;
			}
			return false;
		},

		pointInEl: function(el, x, y)
		{
			var rect = el.getBoundingClientRect();
			if (x > rect.left && x < rect.right && y > rect.top  && y < rect.bottom)
				return 1;
		},

		/*******************************************************
		* Finds the ancestor by the given tagname
		*
		* @method getAncestorByTagName
		* @param {HTMLElement} el	element
		* @param {String} tagName tag to search for
		* @return {HTMLElement} ancestor element
		*
		********************************************************/
		getAncestorByTagName: function(el, tagName)
		{
			tagName = tagName.toLowerCase();

			while (el && (el.nodeName.toLowerCase() != tagName))
				el = el.parentNode;

			return el;
		},

		/*******************************************************
		********************************************************/
		getAncestorBySelector: function(el, selector, stopAt)
		{
			if (!el)
				return null;

			stopAt = stopAt || document.body;

			var t = el;

			while (t != stopAt)
			{
				if (elMatchesSelector(t, selector))
					return t;
				t = t.parentNode;
			}

			function elMatchesSelector(el, selector)
			{
				var p = el.parentNode,
					selected = p.querySelectorAll(p.tagName + " > " + selector);

				for (i = 0; i < selected.length; i++)
				{
					if (selected[i] == el)
						return true;
				}
			}
		},
		/******
		 * Set the background image of the element using CSS background-image attribute
		 *
		 * @param el
		 * @param url
		 */
		setBgImg: function(el, url) {
			if (el)
				el.style.backgroundImage = 'url("' + url + '")';
		},
		/**
		* Alternate implementation for innerHTML.
		* This ends up being about 2x faster than a naive .innerHTML in chrome..
		*
		* @method setInnerHTML
		* @param {HTMLElement} el   element ( or id in a string )
		* @param {String} HTML markup
		* @returns a replacement element (aka the downside of using this)
		*/
		setInnerHTML: function (el, html) {
			if (typeof el == "string")
				el = document.getElementById(el);

			var newChild = el.cloneNode(false);
			newChild.innerHTML = html;
			el.parentNode.replaceChild(newChild, el);

			return newChild;
		},

		/*******************************************************
		* Replace an element with some new HTML markup
		*
		* @method setOuterHTML
		* @param {HTMLElement} el   element ( or id in a string )
		* @param {String} HTML markup
		* @returns the replacement element
		*
		********************************************************/
		setOuterHTML: function(el, html)
		{
			if (typeof el == "string")
				el = document.getElementById(el);

			var newChild = null,
				p = document.createElement("div");

			p.innerHTML = html;
			newChild = p.firstChild;
			if (newChild && el) {
				el.parentNode.replaceChild(newChild, el);
			}

			return newChild;
		},

		/*******************************************************
		* Call a function asynchronously as soon as possible
		*
		* @method nextTick
		* @param {Function} fn function to call back
		*
		********************************************************/
		nextTick: (function() {
			// grabbed from http://www.nonblocking.io/2011/06/windownexttick.html#c3532085861803043211
			var channel = new MessageChannel();
			// linked list of tasks (single, with head node)
			var head = {}, tail = head;
			channel.port1.onmessage = function () {
				var next = head.next;
				var task = next.task;
				head = next;
				task();
			};
			return function (task) {
				tail = tail.next = {task: task};
				channel.port2.postMessage();
			};
		})(),

		getHtmlFromElements: function(elements)
		{
			var clone, children, clonedChildren, element, idx,
				html = [ ];

			if (!elements.hasOwnProperty('length'))
				return getHtmlFromElement(elements);

			for (idx = 0; idx < elements.length; idx++)
				html.push(getHtmlFromElement(elements[idx]));

			return html.join("");

			function getHtmlFromElement(element)
			{
				clone = element.cloneNode(true);

				children = element.getElementsByTagName("*");
				clonedChildren = clone.getElementsByTagName("*");

				Array.prototype.forEach.call(children, function(child, idx) { clonedChildren[idx].style.cssText += getRulesFor(child); });

				clone.style.cssText += getRulesFor(element);

				clone.style.visibility = "visible";
				clone.style.left = 0;
				clone.style.margin = 0;

				if (!clone.querySelector('[data-menu-id]')) {
					clone.dataset.menuId = idx;
				}

				return clone.outerHTML;
			}

			function getRulesFor(element)
			{
				var rules = window.getMatchedCSSRules(element),
					text = "";

				if (rules)
					Array.prototype.forEach.call(rules, function(rule) { text += rule.style.cssText; });

				return text;
			}
		},
		/*
		 * positionMenu will properly align a menu to a given target dom element.  If the menu has a "tail",
		 * the little triangle extension pointing to the target element, it will also align that tail properly
		 * with the right data-tail-pos attribute.
		 * 
		 * To add a tail, just add tail element to your menu. For example: 
		 * 			<div class="menu"> <i class="tail default"></i> </div>
		 * You may need to adjust the position of the tail with your css if necessary.
		 * Params:
		 * @menu: the dom element containing the rendered menu.  There must be a css rule that hide the menu if data-visible != "true"
		 * @elTarget: the target element which the menu will be relatively positioned.
		 * @align: How to align the menu. "vert" will result in the menu be aligned bottom or top of the elTarget
		 * 			"horiz" will result in the menu be aligned left or right of the elTarget
		 * 
		 * Note: Currently the CSS for tail is inside mod-conversation.styl.  if this is used outside, we probably need to move the css 
		 * to the base css file
		 */
		positionMenu: function(menu, elTarget, align, params) {
			if (elTarget && menu) {
				var screenRect = elTarget.getBoundingClientRect(),
				cxWnd = document.body.clientWidth,
				cyWnd = document.body.clientHeight,
				cxMenu = menu.offsetWidth + parseInt(menu.dataset.extrax ? menu.dataset.extrax : 0),
				cyMenu = menu.offsetHeight + parseInt(menu.dataset.extray ? menu.dataset.extray : 0),
				deltaX = parseInt(menu.dataset.deltax ? menu.dataset.deltax : 0),
				spacing = menu.dataset.padding ? parseInt(menu.dataset.padding) : 0,
				tail = menu.querySelector(".tail"),
				fitBot = (screenRect.bottom + cyMenu < cyWnd),
				fitRight = (screenRect.right + cxMenu < cxWnd),
				padding = 10,
				top=0, left=0;

				// Menu is align top/bottom
				if (align == "vert") {
					if (params && params.align == "center")
						left = Math.min(screenRect.left + ((screenRect.width - cxMenu)/2), cxWnd - cxMenu - padding);
					else
						left = Math.min(screenRect.left, cxWnd - cxMenu - padding);
					if (fitBot) {
						top = screenRect.bottom + spacing;
						if (tail) tail.dataset.tailPos = 'bot';
					}
					else {
						top = Math.max(padding, screenRect.top - cyMenu - spacing);
						// if there isn't enough space, we will move it then hide the tail so menu isn't clipped
						// also move the menu to the right so it's doesn't cover the button
						if (top == padding) {
							left += Math.min(screenRect.width, 30) + spacing;
							left = Math.min(cxWnd - cxMenu - padding, left);
							if (tail) tail.dataset.tailPos = "hide";
						}
						else if (tail) tail.dataset.tailPos = 'top';
					}
					if (deltaX) {
						left += deltaX;
					}
					if (tail && left == cxWnd - cxMenu - padding)
						tail.dataset.tailPos = "hide";
					
					if (tail) {
						// We need to also ensure the menu isn't clip
						if (left != screenRect.left)
							tail.style.left = parseInt(screenRect.left - left + screenRect.width/2 - 4) + "px";
						else
							tail.style.left = "";	// clear the style
					}
				}
				// Menu is aligned left/right
				else {
					top = Math.min(screenRect.top, cyWnd - cyMenu - padding);
					if (fitRight) {
						left = screenRect.right + spacing;
						if (tail) tail.dataset.tailPos = 'right';
					}
					else {
						left = Math.max(padding, screenRect.left - cxMenu - spacing);
						// if there isn't enough space, we will move it then hide the tail so menu isn't clipped
						// also move the menu to the bottom a bit so it's doesn't cover the button
						if (left == padding) {
							top += Math.min(screenRect.height, 30) + spacing;
							tail.dataset.tailPos = "hide";
						}
						else if (tail) tail.dataset.tailPos = 'left';
					}
					if (tail) {
						if (top != screenRect.top)
							tail.style.top = parseInt(screenRect.top - top + screenRect.height/2 - 4) + "px";
						else
							tail.style.top = "";	// clear the style
					}
				}
				menu.style.top = parseInt(top) + "px";
				menu.style.left = parseInt(left) + "px";
			}
		},

		getEl: function(elRoot, cssSelector) {
			if (elRoot) {
				return elRoot.querySelector(cssSelector);
			}
		},
		on: function(elRoot, cssSelector, event, cbFunc) {
			var el=null;
			// if the CSS selector is null, we will hook the passed in el
			if (cssSelector === null) {
				el = elRoot;
			}
			else if (elRoot) {
				 el = elRoot.querySelector(cssSelector);
			}
			if (el) {
				el.addEventListener(event, cbFunc);
			}
		},
		off: function(elRoot, cssSelector, event, cbFunc) {
			var el=null;
			// if the CSS selector is null, we will hook the passed in el
			if (cssSelector === null) {
				el = elRoot;
			}
			else if (elRoot) {
				 el = elRoot.querySelector(cssSelector);
			}
			if (el) {
				el.removeEventListener(event, cbFunc);
			}
		},
		sendEvent: function(el, event) {
			if (el) {
				var e = document.createEvent('Event');
				e.initEvent(event, false /* don't bubble */, true);
				el.dispatchEvent(e);
			}
			else {
				console.error("Trying to sendEvent to a null element");
			}

		},
		/* Register predefined events and event handlers with specificied css
		 * events = {
						'css-selector': {
							'event-name': event-handler-function,
							'click': onClick,
						},
						...
					};
		 */
		hookEvents: function(elRoot, events) {
			var el, selector, event;
			for (selector in events) {
				el = elRoot.querySelector(selector);
				for (event in events[selector]) {
					el && el.addEventListener(event, events[selector][event]);
				}
			}
		},
		// Unregister predefined events and event handlers with specificied css
		unhookEvents: function(elRoot, events) {
			var selector, el, event;
			for (selector in events) {
				el = elRoot.querySelector(selector);
				for (event in events[selector]) {
					if (el) {
						el.removeEventListener(event, events[selector][event]);
					}
				}
			}
		},
		getTextVisualWidth: function(elTarget, text) {
			var elTest = document.createElement("span"),
			styles = window.getComputedStyle(elTarget),
			width=0;
			elTest.style.position = "absolute";
			elTest.style.visibility = "hidden";
			elTest.style.height = "auto";
			elTest.style.width = "auto";
			elTest.style.font = styles.font;
			elTest.innerText = text;
			elTarget.appendChild(elTest);
			width = elTest.clientWidth + 1;
			//console.log(text + " width is " + width);
			elTest.remove();
			return width;
		},
		getFont: function() {
			if (!fontFamily) {
				var fonts = ["Helvetica Neue", 
				             "HelveticaNeue-Light", 
				             "Helvetica Neue Light", 
				             "Helvetica", 
				             "Arial", 
				             "Lucida Grande", 
				             "sans-serif"];
				var canvas = document.createElement("canvas");
			    var context = canvas.getContext("2d");
			     
			    // the text whose final pixel size I want to measure
			    var text = "abcdefghijklmnopqrstuvwxyz0123456789";
			     
			    // specifying the baseline font
			    context.font = "72px monospace";
			     
			    // checking the size of the baseline text
			    var baselineSize = context.measureText(text).width;
			    
			    for (var i=0; i < fonts.length; i++) {
				    // specifying the font whose existence we want to check
				    context.font = "72px '" + fonts[i] + "', monospace";
				    // checking the size of the font we want to check
				    if (baselineSize != context.measureText(text).width) {
				    	console.log("Using font: " + fonts[i]);
				    	fontFamily = fonts[i];
				    	break;
				    }
			    }
			    
			    // removing the Canvas element we created
			    delete canvas;
			}
			return fontFamily;
		},
		onClick: function(elRoot, cssSelector, cbFunc) {
			return this.on(elRoot, cssSelector, "click", cbFunc);
		},
		hide: function(el) {
			el.setAttribute("hidden", "");
		},
		show: function(el) {
			el.removeAttribute("hidden");
		},
		toggleShow: function(el) {
			if (el.hasAttribute("hidden")) {
				Caffeine.DomUtils.show(el);
			}
			else {
				Caffeine.DomUtils.hide(el);
			}
		},
		/********************************************************************************************************
		 * Find and extract the data-action attribute from the provided element or it parents (default look up 1 level up)
		 */
		getDataAction: function(el, levelUp) {
			return Caffeine.DomUtils.getDataset(el, "action", levelUp).action;
		},
		/********************************************************************************************************
		 * Find and extract the dataset attribute from the provided element or it parents (default look up 1 level up)
		 */
		getDataset: function(el, key, levelUp) {
			levelUp = levelUp || 1;
			var i = 0, ret = {};
			while (el && i <= levelUp) {
				if (el.dataset && el.dataset[key]) {
					ret.el = el;
					ret.action = el.dataset[key];
					break;
				}
				i++; el = el.parentNode;	// step up
			}
			return ret;
		},
		/********************************************************************************************************
		 * Convert a URI into an URL that can be referenced in an element
		 */
		dataURItoUrl: function(dataURI, type) {
			// Convert data URI into a Blob
			if (!type)
				type = 'image/png';
			var binary, dataAr = dataURI.split(','), data = (dataAr.length == 1 ? dataURI : dataAr[1]);	// If the data is already splitted up no need to do it again
		    var binary = atob(data),
		    array = [], blob, url;
		    for(var i = 0; i < binary.length; i++) {
		        array.push(binary.charCodeAt(i));
		    }
		    blob = new Blob([new Uint8Array(array)], {type: type});

            url = webkitURL.createObjectURL(blob);
            return url;
		},
		/*******************************************************
		* Blurs image using canvas
		*
		* @method blurImage
		* @param {String} id of image to blur
		* @param {String} id of canvas
		* @destEl {HTMLElement} destination element
		* @return {Boolean} true if the image was blurred
		*
		********************************************************/
		blurImage: function(url, destEl, onSuccessCB, radius) {
			var image = new Image();
				radius = radius || 44;

			image.onload = function() {
				var canvas = document.createElement("canvas");
				stackBlurImage(image, canvas, radius, false);
	            if (image.width) {
					if (destEl) {
		                url = canvas.toDataURL("image/jpeg");
	                    destEl.style.background = "url("+url+") repeat scroll 50% 50% / cover transparent";
	                }
					
	                if (onSuccessCB) {
	                	onSuccessCB(url);
	                }
	            }
			};
			if (Caffeine.appMode.mock && url.indexOf("http://") == 0) {
				image.src = "/tools/proxy.php/" + url;
			}
			else {
				image.src = url;
			}
		},
		/*******************************************************
		 * Take a RGB color and return the full CSS compatible string RGB(123,10,24,0.3)
		 *
		 * @method getRGBstring
		 * @param {Array} array of [R,G,B] values of the main color
		 * @param {Int} alpha value
		 */
		getRGBstring: function (rgb, alpha) {
			alpha = alpha || 1;
			return ["rgba(",rgb.join(","), ", ", alpha, ")"].join("");
		},

        /*******************************************************
         * Take a DOM element and remove the attribute from itself and every ancestor.
         *
         * @method removeAttrFromTree
         * @param {HTMLElement} root element
         * @param {String} attribute to be removed
         * @param {String} {Optional} value that attribute to be removed is equal to.
         * @return {Array} array of elements that the attribute was removed from
         */
        removeAttrFromTree: function (el, attr, val){
            var retEls = [],
                sel = val ? '[' + attr + '=\"' + val + '\"' + ']' : '[' + attr + ']';

            if(!(el && el.getAttribute && attr))
                return [];

            try {
                //Check the root node for attribute or attr = val
                if((el.getAttribute(attr) && !val) || (el.getAttribute(attr) == val)) {
                    retEls.push(el);
                    el.removeAttribute(attr);
                }
                //Create an Array from the NodeList returned by querySelectorAll
                retEls = Array.prototype.slice.call(el.querySelectorAll(sel), 0);

                retEls.forEach(function(element, index){
                        element.removeAttribute(attr);
                });
            } catch (e) {
                console.log(e);
                return [];
            }
            return retEls;
        }
	};
 })();
