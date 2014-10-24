/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function() {

"use strict";

// For jshint.  Allow alert & prompt in this file.  Don't add them to .jshintrc - they
// shouldn't be allowed everywhere.
/* global alert, prompt */

var isInternal = Caffeine.CEFContext && Caffeine.CEFContext.isInternalIP && Caffeine.CEFContext.isInternalIP(),
	channel = Caffeine.CEFContext && Caffeine.CEFContext.getUpdateChannel().toLowerCase();

if (!(isInternal || Caffeine.appMode.enableShortcuts || channel == 'dogfood' || channel == 'nightly' || channel == 'developer'))
	return;

document.body.addEventListener("keydown",
	function(e)
	{
		var newlogin, serverURL, netSession, name, sessions;

		if (!(e.ctrlKey && e.altKey))
			return;
			
		switch (e.keyCode)
		{
			// work around security restriction to copy to clipboard via simple UI action for automated tests
			case 65:		// Alt-Ctrl-A
				window.prompt ("Copy to clipboard: Ctrl+C, Enter", document.body.innerText);
				break;
		}
	});

})();
