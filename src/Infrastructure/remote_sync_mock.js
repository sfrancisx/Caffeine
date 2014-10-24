/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function() {

"use strict";

Caffeine.CEFContext =
{
	sendIPC:		sendIPC
};

var sendTo = opener || window.parent;

function sendIPC(target, o, from)
{
	setTimeout(function()
		{
			o = escape(o);
			sendTo.Caffeine.IPC.onReceiveMessage(Caffeine.IPC.id, o);
		}, 0);
}

})();
