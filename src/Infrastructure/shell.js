/*
 * Copyright (c) 2013, Yahoo! Inc. All rights reserved.
 * Copyrights licensed under the New BSD License.
 * See the accompanying LICENSE file for terms.
 */

(function(){

    var windows			= { },
		nextBlankId		= 1,
		inCreate = false,
		poppingWindows	= [ ],
		isClosingChildWindows = false, closeChildWindowsCB,
		failSafeTId,
		isSettingDownloadPath, downloadPathQueue = [],
		dockedPairs = {},
		modalWindowStore = {
			id: undefined
		};

    // The interface is exported as Caffeine.Desktop.
    /**
     * @module Infrastructure
     * @namespace Caffeine
     * @class Desktop
     * @static
     */


	 Caffeine.modalWindowStore = modalWindowStore;
	 Caffeine.IPC.synchronizeObject(modalWindowStore);
	 Caffeine.ModalHelper.bind({ modalStore: modalWindowStore });
		
        /******************************************************************************
         * Create a modal window.
         *
         * @method modalWindow
         * @param {Object} parms Initialization parameters for the new window.  This
         *                    object will be passed to the window's Init() function.
         * @param {function} cb     A function that gets called when the window calls
         *                    closeWindow() on itself.
         *****************************************************************************/
        Caffeine.Desktop.modalWindow = function(parms, cb) {
			parms.isModal = true;
			Caffeine.Desktop.popupWindow(parms, cb);
        };

        /******************************************************************************
         * Close a popup or modal window
         *
         * @method closeWindow
         * @param {Object} parms An object that will be passed to the opener's callback
         *                    function.
         *****************************************************************************/
        Caffeine.Desktop.closeWindow = function(parms) {
          console.log('Shell: closeWindow for target='+parms.target);
        };

        Caffeine.Desktop.windowClosed = function(target) {
			var winLen;

            Caffeine.Desktop.unregisterWindow(target);
            console.log('Shell: closeWindow for target='+target);
            Caffeine.IPC.windowClosed(target);

			if(isClosingChildWindows && closeChildWindowsCB) {
				winLen = Object.keys(windows).length;
				console.log("WClose: remaining windows length = " + winLen);
				if(winLen === 0) {
					isClosingChildWindows = false;
					console.log("WClose: calling closeChildWindowsCB");
					clearTimeout(failSafeTId);
					closeChildWindowsCB();
				}
			}
        };

        Caffeine.Desktop.unregisterWindow = function(target) {
           var	key,
				dPair = dockedPairs[target];

		   if(dPair) {
				delete dockedPairs[target];
		   }

		   key = getWinKeyFromVal(target);
		   if(key) {
				console.log('Shell: unregisterWindow ' + key + '= ' + target);
				delete windows[key];
				unregisterModalWindow(target);
		   }
        };

		function getWinKeyFromVal(target) {
			for(key in windows) {
				if(target == windows[key]) {
					return key;
				}
			}
		}

		function registerModalWindow(id) {
			modalWindowStore.id = id;
		}
		
		function unregisterModalWindow(id) {
			if( id === modalWindowStore.id) {
				modalWindowStore.id = undefined;
			}
		}

		function isModalWindowOpen() {
			return !!modalWindowStore.id;
		}

		/**
		 * close all child windows.
		 * returns "true" if child windows available otherwise false
		 *
		 * @method closeChildWindows
		 *
		 * @param {Object} parms
		 * 
		 * @param {Function} cb The callback function which will be called after the child windows are called. Callback is not callled if there are no child windows available
		 *	
		 */
		Caffeine.Desktop.closeChildWindows =  function(parms, cb) {
			var wIds = Object.keys(windows), 
				childWindowsLen = wIds.length;

			if(childWindowsLen) {
				isClosingChildWindows = true;
				closeChildWindowsCB = cb;
				wIds.forEach(function(key) {
					Caffeine.IPC.remoteCall(windows[key], "Caffeine.Desktop.closeWindow", { appShutdown: true });
				});
				console.log("WClose: closing remote closeWindow and closeChildWindowsCB is set");

				failSafeTId = setTimeout(function() {
					var wNames = "";

					Object.keys(windows).forEach(function(name) {
						wNames += name + " ";
						delete windows[name];
					});

					console.log("WClose: child windows were not closed properly. Unclosed windows are " + wNames + ". Continuing with fail safe execution");

					Caffeine.Stats && Caffeine.Stats.fire( {
						category:	 "Diagnostics",
						subcategory: "Shell",
						name:		 "FailedChildWindowsClose",
						type:		 "counter",
						windows:	 wNames
					});

					isClosingChildWindows = false;

					closeChildWindowsCB();

				}, 10000);

				return true;
			} else {
				return false;
			}
		};

		/**
		 * force close a remote window
		 * returns true if the window exists otherwise returns false
		 * 
		 * @method forceCloseWindow
		 * 
		 * @param {String} target
		 */
		 Caffeine.Desktop.forceCloseWindow = function(target) {
			var id = windows[target];
			if(id) {
				Caffeine.IPC.remoteCall(id, "Caffeine.Desktop.closeWindow", { appShutdown: true });
				return true;
			}
			return false;
		};
        
        /******************************************************************************
         * Create an About Window
         *
         * @method aboutWindow
         * @param {Object} none
         *   - goal is to have the same function called from the header.js, Mac Shell (native menus)
         *****************************************************************************/
        Caffeine.Desktop.aboutWindow = function() {
        	Caffeine.Desktop.popupWindow({ module: "About", width: 1100, height: 800, target: 'feedback' },
            	function(err, result) {
                });
        };

		/**
		 * @method getIpcId
		 * @param {String} target		Name of the window
		 *
		 * Get the IPC ID of a window given its target name.  Can also be used to
		 * check for the existance of a window.
		 *
		 * This is of limited usefulness.  It's provided so stats can distinguish between
		 * new window & re-used window states.
		 */
        Caffeine.Desktop.getIpcId = function(target, cb)
        {
			cb && cb(windows[target]);
			return windows[target];
        };

        /******************************************************************************
         * Create a non-modal popup window.
         *
         * @method popupWindow
         * @param {Object} parms Initialization parameters for the new window.  This
         *                    object will be passed to the window's Init() function.
         * @param {function} cb     A function that gets called when the window calls
         *                    closeWindow() on itself.
         *****************************************************************************/
        Caffeine.Desktop.popupWindow = function(parms, cb) {
            var id, size, timeoutId,
                wndSizes = Caffeine.preferences.windows.sizes,
				isHidden = parms.doNotShow,
				isResizable = true,
				isModal = parms.isModal;

			// Serialize window creation - we need to make sure we don't try to target a window that's in
			// the process of being created (or which isn't yet completely initialized)
            if(inCreate)
			{
				console.log("Shell:popupWindow: queing to poppingWindows. Queue length is " + poppingWindows.length);
                poppingWindows.push([ Caffeine.Desktop.popupWindow, parms, cb ]);
				return;
			}
			
			if(isModal && isModalWindowOpen()) {
				cb({ code: "MODALEXISTS", message: "Modal window exists" }, null);
				return;
			}

            inCreate = true;

            parms.target = parms.target || "_default";
            parms.locale = Caffeine.appMode.locale;
            if ( typeof (parms.resizable) != 'undefined' && parms.resizable == false )
            	isResizable = false;            

            if (parms.target == '_blank')
                parms.target = "UnnamedWindow" + (nextBlankId++);

            if (!parms.width || !parms.height)
            {
                size = wndSizes[parms.target] || wndSizes.default;
                
                if (size.left)
					parms.left = size.left;
                if (size.top)
					parms.top = size.top;
               
                parms.width = size.width;
                parms.height = size.height;
            }

			if(parms.left == undefined) {
				parms.left = 100;
			}
			if(parms.top == undefined) {
				parms.top = 100;
			}
			if(parms.height == undefined) {
				parms.height = 450;
			}
			if(parms.width == undefined) {
				parms.width = 300;
			}
			if(parms.minHeight == undefined) {
				parms.minHeight = 250;
			}
			if(parms.minWidth == undefined) {
				parms.minWidth = 250;
			}

            parms.preferences = Caffeine.preferences;
			parms.modalWindowStore = Caffeine.modalWindowStore;
            parms.appMode = Caffeine.appMode;

            id = windows[parms.target];
            if (id)
            {
               console.log('Shell: popupWindow for ' + parms.target + ' should already exist, and have an id of ' + id);

                Caffeine.IPC.remoteCall(id, 'Caffeine.Bootstrap.loadSources', parms, function() {
                        Caffeine.IPC.remoteCall(id, "Caffeine.Init", parms, creationComplete);
                    });
                return;
            }

			var modParms = parms.moduleParms;
			parms.moduleParms = 0;
			
			id = Caffeine.CEFContext.popupWindow(escape(JSON.stringify(parms)), !!parms.frameless,
				parms.height, parms.width, parms.left, parms.top, parms.target, isResizable, parms.minWidth, parms.minHeight);
					
			parms.moduleParms = modParms;

            windows[parms.target] = id;
            console.log('Shell: windows for ' + parms.target+ ' set to ' + id);

			if(isModal) {
				registerModalWindow(id);
			}
            
			Caffeine.IPC.remoteCall(id, 'Caffeine.Init', parms, creationComplete);

			// TODO: Stat this, fix the underlying problem.
			timeoutId = setTimeout(function(){ processWindowQueue(); }, 2500);

			Caffeine.IPC.windowOpened(id);

            return id;
            
            function creationComplete(err, data)
            {
				timeoutId && clearTimeout(timeoutId);
				timeoutId = 0;

				var state = err && typeof err === "object" && err._windowState;
				if(state === "loading" || state === "loaded") {
					if(state === "loading") {
						console.log("Shell:popupWindow: creationComplete called with loading state");
						processWindowQueue();
					} else {
						console.log("Shell:popupWindow: creationComplete called with loaded state");
						if(!isHidden) {
							Caffeine.IPC.remoteCall(id, 'Caffeine.Desktop.showWindow');
						}
						cb && cb(err.err, data);
					}	
				} else {
					console.log("Shell:popupWindow: creationComplete called with no state");
					if(!isHidden) {
						Caffeine.IPC.remoteCall(id, 'Caffeine.Desktop.showWindow');
					}
					cb && cb.apply(this, arguments);

					processWindowQueue();
				}
            }
        };

        //  TODO:  We're duplicating a lot of code here.
        Caffeine.Desktop.createToastWindow  = function(parms, cb) {
            parms.target = 'Toast';
            parms.locale = Caffeine.appMode.locale;
            parms.preferences = Caffeine.preferences;
            parms.appMode = Caffeine.appMode;

            var id = '-1';

            if ( Caffeine.appMode.Win) {
                id = Caffeine.CEFContext.toastWindow(escape(JSON.stringify(parms)), 'toast');
            }

            if (id == '-1') {
                var err = {'message' : 'New Toast Window is not supported for mac and XP & below'};
                cb && cb(err);
                return;
            }
            
            windows[parms.target] = id;
            console.log('Shell: windows for toast set to ' + id);

            Caffeine.IPC.remoteCall(id, 'Caffeine.Init', parms);

            Caffeine.IPC.windowOpened(id);

            cb && cb();
        };

		Caffeine.Desktop.showToast = function(parms) {
            parms.target = 'Toast';
            parms.locale = Caffeine.appMode.locale;
            parms.preferences = Caffeine.preferences;

            var id = windows[parms.target];
            if (id) {
				console.log('Shell: toastWindow for toast should already exist, and have an id of ' + id);
				Caffeine.IPC.remoteCall(id, "Caffeine.Toast.add", parms.moduleParms);
            } else {
                console.log('Shell: Cannot show toast because toast window has not been created');
            }
        };

        //  TODO:  A lot of redundant code here.
        Caffeine.Desktop.createDockedWindow = function(parms, cb) {
            var id, size,
                wndSizes = Caffeine.preferences.windows.sizes,
				dockedTo = parms.dockedTo,
				currDockedTo;

			/*if (inCreate)
			{
                poppingWindows.push([ Caffeine.Desktop.createDockedWindow, parms, cb]);
				return;
			}

            inCreate = true;*/

            parms.target = parms.target || "_default";
            parms.locale = Caffeine.appMode.locale;

            if (parms.target == '_blank')
                parms.target = "UnnamedWindow" + (nextBlankId++);

            if (!parms.width || !parms.height)
            {
                size = wndSizes[parms.target] || wndSizes.default;
                
                if (size.left)
               parms.left = size.left;
                if (size.top)
               parms.top = size.top;

                parms.width = size.width;
                parms.height = size.height;
            }

            parms.preferences = Caffeine.preferences;
			parms.modalWindowStore = Caffeine.modalWindowStore;
            parms.appMode = Caffeine.appMode;

            // XXX note: right now, these are all dockedWindow
            id = windows['dockedWindow'];   
            // XXX note: the mac shell resuses a dock if trying to open a new one
            if (id)
            {
				currDockedTo = dockedPairs[id];
				if(currDockedTo && getWinKeyFromVal(currDockedTo)) { //Making sure the parent window still exists
					console.log("Shell:popupWindow dockedWindow exists. Doing IPC remote call to load sources");
					Caffeine.IPC.remoteCall(id, 'Caffeine.Bootstrap.loadSources', parms, function() {
							Caffeine.IPC.remoteCall(id, "Caffeine.Init", parms, creationComplete);
						});
					return id;
				}
            }
            id = Caffeine.CEFContext.dockedWindow(escape(JSON.stringify(parms)), dockedTo, parms.width, parms.minTop, parms.minBottom);
            windows['dockedWindow'] = id;
			dockedPairs[id] = dockedTo;

            Caffeine.IPC.remoteCall(id, 'Caffeine.Init', parms, creationComplete);

			Caffeine.IPC.windowOpened(id);

            return id;

            function creationComplete()
            {
				console.log("Shell:popupWindow: createDockedWindow finished and calling callback");
				cb && cb.apply(this, arguments);

                //processWindowQueue();
            }

        };


        function processWindowQueue() {
            //Removes the current window which finished loading
            inCreate = false;
            if(poppingWindows.length) {
                var next = poppingWindows.shift();
                next[0](next[1], next[2]);
            }
        }


(function()
{
   var width, top, bottom, minTop, minBottom, dockedTo;

   Caffeine.Desktop.dockedWindow = function(parms, cb)
   {
      width    = parms.width || 100;
      top         = parms.top || 0;
      bottom      = parms.bottom || 0;
      minTop      = parms.minTop || 20;
      minBottom   = parms.minBottom || 20;
      dockedTo = parms.dockedTo || 'main';

      var id = Caffeine.Desktop.createDockedWindow(parms, cb),
         win = Caffeine.CEFContext.getWindow(parms.target),
         dockedTo = Caffeine.CEFContext.getWindow(parms.dockedTo);

      
      //setInterval(moveWindow, 50);

      function moveWindow()
      {
         var newLeft, newTop, newBottom;

         newLeft = dockedTo.screenX - width;
         if (dockedTo.screenX > dockedTo.screen.width)
            newLeft -= dockedTo.screen.width;

         newTop = top;
         if (top < 0)
            newTop += dockedTo.outerHeight;
         newTop = Math.min(newTop, minTop);
         newTop += dockedTo.screenY;

         newBottom = -bottom;
         if (bottom >= 0)
            newBottom += dockedTo.outerHeight;

         newBottom = Math.min(newBottom, dockedTo.outerHeight - minBottom);

         newBottom += dockedTo.screenY;

         win.moveTo(newLeft, newTop);
         win.resizeTo(width + (win.outerWidth - win.innerWidth), newBottom - newTop + (win.outerHeight - win.innerHeight));
      }
   }

   Caffeine.Desktop.resize = function(parms, cb)
   {
      /// XXX calling  
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
   }
})();

    Caffeine.Desktop.hideWindow = function(parms, cb) {
    	Caffeine.CEFContext.hideWindow(IPC_id);
    };
    Caffeine.Desktop.showWindow = function(parms, cb) {
    	Caffeine.CEFContext.showWindow(IPC_id);
    };
    Caffeine.Desktop.setTransparency = function(parms, cb) {
    };

    Caffeine.Desktop.startFlashing = function(parms, cb) {
        console.log("Caffeine.Desktop.startFlashing() called.");
        Caffeine.CEFContext.startFlashing(IPC_id, true);
    };
    Caffeine.Desktop.stopFlashing = function(parms, cb) {
        console.log("Caffeine.Desktop.stopFlashing() called.");
        Caffeine.CEFContext.stopFlashing(IPC_id);
    };
    Caffeine.Desktop.activateWindow = function() {
        Caffeine.CEFContext.activateWindow(IPC_id);
    };
    Caffeine.Desktop.setUserAgent = function(user_agent) {
        Caffeine.CEFContext.setUserAgent(user_agent);
    };
    Caffeine.Desktop.setPrefixMapping = function(oldPrefix, newPrefix) {
        Caffeine.CEFContext.setPrefixMapping(oldPrefix, newPrefix);
    }
    Caffeine.Desktop.hasFocus = function() {
        return Caffeine.CEFContext.hasFocus(IPC_id);
    };
	
	Caffeine.Desktop.isActivated = function(parms, cb) {
		cb && cb(Caffeine.getBootstrapIntf().isActivated());
	};

	Caffeine.Desktop.setDownloadPath = function(parms, cb) {
		var path = parms.path;

		downloadPathQueue.push({ path: path, cb: cb });
		if(!isSettingDownloadPath) {
			isSettingDownloadPath = true;
			Caffeine.CEFContext.setDownloadPath(path, setDownloadPathCB);
		}
	};
	
    Caffeine.Desktop.setFeedbackLink = function() {
	    var feedback= Caffeine.UserUtils.getUserFeedbackLink();
        Caffeine.CEFContext.setBrowserValue(0,feedback);
    };
	

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
        
})();
