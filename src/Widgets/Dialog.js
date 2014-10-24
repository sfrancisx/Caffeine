/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function() {
"use strict";

	Caffeine.Ctrls = Caffeine.Ctrls || {};

/**
 * Dialog control which displays an inline dialog on the current window. 
 * Supports 
 *	* Close on esc key
 *	* html or template
 *
 * @module Widgets
 * @namespace Caffeine.Ctrls
 * @class Dialog
 * @constructor
 * @params {parms} Object which defines the dialog
 *	
 * - parms.parent The container dom element to which the dialog will be added. By default it is document.body
 *
 * - parms.title [Optional] title for the dialog
 * - parms.html [Optional] html content of the dialog. This is optional if "data" and "template" properties are available
 * - parms.template [Optional] dust template for the content of the dialog. This is optional if "html" property is present.
 * - parms.data [Optional] data for the template. This is optional if "html" property is present.
 *
 * - parms.buttons [Optional] Array of buttons for the dialog
 * - - parms.buttons[i].name unique id for the button
 * - - parms.buttons[i].label label of the button
 * - - parms.buttons[i].click click handler for the button
 * - - parms.buttons[i].focus indicates whether the button is focused when the dialog launches
 *
 * - parms.click click handler for elements with data-action attribute
 *
 * - parms.onClose callback method which will be called when the dialog is closed
 *
 * - parms.cb callback method which will be called after the dialog is created. THe callback is called with an argument which is dialog instance * 
 * Instance methods
 * - close closes the dialog
 *
 * Example
 * Caffeine.Ctrls.Dialog( { 
 *		data: msg, 
 *		template: "FormattedMessage",
 *		buttons: [
 *			{
 *				name: "OK",
 *				label: "{str_confirmation_close}",
 *				click: function() {
 *					this.close();
 *					...
 *				}
 *			},
 *			{
 *				name: "Cancel",
 *				label: "{str_confirmation_cancel}",
 *				focus: true,
 *				click: function() {
 *					this.close();
 *				}
 *			}
 *		],
 *		onClose: function() {
 *			windowClosing = 0;
 *			windowConfirm = 0;
 *		}
 *	} );
 *
 */
 
	var count = 0;

	Caffeine.Ctrls.Dialog = function(parms, cb) {
		var parentEl = parms.parent || document.body,
			onClose = parms.onClose,
			container = document.createElement("div"),
			registrar = Ether.getRegistrar(),
			dialog, instance, tmpObj;

		tmpObj = {
			title: parms.title,
			html: parms.html,
			template: parms.template,
			data: parms.data,
			buttons: parms.buttons,
			count: ++count
		};

		instance = {
			close: function() {
				onClose && onClose();
				registrar.cleanup();
				dialog.remove();
				parentEl.classList.remove("dialog-displayed");
			}
		};

		Caffeine.Template.renderInto("Dialog", tmpObj, container);

		dialog = container.firstChild;

		parentEl.appendChild(dialog);
		parentEl.classList.add("dialog-displayed");
		
		dialog.focus();

		bind(dialog, parms, registrar, instance);

		cb && cb(instance);

	};

	function bind(dialog, props, registrar, instance) {
		var buttons = props.buttons,
			bodyClickHandler = props.click,
			closeBtn = dialog.querySelector("div > section > button.dialog-close"),
			bodyBindClickHandler,
			bLen, index = 0, button,
			bDict, 
			bEls, bElLen, bEl,
			bObj, clickHandler;

		if(buttons && (bLen = buttons.length)) {
			
			bDict = {};
			for(; index < bLen; index++) {
				button = buttons[index];
				bDict[button.name] = button;
			}

			bEls = dialog.querySelectorAll(".buttons button");
			bElLen = bEls.length;

			for(index = 0; index < bElLen; index++) {
				bEl = bEls[index];
				bObj = bDict[bEl.getAttribute("data-name")];
				
				if(bObj) {
					clickHandler = bObj.click;
					if(typeof clickHandler === "function"){
						registrar.addEventListener(bEl, "click", clickHandler.bind(instance));
					}
					
					if(bObj.focus) {
						bEl.focus();
					}
				}
			};
		}

		registrar.addEventListener(dialog, "keydown", function(e) {
			if (e.keyIdentifier == "U+001B") {
				e.stopPropagation();
				instance.close();
			}
		});

		if(closeBtn) {
			registrar.addEventListener(closeBtn, "click", function() {
				instance.close();
			});
		}

		if(bodyClickHandler && (typeof bodyClickHandler === "function")) {
			bodyBindClickHandler = bodyClickHandler.bind(instance);
			registrar.addEventListener(dialog, "click", function(e) {
				var btnCont = dialog.querySelector(".buttons"),
					srcEl = e.target;

				if(btnCont && btnCont.contains(srcEl)) {
					return;
				}

				if(srcEl.getAttribute("data-action")) {
					bodyBindClickHandler(e);
				}

			});
		}
			
	}

})();
