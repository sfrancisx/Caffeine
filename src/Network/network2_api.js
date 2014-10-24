/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

"use strict";

var proxiedFunc = 'proxiedFunc';

if (Caffeine.Network)
	return;

Caffeine.Network =
{
	signin:					proxiedFunc,
	makeAuthorizedRequest:	proxiedFunc,
	getRequestUrl:			proxiedFunc,
	signout:				proxiedFunc,
	sendRequest:			proxiedFunc,

	setServer:				proxiedFunc,
	setLoginServer:			proxiedFunc,

	requestImage:			0,
	clearImageQueue:		0,

	// Externally, you're either logged in or not.  The session doesn't get returned until
	// you're logged in, so there's no 'pending' state.  You can't make requests when
	// a logout is pending, so you're effectively logged out.
	LOGGED_IN:			1,
	LOGGED_OUT:			2,		// Once you're logged out, that's it.  You can't re-login
								// to a session. The only way to get logged out is to call
								// signout().
	LOGIN_ERROR:		3,		// LOGGED_IN can transition to LOGIN_ERROR

	// Authorization states.  These will probably only be used internally.
	AUTH_IDLE:			1,		// We haven't had the need to get this authorization yet
	AUTH_WAITING:		2,		// We're waiting for some other authorization to finish before proceeding
	AUTH_PENDING:		3,		// The request is outstanding
	AUTH_COMPLETE:		4,		// Good to go
	AUTH_ERROR:			5,		// Authorization error
	AUTH_EXPIRED:		6,		// The authorization has expired and needs to be renewed

	// Bits for network.lostNetwork.  These also have to match the corresponding comms2_api.js values.
	LN_LOST:			1 << 0,
	LN_NO_HANGING_GET:	1 << 1,

	ERR_TRANSIENT:		1,
	ERR_FAILURE:		2,
	ERR_INVALID:		3,
	ERR_CAPTCHA:		4,
	ERR_LOCKED:			5,
	ERR_SPECIAL:		6,
	ERR_REGISTER:		7,
	ERR_UNDERAGE:		8,
	ERR_SLCC:			9,
	ERR_INVALID_YID:	10
};

})();
