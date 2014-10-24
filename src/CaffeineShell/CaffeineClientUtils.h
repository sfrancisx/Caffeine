//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_CLIENT_H
#define CAFFEINE_CLIENT_H
#pragma once

#include <string>
#include "include/cef_base.h"
//#include "CaffeineClientApp.h"

class CefApp;
class CefBrowser;
class CefCommandLine;

// Returns the main browser window instance.
//CefRefPtr<CefBrowser> AppGetBrowser();

// Returns the main application window handle.
//CefWindowHandle AppGetMainHwnd();

// Returns the application working directory.
std::string AppGetWorkingDirectory();

// Initialize the application command line.
void AppInitCommandLine(int argc, const char* const* argv);

// Returns the application command line object.
CefRefPtr<CefCommandLine> AppGetCommandLine();

#endif  // CAFFEINE_CLIENT_H