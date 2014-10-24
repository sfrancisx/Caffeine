/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

// This file has JavaScript that CEF needs/uses which does not have to be part
// of CEF's extension.
//
// If you want to have JS events forwarded to CEF, this is the place to do it.

(function(){

"use strict";

var CEFContext				= Caffeine.CEFContext,
	setPersistentValue		= CEFContext.setPersistentValue,
	getPersistentValue		= CEFContext.getPersistentValue,
	getAllPersistentValues	= CEFContext.getAllPersistentValues;

CEFContext.setPersistentValue = function(key, value)
{
	if (value === undefined)
		CEFContext.removePersistentValue(key);
	else
		setPersistentValue(key, JSON.stringify(value));
};

CEFContext.getPersistentValue = function(key)
{
	try
	{
		var value = getPersistentValue(key);
		if (value)
			return JSON.parse(value);
	}
	catch (e)
	{
		// catch parse errors, but ignore them.
	}
};

CEFContext.getAllPersistentValues = function()
{
	var values	= getAllPersistentValues(),
		names	= Object.keys(values);

	names.forEach(
		function(name)
		{
			try
			{
				values[name] = JSON.parse(values[name]);
			}
			catch (e)
			{
				values[name] = undefined;
			}
		});

	return values;
}


})();
