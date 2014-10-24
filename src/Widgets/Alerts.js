/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function() {

	"use strict";

	/**
	* Global alert or message control which displays the message in an overlay on top of the UI
	* 
	* @module Widgets
	* @namespace Caffeine.Ctrls
	* @method Caffeine.Ctrls.Alert
	*
	* @param {Object} parms
	* - parms.msg Alert message
	**/

	function displayAlert(parms) {
		var msg = parms.msg,
			divEl = document.createElement("div"),
            timeout = parms.timeout || 5000;
		
		divEl.appendChild(document.createTextNode(msg));

		if (parms.notError) {
			divEl.className = "globalAlert";
		}
		else
			divEl.className = "globalAlert error";
		divEl.style.webkitAnimationDuration = timeout/1000 + "s";

		document.body.appendChild(divEl);

		setTimeout(function() {
		    document.body.removeChild(divEl);
		}, timeout);
	}

	if(!Caffeine.Ctrls) {
		Caffeine.Ctrls = {};
	}
	Caffeine.Ctrls.Alert = displayAlert;

})();
