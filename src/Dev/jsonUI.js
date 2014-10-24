/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){
"use strict";

var data, parent, struct, seen, names, formatter, title,
	changes = 0,
	renders = 0;

Caffeine.JsonUI =
{
	init: function(parms, cb)
	{
		parent	= parms.parent;
		data	= parms.data;
		struct	= parms.structure;
		formatter = parms.formatter || function(name, v) { return v; };

		title	= title || document.title;

		parent.style.cssText = "white-space: pre;background-color:white";
		render();
		
		Ether.Event.onDeepChange(data, reRender);
		if (data instanceof Array)
			Ether.Event.onArrayChange(data, reRender);
		cb && cb();

		function reRender()
		{
			changes++;
			document.title = "Rendering...";
			Ether.Event.queueHandler(render, 20);
		};
	}
};

function render()
{
	renders++;

	try
	{
		seen = [ ];
		names = [ ];
		var d = decircularize(data, struct, '');
		parent.innerHTML = JSON.stringify(d, replacer, '\t');

		document.title = title + ' Changes: ' + changes + ', Renders: ' + renders;
	}
	catch (e)
	{
		parent.innerHTML = e.toString();
	}
}

function replacer(key, value)
{
	/* jshint validthis:true */

	if (this[key] instanceof Date)
		return this[key].toString();

	return value;
}

function decircularize(data, struct, fullname)
{
	var name, v, structName, nextname, idx,
		d2 = { };

	if (typeof struct != 'object')
		struct = 0;

	for (name in data)
	{
		nextname = (fullname ? fullname + '.' : '') + name;

		structName = name;
		if (struct && !(name in struct))
		{
			if (!Object.keys(struct).some(testKey))
				continue;
		}

		v = data[name];

		if (v instanceof Date)
			d2[name] = formatter(nextname, v, data);
		else if (v && (typeof v == 'object'))
		{
			idx = seen.indexOf(v);
			if (idx == -1)
			{
				seen.push(v);
				names.push(nextname);
				d2[name + "<a name='" + nextname + "'></a>"] = decircularize(v, struct ? struct[structName] : null, nextname);
			}
			else
				d2[name] = "<a href='#" + names[idx] + "'>&lt;" + names[idx] + "&gt;</a>";
		}
		else
			d2[name] = formatter(nextname, v, data);
	}

	return d2;

	function testKey(key)
	{
		if (RegExp(key).test(name))
		{
			structName = key;
			return true;
		}
		console.log(name + ' does not test against ' + key);
	}
}

})();
