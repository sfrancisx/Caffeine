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

var Comms = Caffeine.Comms,
	isInternal = Caffeine.CEFContext && Caffeine.CEFContext.isInternalIP && Caffeine.CEFContext.isInternalIP(),
	channel = Caffeine.CEFContext && Caffeine.CEFContext.getUpdateChannel().toLowerCase();

if (!(isInternal || Caffeine.appMode.enableShortcuts || channel == 'dogfood' || channel == 'nightly' || channel == 'developer' || channel == 'none'))
	return;

document.body.addEventListener("keydown",
	function(e)
	{
		if (!(e.ctrlKey && e.altKey))
			return;
			
		switch (e.keyCode)
		{
			// work around security restriction to copy to clipboard via simple UI action for automated tests
			case 65:		// Alt-Ctrl-A
				window.prompt ("Copy to clipboard: Ctrl+C, Enter", document.body.innerText);
				break;
			
			// Show preferences
			case 80:	// Alt-Ctrl-P
				Caffeine.Desktop.popupWindow(
					{
						module:	'Dev',
						initFn:	'jsonUI',
						target:	'Preferences',
						moduleParms: { data: Caffeine.preferences }
					});
				break;

			// Show the network trace
			case 84:	// Alt-Ctrl-T
				Caffeine.Desktop.popupWindow(
					{
						module:	'Dev',
						initFn:	'jsonUI',
						target:	'NetworkTrace',
						moduleParms: { data: Caffeine.XhrMock.getRecorded() }
					});
				break;

			case 88:		// Alt-Ctrl-X	Set appMode-feature overwrite
				var devAppMode = Caffeine.CEFContext.getPersistentValue('devAppMode');

				devAppMode = prompt('Set appMode values.  Separate values by "&&".  You may need to restart the app to take effect.', devAppMode || '');

				if (devAppMode === null)
					return;

				Caffeine.CEFContext.setPersistentValue('devAppMode', devAppMode);
				Caffeine.setAppModeFromString(devAppMode);

				break;

		}
	});

})();
