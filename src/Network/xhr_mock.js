/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

"use strict";

var defaultResp,
	OldXhr		= XMLHttpRequest,
	responseSet = [ ],
	recorded	= [ ],
	appMode		= Caffeine.appMode;

Caffeine.XhrMock =
{
	loadResponseSet:	loadResponseSet,
	reset:				reset,
	setDefaultResponse:	setDefaultResponse,
	getRecorded:		getRecorded
};

function loadResponseSet(name)
{
	// Allow eval() in this function
	/* jshint -W061:true */
	var responses,
		req = new OldXhr();

	req.open("GET", 'test/data/' + name, false);
	req.send();
	try
	{
		eval("responses = " + req.responseText);
		responses.forEach(
			function(response)
			{
				responseSet.push(response);
			});
	}
	catch (e)
	{
	}
}

function reset()
{
	responseSet = [ ];
	
	// Use splice here so data change watchers will see the change.
	recorded.splice(0, recorded.length);
}

// Call with no parameters to allow unmatched requests to pass through
// Otherwise, call with a recorded object like:
//	{
//		duration:	100,
//		response:
//		{
//			type:	'application/json',
//			status:	500,
//			data:	{ result: null }
//		}
//	}
function setDefaultResponse(d)
{
	defaultResp = d;
}

function getRecorded()
{
	return recorded;
}

window.XMLHttpRequest = function()
{
	return new XhrMock();
};

function XhrMock()
{
	var _this	= this,
		xhr		= _this.xhr		= new OldXhr(),
		r		= _this.recorded = { request: { headers: [ ] } };

	xhr.onloadend = function()
	{
		_this.onloadend && _this.onloadend();
	};

	xhr.onprogress = function()
	{
		_this.onprogress && _this.onprogress();
	};

	xhr.ontimeout = function()
	{
		_this.ontimeout && _this.ontimeout();
	};

	xhr.onreadystatechange = function()
	{
		_this.readyState = xhr.readyState;

		if (_this.readyState == 4)
		{
			r.duration		= new Date() - _this.sent;
			r.response =
			{
				type:		xhr.responseType,
				status:		xhr.status,
				data:		xhr.responseText,
				headers:	xhr.getAllResponseHeaders().split(/\r?\n/)
			};
			
			if (recorded.length < 10)
				recorded.push(r);

			_this.response		= xhr.response;
			_this.responseText	= xhr.responseText;
			_this.responseType	= xhr.responseType;
			_this.responseXML	= xhr.responseXML;
			_this.status		= xhr.status;
			_this.statusText	= xhr.statusText;
		}

		_this.onreadystatechange && _this.onreadystatechange();
	};
}

XhrMock.prototype =
{
	abort:						abort,
	getAllResponseHeaders:		getAllResponseHeaders,
	getResponseHeader:			getResponseHeader,
	open:						openReq,
	overrideMimeType:			overrideMimeType,
	send:						send,
	setRequestHeader:			setRequestHeader
};

function abort()
{
	/* jshint validthis:true */
	this.xhr.abort();
}

function getAllResponseHeaders()
{
	/* jshint validthis:true */
	return this.xhr.getAllResponseHeaders();
}

function getResponseHeader(header)
{
	/* jshint validthis:true */
	if (this.resp)
	{
		header = header.toLowerCase();
		var result = responseSet.headers.filter(
						function(line)
						{
							var i		= line.indexOf(': '),
								key		= line.substr(0, i).toLowerCase();
								//value	= line.substr(i+2);
							
							return header == key;
						});

		return result.join(', ');
	}
	
	return this.xhr.getResponseHeader(header);
}

// js hint is getting confused by this function if I name it 'open' and telling me
//     xhr_mock.js: 'open' is already defined. (W004)
//     xhr_mock.js: 'open' is defined but never used. (W098)
// Changing the name un-confuses jshint.  It's also getting confused by the
// first line in this comment if it starts with 'jshint', hence the 'js hint'.
function openReq(method, url, async, username, pw)
{
	/* jshint validthis:true */

	console.log("%s:%s", method, url);

	var req		= this.recorded.request;
	req.method	= method;
	req.url		= url;

//	if (url.indexOf('http') != 0)
	{
		this.xhr.open(method, url, async, username, pw);
	}
}

function overrideMimeType(mime)
{
	/* jshint validthis:true */

	this.xhr.overrideMimeType(mime);
}

function send(body)
{
	/* jshint validthis:true */

	var resp,
		_this = this;
	
	_this.sent = new Date();
	if (body)
		_this.recorded.request.body = body;
	
	if (appMode.replay)
	{
		resp = findResponse(_this.recorded.request) || defaultResp;
		if (resp)
		{
			resp.applied = 1;

			setTimeout(
				function()
				{
					_this.resp			= resp;

					_this.readyState	= 4;
					_this.response		= resp.data;
					_this.responseText	= resp.data;
					_this.responseType	= resp.type;
					_this.status		= resp.status;

					_this.onreadystatechange && _this.onreadystatechange();
				}, 
				resp.duration);
				
			return;
		}
	}
	
	this.xhr.send(body);
}

function setRequestHeader(name, value)
{
	/* jshint validthis:true */

	this.recorded.request.headers.push({ name: name, value: value });

	this.xhr.setRequestHeader(name, value);
}

function findResponse(req)
{
	var found;
	
	responseSet.some(
		function(resp)
		{
			var found	= resp,
				respReq = resp.request;
			
			if (resp.applyOnce && resp.applied)
				found = 0;
			
			if (found && 
					(!reqMatch(respReq.method, req.method)
					|| !reqMatch(respReq.url, req.url)
					|| !reqMatch(respReq.body, req.body)))
				found = 0;

			if (found && !respReq.headers.some(
					function(line)
					{
						var i		= line.indexOf(': '),
							key		= line.substr(0, i).toLowerCase(),
							value	= line.substr(i+2);
						
						return req.headers.some(
									function(header)
									{
										return headerMatch(key, value, header.name, header.valueOf);
									});
					}))
				found = 0;
			
			return found;
		});

	return found;

	function reqMatch(resp, req)
	{
		// TODO: Be more flexible here.  Allow resp to be a function or regular expression.
		return resp == req;
	}
	
	function headerMatch(respName, respValue, reqName, reqValue)
	{
		// TODO: Be more flexible here.  Allow resp to be a function or regular expression.
		return respName == respValue && reqName == reqValue;
	}
}

})();
