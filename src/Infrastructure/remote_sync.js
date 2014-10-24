/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

/*jshint boss:true */

(function() {

"use strict";

Caffeine.IPC =
{
	// The shell created Caffeine.IPC with only Caffeine.IPC.id.  Make sure it remains
	// on the IPC object after we re-create it.
	id:						Caffeine.IPC.id,

	remoteCall:				remoteCall,
	remoteFire:				remoteFire,
	onReceiveMessage:		onReceiveMessage,
	releaseIPC:				releaseIPC,

	makeProxy:				makeProxy
};

//Ether.Event.on(Caffeine.CEFContext, Caffeine.IPC.onReceiveMessage);

var console				= Caffeine.getConsole('infrastructure'),
	debug				= 0, // Caffeine.appMode.debug,
	bme					= Ether.Event,
	saveOn				= bme.on,
	saveOnce			= bme.once,
	saveOff				= bme.off,
	saveFire			= bme.fire,
	nextRPCId			= 1,
	remoteCalls			= [ ],
	remoteObjects		= [ ],
	deferred			= [ ],
	events				= [ ],
	ipcQueue			= [ ],
	sequence			= 1,
	expected			= 1;

window.remoteObjects = remoteObjects;

Ether.Event.on(Caffeine.CEFContext,
{
	'ipcReceived': function(from, data)
	{
		var ipc, message,
			i = 0;

		try { message = JSON.parse(data); }
		catch(e) { console.error("Not valid JSON: ", data); }

		try
		{
			ipcQueue.push([from, message]);
			
			while (ipc = ipcQueue[i])
			{
				if (ipc[1].sequence != expected)
					i++;
				else
				{
					expected++;
					ipcQueue.splice(i, 1);
					i = 0;

					try
					{
						Caffeine.IPC.onReceiveMessage(ipc[0], ipc[1]);
					}
					catch (e) { }
				}
			}
		}
		catch (e)
		{
			console.log(e);
			console.log(e.stack);
			console.log(data);
		}
	}
});

//////////////////////////////////////////////////////////////////////////////
if (debug)
{
	setTimeout(
		function register()
		{
			if (Caffeine.CEFContext)
			{
				Caffeine.Debug.initIPC(
					{
						syncedObjects:		remoteObjects,
						remoteCalls:		remoteCalls,
						events:				events,
					});
			}
			else
				setTimeout(register, 10);
		}, 0);
}

//////////////////////////////////////////////////////////////////////////////
function remoteCall(target, func, parms, cb)
{
	if (target != 'main')
		throw 'invalid arg';

	var id = nextRPCId++;

	remoteCalls[id] = cb;

	if (typeof func == 'object')
		func.obj = func.obj.syncId;

	sendIPC(
		{
			cmd:	"RPC",
			RPCId:	id,
			func:	func,
			parms:	packageObject(parms)
		});
}

//////////////////////////////////////////////////////////////////////////////
function remoteFire(parms)
{
	remoteCall('main', 'remoteFire', parms);
}

//////////////////////////////////////////////////////////////////////////////
function releaseIPC()
{
//    alert('remote releaseIPC');
	sendIPC( 
		{
			cmd:	"releaseIPC"
		});
}

//////////////////////////////////////////////////////////////////////////////
function makeProxy(o, cb)
{
	var name;
	
	o.proxyTarget		= Caffeine.IPC.id;
	o.proxiedFunctions	= [ ];

	for (name in o)
	{
		if (typeof o[name] == 'function')
			o.proxiedFunctions.push(name);
	}

	remoteCall('main', 'createProxy', o, gotProxy);

	function gotProxy(err, p)
	{
		var name;
		
		for (name in o)
		{
			if (typeof o[name] == 'function')
				p[name] = o[name];
		}

		cb && cb(0, p);
	}
}

// Descriptor describes an object which exists in some other window
//////////////////////////////////////////////////////////////////////////////
function createProxy(descriptor)
{
	var i, name;

	for (i = 0; i < descriptor.proxiedFunctions.length; i++)
	{
		name = descriptor.proxiedFunctions[i];

		descriptor[name] = proxyFunc.bind(0, name);
	}
	
	function proxyFunc(name, parms, cb)
	{
		remoteCall('main', { obj: descriptor, fn: name }, parms, cb);
	}
}

//////////////////////////////////////////////////////////////////////////////
bme.on = function(o, notify)
{
	saveOn(o, notify);
	if (o.syncId)
		syncOn(o, notify);
};

//////////////////////////////////////////////////////////////////////////////
bme.once = function(o, notify)
{
	saveOnce(o, notify);
	if (o.syncId)
		syncOn(o, notify);
};

//////////////////////////////////////////////////////////////////////////////
bme.off = function(o, notify)
{
	saveOff(o, notify);
	if (o.syncId)
		syncOff(o, notify);
};

//////////////////////////////////////////////////////////////////////////////
bme.fire = function(o)
{
	// TODO: This is an exception.  Allowing it for now.
	if (!o)
		return;

	if (o.syncId)
	{
		var fireArgs = Array.prototype.slice.call(arguments, 0);
		remoteCall('main', 'remoteFire', fireArgs);
	}
	else
		saveFire.apply(0, arguments);
};

//////////////////////////////////////////////////////////////////////////////
function syncOn(o, notify)
{
	var syncId = o.syncId;

	if (!events[syncId])
	{
		events[syncId] = [ ];

		sendIPC(
			{
				cmd:	"on",
				syncId:	o.syncId
			});
	}

	if (events[syncId].indexOf(notify) == -1)
		events[syncId].push(notify);

	if (debug)
		Caffeine.Debug.updateEvents();
}

//////////////////////////////////////////////////////////////////////////////
function syncOff(o, notify)
{
	var syncId = o.syncId,
		evts = events[syncId],
		idx = evts && evts.indexOf(notify);

	// TODO: Event handlers on objects aren't being refcounted, so
	// the object can get deleted while handlers are still attached.
	// This fixes an exception when it happens but I should refcount
	// properly.
	if (!evts)
		return;

	if (idx != -1)
		evts.splice(idx, 1);

	if (!evts.length)
	{
		sendIPC(
			{
				cmd:	"off",
				syncId:	o.syncId
			});
		events[syncId] = 0;
	}

	if (debug)
		Caffeine.Debug.updateEvents();
}

//////////////////////////////////////////////////////////////////////////////
function packageObject(o)
{
    var name, pkg;
    
    // literal values
    if (typeof o != "object" || !o)
        return o;
    
    // synchronized object
    if (o.syncId && remoteObjects[o.syncId])
        return { syncId: o.syncId };
    
    if (o.syncId)
	{
        console.error("UNKNOWN SYNC ID on remote: ",o.syncId);
        console.log("you forgot to use an IPC to pass this object to the remote window.");
        return { syncId: o.syncId };
    }
    
    // literal object. anything else is unsupported/destroyed through this.
    // TODO: We're not packaging members with value 'undefined'.  In the main
    // window, for o.m = undefined, o.m == undefined will be true (as it should
    // be), but o.hasOwnProperty('m') will be false (which is wrong.)
    pkg = { dates: { }, funcs: { } };
    pkg.out = o instanceof Array ? [] : {};
    for (name in o)
	{
		// Don't try to package DOM objects.
		// TODO: We should never do this... Remove this code & fix anything it breaks.
		if (o[name] instanceof Node)
			continue;

		if (o[name] instanceof Date)
			pkg.dates[name] = o[name].getTime();

		if ((typeof o[name] == 'function') && !o.noFuncSync)
		{
			// The presence o.proxiedFunctions indicates this is a proxy object
			// Functions on the object are going to be created by the remote window
			// as proxy functions
			if (!o.proxiedFunctions)
				pkg.funcs[name] = o[name].toString();
		}
		else
	        pkg.out[name] = packageObject(o[name]);
	}

    return pkg;
}
//////////////////////////////////////////////////////////////////////////////
function onReceiveMessage(from, message)
{
	var o, cb, name, data, args, parms, cmd, func, p;

	cmd = message.cmd;

	if (cmd == 'create')
		recreateObject(message["package"]);

	if (cmd == 'update')
	{
		o = remoteObjects[message.syncId];
		if (message.newRec)
			o[message.name] = remoteObjects[message.newRec];
		else if (message.newDate)
			o[message.name] = new Date(message.newDate);
		else
			o[message.name] = message.newVal;
	}

	if (cmd == 'updateArray')
	{
		args = recreateObject(message.args);
		o = remoteObjects[message.syncId];
		o[message.name].apply(o, args);
	}

	if (cmd == 'release')
		delete remoteObjects[message.syncId];

	if (cmd == 'callback')
	{
		cb = remoteCalls[message.RPCId];
		remoteCalls[message.RPCId] = 0;

		data = message.data?recreateObject(message.data):message.data;

		cb && cb(message.error, data);
	}

	if (cmd == "RPC")
	{
		func = message.func;
		if (typeof func == 'string')
		{
			name = func.split('.');
			o = window;
			while (name.length)
			{
				p = o;
				o = o[name.shift()];
			}
		}
		else
		{
			p = remoteObjects[func.obj];
			o = p[func.fn];
		}

		parms = message.parms?recreateObject(message.parms):message.parms;

		o.call(p, parms, function(error, data)
			{
				sendIPC(
					{
						cmd:	"callback",
						RPCId:	message.RPCId,
						error:	error,
						data:	packageObject(data)
					});
			});
	}

	if (cmd == 'fire')
	{
		o = remoteObjects[message.syncId];
		args = recreateObject(message.args);
		args.unshift(o);
		saveFire.apply(0, args);
	}

	if (cmd == 'fireNamed')
	{
		name = message.name.split('.');
		o = window;
		while (name.length)
			o = o[name.shift()];
		args = recreateObject(message.args);
		args.unshift(o);
		bme.fire.apply(0, args);
	}
}


//////////////////////////////////////////////////////////////////////////////
function recreateObject(pkg)
{
	/* jshint -W061:true */		// Don't complain about the 'eval' we have to use

	var r, name, i, d, obj,
		values		= pkg.values,
		syncId		= pkg.syncId,
		undefineds	= pkg.undefineds,
		objects		= pkg.objects,
		synced		= pkg.synced,
		dates		= pkg.dates,
		funcs		= pkg.funcs;

	if (syncId)
	{
		obj = remoteObjects[syncId];
		if (obj)
		{
			if (!values)
				return obj;
			for (name in values)
				obj[name] = values[name];
			values = obj;
		}
		else
		{
			// syncId isn't enumerable
			Object.defineProperty(values, 'syncId',
				{
					configurable:	true,
					value:			syncId
				});

			remoteObjects[syncId] = values;

			if (deferred[syncId])
			{
				while (d = deferred[syncId].pop())
					d.o[d.name] = values;

				delete deferred[syncId];
			}
		}
	}

	if (!undefineds)
		return;

	for (i = 0; i < undefineds.length; i++)
		values[undefineds[i]] = undefined;

	for (name in dates)
		values[name] = new Date(dates[name]);

	for (name in synced)
	{
		syncId = synced[name];

		r = remoteObjects[syncId];
		if (r)
			values[name] = r;
		else
		{
			if (!deferred[syncId])
				deferred[syncId] = [ ];

			deferred[syncId].push({ o: values, name: name });
		}
	}

	for (name in objects)
		values[name] = recreateObject(objects[name]);

	if (debug)
		Caffeine.Debug.updateSyncedObjects();

	if (values.proxyTarget && values.proxiedFunctions)
		createProxy(values);
	else
	{
		for (name in funcs)
			eval("values[name] = " + funcs[name]);
	}

	return values;
}

//////////////////////////////////////////////////////////////////////////////
function sendIPC(cmd)
{
	cmd.sequence = sequence++;

    var escaped_cmd = escape(JSON.stringify(cmd));
	Caffeine.CEFContext.sendIPC("main", escaped_cmd, Caffeine.IPC.id);
}

})();
