/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

"use strict";

/**
 * The preferences manager.  'Preferences' is a bad name (as are all of my names...)  This is the
 * persistant storage manager.  Use it to store everything you want stored persistently.
 *
 * **Consuming preferences:**
 *
 * Preferences are stored in a normal JavaScript object named `Caffeine.preferences`.
 * To read a preference, simply read it from the object.  You can subscribe to change
 * events on the object like any other JS object.
 *
 * You cannot write preferences by modifying the `Preferences` object.  (Modifying a preference
 * is (possibly) an asynchronous operation.  Changing a preference with a simple assignment would
 * imply that the change happens synchronously, which isn't true.)  Use `Caffeine.Preferences.set()`
 * to modify a preference.
 *
 * **Creating preferences:**
 *
 * Any new preference has to be added to the `defaults` object in preferences.js.  Setting an unknown
 * preference (i.e. one which isn't in the `defaults` object) will fail.  Normally this applies to _any_
 * additional preference, so you can't add new values to an existing object.  To specify that you should be
 * able to do so, you must specify it in the `characteristics` object by setting the `EXTENDABLE` flag.
 * Don't use `EXTENDABLE` as a way to be lazy.  It's intended for things like which "groups are collapsed" -
 * the member names might include the group name, so they won't be known in advance.
 *
 * Other flags in addition to `EXTENDABLE` include flags to indicate where to store the preference: `GLOBAL`,
 * `CLOUD` and `DEFAULT`.  `GLOBAL` preferences are available at launch and are shared by all users.  `DEFAULT`
 * preferences aren't saved anywhere.  They're called "default" because they're initialized from the `defaults`
 * object on every launch.  `CLOUD` preferences are stored on the Caffeine preferences server.  These
 * preferences will be shared across machines for a particular user.  There's one (big) gotcha with CLOUD
 * preferences: they're fetched asynchronously.  When the user signs in, we immediately fetch a local copy of
 * cloud preferences and we simultaneously make a network request to get them from the preferences server. Any
 * changes made before the fetch completes will be overwritten.
 *
 * The last flag is `DOTTED`.  This indicates that the name of the preference can include dots.  Normally a dot
 * indicates a sub-object.  For `EXTENDABLE` preferences, the names may not be under your control and they may
 * contain dots.
 *
 * **Removing preferences:**
 *
 * There's no direct method for removing a preference.  Currently, preferences will be removed if you set
 * them to 'undefined' (this is a side-effect of the fact that I call JSON.stringify() to store preferences).
 * Let me (sfrancis@) know if you need a more direct method.
 *
 * @module Infrastructure
 * @namespace Caffeine
 * @class Preferences
 * @static
 */
var storageKey,
	defaults =
	{
		windows:
		{
			sizes:
			{
				main:	 { left: 100, top: 100, width: 300, height: 600 },
				default: { left: 450, top: 120, width: 700, height: 400 }
			}
		},
		app:
		{
			enableToast:	 1,
			userPrefsReady:	 0,
			cloudPrefsReady: 0,
			deviceId:		 0,
			statThrottle:	 1.0,
			theme:			"default"
		},
		configs:			{ },
		systemConfigs:		{ },
		cloudConfigs:		{ },
	},
	GLOBAL		= 1 << 0,
	CLOUD		= 1 << 1,
	DEFAULT		= 1 << 2,		// Preference isn't saved anywhere - it will always be initialized to its default value.
	ALL_LOCS	= GLOBAL | CLOUD | DEFAULT,
	EXTENDABLE	= 1 << 3,
	DOTTED		= 1 << 4,
	characteristics =
	{
		windows:
		{
			sizes:
			{
				main:				{ flags: GLOBAL },
				default:			{ flags: GLOBAL }
			}
		},
		app:
		{
			enableToast:	 { flags: CLOUD },
			localPrefsReady: { flags: DEFAULT },
			cloudPrefsReady: { flags: DEFAULT },
			deviceId:		 { flags: GLOBAL },
			statThrottle:    { flags: DEFAULT },
			theme:			 { flags: GLOBAL }
		},
		configs:			{ flags: EXTENDABLE | DOTTED },
		systemConfigs:		{ flags: GLOBAL | EXTENDABLE | DOTTED },
		cloudConfigs:		{ flags: CLOUD | EXTENDABLE | DOTTED }
	};

setGlobalPrefs();

function setGlobalPrefs()
{
	var globalPrefs;

	Caffeine.preferences =
	{
		set:			set,
		setKey:			setKey,
		setPerUser:		setPerUser,
		noFuncSync:		1
	};

    globalPrefs = Caffeine.CEFContext.getPersistentValue('globalPrefs');
	globalPrefs = globalPrefs || { };
	
	getPrefs(globalPrefs, defaults, GLOBAL);
	getPrefs(globalPrefs, defaults, DEFAULT);

	Caffeine.Utils.mix(Caffeine.preferences, globalPrefs, 0, 1);
	Caffeine.IPC.synchronizeObject(Caffeine.preferences);
}

/**
 *
 */
function setKey(parms)
{
	var p, preferences;
	
	if (storageKey)
	{
		p = { };

		getPrefs(p, Caffeine.preferences, GLOBAL);
		getPrefs(p, defaults, DEFAULT);			// TODO: More verification of default prefs
		copyObjectStruct(Caffeine.preferences, p);
	}
	
	storageKey = parms.key;

    preferences = Caffeine.CEFContext.getPersistentValue(storageKey);
	preferences = preferences || { };
	getPrefs(preferences, defaults, 0);
	Caffeine.Utils.mix(Caffeine.preferences, preferences, 0, 1);

	// Cloud preferences get stored locally, too, so they'll be available
	// immediately after launch.
    preferences = Caffeine.CEFContext.getPersistentValue(storageKey + '_cloud');
	preferences = preferences || { };
	getPrefs(preferences, defaults, CLOUD);
	Caffeine.Utils.mix(Caffeine.preferences, preferences, 0, 1);

	Caffeine.IPC.resynchronizeObject(Caffeine.preferences);

	// TODO: This check is here for the unit tests.  Fix the tests & remove this.
	if (Ether.Event && Ether.Event.fire)
	{
		Ether.Event.fire(Caffeine.preferences, "UserPreferencesReady");
		Caffeine.preferences.app.userPrefsReady = 1;
	}
}

/**
 * Change the value of a preference
 *
 * @method set
 * @param {object} pref			The preference to set
 *   @param {string} pref.name	The name of the preference
 *   @param {any} pref.value	The new value of the perference
 * @param {function} [cb]		A callback function to be notified when the preference has been set
 *   @param {object} cb.err		If falsey, indicates no error.  Otherwise it will be a
 *								standard error object.
 *
 * @example
 *
 *		// This code assumes 'wndSizes' is an extendable preference.  Extendable preferences
 *		// can include default values (i.e. we could guarantee that wndSizes.conversation will
 *		// exist by including it in the 'defaults' object even though `wndSizes` is extendable)
 *		// but this code assumes that hasn't been done.  Instead, it illustrates one way to
 *		// provide a default value for an extendable preference.
 *		var wndSizes = Caffeine.Preferences.wndSizes,
 *			csize	 = wndSizes.conversation || wndSizes.default;
 *
 *		Caffeine.Desktop.popupWindow({ width: wndSize.width; height: wndSize.height });
 *
 *		// Set a new default width for wndSizes.conversation
 *		Caffeine.Preferences.set( { name: 'wndSizes.conversation.width', value: 500 } );
 *
 *		// Set a new default size for wndSizes.conversation
 *		Caffeine.Preferences.set( { name: 'wndSizes.conversation', value: { width: 500, height: 400 } } );
 *
 */
function set(args, cb)
{
	var member, error, f, p,
		name = args.name.split('.'),
		preferences = Caffeine.preferences,
		pref = preferences,
		chars = characteristics;

	// Find 'name' in both preferences & characteristics
	while (pref && (name.length > 1) && (!(f & DOTTED)))
	{
		member = name.shift();

		pref = pref[member];
		chars = chars && chars[member];
		f = (chars && chars.flags) || f;
	}

	member = name.join('.');
	
	// If it's already there, update it.  Otherwise, make sure it's
	// an extendable preference.
	if (pref && pref.hasOwnProperty(member))
	{
		if (equivalent(pref[member], args.value))
		{
			//console.warn("Not setting preference.  Old value:");
			//console.warn(pref[member]);
			//console.warn('New value:');
			//console.warn(args.value);

			cb && cb('preference value already set');
			return;
		}

		if (pref[member] && typeof pref[member] == 'object')
			Caffeine.Utils.mix(pref[member], args.value);
		else
			pref[member] = args.value;
	}
	else if (chars && (chars.flags & EXTENDABLE))
	{
		pref[member] = args.value;
		Caffeine.IPC.resynchronizeObject(pref);
	}
	else
		error = { error: 'no such preference' };

	chars = chars && chars[member];
	f = (chars && chars.flags) || f;

	// TODO: This is a temporary hack so we won't apply preferences
	// from the cloud when they're not supposed to be stored there.
	// Not sure if we need this check in the long run, but it we do,
	// we should probably do it in a better way than this...
	if ((args.attr == 'CLOUD') && (!chars || !(chars.flags & CLOUD)))
	{
		cb && cb('not a server side preference');
		return;
	}

	// I could use an onChange() handler for this, but
	//   a) There's no reason to.  It's one line of code, and
	//   b) it would potentially mask errors where someone sets a value
	//      directly instead of using set().
	if (!error)
	{
		p = {};
		
		if (f & GLOBAL)
		{
			getPrefs(p, preferences, GLOBAL);
            Caffeine.CEFContext.setPersistentValue('globalPrefs', p);
		}
		else if (!(f & ALL_LOCS))
		{
			getPrefs(p, preferences, 0);
            Caffeine.CEFContext.setPersistentValue(storageKey, p);
		}
		else if (f & CLOUD)
		{
			getPrefs(p, preferences, CLOUD);
			Ether.Event.fire(Caffeine.preferences, 'CloudPreferenceChanged', p, args.name);

			// Cloud preferences get stored locally, too, so they'll be available
			// immediately after launch.
            Caffeine.CEFContext.setPersistentValue(storageKey + '_cloud', p);
		}
	}
	
	cb && cb(error);
}

/**
 * Change the value of a preference for a per-user
 *
 * @method set
 * @param {object} pref			The preference to set
 *   @param {obj} pref.user		The user object for which the preference will be set
 *   @param {string} pref.name	The name of the preference
 *   @param {any} pref.value	The new value of the preference
 * @param {function} [cb]		A callback function to be notified when the preference has been set
 *   @param {object} cb.err		If falsey, indicates no error.  Otherwise it will be a
 *								standard error object.
 *
 */
// TODO: The preferences module shouldn't know anything about the structure of a contact object.
function setPerUser(params, cb)
{ 
	var defVal = true, p;
	// we only store the setting that's set to false, unless the UI specify it otherwise
	if (params.defVal !== undefined)
		defVal = params.defVal;
	
	p = {
			name:	params.name + '.' + params.user.yid,
			value:	(params.value == defVal) ? undefined : params.value
		};

	set(p, cb);
}

function equivalent(o1, o2)
{
	var name;

	if (typeof o1 != typeof o2)
		return false;

	if (typeof o1 != 'object')
		return o1 == o2;

	if (Object.keys(o1).length != Object.keys(o2).length)
		return false;

	for (name in o1)
	{
		if (!equivalent(o1[name], o2[name]))
			return false;
	}

	return true;
}

function getPrefs(dest, src, location)
{
	inner(dest, src, characteristics);

	function inner(dest, src, characteristics, flags)
	{
		var name, v, c, f, p;
		
		for (name in src)
		{
			v = src[name];
			if (typeof v == 'function')
				continue;

			c = characteristics && characteristics[name];
			f = (c && c.flags) || flags;
			
			if (v && typeof(v) == 'object')
			{
				p = dest[name] || { };
				
				if (inner(p, v, c, f))
					dest[name] = p;
			}
			else if (!dest.hasOwnProperty(name))
			{
				if ((f & ALL_LOCS) == location)
					dest[name] = src[name];
			}
		}
		
		return Object.keys(dest).length || (!Object.keys(src).length && ((flags & ALL_LOCS) == location));
	}
}

function copyObjectStruct(dest, src)
{
	var name, v, s;
	
	for (name in dest)
	{
		v = dest[name];
		if (typeof v == 'function')
			continue;
		
		s = src[name];
		if (typeof v != typeof s)
			delete dest[name];
		else if (v && typeof v == 'object')
			copyObjectStruct(v, s);
	}
}

})();
