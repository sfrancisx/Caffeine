/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

"use strict";

/**
 * A simple widget for popup menus.
 *
 * There are two general ways to use this widget:
 *
 *   1. Automatically: Menus will be created on any elements with a data-menu attribute.
 *   2. Manually:      Call Menu.create(parms, cb)
 *
 * Manual creation has some advantages over automatic creation.  You can provide additional styling for
 * manual menus, and you can have the menu kept up to date with data changes.
 * See {{#crossLink "Menu/create:method"}}{{/crossLink}} for a description of how to create menus manually.
 *
 * When menus are created automatically, events are fired for 'menu created', 'menu dismissed' and
 * 'menu item chosen'.
 *
 * Menus are normally created in a popup window, but you can create them in an element on your page
 * if you need to.
 *
 * @module Widgets
 * @namespace Caffeine.Widgets
 * @class Menu
 */

(function(){

Caffeine.Widgets = Caffeine.Widgets || { };

var closeMenu, menuOpen,
	ymdu	= Caffeine.DomUtils,
	yme		= Ether.Event,
	autoMenus = document.querySelectorAll("[data-menu-action]");

if (autoMenus) {
	var i;
	for (i=0; i<autoMenus.length;i++) {
		autoMenus[i].addEventListener("click", autoCreate);
	}
}

Caffeine.Widgets.Menu =
{
	create:	create,
	init:	init
};

/**
 * Manually create a popup menu
 *
 * @method create
 * @param {object} parms
 * @param {number} parms.left			Screen coordinates of the left edge of the menu
 * @param {number} parms.top			Screen coordinates of the top edge of the menu
 * @param {number} [parms.width]		The width of the menu.  If it's not provided, `Menu` will try
 *										to calculate it.
 * @param {number} [parms.height]		The height of the menu.  If it's not provided, `Menu` will try
 *										to calculate it.
 * @param {string} [parms.styleModule]	This module will be loaded in the popup's window.  `Menu.create()`
 *										won't call any code in the module - the module is loaded only
 *										so its CSS will be available.
 * @param {string} [parms.template]		A dust template used to render the menu.  `styleModule` must include this template.
 * @param {array} [parms.data]			The context for the template
 * @param {array of HTMLElement} [parms.elements]
										Existing elements to use in the menu
 * @param {string} [parms.html]			HTML to use as the menu
 * @param {array of string} [parms.strings]
 *										An array of strings to use for the menu
 * @param {function} cb					A function to call when the menu is dismissed.
 *
 * @example
 *
 * There are 4 different ways to create a menu.  `parms` must include either `template` +
 * `data` xor `elements` xor `html` xor `strings`.
 *
 *
 */
function create(parms, cb)
{
	var win, size, html, idx, element,
		width = parms.width || 0,
		height = parms.height || 0,
		menuParms =
		{
			styleModule:	parms.styleModule,
			html:			parms.html,
			positions:		parms.positions
		};

	if (parms.styleModule)
		Caffeine.Bootstrap.loadSources({ module: parms.styleModule }, continueCreate);
	else
		continueCreate();

	function continueCreate()
	{
		if (menuOpen)
		{
			cb({ error: "open" });
			return;
		}
		menuOpen = 1;

		if (parms.elements)
		{
			menuParms.html = ymdu.getHtmlFromElements(parms.elements);
			for (idx = 0; idx < parms.elements.length; idx++)
			{
				element = parms.elements[idx];
				width = Math.max(width, element.offsetWidth);
				height += element.offsetHeight;
			}
		}

		if (parms.strings)
		{
			html = [ ];

			parms.strings.forEach(function(string, idx)
				{
					html.push('<li data-menu-id="' + idx + '" tabindex="-1"><span>' + string + '</span></li>');
				});
			menuParms.html = html.join("");
		}

		if (parms.template)
		{
			menuParms.template	= parms.template;
			menuParms.data		= parms.data;
			menuParms.html		= [ ];

			parms.data.forEach(function(data, idx)
				{
					dust.render(
						parms.template,
						Object.create(data),
						function(err, out)
						{
							menuParms.html += assignId(out, idx);
						});
				});
		}

		if (!width)
		{
			size = getSize(menuParms.html);
			width = size.width;
			height = size.height;
		}

		win = Caffeine.Desktop.modalWindow(
					{
						module:			"Widgets",
						moduleParms:	menuParms,
						width:			width,
						height:			height,
						left:			parms.left,
						top:			parms.top,
						backgroundColor:parms.backgroundColor
					},
					function(err, data)
					{
						Caffeine.Desktop.closeWindow({ target: win });
						menuOpen = 0;

						cb(err, data);
					});
	}
}

////////////////////////////////////////////////////////////////////////
function autoCreate(e)
{
	var parms = {
		elements: document.querySelector('[data-menu="'+e.currentTarget.dataset.menuAction +'"]')
	}
	Caffeine.Widgets.Menu.create(parms,
	function(err, data)
	{
		console.log(data);
	});
}

////////////////////////////////////////////////////////////////////////
function getSize(html)
{
	var div,
		ret = { };

	div = document.createElement("div");
	div.style.position = "absolute";
	div.style.visibility = "hidden";
	document.body.appendChild(div);
	div.innerHTML = html;
	ret.width = div.offsetWidth;
	ret.height = div.offsetHeight;
	document.body.removeChild(div);

	return ret;
}

////////////////////////////////////////////////////////////////////////
function assignId(html, id)
{
	var div, child;

	div = document.createElement("div");
	div.innerHTML = html;

	child = div.firstChild;

	if (!child.dataset.menuId)
		child.dataset.menuId = id;

	child.dataset.menuIdx = id;

	return div.innerHTML;
}

////////////////////////////////////////////////////////////////////////
function init(parms, cb)
{
	closeMenu = cb;

	var element,
		i			= 0,
		data		= parms.data,
		template	= parms.template,
		parent		= parms.parent;

	if (parms.styleModule)
		Caffeine.Bootstrap.loadSources({ module: parms.styleModule });

	parent.innerHTML = parms.html;
	while (parms.positions && (i < parms.positions.length))
	{
		parent.childNodes[i].style.top = parms.positions[i];
		parent.children[i].style.bottom = '';
		i++;
	}

	parent.addEventListener("click", onClick);
	parent.addEventListener("keydown", onKeyDown);
	parent.querySelector('[data-menu-id]').focus();
	window.addEventListener("blur", onBlur);
	if (parms.data)
	{
		yme.onDeepChange(parms.data, function(name, oldVal)
			{
				var idx = data.indexOf(this),
					element = document.body.querySelector('[data-menu-idx="' + idx + '"]');

				dust.render(
					template,
					Object.create(this),
					function(err, out)
					{
						element.outerHTML = assignId(out, idx);
					}
				);
				console.log(name + ' changed from ' + oldVal + ' to ' + this[name]);
			});
	}
}
function selectItem(item){
	var menuId = (item.dataset && item.dataset.menuId) ? item.dataset.menuId : null;
	if (menuId) {
		menuOpen = 0;
		closeMenu(0, menuId);
		window.close();
	}
}
////////////////////////////////////////////////////////////////////////
function onClick(e)
{
	var item = ymdu.getAncestorBySelector(e.target, "[data-menu-id]", e.currentTarget);

	if (item)
	{
		selectItem(item);
	}
}
////////////////////////////////////////////////////////////////////////
function onKeyDown(e)
{
	var el = ymdu.getAncestorBySelector(e.target, "[data-menu-id]", e.currentTarget),
		nav, selEl;
	switch (e.keyCode) {
		case 13:
			selectItem(e.target);
		case 38: //up arrow
		case 40: //down arrow
			nav = (e.keyCode == 38) ? "previousElementSibling" : "nextElementSibling";
			selEl = el[nav];
			selEl && selEl.focus();
		break;
	}

}
////////////////////////////////////////////////////////////////////////
function onBlur(e)
{
	menuOpen = 0;
	closeMenu(0);
	window.close();
}
})();
