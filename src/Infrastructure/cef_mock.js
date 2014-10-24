/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

// This file has mock implementations of functionality provided by CEF.
// Other files have mock CEF functionality - shell_mock.js, sync_mock.js.  This
// file contains miscellaneous stuff that doesn't rate a dedicated file.

window.IPC_id = 'main';

if (!window.Caffeine)
	window.Caffeine = { };

window.Caffeine.CEFContext =
{
	stopFlashing:	function() { }
};

window.Caffeine.IPC = { id: IPC_id };

Caffeine.CEFContext.getIP = function() {
	return "127.0.0.1";
}

Caffeine.CEFContext.isInternalIP = function() {
	return false;
}

Caffeine.CEFContext.setUserAgent = function(agent)
{
}

Caffeine.CEFContext.setUserToken = function() {
}
Caffeine.CEFContext.getUserToken = function() {
}
Caffeine.CEFContext.removeUserToken = function() {
}
Caffeine.CEFContext.removeAllUserTokens = function() {
}

Caffeine.CEFContext.getWindowState = function() {
    return "normal";
}

Caffeine.CEFContext.setPersistentValue = function() {
}
Caffeine.CEFContext.getPersistentValue = function() {
}
Caffeine.CEFContext.removePersistentValue = function() {
}
Caffeine.CEFContext.getAllPersistentValues = function() {
}

Caffeine.CEFContext.getLocale  = function() {
	return("en-US");
}
// in Browser/Windows won't nede this as gear menu handles logouts
Caffeine.CEFContext.stateIsNowLoggedIn = function(value)
{
}

Caffeine.CEFContext.getUpdaterVersion = function()
{
    return "1.0.37.0";
}

Caffeine.CEFContext.activateApp = function() {
}

Caffeine.CEFContext.showViewMenu = function() {
}

Caffeine.CEFContext.setBadgeCount = function() {
}

Caffeine.CEFContext.showWindow = function() {
}

Caffeine.CEFContext.hideWindow = function() {
}

Caffeine.CEFContext.moveWindowTo = function(left,top,height,width) {
}

Caffeine.CEFContext.getUpdateChannel = function() { return 'Dev'; }

Caffeine.CEFContext.getIPbyName = function() {
}

Caffeine.CEFContext.showFileSaveAsDialog = function() {
}

Caffeine.CEFContext.shellSetsLocation = function() {
  return false;
}

Caffeine.CEFContext.restartApplication = function() {
}

Caffeine.CEFContext.enableSessionMenus = function() {
}

Caffeine.CEFContext.setEphemeralState = function() {
}

Caffeine.CEFContext.getLatestVersion = function() { 
}

Caffeine.CEFContext.getDownloadPathFromUser = function() {
}

Caffeine.CEFContext.showDirectory = function() {
}
