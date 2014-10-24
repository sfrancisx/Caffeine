//
//  DBAccess.c
//  McBrewery
//
//  Created by Fernando Pereira on 2/11/14.
//  Copyright (c) 2014 Yahoo!. All rights reserved.
//

#include <stdio.h>
#include <string.h>
#include "DBAccess.h"


// -----------------------------------------------------------------------------------------
// sanity checks for sqlite dbs
// -----------------------------------------------------------------------------------------


const char*   integrityCheck = "pragma integrity_check;";
const char*   vacuum = "vacuum;";
//const char*   checkMeta = "select count(*) from ItemTable;";
const char*   checkMeta = "select * from ItemTable;";

static int callback(void *NotUsed, int nrCols, char **retVals, char **azColName)
{
    /*
    for (int i=0; i<nrCols; i++)
        fprintf(stderr, "%s:%s ", azColName[i], retVals[i]);
    if (nrCols)
        fprintf(stderr, "\n");
    */
    
    if ( nrCols == 0 )
        return 1;
    
    if ( retVals == NULL )
        return 1;
    
    // if we expected integrity_check:ok but it failed,
    if ( nrCols == 1 &&  strcmp("integrity_check", azColName[0]) == 0  && strncmp(retVals[0],"ok",2) != 0 )
    {
        fprintf(stderr, "============ DB APPCACHE INTEGRITY FAILED =========== ");
        return 1;
    }
    
    return 0;
}

bool execInDB(sqlite3 *db, char* cmd)
{
    char *zErrMsg = 0;
    //fprintf(stderr, "Executing %s \n", cmd);
    int rc = sqlite3_exec(db, cmd, callback, 0, &zErrMsg);
    if ( rc ) {
        //TODO: remove comment after I am sure this error is ignored in the tests
        fprintf(stderr, "SQL error: %s\n", zErrMsg);
        sqlite3_free(zErrMsg);
        sqlite3_close(db);
        return false;
    }
    return true;
}

bool testDB(const char* dbName, bool doVacuum)
{
    sqlite3 *db;
    //fprintf(stderr, "Testing database %s\n", dbName);
    int rc = sqlite3_open(dbName, &db);
    if ( rc ) {
        fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
        sqlite3_close(db);
        return false;
    }
    
    if ( !execInDB (db, (char*)integrityCheck ))
        return false;
    
    if ( doVacuum )
    {
        if ( !execInDB (db, (char*)vacuum ))
            return false;
    }
    
    sqlite3_close(db);
    return true;
}

bool testMeta(const char* dbName)
{
    sqlite3 *db;
    //fprintf(stderr, "Testing database for data %s\n", dbName);
    int rc = sqlite3_open(dbName, &db);
    if ( rc ) {
        fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
        sqlite3_close(db);
        return false;
    }
    
    if ( !execInDB (db, (char*)checkMeta ))
        return false;
    
    sqlite3_close(db);
    //fprintf(stderr, "Testing successful");
    return true;
}



// -----------------------------------------------------------------------------------------------------------
// get/set access to keyvalues in itemtable
//
// supported schema is:
// CREATE TABLE ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB NOT NULL ON CONFLICT FAIL);
// -----------------------------------------------------------------------------------------------------------

sqlite3* openDB(const char* dbName)
{
    sqlite3 *db = NULL;
    int rc = sqlite3_open(dbName, &db);
    if ( rc ) {
        fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
        sqlite3_close(db);
        return NULL;
    }
    return db;
}

void closeDB(sqlite3* db)
{
    sqlite3_close(db);
}


static int callback_for_buffer(void *callbackBuffer, int nrCols, char **retVals, char **azColName)
{
    if ( nrCols != 1 ) return 1; // error
    if ( nrCols == 0 ) return 1; // empty
    if ( retVals == NULL ) return 1; // empty
    
    unsigned long copySz = strlen(retVals[0]);
    if ( copySz >= kBufferSize )
        copySz = kBufferSize - 1;
    memcpy(callbackBuffer, retVals[0], copySz);
    return 0;
}


bool getValueFromKeyInItemTable(sqlite3* db, const char* key, char* value)
{
    char cmdBuffer[kBufferSize];
    
    sprintf(cmdBuffer, "select value from ItemTable where key='%s'", key);
    
    char *zErrMsg = 0;
    memset(value, 0, kBufferSize);
    
    int rc = sqlite3_exec(db, cmdBuffer, callback_for_buffer, value, &zErrMsg);
    if ( rc != SQLITE_OK ) {
        fprintf(stderr, "SQL error: %s\n", zErrMsg);
        sqlite3_free(zErrMsg);
        return false;
    }
    return true;
}


void setValueFromKeyInItemTable(sqlite3* db, const char* key, const char* value)
{
    char cmdBuffer[kBufferSize];
    char *zErrMsg = 0;
    char* buffer[kBufferSize];

    if ( *value != '{' ) // all values not stored as JSON are a string
        sprintf(cmdBuffer, "insert or replace into ItemTable (key,value) values ('%s','\"%s\"')", key, value);
    else
        sprintf(cmdBuffer, "insert or replace into ItemTable (key,value) values ('%s','%s')", key, value);
    
    int rc = sqlite3_exec(db, cmdBuffer, callback_for_buffer, buffer, &zErrMsg);
    if ( rc != SQLITE_OK )
    {
        fprintf(stderr, "SQL error: %s\n", zErrMsg);
        sqlite3_free(zErrMsg);
    }
}

void deleteByKeyFromInItemTable(sqlite3* db, const char* key)
{
    char cmdBuffer[kBufferSize];
    char *zErrMsg = 0;
    char* buffer[kBufferSize];
    
    sprintf(cmdBuffer, "delete from ItemTable  where key='%s'", key);
    
    int rc = sqlite3_exec(db, cmdBuffer, callback_for_buffer, buffer, &zErrMsg);
    if ( rc != SQLITE_OK )
    {
        fprintf(stderr, "SQL error: %s\n", zErrMsg);
        sqlite3_free(zErrMsg);
    }
    
}