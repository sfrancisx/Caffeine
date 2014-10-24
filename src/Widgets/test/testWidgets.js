/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

Caffeine.Bootstrap.loadSources({ module: "Widgets" });

function onMenu(evt)
{
	var data = evt.target.dataset,
		menuActions =
		{
			string:		showStringMenu,
			html:		showHTMLMenu,
			element:	showElementMenu,
			render:		showRenderMenu
		};

	if (data.showMenu)
	{
		menuActions[data.showMenu](
			{
				left:	evt.pageX,
				top:	evt.pageY
			}, evt);
	}
}

function showStringMenu(parms)
{
	parms.strings =
		[
			'Item 1',
			'Item 2'
		];

	Caffeine.Widgets.Menu.create(parms,
		function(err, data)
		{
			if (err) {
				console.log(err.error);
			} else {
				console.log(data);
			}
		});
}

function showHTMLMenu(parms)
{
	parms.html =
		'<li data-menu-id="3" tabindex="-1"><span>Item 1</span></li><li data-menu-id="4" tabindex="-1"><span>Item 2</span></li>';

	Caffeine.Widgets.Menu.create(parms,
		function(err, data)
		{
			console.log(data);
		});
}

function showElementMenu(parms, evt)
{
	//var buttons = ;
	parms.elements = document.getElementsByTagName("button");

	Caffeine.Widgets.Menu.create(parms,
		function(err, data)
		{
			console.log(data);
		});
}

function showRenderMenu(parms)
{
	parms.styleModule = "ConversationTabUI";
	parms.template = "ConvTab";
	parms.data =
	[
		{participants: [
			{ displayName: "Steve" },
			{ displayName: "Sara" }
		]}
	];

	Caffeine.IPC.synchronizeObject(parms.data);

	Caffeine.Widgets.Menu.create(parms,
		function(err, data)
		{
			console.log(data);
		});

	setTimeout(function()
		{
			parms.data[0].participants[0].displayName="Bob"
			console.log(parms.data)
		}, 1000);
}
