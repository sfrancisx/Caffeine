/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

"use strict";

(function() {

var windows = { };

Caffeine.CEFContext =
{
	registerWindow:     registerWindow,
	unregisterWindow:   unregisterWindow,
	getWindow:          getWindow,
	sendIPC:            sendIPC
};

Caffeine.CEFContext.registerWindow(window, Caffeine.IPC.id);

function registerWindow(win, name)
{
	windows[name] = win;

	return name;
}

function unregisterWindow(name)
{
	windows[name] = null;
}

function getWindow(name)
{
	return windows[name];
}

function sendIPC(to, o, from)
{
//	setTimeout(function()
//		{
			o = decodeURIComponent(escape(atob(o)));
			if (!to) { 
				console.error("bad sendIPC call!");
				console.log("Cannot send IPC message to unkonwn remote target", o);
			}
			windows[to].Caffeine.IPC.onReceiveMessage(null, o);
//		}, 0);
}

})();
