//
//  Brewery_platform.h
//  McBrewery
//
//  Created by Fernando on 6/24/13.
//  Copyright (c) 2014 Yahoo. All rights reserved.
//

#ifndef McBrewery_Brewery_platform_h
#define McBrewery_Brewery_platform_h

#if defined(__APPLE__)
// ------------- MacOS X definitions

#include <regex.h>
#include <unordered_map>

typedef void* HWND;

#include "MacSocketDefs.h"

#define TEXT(x)  (const char*) x

bool IsValidRequestURL(std::string url);
bool renameOldFile(std::wstring filename);
void MainLoadingStateChanged(bool isLoading);
void alertMessage(std::wstring& message);

void sendCrashReports(std::wstring comments, CefRefPtr<CefURLRequest> url_request);

void windowTitleChange(CefRefPtr<CefBrowser> browser, const std::wstring& title);

bool getDefaultUserToken(std::string& usr, std::string& tok);

void mainWindowFinishedLoading();

void ConsoleLog(int browser, const CefString& message);

extern int  masterLogEnabled;

#define CUSTOM_FILE_DIALOGS 1

extern "C" {

    long breweryGetpid();
    
}

typedef std::map<std::wstring, std::wstring> PersistentValues;
typedef std::pair<std::wstring, std::wstring> PersistentValue;

bool DeletePersistentValue(std::wstring key);
bool SetPersistentValue(const std::wstring key, const std::wstring value);
PersistentValue GetPersistentValue(std::wstring key);
PersistentValues GetPersistentValues();

void removeAllPersistentValues();
void closePersistentDB();

#elif defined(OS_WIN)
// ------------- Windows definitions

#include "windowhelpers.h"
#include "LanguageCodes.h"
#include <atlbase.h>
#include <Winsock2.h>
#include <tchar.h>

#include <hash_map>
#include <regex>

#include "CaffeineShell.h"
#include "CrashRpt.h"

#endif  //  __APPLE__

#endif  //  McBrewery_Brewery_platform_h
