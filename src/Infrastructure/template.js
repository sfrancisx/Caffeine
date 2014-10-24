/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

/**
 * Template module
 *
 * A slightly higher-level abstraction for using dust templates.
 * Localized strings are made automatically available to templates.
 * If a template contains `{str_localized_string|i}`, the localized string referenced
 * will be processed for variable substitutions.
 *
 * @module Template
 * @namespace Caffeine
 * @class Template
 * @static
 */

(function(){

    Caffeine.Template = {
        render: render,
        renderInto: renderInto,
        renderFasterInto: renderFasterInto,
        renderOuter: renderOuter
    };

    var current_vars,
        iRegEx = /\{([^{}]*)\}/g;
    // So.. if your localized strings use {something|i}, this filter will be called recursively.
    // Not that you should. But you could.
    dust.filters.i = function(value) {
        iRegEx.lastIndex = 0;
        return value.replace(iRegEx,
            function (a, b) {
                var filters = b.split("|"), key = filters.shift();
                var r = current_vars.get(key);
                if (typeof r == "function") {
                    // comment the throw to live on the edge. Note that functions called here will have no access to a Chunk object
                    throw new Error("Template doesn't support function references in a 'i'-filter substitution.");
                    r = r.apply(current_vars.current(), [null, current_vars, null, {auto: null, filters: filters}]);
                }
                if (typeof r !== 'string' && typeof r !== 'number') { return ''; }
                return dust.filter(String(r), null, filters);
            }
        );
    };

	dust.helpers.getDigitalSize = getDigitalSize;
	dust.helpers.evalres = evaluateResources;
	dust.helpers.every = everyHelper;
	dust.helpers.isBidi = function(chunk, context, bodies, parms) {
		if(Caffeine.appMode.locale.indexOf("ar") == 0)
			return bodies.block(chunk, context);
		else if (bodies.else)
			return bodies.else(chunk, context);
		return chunk.write("");
	};


    var Context = dust.makeBase().constructor; // sneak dust's Context type out of their module.

	var contextHelpers = {
		videoEnabled: (Caffeine.appMode.videoEnabled? Caffeine.appMode.videoEnabled : null),
		locale: Caffeine.appMode.locale
	};
    function _render(template, vars) {
        var str;
        vars = Caffeine.Intl.withStrings(Context.wrap(vars));

        vars = vars.push(contextHelpers);

        current_vars = vars;
        dust.render(template, vars, function(err, out) {
            if (err) {
                if (Caffeine.appMode.debug) {
                    str = err;
                }
                console.error("Error rendering "+template, vars, err);
            }
            str = out;
        });
        current_vars = undefined;
        return str;
    }

    /**
     * Return a string resulting from rendering a template against
     * a set of variables.
     *
     * Since this class aims to provide higher-level methods that not
     * only render templates but also use them, wrapping DOM methods that
     * are otherwise considered unsafe, calling this method dumps a warning
     * to the console.
     *
     * If you have a use case that isn't covered by this class and forces you
     * to use this method directly, chances are we need to add another method here.
     *
     * @method render
     * @params {string} template The name of a dust.js template
     * @params {object} vars     A set of variables to apply
     */
    function render(template, vars) {
        console.warn("Raw Template.render called.",template, vars);
        return _render(template, vars);
    }

    /**
     * Process a template against a set of variable and render it within a DOM element.
     *
     * @method renderInto
     * @params {string} template The name of a dust.js template
     * @params {object} vars     A set of variables to apply
     * @params {elt}    Element  A DOM element to target
     */
    function renderInto(template, vars, elt) {
        var str = _render(template, vars);
        if (elt)
            elt.innerHTML = str;
        else
            return str;
        
        return str != null;
    }

    /**
     * Process a template against a set of variable and render it within a DOM element.
     *
     * Note: This method is about 2x faster than renderInto BUT it trashes the
     * element passed, and return a new one that must be used in its stead.
     *
     * @method renderInto
     * @params {string} template The name of a dust.js template
     * @params {object} vars     A set of variables to apply
     * @params {elt}    Element  A DOM element to target
     */
    function renderFasterInto(template, vars, elt) {
        var str = _render(template, vars);
        return Caffeine.DomUtils.setInnerHTML(elt, str);
    }

    /**
     * Process a template against a set of variable and render it by replacing a DOM element.
     *
     * @method renderOuter
     * @params {string} template The name of a dust.js template
     * @params {object} vars     A set of variables to apply
     * @params {elt}    Element  A DOM element to replace
     * @returns {elt}	A new DOM element generated from the templating
     */
    function renderOuter(template, vars, elt) {
        var str = _render(template, vars);
        return Caffeine.DomUtils.setOuterHTML(elt, str);
//        elt.outerHTML = str;
//        return str != null;
    }

	/**
	 * Dust helper to convert a number to human readable size. For example 1024 to 1k.
	 * usage {#getDigitalSize size=1024 /}. The value of size can be a context field
	 */
	var digNoms = [ "str_attach_filesize_bytes", "str_attach_filesize_kb", "str_attach_filesize_mb", "str_attach_filesize_gb", "str_attach_filesize_tb", "str_attach_filesize_pb" ];
	function getDigitalSize(chunk, context, bodies, parms) {
		var size = parseInt(parms.size),
			place, num,
			dSize = "";

		if(size) {
			place = Math.floor( Math.log(size) / Math.log(1024) );
			if(place > 0) {
				num = size / Math.pow(1024, place);
				if(place > 2) {
					//if its gb or above show two decimal points
					num = Math.round( num * 100 );
					num = num / 100;
				} else {
					num = Math.ceil( num );
				}
				dSize = num + context.get(digNoms[place]);
			} else {
				dSize = size + context.get(digNoms[0]);
			}
		}

		return chunk.write(dSize);
	}

	/**
	 * Dust helper to evaluate resource string with context
	 * usage {@evalres text="{str_gtc_tab_display_name}" /}
	 * This one keeps the context where as "i" filter doesn't and resets the context to the root.
	 */
	function evaluateResources(chunk, context, bodies, parms) {
		var text = dust.helpers.tap(parms.text, chunk, context);

		iRegEx.lastIndex = 0;
        text = text.replace(iRegEx,
            function (a, b) {
				var val = context.get(b),
					helper, newChunk;
				if(typeof val === "function") {
					return val(chunk, context, bodies, parms);
				} else if( val === undefined) {
					helper = dust.helpers[b];
					if(helper) {
						newChunk = createFakeChunk();
						helper(newChunk, context, bodies, parms);
						return newChunk.read();
					}
				} else {
					return val;
				}
            }
        );
		
		return chunk.write(text);
	}

	function createFakeChunk() {
		var text = "";
		return {
			write: function(val) {
				text += val;
			}, 
			read: function() {
				return text;
			}
		};
	}

	/**
	 * Dust helper to check a property equal to the value supplied for every item in an array
	 * usage 
	 * {@every list=<array> keypath=<property path> value=<value to be checked>}
	 *	<body block>
	 * [{:else}]
	 *  <else block>
	 * {/every}
	 */
	function everyHelper(chunk, context, bodies, parms) {
		var list	= dust.helpers.tap(parms.list, chunk, context),
			keypath		= dust.helpers.tap(parms.keypath, chunk, context),
			keys = keypath.split("."),
			value	= dust.helpers.tap(parms.value, chunk, context),
			bit = dust.helpers.tap(parms.bit, chunk, context),
			passed;

		passed = list.every(function(item) {
			var obj = item;
			keys.forEach(function(key) {
				obj = obj && obj[key];
			});
			return bit ? obj & Caffeine.Comms[bit] : obj == value;
		})

		if(passed) {
			chunk.render(bodies.block, context);
		} else {
			chunk.render(bodies["else"], context);
		}

		return chunk;
	}

})();
