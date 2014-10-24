/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

"use strict";

/*
	var oldStringify = JSON.stringify;
	JSON.stringify = function(o, replacer, space)
	{
		var s = oldStringify.call(JSON, o, replacer, space);

		if (o && o.__proto__ != {}.__proto__ && o.__proto__ != [].__proto__)
		{
			// TODO: This assumes the prototype is an object.  It could be an array or
			// another JS type.
			s = s.substr(0, s.length-1);
			if (s.substr(-1) != '{')
				s = s + ',';
			s += '"__proto__":';

			s += JSON.stringify(o.__proto__, replacer, space) + "}";
		}

		return s;
	};
*/

	Caffeine.Utils =
	{
		strIsAllAscii: function (str) {
			return  /^[\000-\177]*$/.test(str);
		},
	
		toJSON: function(o, replacer, space)
		{
			var s = JSON.stringify(o, replacer, space);

			if (o && o.__proto__ != {}.__proto__ && o.__proto__ != [].__proto__)
			{
				// TODO: This assumes the prototype is an object.  It could be an array or
				// another JS type.
				s = s.substr(0, s.length-1);
				if (s.substr(-1) != '{')
					s = s + ',';
				s += '"__proto__":';

				s += Caffeine.Utils.toJSON(o.__proto__, replacer, space) + "}";
			}

			return s;
		},

		/**
		 * Copy properties from `src` to `dest`.  Similar to YUI's `aggregate()`, `augment()`
		 * or `mix()` methods (I'm unclear why YUI has so many methods to do this...)
		 * Mixing objects is genrally a really bad idea, so you should have a really good
		 * reason before using this.
		 *
		 * @method mix
		 * @param dest {object}		The object getting modified
		 * @param src {object}		The object who's properties get copied
		 * @param [fields] {array}	Subset of `src` fields to mix
		 * @param [deep] {truthy}	If truthy, mix sub-objects.  `fields` is only applied to the root object.
		 */
		mix: function(dest, src, fields, deep)
		{
			fields = fields || Object.keys(src);
			fields.forEach(function(name)
				{
					if (src.hasOwnProperty(name))
					{
						if (deep && src[name] && (typeof src[name] == 'object'))
						{
							dest[name] = dest[name] || { };
							Caffeine.Utils.mix(dest[name], src[name], 0, deep);
						}
						else
							dest[name] = src[name];
					}
				});
		},

		getObject: function(name, o)
		{
			if (typeof name != 'string')
				return name;

			o = o || window;

			name = name.split('.');

			while (o && name.length)
				o = o[name.shift()];

			return o;
		},

		trimArray: function(idx, a1, a2)
		{
			if (a1)
			{
				a1[idx] = 0;

				idx = a1.length;
				while (idx && !a1[idx-1])
				{
					a1.pop();
					a2 && a2.pop();
					idx--;
				}

				return idx;
			}
		},

		/**
		 * @method setFlags
		 * @param flags		Initial value of the flags
		 * @param value		Bits to set/clear.
		 * @param mask		Bits that will be modified.  Falsy value will just set bits.
		 *
		 * Set and clear flags in a single operation
		 */
		setFlags: function(flags, value, mask)
		{
			var o;

			if (typeof flags == 'object')
			{
				o = flags;
				flags = o.flags;
			}

			// Not mask = mask || value, because 0 is a valid mask.
			if (mask === undefined)
				mask = value;

			// Set any bits that are set in both the mask and the new value
			flags |= (mask & value);

			// Now clear any bits that are clear in the mask and the new value
			flags &= (~mask | value);

			if (o)
				o.flags = flags;

			return flags;
		},

		/**
		 * @method checkFlags
		 * @param flags		Flags
		 * @param value		Value that must match 'flags'
		 * @param mask		Bits to check.
		 *
		 * Check flags for both set & cleared bits in a single operation.
		 */
		checkFlags: function(flags, value, mask)
		{
			if (typeof flags == 'object')
				flags = flags.flags;
			if (typeof value == 'object')
				value = value.flags;

			if (flags === undefined)
				return false;
			if (value === undefined)
				return true;

			// Not mask = mask || value, because 0 is a valid (though weird) mask.
			if (mask === undefined)
				mask = value;

			return (flags & mask) == (value & mask);
		},

		/**
		 *
		 * @method interject
		 */
		interject: function(o, name, f)
		{
			var old = o[name];

			o[name] = function()
						{
							f.apply(this, arguments);
							old.apply(this, arguments);
						};
		},

		substitute: function(str, obj)
		{
			return str.replace(/\{\{([^{}]*)\}\}/g,
				function (a, b)
				{
					var r = obj[b];
					return typeof r === 'string' || typeof r === 'number' ? r : a;
				});
		},

		/**
		 * Wrap an async function into another function with identical semantics.
		 * The function is expected to match this jsig:
		 * (params: Object, callback: (err: Object, data: Object))
		 * 
		 * Using the wrapped function will unceremoniously dump its input, output and errors to the console.
		 * 
		 * @param name
		 * @param f
		 * @returns f'
		 */
		consoleWrap: function (name, f) {
	        return function(params, callback) {
				/* jshint validthis:true */
	            console.log(name+" params:", params);
	            if (!callback) { 
	                callback = params.callback;
	                params.callback = wrappedCallback;
	            }
	            try {
	                f.call(this, params, wrappedCallback);
	            } catch(e) {
	                console.error(name+" threw:",e);
	                throw e;
	            }
	            function wrappedCallback(err, data){
	                console.log(name+" response:", err, JSON.stringify(data));
	                callback.call(this, err, data);
	            }
	        };
	    },

		// TODO: Remove this function, use sendRequest() instead.
	    requestFile: function(url, callbackFn) {
	    	var xmlhttp=new XMLHttpRequest();
	    	xmlhttp.onreadystatechange=function() {
	    		if (xmlhttp.readyState==4) {
	    			if (xmlhttp.status==200 && callbackFn.success)
	    				callbackFn.success(xmlhttp.responseText);
	    			else if (xmlhttp.status==404 && callbackFn.error)
	    				callbackFn.error();
	    	    }
	    	};
	    	xmlhttp.open("GET", url,true);
	    	xmlhttp.send();
	    },
	    
		/** Returns image css transform string based on orientation
		*
		*/

		getImageTranform: function(orientation, imgWidth, imgHeight) {
			var transformStr = "",
				diff = (imgWidth - imgHeight) / 2;

			switch(orientation) {
			case 5:
				transformStr = "scale(-1, 1) rotate(90deg)" + ( diff > 0 ? " translateX(" + diff + "px) translateY(-" + diff + "px)" : " translate(" + diff + "px)" );
				break;
			case 6:
				transformStr = "rotate(90deg)" + (diff > 0 ? " translateX(" + diff + "px) translateY(" + diff + "px)" : " translate(" + diff + "px)");
				break;
			case 7:
				transformStr = "scale(1, -1) rotate(90deg)" + (diff > 0 ? " translateX(-" + diff + "px) translateY(" + diff + "px)" : " translate(" + (diff * -1) + "px)");
				break;
			case 8:
				transformStr = "rotate(-90deg)" + (diff > 0 ? " translateX(-" + diff + "px) translateY(-" + diff + "px)" : " translate(" + (diff * -1) + "px)");
				break;
			}

			return transformStr;
		}

	};

})();
