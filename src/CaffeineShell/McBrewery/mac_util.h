//
//  mac_util.h
//  McBrewery
//
//  Created by pereira on 3/16/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

// C++ to Objective-C++ bridge
// mac_util* declarations are C++ only so that they can be called from CEF code
//           implementation is Objective C++
//
//           mac_util.mm: AppKit (UI) dependent code
//                        used only by the browser process
//                        render processes define stubs for these
//
//           mac_util_agent.mm: called by both browser and render processes

#ifndef McBrewery_mac_util_h
#define McBrewery_mac_util_h

#ifdef ENABLE_MUSIC_SHARE
//void getITunesTrackInfo(CefRefPtr<CefDictionaryValue>& TrackInfo );
void checkiTunes(const std::string& callbackName);

void InternalITunesPlayPreview(const std::wstring& previewURL);
#endif //ENABLE_MUSIC_SHARE

// converts URL to use full path to the Resource directory, if required
bool convertURL(std::string& original, std::string& converted);

// files
bool openFileDlg(std::vector<CefString>& file_paths, bool multiple, bool allowDirectories, const std::vector<CefString>& accept_types, bool pickDirToSave);
bool saveFileDlg(std::vector<CefString>& file_paths, std::wstring& default_file_name);

// returns true if found
// and if so, it fills the output values
bool findMatch(std::string& original, std::map<std::string, std::string>& map,
               // output
               std::string& newURL, std::string& mapVal);

bool findIfItsFileTransferRelay(std::string& original, std::string& mapVal);


bool ShowFolder(std::string directory, std::string selected_file);
bool ShowFolder2(std::wstring directory, CefRefPtr<CefListValue> selected_files);
bool renameOldFile(std::wstring filename);

// activates window
void activatesWindow(const std::string& uuid);

// show/hide window
void showWindow(const std::string& uuid);
void hideWindow(const std::string& uuid);

// show/hide View menu
void showViewMenu(bool showOrHide);

// move/resize window
void AppMoveOrResizeWindow(const std::string& uuid, const int left, const int top,  const int height, const int width);

// is the app active
bool isAppActive();

// is this window the key window?
bool isWindowActive(const std::string& uuid);

// gets main NSView*
CefWindowHandle AppGetMainHwnd();

// gets Main handle
CefRefPtr<CaffeineClientHandler> AppGetMainHandler();

// gets  handle by UUID
CefRefPtr<CaffeineClientHandler> AppGetHandler(const std::string& uuid);

// create window by UUID
void AppCreateWindow(const int height, const int width, const int left, const int top, const std::string& uuid, const char* initArg, bool frameless, bool resizable, const std::string& target, const int minWidth, const int minHeight);

// create dockable
void AppCreateDockableWindow(const std::string& uuid, const std::string& initArg, const std::string& targetUUID,
                          const int width, const int minTop, const int minBottom);

// gets frame by UUID
CefRefPtr<CefFrame> getFrameByUUID(std::string& browser_handle);

// gets browser by UUID
CefRefPtr<CefBrowser> getBrowserByUUID(std::string& browser_handle);

// bounces icon in Dock
void bounceDockIcon();

// badge count by nr_messages
void changeBadgeCount(int count, bool bRequest);

// flashing/shaking
void startFlashing(const std::string& uuid);
void stopFlashing(const std::string& uuid);

void shakeWindow(const std::string& uuid);

// message received while app isn't active:
void incomingMessage(const std::wstring& from, const std::wstring& displayName, const std::wstring& msg, const std::wstring& convId);

// Any session logged in (or not)
void sessionLoggedIn(bool loggedIn);

// enable session menus
void enableSessionMenus(bool value);

// validates video plugin location and version
bool isVideoPluginValid(const std::string& path, const std::string& version);

// opens link in external browser
void openURL(const std::wstring& url);

// gets download path
std::wstring  getDownloadName(const std::wstring& file_name);

// notification for a renderer crash
void rendererCrashed(CefRefPtr<CefBrowser> browser);

void LogMessageReceived(CefRefPtr<CefBrowser> browser,
                        CefProcessId source_process,
                        CefRefPtr<CefProcessMessage> message);

bool ns_regex_match(const std::string& name, const char* expression);

// Keychain handlings

void saveToken (const std::string& usr, const std::string& tok);
void removeToken(const std::string& usr );
void removeTokens ();

extern const int      kYMVendorID ;
extern const unsigned kDescriptionParameterMaxLength;

void alertMessage(std::wstring& message);

void setFeedbackLink(const std::string& link);

void launchFileFromFinder(const std::wstring& fileWithFullPath);

std::wstring LocalizedWrapper( const std::wstring& textTitle, const std::wstring& defaultText );

void activatesApp();

void validateFileResource(std::string& original);

void loadLocalizedString(const char* key, std::wstring value);

#endif

