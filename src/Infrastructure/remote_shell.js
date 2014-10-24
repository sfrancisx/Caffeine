/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

var isSettingDownloadPath, downloadPathQueue = [];

//var _flashWindowRequestors = [];	// This array keeps track of all the IM windows that is requesting for the window flash, once the list goes to 0, we stop flashing
//function findFlashingRequestor(id) {
//	for (var i=0; i<_flashWindowRequestors.length; i++) {
//		if (_flashWindowRequestors[i] == id) {
//			return i;
//		}
//	}
//	return -1;
//}
function _startFlashing(parms /*Requestor Id*/)
{	
//	if (parms && parms.length > 0 && findFlashingRequestor(parms) == -1) {
//		_flashWindowRequestors.push(parms);
		console.log("Caffeine.Desktop.startFlashing() called.");
		Caffeine.CEFContext.startFlashing(IPC_id, true);
//	}
}
function _stopFlashing(parms)
{
//	if (parms && parms.length > 0) {
//		var index = findFlashingRequestor(parms);
//		if (index >= 0) {
//			_flashWindowRequestors.splice(index, 1);
//		}
//		if (_flashWindowRequestors.length == 0) {
//	        console.log("Stop Flashing");
            console.log("Caffeine.Desktop.stopFlashing() called.");
			Caffeine.CEFContext.stopFlashing(IPC_id);
//		}
//	}
}

function setDownloadPathCB() {
	var item = downloadPathQueue.shift(),
		cb = item.cb,
		qlen;

	try {
		cb && cb();
	} catch(e) {}

	qlen = downloadPathQueue.length;

	if(qlen === 0) {
		isSettingDownloadPath = false;
	} else {
		Caffeine.CEFContext.setDownloadPath(downloadPathQueue[0].path, setDownloadPathCB);
	}
}

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
	modalWindow: function(parms, cb) {
		Caffeine.IPC.remoteCall('main', "Caffeine.Desktop.modalWindow", parms, cb);
	},
	startFlashing: _startFlashing,
	stopFlashing: _stopFlashing,
    activateWindow: function(parms)
    {
        Caffeine.CEFContext.activateWindow(IPC_id);
    },
    windowClosed: function(parms) 
    {
        Caffeine.IPC.remoteCall('main', "Caffeine.Desktop.windowClosed", parms);
    },
    setUserAgent: function(user_agent) {
        Caffeine.CEFContext.setUserAgent(user_agent);
    },
    setPrefixMapping: function(oldPrefix, newPrefix) {
        Caffeine.CEFContext.setPrefixMapping(oldPrefix, newPrefix);
    },
    hasFocus: function(parms)
    {
        return Caffeine.CEFContext.hasFocus(IPC_id);
    },
    resize: function(parms, cb)
    {
		if(typeof parms == 'undefined')  {
		  console.log('Caffeine.Desktop.resize called with parms undefined - returning');
		  return;		  
		}

		width       = parms.width || 350;
		height      = parms.height || 400;
		left        = parms.left || 20;
		top         = parms.top || 20;

		Caffeine.CEFContext.moveWindowTo(left,top,height,width);

		cb && cb();
    },
    hideWindow: function(parms, cb) {
        Caffeine.CEFContext.hideWindow(IPC_id);
    },
    showWindow: function(parms, cb) {
        Caffeine.CEFContext.showWindow(IPC_id);
    },
	closeWindow : function(parms) {
		Caffeine.getBootstrapIntf().close(parms);
	},
	isActivated: function(parms, cb) {
		cb && cb(Caffeine.getBootstrapIntf().isActivated());
	},
	setDownloadPath: function(parms, cb) {
		var path = parms.path;

		downloadPathQueue.push({ path: path, cb: cb });
		if(!isSettingDownloadPath) {
			isSettingDownloadPath = true;
			Caffeine.CEFContext.setDownloadPath(path, setDownloadPathCB);
		}
	}

};

})();

