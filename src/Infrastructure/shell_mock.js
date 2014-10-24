/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

/******************************************************************************
 * This module contains a mock implementation of the desktop interface.
 * The real implementation is going to be provided by the native shell.
 *****************************************************************************/

(function(){

var nextBlankId = 1,
	inCreate,
	poppingWindows = [ ];
	
// The interface is exported as Caffeine.Desktop.
/**
 * @module Infrastructure
 * @namespace Caffeine
 * @class Desktop
 * @static
 */

Caffeine.Desktop =
{
	init: function(parms, cb)
	{
		Caffeine.Bootstrap.loadSources(parms, function()
			{
				Caffeine.Init(parms, cb);
			});
	},

	/******************************************************************************
	 * Create a modal window.
	 *
	 * @method modalWindow
	 * @param {Object} parms	Initialization parameters for the new window.  This
     *							object will be passed to the window's Init() function.
	 * @param {function} cb		A function that gets called when the window calls
     *							closeWindow() on itself.
	 *****************************************************************************/
	modalWindow: function(parms, cb)
	{
		parms.target = parms.target || "_modalWindow";

		parms.left = Math.min(parms.left, window.innerWidth - parms.width);
		parms.top  = Math.min(parms.top, window.innerHeight - parms.height);

		var frame = document.createElement("IFRAME");
		frame.id = parms.target;
		frame.style.position = "fixed";
		frame.style.zIndex = 10;
		frame.style.backgroundColor = parms.backgroundColor || "white";
		frame.style.width = parms.width;
		frame.style.height = parms.height;
		frame.style.left = parms.left;
		frame.style.top = parms.top;

		document.body.appendChild(frame);

		return initializeWindow(frame.contentWindow, parms, cb);
	},

	/******************************************************************************
	 * Close a popup or modal window
	 *
	 * @method closeWindow
	 * @param {Object} parms	An object that will be passed to the opener's callback
	 *							function.
	 *****************************************************************************/
	closeWindow: function(parms)
	{
		win = Caffeine.CEFContext.getWindow(parms.target);

		if (win == window.top)
			win.close();
		else
		{
			var p = win.parent,
				el = p.document.getElementById(parms.target);

			p.document.body.removeChild(el);
		}

		Caffeine.Desktop.windowClosed(parms.target);
	},
	
	windowClosed: function(target) {
	    Caffeine.CEFContext.unregisterWindow(target);
	    Caffeine.IPC.windowClosed(target);
	},

	/******************************************************************************
	 * Create a non-modal popup window.
	 *
	 * @method popupWindow
	 * @param {Object} parms	Initialization parameters for the new window.  This
     *							object will be passed to the window's Init() function.
	 * @param {function} cb		A function that gets called when the window calls
     *							closeWindow() on itself.
	 *****************************************************************************/
	popupWindow: function(parms, cb)
	{
		// You might be opening a new window
		// or you might be targetting code in an existing window

		var win, id,
			wndSizes = Caffeine.preferences.windows.sizes,
			features = [];

		if (inCreate)
		{
			poppingWindows.push([ Caffeine.Desktop.popupWindow, parms, cb ]);
			return;
		}
		inCreate = 1;

		parms.target = parms.target || "_default";

		if (parms.target == '_blank')
			parms.target = "UnnamedWindow" + (nextBlankId++);

		if (!parms.width || !parms.height)
		{
			size = wndSizes[parms.target] || wndSizes.default;
			
            if (size.left)
				parms.left = size.left;
            if (size.top)
				parms.top = size.top;

			parms.width = size.width;
			parms.height = size.height;
		}

		win = Caffeine.CEFContext.getWindow(parms.target);

		if (win)
		{
			id = parms.target;
			win.Caffeine.Bootstrap.loadSources(parms, function()
				{
					if (Caffeine.IPC.id == id)
						Caffeine.Init(parms, creationComplete);
					else
						Caffeine.IPC.remoteCall(id, "Caffeine.Init", parms, creationComplete);
				});
		}
		else
		{
			features.push("status=no,location=no,menubar=no,toolbar=no");

			if (parms.left !== undefined)
				features.push("left=" + parms.left);
			if (parms.top !== undefined)
				features.push("top=" + parms.top);
			if (parms.width)
				features.push("width=" + parms.width);
			if (parms.height)
				features.push("height=" + parms.height);

			win	= window.open("about:blank", parms.target, features.join(","));
			win.document.title = parms.title;

			id = initializeWindow(win, parms, creationComplete);
		}

		return id;

        function creationComplete()
        {
			Caffeine.IPC.remoteCall(id, 'Caffeine.Desktop.showWindow');
			inCreate = 0;
			cb && cb.apply(this, arguments);
			var next = poppingWindows.pop();
			if (next)
				next[0](next[1], next[2]);
        }
	},
	createDockedWindow: function(parms, cb) {
		cb && cb();
	},
	hideWindow: function(parms, cb)
	{
	},
	showWindow: function(parms, cb)
	{
	},
	startFlashing: function(parms, cb)
	{
	},
	stopFlashing: function(parms, cb)
	{
	},
	setTransparency: function(parms, cb)
	{
	},
    activateWindow: function() {
        self.focus();
    },
    hasFocus: function() {
        return document.hasFocus();
    },
    setUserAgent: function(user_agent) {
    },
    setFeedbackLink: function() {
    },
    setPrefixMapping: function(oldPrefix, newPrefix) {
    },
	closeChildWindows: function(parms, cb) {
		return false;
	},
	forceCloseWindow: function(target) {
		return false;
	},
	createToastWindow: function(parms, cb) {
	},
	showToast: function(parms, cb) {
	},
	getIpcId: function(param) {
	},
	setDownloadPath: function(param) {
	}
};

(function()
{
	var width, top, bottom, minTop, minBottom, dockedTo;
	
	Caffeine.Desktop.dockedWindow = function(parms, cb)
	{
		width		= parms.width || 100;
		top			= parms.top || 0;
		bottom		= parms.bottom || 0;
		minTop		= parms.minTop || 20;
		minBottom	= parms.minBottom || 20;
		dockedTo	= parms.dockedTo || 'main';

		if (inCreate)
		{
			poppingWindows.push([ Caffeine.Desktop.dockedWindow, parms, cb ]);
			return;
		}

		var id = Caffeine.Desktop.popupWindow(parms, cb),
			win = Caffeine.CEFContext.getWindow(parms.target),
			dockedTo = Caffeine.CEFContext.getWindow(parms.dockedTo),
			timer = setInterval(moveWindow, 50);

		function moveWindow()
		{
			try
			{
				var newLeft, newTop, newBottom;

				newLeft = dockedTo.screenX - width;
				if (dockedTo.screenX > dockedTo.screen.width)
					newLeft -= dockedTo.screen.width;

				newTop = top;
				if (top < 0)
					newTop += dockedTo.outerHeight;
				newTop = Math.min(newTop, minTop);
				newTop += dockedTo.screenY;

				newBottom = -bottom;
				if (bottom >= 0)
					newBottom += dockedTo.outerHeight;

				newBottom = Math.min(newBottom, dockedTo.outerHeight - minBottom);

				newBottom += dockedTo.screenY;

				win.moveTo(newLeft, newTop);
				win.resizeTo(width + (win.outerWidth - win.innerWidth), newBottom - newTop + (win.outerHeight - win.innerHeight));
			}
			catch (e)
			{
				clearInterval(timer);
			}
		}
	}

	Caffeine.Desktop.resize = function(parms, cb)
	{
		width		= parms.width || width;
		top			= parms.top || top;
		bottom		= parms.bottom || bottom;
		minTop		= parms.minTop || minTop;
		minBottom	= parms.minBottom || minBottom;

		if (parms.height)
			bottom = -(top + parms.height);

		cb && cb();
	}
})();

function initializeWindow(win, parms, cb)
{
	var name, el, id,
		i = 0,
		inject	= [ '/src/Infrastructure/modules.js', '/src/Infrastructure/bootstrap.js' ];

	win.IPC_id = id	= Caffeine.CEFContext.registerWindow(win, parms.target);
	Caffeine.IPC.windowOpened(id);

	win.Caffeine = { appMode: { } };

	parms.preferences = Caffeine.preferences;
	
	for (name in Caffeine.appMode)
		win.Caffeine.appMode[name] = Caffeine.appMode[name];
	win.Caffeine.appMode.master = 0;
	win.Caffeine.appMode.slave  = 1;
	// experimental locale-passing
	win.Caffeine.appMode.locale = Caffeine.appMode.locale;

	// adjust base path
	var elt = document.createElement("BASE");
	elt.href = location.origin;
	win.document.head.appendChild(elt);

	injectCode();

	function injectCode()
	{
		el = win.document.createElement("SCRIPT");
		el.onload = function()
					{
						var name;

						i++;
						if (i < inject.length)
							injectCode();
						else
                        {
//                            win.addEventListener('beforeunload', function (event) {
//                                console.log('injected before onload handler');
//                                win.Caffeine.Desktop.windowClosed(win.IPC_id);
//                            });
                            
                            for (name in Modules)
                            {
								if (!win.Modules[name])
									win.Modules[name] = Modules[name];
                            }

							win.Caffeine.Bootstrap.loadSources(parms);
                        }
					};

		el.src = document.location.origin + inject[i];
		win.document.head.appendChild(el);
	}

	Caffeine.IPC.remoteCall(id, "Caffeine.Init", parms, cb);

	return id;
}

})();
