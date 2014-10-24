/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function() {

"use strict";

/**
 *
 * @class IPC
 * @static
 */

Caffeine.IPC =
{
	id:						Caffeine.IPC.id,

	remoteCall:				remoteCall,
	synchronizeObject:		synchronizeObject,
	resynchronizeObject:	function(o) { return synchronizeObject(o, 1); },
	unsynchronizeObject:	unsynchronizeObject,
	synchronizeEvents:		synchronizeEvents,
	unsynchronizeEvents:	unsynchronizeEvents,
	sendObjectTo:			sendObjectTo,
	onReceiveMessage:		onReceiveMessage,
	releaseIPC:				function() { },
	windowOpened:			windowOpened,
	windowClosed:			windowClosed,
	remoteFire:				remoteFire,

	makeProxy:				makeProxy
};

var	yme				= Ether.Event,
	ymu				= Caffeine.Utils,
	debug			= 0,//Caffeine.appMode.debug,
	syncedObjects	= [ 0 ],
	namedSyncFuncs	= [ ],
	nextRPCId		= 1,
	remoteCalls		= [ ],
	events			= [ ],
	allTargets		= [ ],
	releasedTargets	= [ "main" ],
	holdingIPC		= [ ],
	ipcQueue		= [ ],
	sequence		= { },
	expected		= { };

window.syncedObjects = syncedObjects;

yme.on(Caffeine.CEFContext,
{ 
	'ipcReceived': function(from, data)
	{
		var ipc, message,
			i = 0;

		expected[from] = expected[from] || 1;

		try { message = JSON.parse(data); }
		catch(e) { console.error("Not valid JSON: ", data); }

		try
		{
			ipcQueue.push([from, message]);
		
			while (ipc = ipcQueue[i])
			{
				if (ipc[1].sequence != expected[from])
					i++;
				else
				{
					expected[from]++;
					ipcQueue.splice(i, 1);
					i = 0;
					try
					{
						Caffeine.IPC.onReceiveMessage(ipc[0], ipc[1]);
					}
					catch (e) { reportException(e); }
				}
			}
		}
		catch (e) { reportException(e); }

		function reportException(e)
		{
			console.log(e);
			console.log(e.stack);
			console.log(data);
		}
	}
});

synchronizeEvents("Caffeine");

if (Caffeine.Debug && Caffeine.Debug.initIPC)
{
	setTimeout(
		function register()
		{
			if (Caffeine.CEFContext)
			{
				Caffeine.Debug.initIPC(
					{
						syncedObjects:		syncedObjects,
//						remoteCalls:		remoteCalls,
						events:				events
//						releasedTargets:	releasedTargets,
//						holdingIPC:			holdingIPC					
					});
			}
			else
				setTimeout(register, 10);
		}, 0);
}

/**
 * Call a function in a different process
 *
 * @method remoteCall
 * @param {opaque} target		The target process - the process where the call is made
 * @param {string} func			The name of the function call.  The name must be globally accessible.
 * @param {object} parms		The parameter object to pass to the function
 * @param {function} cb			The callback function.  The called function will call this when it's complete.
 *
 * Synchronized parameters (see `{{#crossLink "IPC/synchronizeObject"}}{{/crossLink}}`) will be passed
 * 'by reference'.  All other parameters will be passed by value.
 *******************************************************************************/
function remoteCall(target, func, parms, cb)
{
	var f, id, call;

	if (target == Caffeine.IPC.id)
	{
		f = ymu.getObject(func);
		f(parms, cb);
		return;
	}

	if (typeof func == 'object')
		func.obj = func.obj.syncId;

	id = nextRPCId++;
	call =
	{
		cmd:	"RPC",
		RPCId:	id,
		func:	func,
		parms:	parms?packageObject(parms, target):parms
	};

	remoteCalls[id] = cb;

	sendIPC(target, call);
}

function remoteFire(parms)
{
	var fireArgs = parms.slice(0);
	
	fireArgs[0] = ymu.getObject(fireArgs[0]);
	
	Ether.Event.fire.apply(0, fireArgs);
}

/**
 * Make a proxy-able object
 *
 * You get back an object which will make the proper calls on an object in 'target'
 */
function makeProxy(o, cb)
{
	var name;
	
	o.proxyTarget		= 'main';
	o.proxiedFunctions	= [ ];

	for (name in o)
	{
		if (typeof o[name] == 'function')
			o.proxiedFunctions.push(name);
	}

	synchronizeObject(o);

	cb(0, o);
}

// The real object exists in a remote window.  Create a proxy object
// which will call it.
function createProxy(descriptor, cb)
{
	var i, name;

	synchronizeObject(descriptor);

	for (i = 0; i < descriptor.proxiedFunctions.length; i++)
	{
		name = descriptor.proxiedFunctions[i];

		descriptor[name] = proxyFunc.bind(0, name);
	}

	cb && cb(0, descriptor);
	
	function proxyFunc(name, parms, cb)
	{
		remoteCall(descriptor.proxyTarget, { obj: descriptor, fn: name }, parms, cb);
	}
}

/**
 * Synchronize an object across processes
 *
 * @method synchronizeObject
 * @param {object} o		The object to synchronize
 *
 * This function marks the object for synchronization, but does not actually propagate
 * the object to any other processes.  Use `{{#crossLink "IPC/sendObjectTo"}}{{/crossLink}}()`
 * to send the object to other processes.
 *
 * All objects pointed to by the object will be sent to the remote process as well.  Circular
 * references are OK.
 *
 * Changes to the source object are monitored with `{{#crossLink "Event/onChange"}}{{/crossLink}}()`
 * and `{{#crossLink "Event/onArrayChanging"}}{{/crossLink}}()`.  See those methods for
 * important limitations.
 *
 * Synchronization only makes changes in one direction - from the master to any slaves.  Synchronized
 * objects in slaves are read-only.
 *
 * Note that this object adds a `syncId` member to the object.
 *******************************************************************************/
function synchronizeObject(o, resync)
{
	var name, v, noIncremement,
		// TODO: Hack for objects with prototypes - the subclassed object will be
		// synchronized as a completely separate object.
		syncId = o.hasOwnProperty('syncId') && o.syncId,
		syncRec = syncedObjects[syncId];

	if (!syncId)
	{
		syncId = syncedObjects.push({
										o:			o,
										targets:	[ ],
										refCnt:		0
									}) - 1;

		syncRec = syncedObjects[syncId];

		syncRec.syncFunc = syncFunction.bind(o, syncRec);
		yme.onChange(o, syncRec.syncFunc);

		if (o instanceof Array)
		{
			syncRec.arrayPreSyncFunc = arrayPreSyncFunc.bind(o, syncRec);
			yme.onArrayChanging(o, syncRec.arrayPreSyncFunc);

			// TODO: I think the reference counting is all correct and we want to
			// call unsynch() here, but it's safer not to.  This means things will
			// never get unsynchronized, but that's OK, because we pretty much
			// never throw anything away anyway (with a few small exceptions)
			//syncRec.arrayPostSyncFunc = arrayPostSyncFunc.bind(o, syncRec);
			//yme.onArrayChange(o, syncRec.arrayPostSyncFunc);
		}

		// Make syncId non-enumarable
		Object.defineProperty(o, 'syncId',
			{
				configurable:	true,
				value:			syncId
			});
	}
	else if (resync)
	{
		yme.onChange(o, syncRec.syncFunc);

		// We're re-synchronizing this object, so we don't want to increase the ref count.
		noIncremement = 1;
	}
	
	noIncremement || syncRec.refCnt++;

	for (name in o)
	{
		if (!yme.hasGetter(o, name))
		{
			v = o[name];

			if (v && typeof(v) == "object")
			{
				if (!resync && v.syncId)
					syncedObjects[v.syncId].refCnt++;
				else
					synchronizeObject(v, resync);
			}
		}
	}

	if (resync)
		syncRec.targets.forEach(function(target) { sendObjectTo(o, target, 1); });

	return syncId;
}

/**
 * Stop synchronizing an object
 *
 * @method unsynchronizeObject
 * @param {object} o		The object to unsynchronize
 *
 * Every call to `synchronizeObject()` should have a matching call to `unsynchronizeObject()`
 *
 * Unsynchronizing an object deletes the `syncId` member.  (This violates Google's
 * guidelines for maximum performance.  They say not to use `delete` because it
 * changes the 'shape' of the objec.  You're supposed to set the value to `undefined`
 * instead.  This doesn't seem like it will have a material impact on our performance,
 * so I didn't bother with it.  If it does become an issue, we might want to use
 * an object registry (like event.js uses) so we don't have to modify the object
 * at all.)
 *******************************************************************************/
function unsynchronizeObject(o)
{
	var name, v, i,
		syncId = o.syncId,
		syncRec = syncedObjects[syncId];

	if (!syncRec || !syncRec.refCnt)
		return;

	syncRec.refCnt--;

	for (name in o)
	{
		v = o[name];
		if (v && (typeof v == "object"))
		{
			if (syncedObjects[v.syncId].refCnt == 1)
				unsynchronizeObject(v);
			else
				syncedObjects[v.syncId].refCnt--;
		}
	}

	if (syncRec.refCnt)
		return;

	delete syncedObjects[syncId];
	delete o.syncId;

	yme.offChange(o, syncRec.syncFunction);

	for (i = 0; i < syncRec.targets.length; i++)
		sendIPC(syncRec.targets[i], { cmd: "release", syncId: syncId });
}

//////////////////////////////////////////////////////////////////////////////
function syncFunction(syncRec, name/*, oldVal*/)
{
	/*jshint validthis:true */
	
	var i,
		v = this[name],
		targets = syncRec.targets,
		changeRec =
		{
			cmd: "update", 
			syncId: this.syncId,
			name: name
		};

// TODO: I think the reference counting is all correct and we want to
// call unsynch() here, but it's safer not to.  This means things will
// never get unsynchronized, but that's OK, because we pretty much
// never throw anything away anyway (with a few small exceptions)
//	if (oldVal && (typeof oldVal == 'object'))
//		unsynchronizeObject(oldVal);

// TODO: We don't handle changes to function types (but we probably don't need to)

	if (v instanceof Date)
	{
		changeRec.newDate = v.getTime();
	}
	else if (v && (typeof v == 'object'))
	{
		changeRec.newRec = synchronizeObject(v);
		for (i = 0; i < targets.length; i++)
			sendObjectTo(v, targets[i]);
	}
	else
		changeRec.newVal = v;

	for (i = 0; i < targets.length; i++)
		sendIPC(targets[i], changeRec);
}

//////////////////////////////////////////////////////////////////////////////
function arrayPreSyncFunc(syncRec, name)
{
	/*jshint validthis:true */

	var i, j, v,
		targets = syncRec.targets,
		args = Array.prototype.slice.call(arguments, 2),
		changeRec =
		{
			cmd:	'updateArray',
			syncId:	this.syncId,
			name:	name
		};

	for (j = 0; j < args.length; j++)
	{
		v = args[j];
		if (v && (typeof v == 'object'))
		{
			synchronizeObject(v);
			for (i = 0; i < targets.length; i++)
				sendObjectTo(v, targets[i]);
		}
	}

	for (i = 0; i < targets.length; i++)
	{
		changeRec.args = packageObject(args, targets[i]);
		sendIPC(targets[i], changeRec);
	}
}

// TODO: See the comment in syncFunction() above
//////////////////////////////////////////////////////////////////////////////
//function arrayPostSyncFunc(syncRec, name, ret)
//{
//	var i;

//	if (name == 'shift' || name == 'pop')
//		unsynchronizeObject(ret);

//	if (name == 'splice')
//	{
//		for (i = 0; i < ret.length; i++)
//			unsynchronizeObject(ret[i]);
//	}
//}

/**
 * Synchronize events on a global, non-synchronized object across processes
 *
 * @method synchronizeEvents
 * @param {string} name		The global name of the object who's events should be synchronized.
 *
 * @example
 *
 *		Caffeine.IPC.synchronizeEvents('Caffeine.IPC');
 *		Ether.Event.fire(Caffeine.IPC, 'someEvent', arg1, arg2);
 *
 * Our API will exist in multiple processes, but the objects that implement it won't be synchronized.
 * `synchronizeEvents()` allows events fired on global objects to be propagated across process
 * boundaries.
 *
 * Synchronization only makes changes in one direction - from the master to any slaves.  Events fired
 * on these objects in slave windows won't propagate to the master.
 *
 * Calling this function on a synchronized object will cause events to be fired twice in remote
 * processes.  This is an unlikely scenario because global objects will likely not be synchronized.
 * I could check for this case, but it seems unlikely enough that it's not worth the effort.
 *******************************************************************************/
function synchronizeEvents(name)
{
	var func, names,
		o		= window,
		syncRec	= namedSyncFuncs[name];

	if (syncRec)
		syncRec.count++;
	else
	{
		names	= name.split('.');
		func	= namedSyncFunc.bind(o, name);

		while (names.length)
			o = o[names.shift()];

		syncRec = { count: 1, func: func };

		yme.on(o, func);
	}
}

/**
 * Stop synchronizing events on global objects.
 *
 * @method unsynchronizeEvents
 * @param {string} name		The global name of the object who's events should be synchronized.
 *
 * @example
 *
 *		Caffeine.IPC.synchronizeEvents('Caffeine.IPC');
 *		Ether.Event.fire(Caffeine.IPC, 'someEvent', arg1, arg2);
 *		Caffeine.IPC.unsynchronizeEvents('Caffeine.IPC');
 *
 * This function takes the name of the object to be parallel to `synchronizeEvents()`.
 * `synchronizeEvents()` has to take the name, but `unsynchronizeEvents()` could take
 * the object itself instead, or it take either by checking the parameter type.  This
 * seemed like an unnecessary feature.
 *******************************************************************************/
function unsynchronizeEvents(name)
{
	var names,
		o = window,
		syncRec = namedSyncFuncs[name];

	syncRec.count--;

	if (!syncRec.count)
	{
		names = name.split('.');

		while (names.length)
			o = o[names.shift()];

		yme.off(o, namedSyncFuncs[name]);
		delete namedSyncFuncs[name];
	}
}

//////////////////////////////////////////////////////////////////////////////
function namedSyncFunc(name)
{
// TODO: There are a couple of ways to handle events on named objects.
// The way I chose to do it is to have the main window keep track of
// all named objects with synchronized events.  Any event on any of these
// objects gets broadcast to every process, whether they've subscribed to
// it or not.
// It would be more efficient to send the list of names to every remote
// process and to allow them to subscribe to an object only when code in
// the process has subscribed to it.  This is more complex and I think the
// performance benefit would be minimal, so I didn't do it.

	var args = Array.prototype.slice.call(arguments, 1),
		cmd =
		{
			cmd:	'fireNamed',
			name:	name
		};

	allTargets.forEach(function(target)
		{
			cmd.args = packageObject(args, target);
			sendIPC(target, cmd);
		});
}

/**
 * Send a synchronized object to a remote process
 *
 * @method sendObjectTo
 * @param {object} o		The object to send
 * @param {opaque} target	The process ID of the target
 *******************************************************************************/
function sendObjectTo(o, target, repackage)
{
	var pkg = packageObject(o, target, repackage);

	if (pkg && pkg.values)
		sendIPC(target, { cmd: 'create', "package": pkg });
}

//////////////////////////////////////////////////////////////////////////////
function packageObject(o, target, repackage)
{
	var name, v,
		pkg =
		{
			synced:		{ },
			undefineds:	[ ],
			funcs:		{ },
			objects:	{ },
			dates:		{ }
		},
		syncRec = syncedObjects[o.syncId];

	if (syncRec)
	{
		if (syncRec.targets.indexOf(target) != -1)
		{
			if (!repackage)
				return { syncId: o.syncId };
		}
		else
			syncRec.targets.push(target);
	}

	try
	{
		yme.eventsOff(true);

		pkg.values = (o instanceof Array) ? [] : {};

		for (name in o)
		{
			v = o[name];

			// Don't try to package DOM objects.
			// TODO: We should never do this... Remove this code & fix anything it breaks.
			if (v instanceof Node)
				continue;

			if (v instanceof Date)
			{
				pkg.dates[name] = v.getTime();
			}
			else if (v && (typeof v == "object"))
			{
				if (v.syncId)
				{
					pkg.synced[name] = v.syncId;
					sendObjectTo(v, target);
				}
				else
				{
					o[name] = 0;
					pkg.objects[name] = packageObject(v, target, repackage);
					o[name] = v;
				}
			}
			else if (v === undefined)
				pkg.undefineds.push(name);
			else if ((typeof v == 'function') && !o.noFuncSync)
			{
				// The presence o.proxiedFunctions indicates this is a proxy object
				// Functions on the object are going to be created by the remote window
				// as proxy functions
				if (!o.proxiedFunctions)
					pkg.funcs[name] = v.toString();
			}
			else
				pkg.values[name] = v;
		}

		pkg.syncId = o.syncId;
	}
	finally
	{
		yme.eventsOff(false);
	}

	return pkg;
}

//////////////////////////////////////////////////////////////////////////////
function onReceiveMessage(from, message)
{
//    alert('main onreceivemessage');
	var o, name, cb, e, i, p, func, data,
		cmd = message.cmd;

	if (cmd == "RPC")
	{
		func = message.func;
		if (typeof func == 'string')
		{
			p = 0;

			if (func == 'createProxy')
				o = createProxy;
			else if (func == 'remoteFire')
				o = remoteFire;
			else
			{
				name = func.split('.');
				o = window;
				while (name.length)
				{
					o = o[name.shift()];
				}
			}
		}
		else
		{
			p = syncedObjects[func.obj].o;
			o = p[func.fn];
		}
		
		o.call(p, recreateObject(message.parms), function(error, data)
			{
				var response =
					{
						cmd:	"callback",
						RPCId:	message.RPCId,
						error:	error,
						data:	data?packageObject(data, from):data
					};

				sendIPC(from, response);
			});
	}

	if (cmd == "releaseIPC")
	{
		if (releasedTargets.indexOf(from) == -1)
		{
			releasedTargets.push(from);

			i = 0;
			while (i < holdingIPC.length)
			{
				if (holdingIPC[i].to === from)
				{
					sendEncodedIPC(from, holdingIPC[i].encoded);
					holdingIPC.splice(i, 1);
				}
				else
					i++;
			}
		}
	}

	if (cmd == "callback")
	{
		cb = remoteCalls[message.RPCId];

		if(!(message.error && message.error._ipcState === "partial")){
			remoteCalls[message.RPCId] = 0;
		}

		data = message.data ? recreateObject(message.data) : message.data;

		if (data && data.proxyTarget && data.proxiedFunctions)
			createProxy(data);

		cb && cb(message.error, data);
	}

	if (cmd == "on")
	{
		e = events[message.syncId];
		if (!e)
		{
			e = events[message.syncId] = [ ];
			yme.on(syncedObjects[message.syncId].o, onEvent);
		}

		e.push(from);

		if (debug)
			Caffeine.Debug.updateEvents();
	}

	if (cmd == 'off')
	{
		e = events[message.syncId];
		i = e.indexOf(from);
		if (i != -1)
			e.splice(i, 1);

		if (!e.length)
		{
			yme.off(syncedObjects[message.syncId].o, onEvent);
			events[message.syncId] = 0;
		}

		if (debug)
			Caffeine.Debug.updateEvents();
	}

	function onEvent()
	{
		/*jshint validthis:true */
		
		var e, i, args;

		e = events[this.syncId];
		cmd = { cmd: 'fire', syncId: this.syncId };
		args = Array.prototype.slice.call(arguments, 0);

		for (i = 0; i < e.length; i++)
		{
			cmd.args = packageObject(args, e[i]);	// TODO: that 'e[i]' used to be 'from'.  Verify this fix.
			sendIPC(e[i], cmd);
		}
	}
}

//////////////////////////////////////////////////////////////////////////////
function recreateObject(pkg)
{
	/* jshint -W061:true */		// Don't complain about the 'eval' we have to use

	if (typeof pkg != "object" || !pkg)
		return pkg;

	if (pkg.syncId)
		return syncedObjects[pkg.syncId].o;

	for (var name in pkg.out)
		pkg.out[name] = recreateObject(pkg.out[name]);

	for (name in pkg.dates)
		pkg.out[name] = new Date(pkg.dates[name]);

	if (debug)
		Caffeine.Debug.updateSyncedObjects();

	if (pkg.out.proxyTarget && pkg.out.proxiedFunctions)
		createProxy(pkg.out);
	else
	{
		for (name in pkg.funcs)
			eval("pkg.out[name] = " + pkg.funcs[name]);
	}

	return pkg.out;
}

//////////////////////////////////////////////////////////////////////////////
function windowOpened(win)
{
	allTargets.push(win);
}

//////////////////////////////////////////////////////////////////////////////
function windowClosed(target)
{
	var idx = releasedTargets.indexOf(target);
	if (idx != -1)
		releasedTargets.splice(idx, 1);

	idx = allTargets.indexOf(target);
	if (idx != -1)
		allTargets.splice(idx, 1);
	else
		console.log('Warning: closing ' + target + ' more than once.');

	syncedObjects.forEach(function(synced)
		{
			if (!synced)
				return;
			
			var idx = synced.targets.indexOf(target);
			if (idx != -1)
				synced.targets.splice(idx, 1);
		});
}

//////////////////////////////////////////////////////////////////////////////
function sendIPC(target, cmd)
{
	sequence[target] = sequence[target] || 1;
	cmd.sequence = sequence[target]++;
	
	var encoded = escape(JSON.stringify(cmd));

	if (releasedTargets.indexOf(target) != -1)
		sendEncodedIPC(target, encoded);
	else
		holdingIPC.push({ to: target, encoded: encoded });
}

//////////////////////////////////////////////////////////////////////////////
function sendEncodedIPC(target, encoded)
{
	try
	{
		Caffeine.CEFContext.sendIPC(target, encoded, Caffeine.IPC.id);
	}
	catch(e)
	{
		Caffeine.log4js.disable();
		console.error("Error sending IPC cmd ", unescape(encoded));
		console.log(e.stack);
		Caffeine.log4js.enable();
	}
}

})();
