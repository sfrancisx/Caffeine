/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

Caffeine.preferences =
{
	set: function(parms, cb) { Caffeine.IPC.remoteCall('main', { obj: Caffeine.preferences, fn: 'set' }, parms, cb); },
	setPerUser: function(parms, cb) { Caffeine.IPC.remoteCall('main', { obj: Caffeine.preferences, fn: 'setPerUser' }, parms, cb); }
};
