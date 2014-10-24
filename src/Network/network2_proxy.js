/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function() {
	
"use strict";

setupProxy(Caffeine.Network, "Caffeine.Network");

// clone a complex yet literal structure, replace every function with a proxy method
function setupProxy(base, basename)
{
	var obj = base;// instanceof Array?[]:{};
	Object.keys(base).forEach(function(key)
		{
			var val = base[key], 
				name = [basename, key].join(".");
				
			if (typeof val == "object" && val)
				obj[key] = setupProxy(val, name);
			else if (val == 'proxiedFunc')
			{
				//alert('binding ' + name);
				obj[key] = RPCDefine.bind(null, name);
			}
			else
				obj[key] = val;
		});

	return obj;
}

function RPCDefine(name, params, cb)
{
	cb = cb || function() {};
	Caffeine.IPC.remoteCall('main', name, params, cb);
}
	
})();
