/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

'use strict';

Caffeine.Ctrls = Caffeine.Ctrls || { };

var tabCtrl, overlayCtrl, proxyCtrl,
	isCreated = false,
	queue = [];

/**
 * A docked tab control - the tabs are in a different window than the content they control.
 *
 * A window can only have one docked tab.  For convenience, you can pass the tab definition
 * to this control's `init()` function to add a tab to this window's docked tab.
 *
 * @module Widgets
 * @namespace Caffeine.Ctrls
 * @class DockedTab
 */
Caffeine.Ctrls.DockedTab =
{
	init:		init
};

/**
 * Initialize the control.
 *
 * @method init
 * @param parms
 * @param parms.dockedWin					Parameters for the docked window, with a couple of differences.  This
 *											module will fill in `target`, `module` and `initFn`.
 * @param parms.dockedWin.width					Passed to the tile control as the width a single tile.  (The width of
 *												the window is the same as the width of a tile.)
 * @param parms.dockedWin.height {number}		The height of a single tile.
 * @param parms.dockedWin.top {number}			Requested top edge of the docked window.  A negative number means to measure from the bottom of the window.
 * @param parms.dockedWin.bottom {number}		Requested bottom edge of the docked window.  A negative number means to measure from the top of the window.
 * @param parms.dockedWin.minTop {number}		Minimum allowed top.
 * @param parms.dockedWin.minBottom {number}	Minimum allowed bottom.
 * @param parms.tab {object}				The initialization parameter for the TileCtrl.  If present, it's used to add a tile to the control.
 * @param parms.overlay						The initialization parameter for the OverlayCtrl.  If present, it's used to add content to the control.
 * @param cb
 * @param cb.err
 * @param cb.ctrl						An interface to the control.  This interface can be used across process boundaries.
 */
function init(parms, cb)
{
	var intf = parms.intf,
		registrar;

	if (!isCreated)
	{
		isCreated = true;

		registrar = Ether.getRegistrar();

		Caffeine.Ctrls.OverlayCtrl( { parent: parms.parent, intf: intf }, function(err, ctrl)
			{
				overlayCtrl = ctrl;

				Caffeine.IPC.makeProxy(Caffeine.Ctrls.DockedTab, function(err, ctrl)
				{
					proxyCtrl = ctrl;
	
					cb && cb({ _windowState: "loading", _ipcState: "partial" }, proxyCtrl);
					var dockParms = parms.dockedWin;
					dockParms.target = Caffeine.windowId + "_dock";

					Caffeine.Desktop.dockedWindow(dockParms, function(err, ctrl)
					{
						tabCtrl = ctrl;
						
						addToCntrls(parms, function(err, data) {
							var	item;

							cb({ _windowState: "loaded", err: err }, data);

							while(item = queue.shift()) {
								addToCntrls(item.parms, item.cb);
							}
						});

					});

				});

			});
			
		intf.closeCheck = function() {
			var result = this.sendCloseCheckToParent();
			if(result && result.returnValue === false) {
				tabCtrl && tabCtrl.block();
			}
			return result;
		};

		registrar.on(intf, { 
			closed: function() { 
				registrar.cleanup(); 
				isCreated = false;
				tabCtrl = undefined;
				overlayCtrl = undefined;
				proxyCtrl = undefined;
			},
			activated: function() { tabCtrl && tabCtrl.unblock(); }
		});

	}
	else
	{
		if(tabCtrl) {
			addToCntrls(parms, cb);
		} else {
			queue.push({ parms: parms, cb: cb});
		}
		intf.close();
	}

	function addToCntrls(parms, cb) {
		overlayCtrl.add(parms.overlay, function() {
			tabCtrl.add(parms.tab, function() {
				cb && cb(0, proxyCtrl);
			});
		});
	}

}

})();
