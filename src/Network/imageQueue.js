/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

'use strict';

var Network	= Caffeine.Network,
	Utils	= Caffeine.Utils,
	queues	= { },
	els		= Ether.registry();

Utils.requestImage = requestImage;
Utils.clearImageQueue = clearImageQueue;

Network.requestImage = requestImage;
Network.clearImageQueue = clearImageQueue;

/**
 * @param {string}	[parms.queue]
 * @param {int}		[priority]				Clear only items with this priority
 */
function clearImageQueue(parms, cb)
{
	var name = parms.queue || 'default',
		queue = queues[name] || [ ];

	queue.forEach(function(item)
		{
			if (item && (parms.priority === undefined || item.priority == parms.priority))
			{
				item.forEach(function(parm)
					{
						els.remove(parm.el);
					});

				item.length = 0;
			}
		});

	cb && cb();
}

/**
 * @param {HTMLElement|string}	el				element
 * @param {string}				url				url of the image
 * @param {string}				attr			attr to set when the image is loaded
 * @param {string}				[parms.server]	
 * @param {string}				[parms.path]		
 * @param {object}				[parms.context]	
 * @param {int}					[priority]
 * @param {string}				[queue]
 * @param {boolean}				front
 * @param {int}					maxFetches
 * @param {array[string]}		args			additional query parms to add to the URL
 * @param parms.headers
 * @param parms.timeout
 */
function requestImage(parms, cb)
{
	parms.queue		= parms.queue || 'default';
	parms.priority	= parms.priority || 0;
	parms.cb		= cb;

	var queue, i,
		registered	= els.get(parms.el),
		old			= registered.parms;

	if (old)
	{
		queue = queues[old.queue][old.priority];
		// clearing a queue will remove everything in it.
		if (queue)
		{
			i = queue.indexOf(old);
			queue.splice(i, 1);
		}
	}

	registered.parms = parms;
		
	queue = queues[parms.queue] = queues[parms.queue] || [ ];
	queue.maxFetches = parms.maxFetches || queue.maxFetches || 5;

	queue = queue[parms.priority] = queue[parms.priority] || [ ];

	parms.front && queue.shift(parms);
	parms.front || queue.push(parms);
	
	pumpQueues();
}

function pumpQueues()
{
	var name, queue, maxFetches, priority, items, item;

	// The app is closing.  Stop fetching images.
	if (Caffeine.closing)
		return;

	for (name in queues)
	{
		queue = queues[name];
		maxFetches = queue.maxFetches;
		priority = 0;
		
		while (maxFetches && (priority < queue.length))
		{
			var i = 0;
			
			items = queue[priority++] || [];
			
			while (maxFetches && (item = items[i++]))
			{
				if (item.fetching)
					maxFetches--;
			}
			
			i = 0;
			while (maxFetches && (item = items[i++]))
			{
				if (!item.fetching)
				{
					fetch(item);
					maxFetches--;
				}
			}
		}
	}
}

function fetch(item)
{
	item.fetching = 1;

	if (Caffeine.appMode.slave && (typeof item.url == 'function'))
		item.url = item.url();

	Network.sendRequest(item,
		function(err, data, headers)
		{
			var el		= item.el,
				queue	= queues[item.queue][item.priority],
				i		= queue.indexOf(item),
				url		= item.url;
				
			queue.splice(i, 1);

			pumpQueues();
			
			if (!err)
			{
				el = item.el;
				if (typeof el == 'string')
					el = document.querySelector(el);
				
				if (typeof url == 'function')
					url = item.url();

				if (el)
				{
					if (item.attr)
						el.style[item.attr] = "url("+url+")";
					else
						el.src = url;
				}
			}

			try
			{
				item.cb && item.cb(
					err || (el ? 0 : { msg: 'element not found' }),
					{
						data:		data,
						headers:	headers
					});
			}
			catch (e)
			{
			}
		});
}

})();
