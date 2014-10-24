/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

'use strict';

Caffeine.Ctrls = Caffeine.Ctrls || { };

var fire		= Ether.Event.fire,
	registry	= Ether.registry();

/**
 * An overlay control - the control will hold any number of modules, but will only display one
 * at a time.  Inactive controls are removed from the DOM and stored in a document fragment.
 *
 * Each item in the overlay has a 'data' object and a 'signal' object.  The 'data' object is 
 * intended to be used by the module in the overlay.  For example, when a conversation UI is in
 * the overlay, 'data' is the conversation object.  The 'signal' object allows multiple modules
 * concerned with the same data object to communicate.
 *
 * Overlay has to distinguish between global actions on the `signal` object, and local actions
 * on the control itself.  Firing `Closed` on the signal object indicates that it has been closed
 * - if a conversation gets closed, it should close everywhere.  Calling 'remove' on the overlay
 * control removes the item from the overlay but doesn't close it everywhere.  When I tear out
 * a tab, I want to remove the conversation from the overlay but I don't want to close the
 * conversation.
 *
 * @module Widgets
 * @namespace Caffeine.Ctrls
 * @class OverlayCtrl
 */
Caffeine.Ctrls.OverlayCtrl = function(parms, cb)
{
	// A parent can only have one OverlayCtrl.  Attempting to add a second overlay to a parent
	// will instead add an item to the overlay.
	var ctrl = registry.get(parms.parent),
		parentEl;

	if (!ctrl.data)
	{
		ctrl.intf		= parms.intf;
		ctrl.registrar	= Ether.getRegistrar();

		parentEl = document.createElement("div");
		parms.parent.appendChild(parentEl);
		ctrl.parent		= parentEl;

		ctrl.data		= [ ];
		ctrl.signals	= [ ];
		ctrl.fragments	= [ ];
		ctrl.intfs		= [ ];

		// This is the public interface of the overlay control.
		ctrl.ctrl =
		{
			add:		add,
			remove:		function(parms) { throw new Error("Not Implemented"); },
			activate:	function(parms) { activated.call(parms.signal || parms.data); }
		};

		ctrl.registrar.on(ctrl.intf, { 
			closed: function() { 
				ctrl.registrar.cleanup(); 
				registry.remove(parms.parent);
			} 
		});

		ctrl.registrar.onElement(ctrl.signals,
			{
				Closing:	closing,
				Activated:	activated
			});
        
		Caffeine.IPC.makeProxy(ctrl.ctrl, finishCreate);

        ctrl.intf.activated = function() {
            if(ctrl.showing !== undefined) {
                fire(ctrl.intfs[ctrl.showing], 'activated');
            }
        };

		bindKeyboardShortCuts();
	}
	else
		finishCreate(0, ctrl.ctrl);

	function finishCreate(err, ctrl)
	{
		parms.data && add(parms, callback);
		parms.data || callback();

		function callback() { cb && cb(0, ctrl); }
	}

	/**
	 * @method add
	 * @param parms
	 * @param parms.data   {object}			The data object for the module.
	 * @param parms.signal {object}			The signalling object.  If not present, `data` is used.
	 * @param parms.module {object|string}	The module to put into the overlay
	 */
	function add(parms, cb)
	{
		var init,
			signal		= parms.signal || parms.data,
			intf		= Caffeine.getPassthruIntf(ctrl.intf),
			d			= document.createElement('DIV'),
			notifyIntfClosed = { "closed": onIntfClosed };

		ctrl.data.push(parms.data);
		ctrl.fragments.push(d);
		ctrl.signals.push(signal);
		ctrl.intfs.push(intf);

		Caffeine.Bootstrap.loadSources(parms, continueAdd);

		Ether.Event.on(intf, notifyIntfClosed);

		function continueAdd()
		{
			init = Caffeine.Bootstrap.getInitFn(parms.module);

			parms.data.parent = d;

			parms.data.intf = intf;

			try {
				init(parms.data, cb);
			} catch(e) {
				cb();
				console.error(e);
			}

			console.log("Overlay: overlay created for " + signal.id + ". Number of overlays = " + ctrl.signals.length);

			if (parms.activate) {
				ctrl.ctrl.activate(parms);
			} else if(ctrl.signals.length === 1) {
				activated.call(signal, true);
			}
				
		}

		function onIntfClosed()
		{
			var idx = ctrl.signals.indexOf(signal),
				len = ctrl.signals.length,
				idxShowing = ctrl.showing,
				nextSignal;

			if( len > 1 ) {
				if(idx == idxShowing) {
					nextSignal = (idxShowing == len -1) ? ctrl.signals[idx - 1] : ctrl.signals[idx + 1];
					activated.call(nextSignal);
				}

				idxShowing = ctrl.showing;
				if( (idxShowing !== undefined) && (idx <= idxShowing) ) {
					ctrl.showing = ctrl.showing - 1;
				}
			} 
			
			ctrl.data.splice(idx, 1);
			ctrl.signals.splice(idx, 1);
			ctrl.fragments.splice(idx, 1);
			ctrl.intfs.splice(idx, 1);

			Ether.Event.off(intf, notifyIntfClosed);

			if(nextSignal) {
				fire(nextSignal, "Activated");
			}

			fire(signal, "Closed");
			console.log("Overlay: fired Closed event on the signal. remaining overlays = " + ctrl.signals.length);

		}

	}

	function activated(isPassive/*Indicates that indirect activation in case of first item in the overlay*/)
	{
		/*jshint validthis:true */


		var parentEl = ctrl.parent,
			oldChild, 
			showingIdx = ctrl.showing,
			idx = ctrl.signals.indexOf(this),
			intf = ctrl.intfs[idx],
			oldIntf,
			children, len;

		if (idx == showingIdx) {
			if(!isPassive) {
				fire(ctrl.intfs[idx], 'activated');
			}
			return;
		}

		if (showingIdx !== undefined)
		{
			oldChild = parentEl.replaceChild(ctrl.fragments[idx], parentEl.lastChild);
			oldIntf = ctrl.intfs[showingIdx];

			if (oldIntf) {
				fire(oldIntf, "nondisplayed");
				fire(oldIntf, 'deactivated');
				ctrl.fragments[showingIdx] = oldChild;
			}
		}
		else
			parentEl.appendChild(ctrl.fragments[idx]);


		fire(intf, "displayed");
		if(!isPassive) {
			fire(intf, 'activated');
		}

		ctrl.showing = idx;
	}

	/**
	 *
	 */
	function closing()
	{
		/*jshint validthis:true */

		var idx = ctrl.signals.indexOf(this);
        fire(ctrl.intfs[idx], 'closing');
	}

	function bindKeyboardShortCuts() {
		var keyNav = Caffeine.KeyboardNav;
		if(keyNav) {
			keyNav.onCmdTab = showNextOverlay;
			keyNav.onCmdShftTab = showPrevOverlay;
			keyNav.onCmdW = closeCurrentOverlay;
			keyNav.onEsc = closeCurrentOverlay;
		}
	}


	function closeCurrentOverlay() {
		if(ctrl.showing !== undefined) {
            Ether.Event.fire(ctrl.signals[ctrl.showing], "Closing");
		}
	}

	/**
	 * Move to next overlay when ctrl-tab, ctrl-PgUp, cmd-shift-]
	 */
	function showNextOverlay() {
		showNPOverlay(true);
	}

	/**
	 * Move to prev  overlay when ctrl-shift-tab, ctrl-PgDn, cmd-shift-[
	 */
	function showPrevOverlay() {
		showNPOverlay(false);
	}

	function showNPOverlay(isNext) {
		var showing = ctrl.showing,
			len = ctrl.intfs.length,
			npIndex, npItem;

		if(showing !== undefined) {
			//index decreases for next items and increases for prev items
			if(isNext) {
				npIndex = showing === 0 ? len - 1 : showing - 1;
			} else {
				npIndex = showing === len - 1 ? 0 : showing + 1;
			}

			npItem = ctrl.signals[npIndex];
			if(npItem) {
				fire(npItem, "Activated");
			}
		}
	}

};

})();
