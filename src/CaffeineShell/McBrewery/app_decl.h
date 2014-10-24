//
//  app_decl.h
//  McBrewery
//
//  Created by Fernando on 5/14/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

// NOTE:
// This include is ONLY for the 2 main processes
// one in YBreweryApplication
// other in the process_helper_mac

#ifndef McBrewery_app_decl_h
#define McBrewery_app_decl_h

// The global CaffeineClientHandler App reference.
CefRefPtr<CaffeineClientApp> app(new CaffeineClientApp);

// used to set the path for the JS, etc, files
// in LoadResource
//
// allows developers to choose an alternate path
//
const char* defaultPathValue    = "default";

const int   open_files_needed_by_msgr   = 10240;

// true if in main app, false if in helper
bool        inBrowserProcess;

// LOG_ENABLED or not
int         masterLogEnabled;

std::string userAgent;

#endif
