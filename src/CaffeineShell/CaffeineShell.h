//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_SHELL_H
#define CAFFEINE_SHELL_H
#pragma once

#define MAX_LOADSTRING  (100)
#define MAX_URL_LENGTH  (255)

#define CACHE_TOO_BIG_BYTES (536870912)  //512MB

#define SHUTDOWN_KEY_PATH   TEXT("Software\\") COMPANY TEXT("\\") PRODUCT
#define SHUTDOWN_KEY_VALUE  TEXT("ShutdownStatus")
#define DEBUG_LOG_REGEX     ("Corrupt Index file|Unable to create cache")

#include "defines.h"
#include <Windows.h>
#include <Shlobj.h>
#include <Shlwapi.h>
#include <string>

#include <tchar.h>

HANDLE getCaffeineSemaphore();
bool SetShutdownFlag(bool bClear);
bool ImproperShutdownHappened();

//  TODO:  Does this need to be lockable?
class CaffeineSettings
{
    public:
        std::wstring user_dir;
        std::wstring app_cache_dir;
        std::wstring console_log;
        std::wstring debug_log;

        CaffeineSettings()
        {
            WCHAR szTemp[2*MAX_PATH] = {0,};

            ::SHGetFolderPath(NULL, CSIDL_LOCAL_APPDATA|CSIDL_FLAG_CREATE, NULL, 0, szTemp);
            ::PathAppend(szTemp, COMPANY);
            user_dir = szTemp;

            ::wcscpy(szTemp, user_dir.c_str());
            ::PathAppend(szTemp, APP_CACHE_NAME);
            app_cache_dir = szTemp;

            ::wcscpy(szTemp, user_dir.c_str());
            ::PathAppend(szTemp, L"console.log");
            console_log = szTemp;


            ::wcscpy(szTemp, user_dir.c_str());
            std::wstring debug_log_name = L"debug.log";
            ::PathAppend(szTemp, debug_log_name.c_str());
            debug_log = szTemp;
        }
};

#endif  //  CAFFEINE_SHELL_H



