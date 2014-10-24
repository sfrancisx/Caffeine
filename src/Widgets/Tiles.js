/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

'use strict';

Caffeine.Ctrls = Caffeine.Ctrls || { };

var fire		= Ether.Event.fire,
	domutils	= Caffeine.DomUtils,
	registry	= Ether.registry(),
    hiddenIfSingle = false,
    isHidden = true;

Caffeine.Ctrls.TileCtrl = function(parms, cb)
{
	var ctrl = registry.get(parms.parent),
        hiddenIfSingle = parms.hiddenIfSingle,
        instance, mpopState;

	if (!ctrl.data)
	{
		ctrl.intf		= parms.intf;
		ctrl.registrar	= Ether.getRegistrar();
		ctrl.parent		= parms.parent;
		ctrl.tileWidth	= parms.width;
		ctrl.tileHeight	= parms.height;
		ctrl.barTemplate = parms.barTemplate;

		ctrl.data		= [ ];
		ctrl.templates	= [ ];
		ctrl.divs		= [ ];
		ctrl.signals	= [ ];
		ctrl.bindings	= [ ];
		ctrl.instances	= [ ];

		instance =
		{
			add:		add,
			remove:		function(parms) { closed.call(parms.signal || parms.data); },
			activate:	function(parms) { activated.call(parms.signal || parms.data); },
			block :		function() { blockEvents(ctrl.parent); },
			unblock :	function() { unblockEvents(ctrl.parent); }
		};

		ctrl.intf.close = function() {
			console.log("Tiles: intf close called");
			if(!ctrl.data.length) {
				console.log("Tiles: real close called");
				ctrl.intf.sendCloseToParent();
			}
		};

		ctrl.registrar.on(ctrl.intf, {
			closed: function() { 
				ctrl.registrar.cleanup();
				registry.remove(ctrl.parent);
				hiddenIfSingle = false;
				isHidden = true;
			},
			resized: layout,
		});

		ctrl.registrar.onElement(ctrl.signals,
			{
				Closed:		closed,
				Activated:	activated
			});

		ctrl.registrar.addEventListener(ctrl.parent, 'click',
			function(e)
			{
				var target = e.target,
					idx = findElementFor(e.target),
					classList = target.classList,
					command, commandList, commandObjParent, commandObj,
					index, len;

				if (idx != -1)
				{
					if(target.parentNode.classList.contains('tab-close')) {
						fire(ctrl.signals[idx], 'Closing');
					} else {
						fire(ctrl.signals[idx], 'Activated');
					}
				} else if (target.classList.contains('tab-overflow-down')) {
					scrollDown();
				} else if (target.classList.contains('tab-overflow-up')) {
					scrollUp();
				} else if(target.classList.contains('tab-header-item')) {
					command = target.getAttribute('data-command');
					if(command) {
						commandList = command.split(".");
						index = 0;
						len = commandList.length;
						commandObjParent = window;

						if(len) {
							for(; index < len; index++) {
								if(commandObj) {
									commandObjParent = commandObj;
								}
								commandObj = commandObjParent[commandList[index]];
								if(!commandObj) {
									break;
								}
							}

							if(typeof commandObj === "function") {
								commandObj.call(commandObjParent);
							}
						}
					}
				}
			});

		ctrl.registrar.addEventListener(ctrl.parent, 'mousewheel', layout);
		
		if(parms.state) {
			mpopState = parms.state.mpopState;
			ctrl.registrar.onChange(parms.state, { mpopState: function() {
				mpopState = this.mpopState;
				if(!mpopState && isHidden && ctrl.divs.length > 1) {
					ctrl.intf.show();
					isHidden = false;
				}
			} });
		}

		Caffeine.IPC.makeProxy(instance, finishCreate);
	}
	else {
		finishCreate(0, ctrl.ctrl);
        parms.intf.close();
    }

    ctrl.intf.alert('signal');

	function finishCreate(err, pCtrl)
	{
		if (parms.data)
			add(parms);

        if(!ctrl.ctrl) {
            ctrl.ctrl = pCtrl;
        }

		cb && cb(err, pCtrl);
	}

	/**
	 *
	 */
	function add(parms, cb)
	{
		var d = document.createElement('DIV'),
			binding;

		d.style.width = ctrl.tileWidth;
		d.style.height = ctrl.tileHeight;
		d.style.overflow = 'hidden';
		d.style.position = 'absolute';

		ctrl.data.push(parms.data);
		ctrl.templates.push(parms.template);
		ctrl.signals.push(parms.signal);

        hiddenIfSingle = parms.hiddenIfSingle != undefined ? parms.hiddenIfSingle : hiddenIfSingle;

		if (parms.module)
			Caffeine.Bootstrap.loadSources(parms, continueAdd);
		else
			continueAdd();

		function continueAdd()
		{
			var tabs,
				data = parms.data,
				signal = parms.signal || data,
				init, instance;
            
			if (ctrl.divs.length == 0) {
				Caffeine.Template.renderInto(parms.barTemplate, {data: data, isGTC: Caffeine.appMode.gtc }, ctrl.parent);
				d = ctrl.parent.querySelector('.tab-item');

                if(isHidden && !hiddenIfSingle && !mpopState) {
                    ctrl.intf.show();
                    isHidden = false;
                }

			} else {
				Caffeine.Template.renderInto(parms.template, {data: data}, d);
				d = d.firstChild;
                
                if(isHidden && !mpopState) {
                    ctrl.intf.show();
                    isHidden = false;
                }
			}
			ctrl.divs.push(d);

			binding = dataChanged.bind(data);
			init = Caffeine.Bootstrap.getInitFn(parms.module);

			if(init) {
				init({ data: data, datachangeCB: binding }, function(err, inst) {
					instance = inst;
				});
			} else {
				Ether.Event.onDeepChange(data, binding);
			}
			
			ctrl.bindings.push(init ? undefined : binding);
			ctrl.instances.push(instance);

			tabs = ctrl.parent.querySelector('.ym-tabs');

			if (tabs.firstChild) {
				tabs.insertBefore(d, tabs.firstChild);
			} else {
				tabs.appendChild(d);
			}

			layout();

			if (parms.activate || (ctrl.signals.length == 1) ) {
				activated.call(parms.signal || parms.data);
			}

			console.log("Tiles: tab created for " + parms.signal.id + ". Number of tiles = " + ctrl.divs.length);

			cb && cb();

		}
	}

	/**
	 *
	 */
	function closed()
	{
		/*jshint validthis:true */

		var idx = ctrl.signals.indexOf(this),
			d = ctrl.divs[idx],
			activeTile = ctrl.activeTile,
            dataLen, signal, data, binding, instance;


		console.log("Tiles: closed called. tiles length = " + ctrl.data.length);

		data = ctrl.data.splice(idx, 1)[0];
		signal = ctrl.signals.splice(idx, 1)[0];
		ctrl.templates.splice(idx, 1);
		ctrl.divs.splice(idx, 1);
		binding = ctrl.bindings.splice(idx, 1)[0];
		instance = ctrl.instances.splice(idx, 1)[0];

		binding && Ether.Event.offDeepChange(data, binding);
		instance && instance.close();

        dataLen = ctrl.data.length;

		if (!dataLen) {
			console.log("Tiles: no more tiles. Closing the intf");
			ctrl.intf.close();
		} else {
			d.parentNode.removeChild(d);

			if (ctrl.activeTile != undefined && idx <= ctrl.activeTile) {
				ctrl.activeTile = null;
				if (idx < activeTile || (idx==activeTile && idx == ctrl.data.length)) {
					activeTile = activeTile-1;
				}

				activated.call(ctrl.signals[activeTile] || ctrl.data[activeTile]);
			}

            //hide the intf if there is only one tile
            if(hiddenIfSingle && dataLen === 1) {
                ctrl.intf.hide();
                isHidden = true;
            } else if (dataLen) {
				layout();
			}

			console.log("Tiles: remaining tiles length = " + dataLen);

		}
	}

	/**
	 *
	 */
	function activated()
	{
		/*jshint validthis:true */

		var idx = ctrl.signals.indexOf(this),
			newActiveEl;

		if (ctrl.activeTile == idx) {
			return;
		}
		if (ctrl.divs.length > 1 && ctrl.divs[ctrl.activeTile]) {
			domutils.removeClass(ctrl.divs[ctrl.activeTile], 'selected');
		}
		ctrl.activeTile = idx;

		newActiveEl = ctrl.divs[idx];
		domutils.addClass(newActiveEl, 'selected');
		newActiveEl.scrollIntoViewIfNeeded();

	}

	/**
	 *
	 */
	function findElementFor(el)
	{
		var idx;

		while (el && (el != parent))
		{
			idx = ctrl.divs.indexOf(el);
			if (idx != -1)
				return idx;
			el = el.parentNode;
		}

		return -1;
	}

	/**
	 *
	 */
	function dataChanged()
	{
		/*jshint validthis:true */
		//var idx = ctrl.signals.indexOf(this);
		//if (idx < 0) {
		var idx = ctrl.data.indexOf(this);
		if(idx < 0) {
			//Todo - debug why idx is still -1. Most probably due to not off binding the Event
			return;
		}
		//}

		ctrl.divs[idx] = Caffeine.Template.renderOuter(ctrl.templates[idx], { data: this} , ctrl.divs[idx]);
		if (ctrl.activeTile == idx) {
			domutils.addClass(ctrl.divs[idx], 'selected');
		}
		layout();
	}

	function layout()
	{
		var divs	= ctrl.divs,
			tabs = divs[0].parentNode,
			container = tabs.parentNode,
			downClassList = container.querySelector('.tab-overflow-down').classList,
			upClassList = container.querySelector('.tab-overflow-up').classList,
			offsetHeight = tabs.offsetHeight,
			scrollTop = tabs.scrollTop,
			scrollBottom = scrollTop + offsetHeight,
			isUpDisplaying = scrollTop != 0,
			isDownDisplaying = tabs.scrollHeight > scrollBottom,
			isUpRedFlag,
			isDownRedFlag;


		downClassList.toggle("show", isDownDisplaying);
		upClassList.toggle("show", isUpDisplaying);

		if(isUpDisplaying || isDownDisplaying) {
			divs.some(function(el, index) {
				var offsetTop = el.offsetTop,
					redFlag = el.getAttribute("data-red-flag");

				isUpRedFlag = isUpRedFlag || ( (offsetTop < scrollTop) && parseInt(redFlag) );
				isDownRedFlag = isDownRedFlag || ( (offsetTop + 50 > scrollBottom) && parseInt(redFlag) );
				
				return (isUpRedFlag && isDownRedFlag) || (!isUpDisplaying && isDownRedFlag) || (!isDownDisplaying && isUpRedFlag); 
			});
		}

		upClassList.toggle("redflag", isUpRedFlag);
		downClassList.toggle("redflag", isDownRedFlag);
	}

	function scrollDown(){
		var tabs = ctrl.divs[0].parentNode;
			tabs.scrollTop = tabs.scrollTop + 200;
			layout();
	}

	function scrollUp(){
		var tabs = ctrl.divs[0].parentNode,
			st = tabs.scrollTop - 200;

			tabs.scrollTop = st;
			layout();
	}

};

function blockEvents(el) {
	if(!el.getAttribute("data-blocked")) {
		el.addEventListener("click", freeze, true);
		el.addEventListener("keydown", freeze, true);
		el.setAttribute("data-blocked", "1");
	}
}

function unblockEvents(el) {
	if(el.getAttribute("data-blocked")) {
		el.removeEventListener("click", freeze, true);
		el.removeEventListener("keydown", freeze, true);
		el.removeAttribute("data-blocked");
	}
}

function freeze(e) {
	e.stopPropagation();
}

})();
