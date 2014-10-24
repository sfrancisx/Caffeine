/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

/*jshint proto:true */
/**
 * Internationalization module
 * 
 * @module Infrastructure
 * @namespace Caffeine
 * @class Intl
 * @static
 */

(function(){
    "use strict";
    
    var store = {
        locale: undefined
    };
    var strings = {};
    
    Caffeine.Intl = {
        getLocale: getLocale,
        setLocale: setLocale,
        withStrings: withStrings,
        get: getString,
        createCollator: createCollator,
        createNumberFormatter: createNumberFormatter,
        createDateFormatter: createDateFormatter
        // @event: localeChange
    };
    
    var Intl = window.Intl || window.v8Intl || {
        // fallback object, indicative that we're not in a happy environment.
        // things are unlikely to localize as well as usual here.
        Collator: function() {
            return {
                compare: function(a,b) {
                    return String(a).localeCompare(String(b), [store.locale]);
                }
            };
        },
        NumberFormat: function(options) {
            return {
                format: function(number) {
                    return number.toLocaleString([store.locale], options);
                }
            };
        },
        DateTimeFormat: function(options) {
            return {
                format: function(date) {
                    return date.toLocaleString([store.locale], options);
                }
            };
        }
    };
    
    // slave intls need to ask the master what locale we're using
    if (Caffeine.appMode.slave) {
        if (Caffeine.appMode.locale) {
            _setLocale(Caffeine.appMode);
//            console.log("INTL LOADING, locale known: ", store.locale)
        } else {
//            console.log("INTL LOADING (but no locale available yet)")
        }
        // necessary either way to obtain a synchronized object to watch
        Caffeine.IPC.remoteCall('main', "Caffeine.Intl.getLocale",{}, function(err, data) {
            Ether.Event.onChange(data, {"locale": function(){
                _setLocale(this);
            }});
            if (store.locale != data.locale) {
                _setLocale(data);
            }
        });
    } else {
        Caffeine.IPC.synchronizeObject(store);
    }
    
    /**
     * Returns an object containing a "locale" member.
     * Please treat that member as read-only.
     * 
     * Note: You can listen for changes on that object to be
     * notified as soon as the locale is changed.
     * Alternatively, you can listen for "localeChange" events on
     * Caffeine.Intl itself to be notified when a new locale is
     * ready to be used.
     * 
     * @method getLocale
     * @params {object} params Not used
     * @params {function} cb   A function to call back with the object
     */
    function getLocale(params, cb) {
        cb(null, store);
    }
    
    // internal variant of setLocale, does not validate input,
    // has no slave/master awareness.
    function _setLocale(params, cb) {
        store.locale = params.locale;
        Caffeine.appMode.locale = params.locale;
        refreshStrings({}, function(err){
            if (err) { return cb&&cb(err); }
            Ether.Event.fire(Caffeine.Intl, "localeChange", store.locale);
            cb&&cb();
        });        
    }
    
    /**
     * Loads a locale-based string file.
     * Emits a "localeChange" event on completion.
     * 
     * @method setLocale
     * @params {string} locale  A locale to load strings for
     * @params {function} cb    A function to call back when loading is complete
     */
    function setLocale(params, cb) {
        if (!params.locale) {
            return cb(new Error("Invalid locale specified"));
        }
        if (store.locale == params.locale) {
            return cb && cb();
        }
        if (Caffeine.appMode.master) {
            _setLocale(params, cb)
        } else {
            Caffeine.IPC.remoteCall('main', "Caffeine.Intl.setLocale", params, function() {
                _setLocale(params, cb)
            });
        }
    }
    
    // we use XHR here, but only to grab local files.
    // as such, this escapes the reach of the Network::transport module
    // also, this is now synchronous to help enforce we load early enough.
    function refreshStrings(params, cb) {
        var rcvd = false;
        var req = new XMLHttpRequest();
        var url = "strings/" + store.locale + "/app.resjson";
        if ( typeof isCEF === "undefined" )  {
        	url = "/"+url;
        }
        req.open("GET", url, false);
        req.send();
        //if (req.status == 200) {
            try {
                strings = eval("strings="+req.responseText);
            } catch (e) {
                return cb(e);
            }
            cb();
        //}
    }
    /**
    * Make localized strings accessible on a literal object or a dust Context object.
    * Using this on objects given to dust templates allows those templates to access localized strings easily.
    * 
    * @method withStrings
    * @params {object} obj The object to add strings to.
    */
    function withStrings(obj) {
        if (obj.constructor.name == "Context") {
            return obj.push(strings);
        } else {
            obj.__proto__ = strings;
            return obj;
        }
    }
    /**
    * Return a single localized string
    * 
    * @method get
    * @params {string} id The id of the string to get.
    */
    function getString(id) {
        console.assert(store.locale);
        return strings[id];
    }
    
    /**
     * Create and return a collator object, using the 
     * preset locale, with an optional settings object.
     * 
     * To use:
     * 
     *      Caffeine.Intl.setLocale("fr-FR", function() {  
     *          var collator = Caffeine.Intl.createCollator();  
     *          my_array.sort(collator.compare);  
     *      });
     * 
     * For settings to use and details: 
     * http://www.ecma-international.org/ecma-402/1.0/#sec-10
     * 
     * @method createCollator
     * @params {object} options Options to use for the collator.
     */
    function createCollator(options) {
        console.assert(store.locale);
        var c = new Intl.Collator([store.locale], options);
        return c;
    }
    
    function createNumberFormatter(options) {
        console.assert(store.locale);
        var f = new Intl.NumberFormat([store.locale], options);
        return f;
    }
    
    function createDateFormatter(options) {
        console.assert(store.locale);
        var f = new Intl.DateTimeFormat([store.locale], options);
        return f;
    }
    
})();
