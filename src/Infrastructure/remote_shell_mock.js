/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

Caffeine.Desktop =
{
	popupWindow: function(parms, cb)
	{
		Caffeine.IPC.remoteCall('main', "Caffeine.Desktop.popupWindow", parms, cb);
	},
	dockedWindow: function(parms, cb)
	{
		parms.dockedTo = parms.dockedTo || Caffeine.IPC.id;
		Caffeine.IPC.remoteCall('main', "Caffeine.Desktop.dockedWindow", parms, cb);
	},
	closeWindow: function(parms)
	{
		Caffeine.getBootstrapIntf().close(parms);
	},
	startFlashing: function(parms)
	{
	},
	stopFlashing: function(parms)
	{
	},
	windowClosed: function(parms) {
	    console.log("remote_shell_mock::windowClosed(",parms,")");
        Caffeine.IPC.remoteCall('main', "Caffeine.Desktop.windowClosed", parms);
	},
    setUserAgent: function(user_agent) {
    },
    setPrefixMapping: function(oldPrefix, newPrefix) {
    },
    activateWindow: function() {
        self.focus();
    },
    hasFocus: function() {
        return document.hasFocus();
    },
    resize: function(parms, cb)
    {
		Caffeine.IPC.remoteCall('main', 'Caffeine.Desktop.resize', parms, cb);
    },
    hideWindow: function(parms, cb) {
        var div = document.createElement("div"),
            style = div.style;

        style.position = "absolute";
        style.left = "0px";
        style.top = "0px";
        style.bottom = "0px";
        style.right = "0px";
        style.backgroundColor = "white";
        div.textContent = "This is hidden";
        style.transition = "top 5s";
        document.body.appendChild(div);
        setTimeout(function() {
            style.top = "100%";
        }, 3);
    },
    showWindow: function(parms, cb) {
    }
};

Caffeine.Desktop.modalWindow = Caffeine.Desktop.popupWindow;

})();
