/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function() {
"use strict";

	function keyboardNav(e) {
		var srcEl = e.target,
			tagName = srcEl.tagName,
			which = e.which,
			isMeta = e.metaKey,
			isCtrl = e.ctrlKey,
			isShift = e.shiftKey,
			isAlt = e.altKey,
			isTargetEditable,
			keyNav = Caffeine.KeyboardNav;

		if (isCtrl && isAlt) {
			return;
		}

		if(this.classList.contains("dialog-displayed")) {
			return;
		}

		if(tagName === "INPUT" || tagName === "TEXTAREA" || srcEl.getAttribute("contenteditable")) {
			isTargetEditable = true;
		}

		if( (which === 78 &&  (isMeta || isCtrl)) || (which === 89 && (isMeta || isAlt)) ) {

			//ctrl-N or cmd-N or cmd-Y or alt-Y
			//Focus on the search box in main window
				
			if(Caffeine.appMode.slave) {
				Caffeine.IPC.remoteCall("main", "Caffeine.KeyboardNav.onCmdN", { fromRemote: 1 });
			} else if(typeof keyNav.onCmdN === "function") {
				keyNav.onCmdN();
			}
				
		} else if(typeof keyNav.onType === "function" && !isMeta && !isCtrl && !isAlt && (which >=65) && (which <= 90) && !isTargetEditable ) {

			keyNav.onType({ input: String.fromCharCode(which) });
		
		} else if ( (which == 9 && isCtrl && !isShift) || (which == 33 && isCtrl) || (isMeta && isShift && which == 221 ) ) {

			//both: ctrl-tab, Win: ctrl-PgUp, Mac: cmd-shift-]  switch to the other list
			//switch to the other list
			if(typeof keyNav.onCmdTab === "function") {
				keyNav.onCmdTab();
			}

		} else if ( (which == 9 && isCtrl && isShift) || (which == 34 && isCtrl) || (isMeta && isShift && which == 219 ) ) {

			//both: ctrl-shift-tab, Win: ctrl-PgDn, Mac: cmd-shift-[
			//switch to the other list
			if(typeof keyNav.onCmdShftTab === "function") {
				keyNav.onCmdShftTab();
			}

		} else if (which == 68 && isCtrl) {

			//ctrl-D: sign out
			if(typeof keyNav.onCtrlD === "function") {
				keyNav.onCtrlD();
			}

		} else if(which == 87 && !isShift && (isCtrl || isMeta)) {
			//ctrl-W or cmd-W
			if(typeof keyNav.onCmdW === "function") {
				keyNav.onCmdW();
				e.preventDefault();
			}

		} else if(which == 27) {
			//esc key
			if(typeof keyNav.onEsc === "function") {
				keyNav.onEsc();
			}

		}
	}

	function onContextMenu(e) {
		var srcEl = e.target,
			tagName = srcEl.tagName;

		if(tagName == "INPUT" || tagName == "TEXTAREA" || srcEl.getAttribute("contenteditable")) {
			return;
		}

		e.preventDefault();
	}

	Caffeine.KeyboardNav = {
		onCmdN: undefined,
		onType: undefined,
		onCmdTab: undefined,
		onCmdShftTab: undefined,
		onCtrlD: undefined,
		onCmdW: undefined,
		onEsc: undefined
	};

	var notify = { "windowclose": function() {
		Ether.Event.off(Caffeine, notify);
		document.body.removeEventListener("keydown", keyboardNav);
		document.body.removeEventListener("contextmenu", onContextMenu);
	} };

	document.body.addEventListener("keydown", keyboardNav);

	document.body.addEventListener("contextmenu", onContextMenu);

	Ether.Event.on(Caffeine, notify);

})();
