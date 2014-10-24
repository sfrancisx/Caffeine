/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

'use strict';

/* global IPC_id, alert */

window.Caffeine = window.Caffeine || { };
Caffeine.appMode = Caffeine.appMode || { };
Caffeine.Desktop = Caffeine.Desktop || { };
Caffeine.windowId = window.IPC_id || 'main';

var active, windowClosing, onBootstrap, loading, initReported, forceClose, windowConfirm, appShutdown,
	appMode			= Caffeine.appMode,
	loadQueue		= [ ],
	bootstrapIntf	= getPassthruIntf(),
	pendingTasks	= 0,
	namedTasks		= [ ];

Caffeine.closing = 0;

Caffeine.addPendingTask = function(name)
{
	pendingTasks++;
	if (name)
		namedTasks.push(name);
};

Caffeine.pendingTaskDone = function(name)
{
	pendingTasks--;
	if (name)
	{
		var idx = namedTasks.indexOf(name);
		if (idx == -1)
			console.error("Can't find pending task: " + name);
		else
			namedTasks.splice(idx, 1);
	}

	if (!pendingTasks && Caffeine.closing) {
		console.log("WClose: calling window close by pendingTaskDone");
		window.close();
	}
};

Caffeine.showPendingTasks = function()
{
	console.error('Named pending tasks: ' + namedTasks.join(', '));
};

/**
 * This is the standard interface used for communication between parent & child components.
 * The interface is bi-directional.  For the most part, functions on the interface are used
 * for the child to request something of the parent.  The parent notifies the child that
 * something happened by firing an event.  (The exceptions to this pattern are `serialize()`
 * and `deserialize()`, which are called by the parent to get/put data from/to the child.)
 *
 * The standard methods on the object are:
 *
 *		alert
 *		satisfied
 *		activate
 *		show
 *		hide
 *		resize
 *		setTitle
 *		close
 *		idle
 *		active
 *		serialize
 *		deserialize
 *
 * In addition to the standard methods, there are some standard events which might be fired by
 * the parent.  These are:
 *
 *		activated
 *		deactivated
 *		closing
 *		resized
 *
 * If you don't care about any of this stuff, you can get a pass-through interface with
 * `Caffeine.getPassthruIntf()`.  The returned interface will usually do the right thing.
 * You can modify the passthru interface after getting it for any special case behavior.
 * (Any time you want special behavior, you should get a passthru interface and then modify
 * it.)
 *
 * The process of closing a component deserves special mention.  Normally, components are
 * expected to close themselves in response to a closing event.  A component closes itself by:
 *
 *	a) Firing a `closing` event to all of its children,
 *	b) doing normal clean up (detaching event handlers, removing itself from the DOM, etc.),
 *	c) Waiting for all its children to close() themselves
 *	d) calling close() on the interface given to it by its parent.
 *
 * If you can close synchronously, the passthru interface will handle it for you.  Just add an
 * event listener for the 'closing' event and clean yourself up.  If you can't close synchronously
 * things are a little more complex because you'll have to override the passthru interface's
 * handling of the `close()` method and/or the `closing` event.  See the documentation for
 * `getPassthruIntf()` for details.
 *
 * You should be able to use this interface object for any parent/child communication.  Components
 * can add methods or events freely.
 *
 * @class intf
 * @static
 */
bootstrapIntf.name = 'bootstrap';
/**
 * Ask my parent to get the user's attention for me
 *
 * @method alert
 * @param {String} urgency		'signal', 'warn', 'alarm'
 *
 * * 'signal': Signal the user.  Mildest form of getting attention.
 *             Example: Message received in existing tab.  Flash the tab and/or
 *             the window.
 * * 'warn':   Signal the user, more insistently.
 *             Example: Message received by a new tab.  Bring the window to the front,
 *             activate the tab.
 * * 'alarm':  Signal the user, most insistently.
 *             Example: Network connection lost.  Pop up a dialog.
 */
bootstrapIntf.alert = function(urgency)
{
	if (!Caffeine.Desktop.hasFocus())
	{
		//document.title = "flashing";
		if (urgency == 'signal') 
        {
			Caffeine.Desktop && Caffeine.Desktop.startFlashing();
        }
		else
        {
			Caffeine.Desktop && Caffeine.Desktop.activateWindow();
        }
	}
};

/**
 * Tell my parent that I'm satisfied with the attention I got.
 *
 * @method satisfied
 */
bootstrapIntf.satisfied = function()
{
	//document.title = "not flashing";
	Caffeine.Desktop && Caffeine.Desktop.stopFlashing();
};

/**
 * Ask my parent to activate me.
 * Example: I don't know...  The alert seems sufficient
 * @method activate
 */
bootstrapIntf.activate = function()
{
	Caffeine.Desktop && Caffeine.Desktop.activateWindow();
};

/**
 * Ask my parent to show me
 * @method show
 */
bootstrapIntf.show = function()
{
	if (!Caffeine.closing)
		Caffeine.Desktop.showWindow();
};

/**
 * Ask my parent to hide me.
 * @method hide
 */
bootstrapIntf.hide = function()
{
	Caffeine.Desktop.hideWindow();
};

/**
 * Ask my parent to resize me
 * @method resize
 * @param {int} width
 * @param {int} height
 */
bootstrapIntf.resize = function(parms)
{
	Caffeine.Desktop.resize(parms);
};

/**
 * Ask my parent to set my title
 * @method setTitle
 * @param {string} title
 */
bootstrapIntf.setTitle = function(title)
{
	document.title = title;
};

/**
 * Ask my parent to close me
 * @method close
 */
bootstrapIntf.close = function(parms)
{
	if (!appMode.mock) {
		var parmShutdown = parms && parms.appShutdown;
		if (!windowClosing || parmShutdown) {
			if(parmShutdown) {
				appShutdown = true;
				if(Ether.Event) {
					Ether.Event.fire(Caffeine, "appshutdown");
				}
			}
			console.log("WClose:" + (appMode.master ? "master" : "slave") + ":" + IPC_id + " window close called by bootstrap close");
			window.close();
		} else {
			console.log("WClose:" + (appMode.master ? "master" : "slave") + ":" + IPC_id + " bootstrap close called and ignored");
		}
	}
};

/**
 * I've gone idle
 * Example: A conversation tab says it's idle.  The parent could
 * remove its the tab's content from the DOM to improve performance
 * (the cost would be slower switching to the tab.)
 * @method idle
 */
bootstrapIntf.idle = function() { };

/**
 * I'm no longer idle.
 * @method active
 */
bootstrapIntf.active = function() { };

/**
 * checks whether the intf is active or not
 */
bootstrapIntf.isActivated = function() { return active; };

/**
 * show inline dialog
 * @method dialog
 */
bootstrapIntf.dialog = function(parms) {
	if(Caffeine.Ctrls && Caffeine.Ctrls.Dialog) {
		Caffeine.Ctrls.Dialog(parms);
	}
};

/**
 * Serialize yourself.
 * This method should be implemented by the child.
 * @method serialize
 */
/**
 * Deserialize yourself.
 * This method should be implemented by the child.
 * @method deserialize
 */
/**
 * Fired by parent when the child is activated.
 * @event activated
 */
/**
 * Fired by parent when the child is deactivated.
 * @event deactivated
 */
/**
 * Fired by parent to notify the child it should close.
 * The child is expected to call `close()` as soon as possible in response to
 * this event.
 * @event closing
 */
/**
 * Fired by parent to notify the child that it has been resized.
 * @event resized
 */
(function()
{
	window.onerror = function(message, filename, linenumber, retryNum)
	{
		retryNum = retryNum || 0;
		if (retryNum == 3)
			return;

		// Strip out the root directory (I hope...)
		filename = filename.split('/src/');
		filename = filename[filename.length-1];
		filename = filename.split('/shelf/');
		filename = filename[filename.length-1];
		
		if (appMode.debug)
			alert('Unhandled exception: ' + message + ' at ' + filename + ':' + linenumber);

		if (Caffeine.Stats)
		{
			console.error('Unhandled exception: "' + message + '" at ' + filename + ':' + linenumber);
			
			Caffeine.Stats.fire(
				{
				    category:    'Error',
                    subcategory: 'Bootstrap',
					name:		 'UnhandledException',
					message:	 message,
					filename:	 filename,
					linenumber:	 linenumber
				});
		}
		else
		{
			setTimeout(function()
				{
					window.onerror(message, filename, linenumber, retryNum+1);
				}, 5000);
		}
	};
	
	window.addEventListener('activated', function()
	{	
		var modalWindowStore = Caffeine.modalWindowStore,
			modalId = modalWindowStore && modalWindowStore.id;
		if(modalId && modalId != window.IPC_id) {
			//modal window is open
			if(appMode.master) {
				Caffeine.ModalHelper.activate({ modalId: modalId });
			} else {
				Caffeine.IPC.remoteCall("main", "Caffeine.ModalHelper.activate", { modalId: modalId } );
			}

			return;
		}

		if(!windowConfirm) {
			raiseActivationEvent();
		}
	}, true);

	function raiseActivationEvent(force) {
		if(!active || force) {
			active = 1;
			Ether.Event && Ether.Event.fire(bootstrapIntf, 'activated');
			document.body.classList.remove("deactivated");
		}
	}

	window.addEventListener('deactivated', function()
	{
		if(active) {
			active = 0;
			Ether.Event && Ether.Event.fire(bootstrapIntf, 'deactivated');
			document.body.classList.add("deactivated");
		}
	}, true);
		
	// used window.onbeforeunload because addEventListener for beforeunload does not cancel the unloading	
	window.onbeforeunload = function() {
		console.log("WClose:" + (appMode.master ? "master" : "slave") + ":" + (window.IPC_id || "")  + " onbeforeunload handler triggered.");
		var res = bootstrapCloseCheck();

		if (!res && Caffeine.Desktop.windowClosed)
		{
			// We've decided not to cancel the close.  Note
			// that this can still happen multiple times, since
			// JS will continue executing for a short while.
			// We could move this to an 'unload' handler, but
			// (a) I don't know if it's any better, and
			// (b) we actually depend on some JS executing
			//     in remote windows.
			Caffeine.Desktop.windowClosed(Caffeine.IPC.id);
		}

		return res;
	};

	window.addEventListener('resize',
		function(/*e*/)
		{
			Ether.Event && Ether.Event.fire(bootstrapIntf, 'resized');
		});

	window.addEventListener("startIdle", function() {
		Ether.Event && Ether.Event.fire(bootstrapIntf, "startIdle");
	});

	window.addEventListener("stopIdle", function() {
		Ether.Event && Ether.Event.fire(bootstrapIntf, "stopIdle");
	});

	window.addEventListener("os:locked", function() {
		Ether.Event && Ether.Event.fire(bootstrapIntf, "locked");
	});

	window.addEventListener("os:unlocked", function() {
		Ether.Event && Ether.Event.fire(bootstrapIntf, "unlocked");
	});

    document.addEventListener('dragover', function(e) {
        e.preventDefault();
    });

    document.addEventListener('drop', function(e) {
        e.preventDefault();
    });

	function bootstrapCloseCheck(nocheck)
	{
		var chkResult, msg,
			desktop = Caffeine.Desktop;

		if(windowConfirm && !appShutdown) {
			return cancelWindowClose();
		}

		windowClosing = !nocheck ? 1 : windowClosing;

		//close child windows
		if(appMode.master && desktop.closeChildWindows && desktop.closeChildWindows(null, closeChildWindowsCB)) {
			console.log("WClose: cancelling main window close and closing child windows");
			desktop.hideWindow(Caffeine.IPC.id);
			return cancelWindowClose();
		}

		chkResult = !nocheck && !appShutdown && bootstrapIntf.closeCheck();

		if(chkResult && chkResult.returnValue === false) {
			msg = processMessage(chkResult.message);
			if(msg) {
				showCloseConfirmDialog(msg);		
			} else {
				windowClosing = 0;
			}
			
			return cancelWindowClose();
		}

		Ether.Event && Ether.Event.fire(bootstrapIntf, 'closing');
		windowClosing = 0;

		if (bootstrapIntf.opened.length) 
		{
			return cancelWindowClose();
		} else
		{
			if (desktop.windowClosed)
			{
				try {
					if(!Caffeine.closing) {
						Ether.Event && Ether.Event.fire(Caffeine, "windowclose");
					}
				}catch(e){console.error(e);}

				Caffeine.closing = 1;

				if (!forceClose && pendingTasks)
				{
					// Caffeine.showPendingTasks();

					desktop.hideWindow(Caffeine.IPC.id);
					setTimeout(function()
						{
							console.log("WClose: Force closing the window after 5 seconds");
							forceClose = 1;
							window.close();

						}, 5000);
					
					console.log("WClose: Executing  " + pendingTasks + " pending tasks");
					return cancelWindowClose();
				}
			}
		}

		console.log("WClose:" + (appMode.master ? "master" : "slave") + ":" + (window.IPC_id || "")  + " onbeforeunload handler completes without cancellation.");

	}

	function showCloseConfirmDialog(msg) {
		var notConfirmed = true;
		try{
			windowConfirm = 1;

			bootstrapIntf.dialog( { 
				data: msg, 
				template: "FormattedMessage",
				buttons: [
					{
						name: "OK",
						label: "{str_confirmation_close}",
						secondary: true,
						click: function() {
							notConfirmed = false;
							this.close();
							bootstrapCloseCheck(true);
						}
					},
					{
						name: "Cancel",
						label: "{str_confirmation_cancel}",
						focus: true,
						click: function() {
							this.close();
						}
					}
				],
				onClose: function() {
					windowClosing = 0;
					windowConfirm = 0;
					if(notConfirmed) {
						raiseActivationEvent(true);
					}
				}
			} );

			if(!active) {
				Caffeine.CEFContext && Caffeine.CEFContext.activateApp();
			}

		} catch(e) {
			windowClosing = 0;
			windowConfirm = 0;
			console.log(e);
		}
	}

	function cancelWindowClose() {
		appShutdown = false;
		return "wait...";
	}

	function closeChildWindowsCB() {
		windowClosing = 0;
		bootstrapIntf.close();
	}
})();

Caffeine.Init = function(parms, cb)
{
	var modalWindowStore = parms.modalWindowStore;

	if (parms.preferences && (Caffeine.preferences != parms.preferences))
	{
		parms.preferences.set = Caffeine.preferences.set;
		parms.preferences.setPerUser = Caffeine.preferences.setPerUser;
		Caffeine.preferences = parms.preferences;
	}

	if(modalWindowStore && (Caffeine.modalWindowStore != modalWindowStore) && Caffeine.ModalHelper) {
		Caffeine.modalWindowStore = modalWindowStore;
		Caffeine.ModalHelper.bind({ modalStore: modalWindowStore });
	}
		
	function continueLoading()
	{
		var initFn = Caffeine.Bootstrap.getInitFn(parms),
			mod = parms.module;

		if (parms.target)
			Caffeine.windowId = parms.target;

		parms = parms.moduleParms || { };

		parms.parent	= parms.parent || document.body;
		parms.intf		= Caffeine.getPassthruIntf(bootstrapIntf);
		parms.intf.name = "top level module " + bootstrapIntf.opened.length + " (pasthru for " + mod + ')';

		initFn && initFn(parms, cb);
		initFn || (cb && cb());

		Ether.Event.fire(parms.intf, "displayed");
	}

	Caffeine.continueLoading = function()
	{
		document.body.innerHTML = '';
		continueLoading();
	};

	if (!appMode.wait || Caffeine.alreadyInited)
		continueLoading();
	else
	{
		Caffeine.Desktop.showWindow();
		Caffeine.alreadyInited = 1;
		document.body.innerHTML = '<button onclick="Caffeine.continueLoading()">Continue</button>';
	}
};

/**
 * @method getPassthruIntf
 *
 * Get a pass-thru interface.  This interface will just pass method calls and events to parents
 * or children, as appropriate.
 */
function getPassthruIntf(intf)
{
	var name;
	
	intf = intf || bootstrapIntf;
	
	var passEventsToChild =
		{
			displayed: function()
			{
				newIntf.opened.forEach(fireDisplayedOnChildIntf);
			},
			nondisplayed: function()
			{
				newIntf.opened.forEach(fireNonDisplayedOnChildIntf);
			},
			activated: function()
			{
				newIntf.opened.forEach(fireActivatedOnChildIntf);
			},
			deactivated: function()
			{
				newIntf.opened.forEach(fireDeActivatedOnChildIntf);
			},
			closing: function()
			{
				// Make a copy of my children before iterating over them.  They may close themselves,
				// changing the array indexes of subsequent children.
				var copy = newIntf.opened.concat();

				Ether.Event.once(newIntf,
					{
						closing: function()
						{
							if ((!intf || (intf.opened.indexOf(newIntf) != -1)) && !newIntf.opened.length)
								newIntf.close();
						}
					});

				copy.forEach(closingOnChildIntfBinder);
			},
			resized: function()
			{
				newIntf.opened.forEach(fireResizedOnChildIntf);
			},
			startIdle: function() {
				newIntf.opened.forEach(fireStartIdleOnChildIntf);
			},
			stopIdle: function() {
				newIntf.opened.forEach(fireStopIdleOnChildIntf);
			},
			locked: function() {
				newIntf.opened.forEach(fireLockedOnChildIntf);
			},
			unlocked: function() {
				newIntf.opened.forEach(fireUnlockedOnChildIntf);
			}
		},
		newIntf =
		{
			alert: function(urgency)
			{
				if (intf.alerting[urgency].indexOf(newIntf) == -1)
					intf.alerting[urgency].push(newIntf);
				sendAlert(intf, newIntf);
			},
			satisfied: function()
			{
				removeFromAlerting('signal', intf, newIntf);
				removeFromAlerting('warn', intf, newIntf);
				removeFromAlerting('alarm', intf, newIntf);

				sendAlert(intf, newIntf);
			},
			activate: function(urgency)
			{
				return intf.activate(urgency);
			},
			show: function()
			{
				return intf.show();
			},
			hide: function()
			{
				return intf.hide();
			},
			resize: function(parms)
			{
				return intf.resize(parms);
			},
			setTitle: function(title)
			{
				return intf.setTitle(title);
			},
			closeCheck: closeCheck,
			close: function()
			{
				newIntf.satisfied();
				
				var idx = intf.opened.indexOf(newIntf);
				if (idx == -1)
					throw "This component was already closed.";

				Ether.Event.fire(newIntf, "closed");
				//setTimeout(function() { Ether.Event.off(newIntf); }, 0);
				Ether.Event.off(newIntf);
				intf.opened.splice(idx, 1);


				if (!intf.opened.length)
					intf.close();
			},
			idle: function()
			{
				return intf.idle(newIntf);
			},
			active: function()
			{
				return intf.active(newIntf);
			}
		},
		closingOnChildIntfBinder = fireClosingOnChildIntf.bind(undefined, newIntf);

	for (name in newIntf)
		newIntf['send' + name.replace(/(^.)(.*)/, capitalize) + 'ToParent'] = newIntf[name];

	for (name in passEventsToChild)
	{
		newIntf[name] = passEventsToChild[name];
		newIntf['send' + name.replace(/(^.)(.*)/, capitalize) + 'ToChild'] = newIntf[name];
	}
	newIntf.opened = [ ];
	newIntf.alerting = { signal: [ ], warn: [ ], alarm: [ ] };
	
	if (intf)
	{
		Ether.Event.on(newIntf);
		
		intf.opened.push(newIntf);
	
		if (!intf.serialize)
			intf.serialize = function() { return (newIntf.serialize && newIntf.serialize()); };
		if (!intf.deserialize)
			intf.deserialize = function() { return (newIntf.deserialize && newIntf.deserialize()); };
	}
	
	return newIntf;
	
}

function fireDisplayedOnChildIntf(childIntf) {
	Ether.Event.fire(childIntf, "displayed");
}

function fireNonDisplayedOnChildIntf(childIntf) {
	Ether.Event.fire(childIntf, "nondisplayed");
}

function fireActivatedOnChildIntf(childIntf) {
	Ether.Event.fire(childIntf, 'activated');
}

function fireDeActivatedOnChildIntf(childIntf) {
	Ether.Event.fire(childIntf, 'deactivated');
}

function fireClosingOnChildIntf(parentIntf, childIntf) {
	Ether.Event.fire(childIntf, 'closing');

	// The bottom-most component may not be listening for closing events.  If not,
	// go ahead & close it here.
	if ((parentIntf.opened.indexOf(childIntf) != -1) && !childIntf.opened.length)
	{
		childIntf.close();
 	}
 }
 
function fireResizedOnChildIntf(childIntf) {
	Ether.Event.fire(childIntf, 'resized');
}

function fireStartIdleOnChildIntf(childIntf) {
	Ether.Event.fire(childIntf, "startIdle");
}

function fireStopIdleOnChildIntf(childIntf) {
	Ether.Event.fire(childIntf, "stopIdle");
}

function fireLockedOnChildIntf(childIntf) {
	Ether.Event.fire(childIntf, "locked");
}

function fireUnlockedOnChildIntf(childIntf) {
	Ether.Event.fire(childIntf, "unlocked");
}

function removeFromAlerting(name, intf, newIntf) {
	var idx = intf.alerting[name].indexOf(newIntf);
	if (idx != -1)
		intf.alerting[name].splice(idx, 1);
}

function capitalize(s, a, b) { return a.toUpperCase() + b; }

function sendAlert(intf, newIntf)
{
	if (intf.alerting.alarm.length)
		intf.alert('alarm', newIntf);
	else if (intf.alerting.warn.length)
		intf.alert('warn', newIntf);
	else if (intf.alerting.signal.length)
		intf.alert('signal', newIntf);
	else
		intf.satisfied(newIntf);
}

function closeCheck(/*parms*/)
{
	/* jshint validthis:true */

	var opened = this.opened,
		results = [], messages;
	if(opened && opened.length) {
		messages = {};
		opened.forEach(function(openIntf)
		{
			var result = openIntf.closeCheck();
			if(result && result.returnValue === false)
			{
				results.push(result);
				aggregateMessage(result.message, messages);
			}
		});

		if(Object.keys(messages).length === 0) {
			messages = undefined;
		}
	}
	
	return results.length ? { returnValue: false, message: messages } : undefined;
}

function aggregateMessage(msg, messages) {
	var type = typeof msg;
	if(type === "string") {
		messages[msg] = 1;
	} else if(type === "object") {
		Object.keys(msg).forEach(function(key) {
			var args = msg[key],
				newArgs, i, len;
			if(Array.isArray(args)) {
				newArgs = messages[key];
				if(newArgs) {
					for(i =0, len = args.length; i < len; i++) {
						newArgs[i] += args[i];
					}
				} else {
					messages[key] = args;
				}
			} else {
				messages[key] = 1;
			}
		});
	}
}

function formatMessage(format, args) {
	var formatId = Caffeine.formatId;
	args.forEach(function(arg) {
		format = format.replace(formatId, arg);
	});
	return format;
}

function processMessage(msg) {
	var type,
		processedMsg;

	if(msg) {
		type = typeof msg;
		processedMsg = [];

		if(type === "object") {
			Object.keys(msg).forEach(function(key) {
				var args = msg[key];
				if(Array.isArray(args)) {
					processedMsg.push(formatMessage(key, args));
				} else {
					processedMsg.push(key);
				}
			});
		} else if(type === "string") {
			processedMsg.push(msg);
		}

	}
	
	return processedMsg;
}

Caffeine.getPassthruIntf = getPassthruIntf;
Caffeine.getBootstrapIntf = function() { return bootstrapIntf; };

Caffeine.formatId = "%b";

/**
 * @module Bootstrap
 * @namespace Caffeine
 * @class Bootstrap
 * @static
 */
Caffeine.Bootstrap =
{
	loadSources:	loadSources,
	getInitFn:		getInitFn
};

var appModeInitialized,
	modulemap	= { },
	filemap		= { };

/******************************************************************************/
function getInitFn(parm)
{
	var initFn,
		fn		= window;

	if (typeof parm == 'string')
		initFn = Modules[parm].initFn;
	else
		initFn = Modules[parm.module].initFn;

	if (typeof initFn != 'string')
		initFn = initFn && initFn[parm.initFn || 'default'];
		
	if (initFn)
	{
		initFn = initFn.split('.');

		while (initFn.length)
			fn = fn[initFn.shift()];

		return fn;
	}
}

/******************************************************************************
* Load sources for a module into a window.
*
* @method loadSources
* @param {String} modName	The module to load.  All required and used modules
*							will be loaded, in the proper order.
*							CSS for all modules will also be loaded.
* @param {function} cb		Callback function.  Called after all code has been
*							loaded.
*****************************************************************************/
function loadSources(parms, cb)
{
	var i, j, el, name, next, modName,
		requires	= [ ],
		types		= [ ];

	appModeInitialized || initializeAppMode(parms);
	appModeInitialized = 1;
	appMode = Caffeine.appMode;

	if ( typeof isCEF === "undefined" ) 
	{
		types		=
			[
				{ src: [ ], root: "/css/", css: 1 },
				{ src: [ ], root: "/src/" },
				{ src: [ ], root: "/templates/" }
			];
	}
	else
	{
		types		=
			[
				{ src: [ ], root: "css/", css: 1 },
				{ src: [ ], root: "src/" },
				{ src: [ ], root: "templates/" }
			];
	}
	

	if (parms instanceof Array)
	{
		for (i = loading ? 0 : 1; i < parms.length; i++)
			loadQueue.push({ module: parms[i].module, cb: (i == parms.length-1?cb:0) });

		if (loading)
			return;

		if (parms.length > 1)
			cb = 0;

		parms = parms[0];
	}

	if (parms.additionalModules)
	{
		for (name in parms.additionalModules)
			Modules[name] = parms.additionalModules[name];
	}
	
	modName = parms.module;

	if (loading)
	{
		loadQueue.push({module: modName, cb: cb});
		return;
	}

	loading = 1;

	// Build the 'requires' list.  This will be all modules we're going to load,
	// in the correct order.
	getRequirements(modName);

	// Walk the list of modules, getting the list of files each one uses.
	for (i = 0; i < requires.length; i++)
	{
		readDefinition(filemap, Modules[requires[i]].code, types[1].src);
		readDefinition(filemap, Modules[requires[i]].templates, types[2].src);

		readDefinition(filemap, Modules[requires[i]].style, types[0].src);
	}

//	if (Caffeine.appMode.browser)
//	{
//		types[0].root = "/build/out/css/";
//		types[2].root = "/build/out/templates/";
//	}

	i = j = 0;
	loadFiles();

	// loadFiles() will load a single file.  The 'onload' function will call loadFiles() again
	// to get the next file.  When all files of one type are loaded, it will move on to the next
	// type.  After all files of all types are loaded, it will call the callback.
	function loadFiles()
	{
		while (i == types[j].src.length)
		{
			i = 0;
			j++;
			
			if (j == types.length)
			{
				if (!onBootstrap)
				{
					Ether.Event.on(bootstrapIntf);
					Ether.Event.fire(Caffeine, 'modulesloaded');
				}
				onBootstrap = 1;

				if (Caffeine.IPC && Caffeine.IPC.releaseIPC)
					Caffeine.IPC.releaseIPC();

				if (Caffeine.appMode.master && Caffeine.Version && !initReported)
					console.log('Initializing Caffeine v' + Caffeine.Version.appVersion + ', channel ' + Caffeine.CEFContext.getUpdateChannel());
				initReported = 1;
				
				console.log('Loaded module ' + parms.module);

				cb && cb();

				loading = 0;
				if (loadQueue.length)
				{
					next = loadQueue.shift();
					loadSources(next, next.cb);
				}
				return;
			}
		}
		el = document.createElement(types[j].css?"LINK":"SCRIPT");

		el.onload = loadFiles;
		el.onerror = loadFiles;

		name = types[j].src[i];
		if ((name.indexOf('/') !== 0) && (name.indexOf('http') !== 0))
			name = types[j].root + name;

		if (types[j].css)
		{
			el.rel = "stylesheet";
			el.href = name;
		}
		else
			el.src = name;
		i++;
		document.head.appendChild(el);
	}
	
	// walk a module's requirements, adding to requires array
	function getRequirements(name)
	{
		var map = { },
			req	= [ ];

		readDefinition(map, Modules[name].requires, req);

		req.forEach(getRequirements);
		req.push(name);

		req.forEach(function(name)
					{
						if (!modulemap[name])
						{
							modulemap[name] = 1;
							requires.push(name);
						}
					});
	}

	function readDefinition(map, src, dest)
	{
		var i, name, temp;

		if (src instanceof Array)
		{
			for (i = 0; i < src.length; i++)
			{
				temp = src[i];
				if (typeof temp == 'string')
				{
					if (!map[src[i]])
					{
						dest.push(src[i]);
						map[src[i]] = 1;
					}
				}
				else
					readDefinition(map, temp, dest);
			}
		}
		else if (typeof src == "string")
		{
			if (!map[src])
				dest.push(src);
			map[src] = 1;
		}
		else if (src)
		{
			// Special handling for 'always', to ensure it gets handled first
			// TODO: Try to find a more elegant way to get 'always' to get used first...
			readDefinition(map, src.always, dest);

			for (name in appMode)
			{
				if (name == 'always' || name == 'after')
					continue;

				if (appMode[name] && src[name])
					readDefinition(map, src[name], dest);
			}

			// Special handling for 'after', to ensure it gets handled last
			readDefinition(map, src.after, dest);
		}
	}

}

Caffeine.setAppModeFromString = function(string)
{
	if (string)
	{
		string = string.split('&');
		string.forEach(
			function(value)
			{
				var p = value.split('=');
				value = +p[1]||0;
				Caffeine.appMode[p[0]] = value;
				console.log("Setting appMode." + p[0] + '=' + value);
			});
	}
};

function initializeAppMode(parms)
{
	var name,
		appMode = Caffeine.appMode,
		locale = (Caffeine.CEFContext && Caffeine.CEFContext.getLocale()) || 'en-US',
		channel = Caffeine.CEFContext && Caffeine.CEFContext.getUpdateChannel();

	Caffeine.IPC = { id: window.IPC_id || "main" };
	if (parms.appMode)
	{
		for (name in parms.appMode)
		{
			if (name != 'master' && name != 'slave')
				Caffeine.appMode[name] = parms.appMode[name];
		}
	}

	appMode.always = appMode.after = 1;

	appMode.locale = locale;
	appMode[locale] = 1;
	locale = locale.split('-');
	locale.pop();
	locale = locale.join('-');
	appMode[locale] = 1;
	
	appMode[channel] = 1;

	if (!appMode.slave)
		appMode.master = 1;

	appMode.browser	= !Caffeine.CEFContext;
	appMode.CEF		= !appMode.browser;

	// For the config file.
	appMode.desktop = 1;

	// TODO: Include OS versions WinXP, Win7, Win8, Mac10.6, Mac10.7, Mac10.8, Mac10.9
	if (navigator.platform == 'MacIntel')
		appMode.Mac = 1;
	if (navigator.platform == 'Win32')
		appMode.Win = 1;

    appMode.videoEnabled = (appMode.videoenabled !== undefined? +appMode.videoenabled : 0);
    delete appMode.videoenabled;
	
    if (appMode.p === undefined) appMode.p = Math.random();
	if (appMode.secure === undefined)
		appMode.secure = 1;

	if (appMode.real !== undefined)
		appMode.mock = !appMode.real;
	else
		appMode.real = !appMode.mock;
		
	if (appMode.comms1 !== undefined)
		appMode.comms2 = !appMode.comms1;
	else
		appMode.comms2 = 1;
		
	if (appMode.ab2 !== undefined)
		appMode.ab1 = !appMode.ab2;
	else
		appMode.ab1 = 1;

	if (appMode.gtc === undefined)
		appMode.gtc = 1;
		
	appMode.contacts2 = !appMode.gtc;
	if (appMode.contacts2 !== undefined)
		appMode.contacts1 = !appMode.contacts2;
	else
		appMode.contacts1 = 1;

	appMode.createConv = 1;

	// See if the user wants to override anything.  Only necessary in the main process -
	// remote processes get everything copied from the main process anyway.
	if (appMode.master)
	{
		if (Caffeine.CEFContext)
			Caffeine.setAppModeFromString(Caffeine.CEFContext.getPersistentValue('devAppMode'));

		Caffeine.setAppModeFromString(document.location.search.substr(1));
	}
}

})();
