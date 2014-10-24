/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

"use strict";

/**
 * To use this module, call `signin()` with a set of credentials.  `signin()` will return a signed-in
 * session that will be valid until `signout()` is called.
 *
 * Once you have a session, you can make requests that require authorization with `makeAuthorizedRequest()`.
 * The module knows about the server you're talking to and includes whatever credentials are required
 * (which might be none - you can use `makeAuthorizedRequest()` even if authorization isn't required.)
 * The request will be queued if required (it's required when there's no network connection, and possibly
 * other times depending on the server being used.)  The module will recover from errors where possible.
 * 
 * The module also provides the simpler `sendRequest()`, which is a wrapper for XHR.  `sendRequest()`
 * is suitable (and should be used) for all XHR calls.  It provides a few simple services on top of XHR,
 * including: exception handling, parameter encoding and decoding, argument encoding, timeouts, statting,
 * record/replay and response interpretation (i.e. it calls JSON.parse() on json responses.)
 *
 * @module Network
 * @class Network
 */
var Network = Caffeine.Network;

Network.signin					= signin;
Network.makeAuthorizedRequest	= makeAuthorizedRequest;
Network.getRequestUrl			= getRequestUrl;
Network.signout					= signout;
Network.sendRequest				= sendRequest;

Network.setServer				= setServer;
Network.setLoginServer			= setLoginServer;

var userAgent,
	Event			= Ether.Event,
	Stats			= Caffeine.Stats,
	Utils			= Caffeine.Utils,
	ERR_TRANSIENT	= Network.ERR_TRANSIENT,
	ERR_FAILURE		= Network.ERR_FAILURE,
	ERR_INVALID		= Network.ERR_INVALID,
	ERR_LOCKED		= Network.ERR_LOCKED,
	ERR_SPECIAL		= Network.ERR_SPECIAL,
	ERR_REGISTER	= Network.ERR_REGISTER,
	ERR_UNDERAGE	= Network.ERR_UNDERAGE,
	ERR_SLCC		= Network.ERR_SLCC,
	LN_LOST			= Network.LN_LOST,
	appMode			= Caffeine.appMode,
	secure			= appMode.secure,
	secureServers	= 
	{
		login:			"https://login.caffeine.com",
	},
	insecureServers	=
	{
		login:			"http://login.caffeine.com",
	},
	loginSrv		= secureServers.login,
	overrides		= {
					  },
	defaultServers	= { },
	sessions		= [ ],
	requestNum		= 0,
	base32Bits		= [ '0','1','2','3','4','5','6','7',
						'8','9','a','b','c','d','e','f',
						'g','h','i','j','k','l','m','n',
						'o','p','q','r','s','t','u','v' ];

Utils.mix(defaultServers, secure ? secureServers : insecureServers);

function setLoginServer(chnglogSrv)
{
	if (chnglogSrv == loginSrv)
		return;

	console.log("Changing login server to " + chnglogSrv + " from " + loginSrv);
	loginSrv = chnglogSrv;

	secureServers	= 
	{
		login:			"https://" + loginSrv
	};
	insecureServers	=
	{
		login:			"http://" + loginSrv
	};
	
}

setLoginServer("login.caffeine.com");

function setServer(session, server, url, useSecure)
{
	if (arguments.length < 4)
		useSecure = appMode.secure;
	secure = useSecure;
	
	var servers = secure ? secureServers : insecureServers;

	if (!url)
		url = servers[server];

	overrides[server] = url;

	if (session)
	{
		session.servers[server] = url;
	}
}

setUserAgent();

if (appMode.Win)
{
	window.addEventListener("online", handleConnectivityChange.bind(0, 0), false);
	window.addEventListener("offline", handleConnectivityChange.bind(0, 1), false);
}
else
{
	// TODO: When the shell fires these --- add them to Windows

	// NOTE!!! These events can fire before navigator.onLine gets set.
	window.addEventListener("os:online", handleConnectivityChange.bind(0, 0), false);
	window.addEventListener("os:offline", handleConnectivityChange.bind(0, 1), false);
}

/**
 * Signin, providing whatever credentials are required.  The signin state will be maintained.  This module
 * will renew cookies and crumbs as required.
 *
 * @method signin
 * @param parms
 * @param parms.login {string}			ID of the user being signed in.
 * @param parms.token {string}			Signin token (if available).
 * @param parms.password {string}		Signin password.  Either `token` or `password` is required.
 * @param [parms.msgrAppId] {string}	Override for Caffeine's appId.  Defaults to `rest-win`.
 * @param cb {function(err, session)}	Callback function
 * @param cb.err {object|falsey}		Falsey indicates no error.
 * @param {cb.err.code}					Error code.
 *											1. Transient error
 *											2. Generic failure
 *											3. Invalid password
 *											4. Captcha
 *											5. Account locked
 *											6. Special handling required
 *											7. Account doesn't exist
 * @param cb.session {Session}			The network session object. Required to make requests that require authorization.
 */

// client-info ::== client-model ";" client-version
// device-info ::== device-id ";" device-make ";" device-model [";" device-os ["/"device-osvers]]
function setUserAgent(yid)
{
	var hdrCtx, newAgent,
		deviceId = Caffeine.preferences.app.deviceId;

	if (!deviceId || appMode.newDeviceId)
	{
		deviceId = btoa(Math.random());
		Caffeine.preferences.set({name: 'app.deviceId', value: deviceId});
	}

	hdrCtx =
	{
		version:		Caffeine.Version.appVersion,
		os:				(appMode.Win ? 'Windows' : 'Mac'),
		deviceId:		btoa((yid||'') + deviceId),
		yid:			yid || ''
	};

	newAgent = expand('Caffeine/1.0 ({os} Caffeine;{version}) ({deviceId}_{yid};;;{os})', hdrCtx);

	if (userAgent != newAgent)
	{
		userAgent = newAgent;
		Caffeine.Desktop.setUserAgent(userAgent);
	}
}

function signin(parms, cb)
{
	var headers =
		{
			"Content-Type":				"application/json;charset=utf-8"
		},
		session =
		{
			network:
			{
				state:			Network.LOGGED_OUT,
				flags:			0
			},
			authState:
			{
				membership:	Network.AUTH_PENDING,
				crumb:		Network.AUTH_WAITING,
				session:	Network.AUTH_WAITING,
				wssid:		Network.AUTH_IDLE,
				oauth:		Network.AUTH_IDLE
			},
			notifySequence:	0,
			sequenceRetry:	0,
			pending:		[ ],
			credentials:
			{
				login:			parms.login,
				password:		parms.password,
				
				jurisdiction:	undefined,

				primaryId:		0,
				
				sessionId:		0,
				crumb:			0,

				cookieRepeat:	0,
				loginCrumb:		0,
				
				wssid:			0,

				captcha:		parms.captcha,
				slcc:			parms.slcc || "",
				mobile_code:	parms.mobile_code,
				landline_code:	parms.landline_code,
				aea_code:		parms.aea_code,
				sanswer:		parms.sanswer
			},
			// TODO: This should be a structure which includes 'headers' and 'args' in
			// addition to the host name?
			// 'servers' are stored here to allow us to override the defaults (to use QA servers, for example.)
			servers:
			{
				login:			parms.loginServer	|| defaultServers.login,
			},
			headers:
			{
				login:			headers
			},
			relogin:	0
		};

	setUserAgent(parms.login);

	sessions[0] = session;

	for (var name in overrides)
		session.servers[name] = overrides[name];
		
	Event.onChange(session,
		{
			authState:
			{
				membership: authChange
			}
		});
	
	signinWithCreds(session, function(err/*, data*/)
		{
			cb(err, session);
		});
}

// This is _totally_ unreliable.  At least when you're connecting to Fiddler in a NAT'd VM over
// a wireless VPN connection.
// Given the unreliability here, I don't know what to do about lost network errors.  Chrome sometimes
// reports you as online when you're offline, and sometimes it says you're offline when you are online.
function handleConnectivityChange(lost)
{
	sessions.forEach(function(session)
		{
			var network = session.network;

			if (lost)
			{
				console.log('Connectivity change: Network lost');
				network.lostNetwork = LN_LOST;
			}
			else
			{
				network.lostNetwork = 0;
				console.log('Connectivity change: Network regained');
			}

			if (!network.lostNetwork)
				dequeueRequest(session);
		});
}

/**
 * Signout of all servers we're signed in to (in this session.)  You can't sign back in
 * once you've signed out - you have to create a new session.
 *
 * @method signout
 * @param parms {object}
 * @param parms.session {object}		The session to signout of
 * @param parms.global
 * @param parms.quick {0|1}				Quick signout -> signout NOW.  Slow signout -> Add a signout request to the queue
 * @param cb {function}
 */
function signout(parms, cb)
{
	Caffeine.pendingYIDs.splice(0,Caffeine.pendingYIDs.length);

	Caffeine.addPendingTask('signout');

	makeAuthorizedRequest(
		{
			session:	parms.session,
			method:		'DELETE',
			server:		'login',
			path:		'/session',
			timeout:	4750,
			priority:	parms.quick,
			retries:	2
		},
		function(err)
		{
			Caffeine.pendingTaskDone('signout');
		});
}

/**
 * Make a network request, supplying the required credentials.  Will relogin, get a crumb or
 * wssid, etc. if required.   The request will be queued if required (it's required when there's
 * no network connection, and possibly other times depending on the server being used.)  The
 * module will recover from errors where possible.
 *
 * The timeout to makeAuthorizedRequest() is the XHR timeout, not an overall timeout (time in
 * the queue doesn't count.)  Failed requests will be retried automatically.  A request that
 * fails due to session expiration or lost network will be re-issued - this is not considered
 * a retry.
 *
 * @param parms
 * @param parms.session
 * @param parms.server
 * @param parms.path
 * @param parms.args
 * @param parms.url
 * @param parms.method
 * @param parms.body
 * @param parms.retries
 * @param parms.stat
 * @param parms.statRetries
 * @param parms.noLog
 * @param parms.queue {String}
 * @param parms.priority
 * @param cb
 */
function makeAuthorizedRequest(parms, cb, retryCount, abortObj)
{
	var session		= parms.session,
		creds		= session.credentials,
		autoRetries = parms.retries || 0,
		server		= parms.server;

	abortObj	= abortObj || { };
	retryCount	= retryCount || 0;

	if (!checkRequest(parms))
	{
		queueRequest(parms, cb, retryCount, parms.priority, abortObj);
		return abortObj;
	}

	var newParms = normalizeRequestParms(parms);
	
	abortObj.abort = issueRequest(newParms, processResponse, retryCount);

	return abortObj;

	function processResponse(err, data, headers)
	{
		try
		{
			// See if this server embedded an error in the returned data
			err = getErrorFromData(err, data);

			// Some errors can be handled here, such as crumb or credential errors
			if (err && errorRecovery(err, data))
				return;
		}
		catch (e)
		{
			Stats.fire(
				{
					category:	 'Error',
                    subcategory: 'Network',
					name:		 'RequestError1',
					type:		 'counter',
					msg:		 e.message,
					exception:	 e.name
				});
		}

		try
		{
			// TODO: What to do about unrecoverable errors?
			dequeueRequest(session);
		}
		catch (e)
		{
			Stats.fire(
				{
					category:	 'Error',
					subcategory: 'Network',
					name:        'RequestError2',
					type:		 'counter',
					msg:		 e.message,
					exception:	 e.name
				});
		}

		cb && cb(err, data, headers);
	}

	// Returns truthy for 'error recovery in progress'
	function errorRecovery(err, data)
	{
		var httpStatus = err.httpStatus,
			authState = session.authState,
			retryList	= [ 408, 413, 414 ];

		// internalCode 1 => aborted
		if (errIs(err, 1))
			return;

		if (session.network.lostNetwork & LN_LOST)
		{
			queueRequest(parms, cb, retryCount, 1, abortObj);
			return 1;
		}

		// internalCode 1 => aborted, 2 => timeout
		if (errIsInternal(err) && (err.code == 1 || err.code == 2))
			return;
		
		if (httpStatus == 401 || httpStatus == 403)							// cookies expired
		{
			queueRequest(parms, cb, retryCount, 1, abortObj);

			if (authState.membership == Network.AUTH_COMPLETE)
				authState.membership = Network.AUTH_PENDING;

			return 1;
		}

		// TODO: Handle the "Retry-After" header

		// Most 4xx errors shouldn't be retried
		if (httpStatus >= 400 && httpStatus < 500)
		{
			// but there are a few exceptions...
			if (retryList.indexOf(httpStatus) == -1)
				return;
		}

		if (retryCount < autoRetries)
		{
			retryCount++;
			makeAuthorizedRequest(parms, cb, retryCount, abortObj);
			return 1;
		}
	}

	function getErrorFromData(err, data)
	{
		if (data && data.error)
			return data.error;

		return err;
	}
}

function getRequestUrl(parms)
{
	parms = normalizeRequestParms(parms);

	return parms.url;
}

/**
 * Send a network request.
 * @method issueRequest
 * @param parms
 * @param parms.url		
 * @param [parms.server]	{string}
 * @param [parms.path]		{string}
 * @param [parms.context]	{object}
 * @param [parms.args]		{array[string]}	Query parameters.  These will be URI encoded here.
 * @param [parms.body]		{string|object}
 * @param [parms.cachebust] {string}		Name to use for cachebuster arg, falsey for none.
 * @param parms.method
 * @param parms.headers
 * @param parms.timeout
 * @param parms.type
 * @param cb
 *
 * Simply send a network request.  Doesn't queue the request or check for network connectivity.
 * Doesn't support automatic retries.  An error is reported if:
 * 1) The http status code >= 400
 * 2) The request timed out
 * 3) The request was aborted
 */
function sendRequest(parms, cb)
{
	parms = normalizeRequestParms(parms);
	return issueRequest(parms, cb, 0);
}

function issueRequest(parms, cb, retryNum)
{
	/* jshint -W041: true */	// Allow '== 0' comparison

	var req, timeoutId, aborting, key, stat, msg, progress, host,
		timeout	= parms.timeout,
		method	= parms.method,
		url		= parms.url,
		headers = parms.headers,
		type	= parms.type,
		body	= parms.body,
		number	= requestNum,
		now		= new Date(),
		op		= parms.originalParms,
		xRid	= headers['X-RID'];

	try
	{
		// TODO: Does this belong in imageQueue.js?
		// Does it belong in the code at all?
		// Should we do a better check for the protocol?
		if (parms.url.toLowerCase().indexOf('blob:') == 0)
		{
			cb && cb();
			return;
		}

		host = document.createElement('a');
		host.href = parms.url;
		host = host.host;

		req = new XMLHttpRequest();
		
		req.onloadend = onLoadEnd;
		req.onprogress = onProgress;

		if (timeout)
		{
			req.ontimeout = function() { abort(netError(2)); };
			req.timeout = timeout;
		}

		req.open(method, prefix + url, !op.sync);
		for (key in headers)
			req.setRequestHeader(key, headers[key]);

		if (!op.sync)
			req.responseType = type;

		req.send(body);

		Caffeine.addPendingTask('XHR #' + number);

		requestNum++;
		
		if (!op.noLog)
		{
			msg = 'XHR #' + number + ': send(' + parms.url + ')';

			if (xRid)
				msg += " X-RID: " + xRid;

			console.log(msg);
		}

		if (!op.noLog && body)
		{
			// xRid already logged with the URL
			console.log(msg);
		}

		stat = buildStat(op);
		if (stat)
		{
			stat.name += 'Request';
			Stats.fire(stat);
		}
	}
	catch (e)
	{
		callback(e);
	}

	return abort;

	function abort(error)
	{
		if (error)
			error.progress = progress;

		if (!op.noLog)
		{
			msg = 'Aborting XHR #' + number + ' after ' + (new Date() - now) + 'ms';
			if (xRid)
				msg += " X-RID: " + xRid;
			console.log(msg);
		}

		requestNum++;

		aborting = 1;
		try { req.abort(); } catch(e) {}
		callback(error || netError(1));
	}
	
	function callback(err, data, headers)
	{
		if (req)
		{
			if (!op.noLog)
			{
				msg = 'Calling callback for XHR #' + number + ' after ' + (new Date() - now) + 'ms';
				if (xRid)
					msg += " X-RID: " + xRid;
				console.log(msg);
			}

			Caffeine.pendingTaskDone('XHR #' + number);

			clearTimeout(timeoutId);
			timeoutId = 0;

			req.onloadend = null;
			req.ontimeout = null;
			req = null;
			cb && cb(err, data, headers);
		}
		
		cb = 0;		// prevent the callback from being called more than once
	}

	function onProgress()
	{
		// Flag that we got some data to attempt to recognize the problem where core
		// never finishes the response.
		if (req)
			progress = 1;
	}

	function onLoadEnd()
	{
		var data, err, headers, status, stat,
			duration = new Date() - now;

		// Request is being aborted or timed out
		if (!req)
			return;

		try
		{
			stat = buildStat(op);
			
			if (aborting)
			{
				if (stat)
					stat.name += 'ResponseAfterAbort';

				return;
			}

			clearTimeout(timeoutId);
			timeoutId = 0;
			
			if (typeof req.responseText == "string")
				data = req.responseXML || req.response;

			status = req.status || 0;

			if (appMode.errCodeZero && !status)
				alert('got error code 0 for ' + (parms.path || parms.url) + ' after ' + duration + ' ms');

			if (stat)
				stat.code = status;

			// TODO: More error normalization
			// TODO: follow our standard error definition
			if (!status || (status >= 400))		// I'm getting 0 when I'm disconnected (even though Fiddler says it's returning 502)
			{
				err = netError(3);
				err.httpStatus = status;
				err.detail = req.statusText;
				
				if (stat)
				{
					stat.netErrorCode = 3;
					stat.progress = progress;
					stat.name += 'ResponseError';
				}

			}
			else if (stat)
			{
				if (appMode.showSlowReqs && (duration > 60000))
				{
					alert('Got ' + status + ' after ' + duration + 'ms for XHR #' + number);
					console.log('Slow response for XHR #' + number + '. Duration = ' + duration);
				}

				stat.name += 'Response';
			}

			type = req.getResponseHeader('content-type');

			if (!op.noLog)
			{
				msg = 'XHR #' + number + ' response: ' + status + ' ' + type;
				if (xRid)
					msg += " X-RID: " + xRid;
				console.log(msg);				
			}

			if (!op.noLog && op.logResponse && data)
				console.log(data);

			if (type && (type.indexOf('application/json') === 0))
			{
				try
				{
					if (data.length == 0)
						data = null;
					else
						data = JSON.parse(data);
				}
				catch (e)
				{
					err = netError(4);
                    if (stat)
                    {
					    stat.netErrorCode = 4;
					    stat.category = 'Error';
					    stat.message = e.message;
                    }
				}
			}
		}
		catch (e)
		{
            if (stat) 
            {
			    stat.category = 'Error';
			    stat.message = e.message;
            }

			console.error(e.message, e.stack);
			err = e;
		}
		finally
		{
			try { stat && Stats.fire(stat); } catch (e) { }
		}
		
		headers = parseHeaders(req.getAllResponseHeaders());
		callback(err, data, headers);
	}
	
	function buildStat(parms)
	{
		if (parms && parms.path && !parms.noStat)
		{
			var stat = 
				{
					category:		'Performance',
                    subcategory:	'Network',
					type:			'gauge',
					api:			method + ":" + parms.path,
					host:			host,
                    data:			(new Date()) - now
				};

			if (retryNum !== undefined)
				stat.retryNum = retryNum;

			return stat;
		}
	}
}

function normalizeRequestParms(parms)
{
	/* jshint -W041: true */	// Allow '== 0' comparison

	var name, url, urlArgs,
		path		= parms.path || '',
		args		= parms.args,
		session		= parms.session,
		creds		= session && session.credentials,
		server		= parms.server || parms.url,
		context		= parms.context,
		body		= parms.body,
		headers		= { },
		cachebust	= parms.cache,
		newParms	=
		{
			headers:		headers,
			method:			parms.method || (body?"POST":"GET"),
			type:			parms.type || '',
			timeout:		parms.timeout,
			retries:		(parms.retries === undefined) ? 2 : parms.retries,
			originalParms:	parms
		};
	
	// 1. Expand the path
	if (context)
		path = expand(path, context, parms.base);

	// 2. Normalize args
	if (args instanceof Array)
		args = args.slice(0);
	else if (typeof args == 'string')
		args = [ args ];
	else
	{
		args = [ ];
		if (parms.args)
		{
			for (name in parms.args)
			{
				if (parms.args[name] !== undefined)
					args.push(name + '=' + parms.args[name]);
			}
		}
	}
	
	// 2a. Add a cachebuster, if requested.
	if (cachebust)
		args.push(cachebust + '=' + (new Date()).getTime());

	// 3. Add credentials
	if (creds)
	{
		creds.crumb	&& args.push('c=' + creds.crumb);
		creds.sessionId && args.push('sid=' + creds.sessionId);
	}

	// 4. Encode args.  This has to be done after adding credentials because
	// they may need encoding
	if (args && args.length)
	{
		args.forEach(function(arg, idx)
			{
				var k,
					v = arg.split('=');
				
				k = v.shift();
				v = encodeURIComponent(v.join('='));

				args[idx] = k + '=' + v;
			});
	}
	
	// 5. Set up headers
	if (session && session.headers[server])
	{
		for (name in session.headers[server])
			headers[name] = session.headers[server][name];
	}

	// Add the X-RID header to all requests.
	headers['X-RID'] = getXRID();

	if (parms.headers)
	{
		for (name in parms.headers)
			headers[name] = parms.headers[name];
	}

	// 6. build the URL
	if (parms.url)
		url = parms.url;
	else if (session)
		url = session.servers[server] + path;
	else
		url = server + path;

	if (typeof url == 'function')
		url = url();

	urlArgs = url.split('?');
	if (urlArgs && urlArgs[1])
	{
		url = urlArgs[0];

		urlArgs = urlArgs[1].split('&');
		urlArgs.forEach(function(arg)
			{
				var k, v,
					s = arg.split('=');

				k = s.shift() + '=';
				v = s.join('=');

				if (!args.some(function(arg) { return arg.indexOf(k) == 0; }))
					args.push(k+v);
			});
	}

	if (args.length)
		url += '?' + args.join('&');

	newParms.url = url;
	
	// 7. stringify the body
	if (body)
	{
		if (typeof(body) == 'object')
		{
			body = JSON.stringify(body);
			headers["Content-Type"] = headers["Content-Type"] || "application/json;charset=utf-8";
		}

		newParms.body = body;
	}

	// 8. Don't allow XML type.  I'm guessing this was to work around some weird
	// IE 6 bug or something.
	if (parms.type == 'xml')
		parms.type = '';

	return newParms;
}

function authChange()
{
	/*jshint validthis:true */

	var session		= this,
		authState	= session.authState;

	switch (authState.membership)
	{
		case Network.AUTH_PENDING:
			removeLoginRequests(session, 0);

			authState.session = authState.crumb = Network.AUTH_WAITING;
			signinWithCreds(session);
			break;

		case Network.AUTH_COMPLETE:
			removeLoginRequests(session, 0);

			session.network.state = Network.LOGGED_IN;
			authState.crumb = Network.AUTH_PENDING;
			break;
	}
}

function getXRID()
{
	var i,
		s = [],
		d = new Date().getTime(),
		r = Math.random() * (1 << 31);		// 1 << 31 == INT_MIN

	for (i = 0; i < 6; i++)
	{
		s.unshift(base32Bits[d & 0x1F]);
		d >>= 5;
		d &= 0x07FFFFFF;					// JS sign extends right shift.  Make sure the high bits are clear
	}

	s.unshift(base32Bits[((r & 7) << 2) + d]);
	r >>= 3;
	r &= 0x1FFFFFFF;

	for (i = 0; i < 6; i++)
	{
		s.unshift(base32Bits[r & 0x1F]);
		r >>= 5;
	}

	return s.join('');
}

function signinWithCreds(session, cb)
{
	cb && cb('not implemented');
}

// error handlers for authCodeMaps to reference
function transientError(o, cb)	{ cb({code:ERR_TRANSIENT, message:"transient error"}); }
function failure(o, cb)			{ cb({code:ERR_FAILURE, message:"generic failure"}); }
function invalid(o, cb)			{ cb({code:ERR_INVALID, message:"invalid password"}); }
function locked(o, cb)			{ cb({code:ERR_LOCKED, message:"account locked"}); }
function special(o, cb)			{ cb({code:ERR_SPECIAL, url: o.url, message:"special handling needed"}); }
function register(o, cb)		{ cb({code:ERR_REGISTER, message:"account does not exist" }); }
function underage(o, cb)		{ cb({code:ERR_UNDERAGE, message:"user is under allowed age" }); }
function slcc(o, cb)			{ cb({code:ERR_SLCC, slcc: o, message:"second login challenge" }); }

// Return falsey if the request should be queued.
function checkRequest(parms)
{
	var session		= parms.session,
		authState	= session.authState,
		server		= parms.server;

	if (session.network.lostNetwork & LN_LOST)
		return 0;

	if (authState.membership == Network.AUTH_COMPLETE)
	{
		return 1;
	}
}

function queueRequest(parms, cb, retryCount, atFront, abortObj)
{
	var session = parms.session,
		a = [parms, cb, retryCount];

	if (atFront)
		session.pending.unshift(a);
	else
		session.pending.push(a);

	abortObj.abort = function(err)
	{
		removeRequest(a);
		a[1] && a[1](arguments.length ? err : netError(1));
	};

	abortObj.queued = 1;
}

function removeRequest(a)
{
	var session = a[0].session,
		idx = session.pending.indexOf(a);

	if (idx != -1)
		session.pending.splice(idx, 1);
}

function dequeueRequest(session)
{
	var req,
		pending = session.pending.splice(0);

	while (pending.length)
	{
		req = pending.shift();
		makeAuthorizedRequest(req[0], req[1], req[2] || 0);
	}
}

function removeLoginRequests(session)
{
	removeRequestsLike(session, "/auth");
}

// Remove pending requests that match the regex.  Note that
// the requests aren't aborted, so the caller's callback will
// never happen.
function removeRequestsLike(session, regex)
{
	var req, url,
		pending = session.pending,
		idx		= 0;

	while (req = pending[idx])
	{
		url = getRequestUrl(req[0]);
		if (url.search(regex) != -1)
			pending.splice(idx, 1);
		else
			idx++;
	}
}

function parseHeaders(headers)
{
	var i, key, value,
		obj = {},
		lines = headers.split(/\r?\n/);
		
	lines.forEach(function(line)
	{
		i = line.indexOf(": ");
		if (i > -1)
		{
			key = line.substr(0,i).toLowerCase();
			value = line.substr(i+2);
			
			if (key in obj)
			{
				if (!(obj[key] instanceof Array))
					obj[key] = [ obj[key] ];

				obj[key].push(value);
			}
			else
				obj[key] = value;
		}
	});

	return obj;
}

// TODO: This is a slightly more capable form of Utils.substitute, except that
// one wants {{}} and doesn't accept dotted names.  Get rid of this, improve that,
// update the templates we're using and start using Utils.substitute.
function expand(str, o, base)
{
	var expanded;

	if (!dust.cache[str])
		dust.loadSource(dust.compile(str, str));

	if (base)
		o = base.push(o);

	dust.render(str, o, function(err, out) { expanded = out; });

	return expanded;
}

// code 1 ==> aborted
//      2 ==> timeout
//		3 ==> HTTP error.  Http status code in 'httpStatus', statusText in 'detail'
//		4 ==> JSON parse error
function netError(code)
{
	return { code: code, module: 'network', source: 'msgr' };
}

function errIs(err, code, module, source)
{
	return (err.module == (module || 'network')
			&& err.source  == (source || 'msgr')
			&& err.code == code);
}

function errIsInternal(err, module, source)
{
	return (err.module == (module || 'network')
			&& err.source  == (source || 'msgr'));
}

})();
