//
//  DBAccess.h
//  McBrewery
//
//  Created by Fernando Pereira on 2/11/14.
//  Copyright (c) 2014 Yahoo!. All rights reserved.
//

#ifndef McBrewery_DBAccess_h
#define McBrewery_DBAccess_h

#include <sqlite3.h>


// db sanity checks
bool testDB(const char* dbName, bool doVacuum);
bool testMeta(const char* dbName);



// DB open/close
sqlite3* openDB(const char* dbName);
void closeDB(sqlite3* db);

// get/set Values in ItemTable
#define kBufferSize 4096

bool getValueFromKeyInItemTable(sqlite3* db, const char* key, char* value);
void setValueFromKeyInItemTable(sqlite3* db, const char* key, const char* value);
void deleteByKeyFromInItemTable(sqlite3* db, const char* key);

#endif
