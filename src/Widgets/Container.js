/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){
"use strict";

var intf, 
	childModule, childModuleInit,
	closingChildIntf,
	parentEl;

Caffeine.Ctrls = Caffeine.Ctrls || {};

Caffeine.Ctrls.Container = function(parms, cb) {
	var moduleParms = parms.moduleParms;
		/*containingModule = moduleParms.module,
		containingInit = moduleParms.initFn;*/
	if(intf) {
		/*if(childIntf) {
			if(containingModule && ((containingModule !== childModule) || (containingModule == childModule && containingInit !== childModuleInit))) {
				closingChildIntf = true;
				Ether.Event.fire(childIntf,  "closing");
			}
		}*/
		parms.intf.close();
	} else {
		intf = parms.intf;
		parentEl = parms.parent;
		bindIntf();
	}

	if(moduleParms) {
		addChild(moduleParms, cb);
	}else {
		cb();
	}
};

function bindIntf() {
	var registrar = Ether.getRegistrar(),
		appShutdown;

	registrar.on(Caffeine, { "appshutdown": function() {
		appShutdown = true;
	}});
	
	intf.close = function() {
		/*if(closingChildIntf) {
			closingChildIntf = false;
			return;
		}*/

		if(appShutdown) {
			registrar.cleanup();
			intf.sendCloseToParent();
			intf = null;
			appShutdown = false;
		} else {
			intf.hide();
			cleanParentEl();
		}
	};
}

function addChild(parms, cb) {
	var module = parms.module;

	if(!module) {
		cb();
		return;
	}

	if(childModule !== module) {
		Caffeine.Bootstrap.loadSources(parms, function() {
			afterLoad(parms, cb);
		});
	} else {
		afterLoad(parms, cb);
	}
}

function afterLoad(parms, cb) {
	var init = Caffeine.Bootstrap.getInitFn(parms),
		childIntf = Caffeine.getPassthruIntf(intf),
		childParms = parms.moduleParms;

	childParms.parent = parentEl;
	childParms.intf = childIntf;

	init(childParms, cb);
}
	

function cleanParentEl() {
	var children = parentEl.children,
		len = children.length,
		child;

	while(len--) {
		child = children[len];
		if(child.tagName !== "SCRIPT") {
			child.remove();
		}
	}
}
		

})();
