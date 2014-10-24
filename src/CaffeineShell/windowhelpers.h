//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_WINDOW_HELPERS_H
#define CAFFEINE_WINDOW_HELPERS_H
#pragma once

//  Includes
#include "defines.h"
#include <windows.h>
#include <string>
#include <list>
#include <map>
//  TODO:  Do we want a CEF dependency here?
#include "include/cef_base.h"
#include "include/cef_values.h"

#define CHANNEL_PATH           TEXT("Software\\") COMPANY TEXT("\\Update\\Channels\\") PRODUCT
#define INSTALLER_STATS_PATH   TEXT("Software\\") COMPANY TEXT("\\") PRODUCT TEXT("\\Install\\stats")
#define INSTALLER_STATS_VALUE  TEXT("data")

#define MAX_STATS_SIZE         (4096)
#define INFO_BUFFER_SIZE       (8192)
#define VERT_EDGE_TOLERANCE    (50)
#define BOTTOM_EDGE_TOLERANCE  (50)

typedef std::list<std::wstring> GUIDList;
typedef std::map<std::wstring, std::wstring> PersistentValues;
typedef std::pair<std::wstring, std::wstring> PersistentValue;
typedef HRESULT (WINAPI *pfnIsInternetConnected)();

//  Make this a singleton?
class IsInternetConnected
{
    public:
        IsInternetConnected();
        ~IsInternetConnected();

        bool operator()();

    private:
        pfnIsInternetConnected connect_fn;
        HMODULE hConnect;
};

//  TODO:  Eventually, we only need one of these structs.
class WindowExtras
{
    public:
        WindowExtras();
        ~WindowExtras();

        UINT IdleTimeThreshold;
        bool IsIdle;
        IsInternetConnected NetworkAvailable;
        bool IsConnected;

    private:
        WindowExtras(const WindowExtras &);
};

bool BackupFile(std::wstring file);
bool DeletePersistentValue(std::wstring key);
std::wstring ExtractYID(std::wstring YidValue);
void FixupWndProcs(const HWND &hwndOuterWindow);
std::wstring GetIPbyName(const std::wstring& hostName);
PersistentValue GetPersistentValue(std::wstring key);
PersistentValues GetPersistentValues();
LRESULT HitTestBorders(const RECT &client_rect, const POINT &point);
bool InternalGetLangCode(HKEY hKey, PDWORD val);
LRESULT CALLBACK newWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
void NormalizeScreenCoordinates(RECT &screenCoordinates);
bool IsValidRequestURL(std::string url);
bool SetPersistentValue(const std::wstring key, const std::wstring value);
bool ShowFolder(std::string directory, std::string selected_file);
bool ShowFolder2(std::wstring directory, CefRefPtr<CefListValue> selected_files);

//  TODO:  This needs to be moved somewhere else
GUIDList GetChannelGUIDs();
std::wstring GetInstallerStats();

bool IsWindowsVistaOrGreater();
std::wstring GetLastErrorString();

int GetWindowBorderSize(HWND hwnd);

#endif  //  CAFFEINE_WINDOW_HELPERS_H