/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

/******************************************************************************
 * Our master list of modules.
 *****************************************************************************/

Modules =
{


   // TODO: Change this to 'Controls'.  A widget is some UI element with limited functionality.
   // A control is a customizable widget the user interacts with to control the application.
   Widgets:
   {
      code:    [
                  'Widgets/MenuWidget.js',
                  'Widgets/Overlays.js',
                  'Widgets/Tiles.js',
                  'Widgets/DockedTab.js',
                  'Widgets/SplitTab.js',
				  'Widgets/Container.js',
				  'Widgets/WindowKeyNav.js',
				  'Widgets/Snapshot.js',
				  'Widgets/ImageFilters.js'
               ],
      templates:  ["TabContainer.js", "FormattedMessage.js", "Snapshot.js"],
      style:      [ 'base.css', 'MenuDefaults.css', 'Snapshot.css'],

      initFn:     {
                  default:   	 'Caffeine.Widgets.Menu.init',
                  MenuCtrl:      'Caffeine.Widgets.Menu.init',
                  TileCtrl:      'Caffeine.Ctrls.TileCtrl',
                  OverlayCtrl:   'Caffeine.Ctrls.OverlayCtrl',
                  DockedTab:     'Caffeine.Ctrls.DockedTab.init',
				  Snapshot:		 'Caffeine.Ctrls.Snapshot',
				  Container:	 'Caffeine.Ctrls.Container',
				  SplitTab:		 'Caffeine.Ctrls.SplitTab.init'
               },

      requires:   [ 'Sync', 'DomUtils', 'Alerts', 'Dialog' ]
   },

	Network2:
	{
		code:
			{
				always:
				[
					'network2/network2_api.js',
					'network2/imageQueue.js'
				],
				master:
				[
					'network2/network2.js',
					'network2/oauth.js',
					'network2/sha1.js'
				],
				slave:	'network2/network2_proxy.js'
			},
		requires: 'Dust'
	},

   CommonUtils:
   {
      code:    [ 'Common/UserUtils.js' ],
      templates: ["richpresencestatus.js"],
      requires:   [ "Comms", "Intl"]
   },

   DomUtils:
   {
      code:    [ 'Common/domutils.js' ],
      requires:   [ "Dust", "Template", 'Intl', 'StackBlur' ]
   },

   LogUploader:
   {
      code:       [ "LogUploader/LogUploader.js"],
      templates:  [ "LogUploader.js" ],
      style:      [ "base.css", "global.css", "settings.css", "mod-loguploader.css"],
      initFn:     "Caffeine.LogUploader",
      requires:   [ "Comms", "Event", "DomUtils", "CommonUtils", "Alerts", "ImageCacher" ]
   },
   
   // localized string resources can be accessed through this module
   Intl:
   {
      code:      [ 'Infrastructure/intl.js' ],
      requires:  [ 'Event', 'Sync' ]
   },

   Template:
   {
       code:      [ 'Infrastructure/template.js' ],
       requires:  [ 'Dust', 'Intl' ]
   },

   Dev:
   {
      code: [ 'Dev/log4js.js', 'Dev/jsonUI.js' ],
      requires:
            [ 'Infrastructure', 'Comms' ],
      initFn: {
               jsonUI:  'Caffeine.JsonUI.init'
            }
   },

    Infrastructure:
    {
        code:
        {
            always:
            [
				//'Network2/xhr_mock.js',
				'Infrastructure/options.js',
                'Infrastructure/registry.js',
                'Infrastructure/registrar.js',
                'Common/utils.js',
                'Infrastructure/event.js',
                'Dev/log4js.js',
                { master: 'Dev/shortcuts.js', slave: 'Dev/shortcuts_remote.js' },
				'Infrastructure/modal_helper.js',
                "AboutBox/version.js"
            ],
            master:
            {
                always:     [ 'Infrastructure/sync.js', 'Infrastructure/preferences.js', 'Infrastructure/stats.js', 'Infrastructure/handlers.js' ],
                CEF:        [ 'Infrastructure/shell.js' ]
            },
            slave:
            {
                always:     [ 'Infrastructure/remote_sync.js', 'Infrastructure/preferences_remote.js', 'Infrastructure/stats.js', 'Infrastructure/handlers.js' ],
                CEF:        [ 'Infrastructure/remote_shell.js' ]
            }
        },
        requires: 
        {
            browser: 'CefContext'
        }
    },

    CefContext:
    {
        code:
        {
            master: [ 'Infrastructure/shell_mock.js', 'Infrastructure/sync_mock.js', 'Infrastructure/cef_mock.js', '../test/ConversationMock.js' ],
            slave: [ 'Infrastructure/remote_shell_mock.js', 'Infrastructure/remote_sync_mock.js', 'Infrastructure/cef_mock.js', '../test/ConversationMock.js' ]
        }
    },

   // external dependencies
   Dust:
   {
      code:       ['../shelf/dust/dust-full-1.2.3.js', '../shelf/dust/dust-helpers-1.1.1.js']
   },

   StackBlur:
   {
      code:      [ '../shelf/StackBlur/StackBlur.js' ]
   },

	Alerts: 
	{
		code:	[ 'Widgets/Alerts.js' ],
		style:  [ 'Alerts.css' ]
	},

	Dialog: 
	{
		code: [ 'Widgets/Dialog.js' ],
		templates: [ 'Dialog.js' ],
		style: [ 'dialog.css' ],
		requires: [ 'Template' ]
	},
 
    Toast:
    {
        code:      ['Toast/toast2.js'],
		templates: ['toast.js'],
		requires:  [ 'Infrastructure', 'CommonUtils', 'Template' ],
		style:     [ 'base.css', 'global.css', 'mod-toast.css'  ],
		initFn:	   'Caffeine.Toast.init'
    }
};
