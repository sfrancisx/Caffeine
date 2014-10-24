//
//  mac_util_agent.mm
//  McBrewery
//
//  Created by pereira on 4/5/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <string>
#include <vector>
#include <map>
#import "NSString_NSString_wstring.h"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#include "include/cef_base.h"
#pragma clang diagnostic pop
#include "CaffeineClientApp.h"  // NOLINT(build/include)
#include "mac_util.h"
#import "CommonDefs.h"
#import "NSString_Encode.h"
#import "YPreferencesManager.h"


extern int  gCurrentOS;
extern bool gInDev0;
extern int  masterLogEnabled;
extern std::string userAgent;

#pragma mark --- other functions

void DumpRequestContents(CefRefPtr<CefRequest> request, std::string& str);

extern std::string mainUUID ;
extern CefRefPtr<CaffeineClientApp> app;


// Global working directory - same as cache location, ~/Library/Caches
std::string AppGetWorkingDirectory()
{
    NSString* logPath = @"~/Library/Caches/";
    return [[logPath stringByExpandingTildeInPath] UTF8String];
    //return ( [[appSupport stringByExpandingTildeInPath] UTF8String] );
    //return [privateDataPath() UTF8String];
}


bool ns_regex_match(const std::string& name, const char* expression)
{
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithUTF8String:expression]
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    
    // Check for any error returned.  This can be a result of incorrect regex
    // syntax.
    if (error)
    {
        YLog(LOG_NORMAL, @"Error creating regex - %@", error);
        return false;
    }
    
    NSString* strName = [NSString stringWithUTF8String: name.c_str()];
    NSUInteger numberOfMatches = [regex numberOfMatchesInString:strName
                                                        options:0
                                                          range:NSMakeRange(0, [strName length])];
    
    if ( numberOfMatches < 1  )
        return false;
    
    //YLog(LOG_NORMAL, @"ns_regex_match for %s, number of matches = %ld", name.c_str(), numberOfMatches);
    
    return true;
}

#pragma mark ------ called by CEF --------

//
// open URL in default browser
//
void openURL(const std::wstring& wurl)
{
    NSString* swurl = [NSString stringWithwstring: wurl];
    YLog(LOG_ONLY_IN_DEBUG, @"openURL: %@", swurl);

    NSURL* nurl = [NSURL URLWithString: swurl];
    
    if  ( nurl == nil ) // needs encoding
    {
        NSString* surl = [swurl  encodeString:NSUTF8StringEncoding];
        //NSString* surl = [swurl  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        YLog(LOG_NORMAL, @"openURL: %@", surl);
        
        nurl = [NSURL URLWithString: surl];
    }
    
    if ( nurl == nil )
    {
        YLog(LOG_MAXIMUM, @"trying to open invalid URL: %@", nurl);
    }
    else if (! [[NSWorkspace sharedWorkspace] openURL: nurl] )
    {
        YLog(LOG_MAXIMUM, @"failed to open URL:%@", [nurl description]);
    }
}

// generates unique UUIDs
std::string GenerateUUID()
{
    CFUUIDRef theUUID = CFUUIDCreate( kCFAllocatorDefault );
    NSString *uuidStr = (NSString *)CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, theUUID));
    std::string uuid(uuidStr.UTF8String);
    CFRelease( theUUID );
    return uuid;
}

bool findMatch(std::string& original, std::map<std::string, std::string>& map,
               // output
               std::string& newURL, std::string& mapVal)
{
    NSString* originalURL = [NSString stringWithUTF8String: original.c_str()];
    
    if ( [originalURL rangeOfString:@"relay"].location == NSNotFound ) return NULL;
    
    std::map<std::string, std::string>::iterator iter;
    
    for (iter = map.begin(); iter != map.end(); iter++)
    {
        NSString* map1 = [NSString stringWithUTF8String: iter->first.c_str()];
        NSRange range = [originalURL rangeOfString:map1 options:NSCaseInsensitiveSearch];
        
        if ( range.location != NSNotFound && range.length > 0 )
        {
            NSString* map2 = [NSString stringWithUTF8String: iter->second.c_str()];
            NSString* matchText = [originalURL stringByReplacingCharactersInRange:range withString: map2];
            //YLog(LOG_NORMAL, @"findMatch - replaced ORIGINAL=%@ with this one=%@", originalURL, matchText);
            
            newURL = [matchText cStringUsingEncoding:NSUTF8StringEncoding];
            mapVal = iter->first;
            
            return true;
        }
    }
    return false;
}


bool findIfItsFileTransferRelay(std::string& original, std::string& mapVal)
{
    NSURL* originalURL = [NSURL URLWithString:[NSString stringWithUTF8String: original.c_str()]];
    if ( [ originalURL.scheme rangeOfString:@"http"].location == NSNotFound )
        return false;
    
    // 1st component is /, 2nd has to be relay
    NSArray* components = [originalURL pathComponents];
    if ( components.count == 2 &&
        [@"/" isEqual: [components objectAtIndex:0]] &&
        [@"relay" isEqual: [components objectAtIndex:1]] )  // is relay
    {
        NSString* ret = [NSString stringWithFormat: @"%@://%@", [originalURL scheme], [originalURL host] ];
        mapVal = [ret cStringUsingEncoding:NSUTF8StringEncoding];
        YLog(LOG_NORMAL, @"FOUND RELAY  MR1=%s", mapVal.c_str());
        return true;
    }
    
    
    return false;
}


// called by CEF to validate plugins location
// ONLY allows plugins from the app own plugin directory

bool isVideoPluginValid(const std::string& path, const std::string& version)
{
    YLog(LOG_NORMAL, @"Validating plugin %s, version %s", path.c_str(), version.c_str());
    NSString* npath = [NSString stringWithUTF8String: path.c_str()];
    NSURL* url = [[NSBundle mainBundle] builtInPlugInsURL];
    
    NSRange rng = [npath rangeOfString:url.path];
    if ( rng.location == NSNotFound )
    {
        YLog(LOG_MAXIMUM, @"Plugin rejected - not from the App/Plugins directory:  %s, version %s", path.c_str(), version.c_str());
        return false;
    }
    
    return true;
}

#pragma mark ------ File Management --------------------------


bool renameOldFile(std::wstring filename)
{
    NSString* file = [NSString stringWithwstring: filename];
    //YLog(LOG_NORMAL, @"Renaming file = %@", file);
    BOOL isDir;
    if (  [[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDir] == YES && isDir == FALSE)
    {
        NSString* extension = [file pathExtension];
        NSString* extensionWithDot = nil;
        if ( extension && [extension compare:@""] != NSOrderedSame )
        {
            extensionWithDot = [NSString stringWithFormat:@".%@", extension];
        }
        NSString* fileNoExt = [file stringByDeletingPathExtension];
        
        NSString* new_name = [NSString stringWithFormat:@"%@.old%@", fileNoExt, (extensionWithDot?extensionWithDot:@"") ];
        
        renameOldFile([new_name getwstring]);
        NSError* error = nil;
        [[NSFileManager defaultManager] moveItemAtPath:file toPath:new_name error:&error];
        if ( error != nil )
        {
            YLog(LOG_NORMAL, @"Error renaming file = %@", [error description]);
        }
        return true;
    }
    return false;
}

bool ShowFolder2(std::wstring directory, CefRefPtr<CefListValue> selected_files)
{
    NSInteger num_files = selected_files->GetSize();
    NSMutableArray* fileURLs = [[NSMutableArray alloc] init];
    for (int i=0; i<num_files; i++)
    {
        NSString* filename = [NSString stringWithFormat:@"%@/%@", [NSString stringWithwstring:directory], [NSString stringWithwstring:selected_files->GetString(i).ToWString()]];
        //YLog(LOG_NORMAL, @"ShowFolder2: Opening file:%@ ", filename);
        BOOL isDir;
        if (  [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir] == YES && isDir == FALSE)
        {
            [fileURLs addObject: [[NSURL fileURLWithPath: filename] absoluteURL]];
        }
        else
        {
            YLog(LOG_NORMAL, @"ShowFolder2 File %@ does NOT exist OR is a directory - ignored", filename);
        }
    }

    if ( [fileURLs count] > 0 )
    {
        //YLog(LOG_NORMAL, @"Calling NSWorkspace activateFileViewerSelectingURLs with %lu files", (unsigned long)[fileURLs count]);
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
    }
    else
    {
        YLog(LOG_NORMAL, @"ShowFolder2 ignored as there are no valid files");
    }
    
    return true;
}

bool ShowFolder(std::string directory, std::string selected_file)
{
    NSString* filename = [NSString stringWithFormat:@"%s%s", directory.c_str(), selected_file.c_str()];

    BOOL isDir;
    if (  [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir] == YES && isDir == FALSE)
    {
        NSURL* fileurl = [[NSURL fileURLWithPath: [NSString stringWithFormat:@"%s%s", directory.c_str(), selected_file.c_str()]] absoluteURL];
        
        //YLog(LOG_NORMAL, @"ShowFolder: Opening file:%@ ", filename);
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: @[ fileurl ] ];
        return true;
    }
    else
    {
        YLog(LOG_NORMAL, @"ShowFolder: file:%@ does NOT exist OR is a directory - ignored ", filename);
        return false;
    }
}


#pragma mark ----- Logging -----------------------------------

// exta logging for  CaffeineClientHandler::OnProcessMessageReceived
void LogMessageReceived(CefRefPtr<CefBrowser> browser,
                        CefProcessId source_process,
                        CefRefPtr<CefProcessMessage> message)
{
    std::string str = message->GetName();
    //YLog(LOG_NORMAL, @"LogMessageReceived: Source=%d name=%s", source_process, str.c_str());
    
    if(str == "sendIPC")
    {
        //  Probably should have a few asserts around this
        CefRefPtr<CefListValue> retval = message->GetArgumentList();
        CefString browser_handle = retval->GetString(0);
        std::string browserstr (browser_handle);
        YLog(LOG_NORMAL, @"LogMessageReceived (sendIPC) browser_handle=%s", browserstr.c_str());
    }
    
}


#
#pragma mark ---- Application active

// is the app active
bool isAppActive()
{
    NSRunningApplication* uiApp = [NSRunningApplication runningApplicationWithProcessIdentifier: app->browserPID];
    return  ( [uiApp isActive]);
}



#pragma mark - general

void launchFileFromFinder(const std::wstring& fileWithFullPath)
{
    NSString* fileName = [NSString stringWithwstring: fileWithFullPath];
    if ( [[NSWorkspace sharedWorkspace] openFile:fileName] != YES )
    {
        YLog(LOG_NORMAL, @"Error: failed to launch: %@", fileName);
    }
}


void ShellLog(const char* szStr)
{
    YLog(LOG_NORMAL, @"%s", szStr);
}

void ConsoleLog(int browser, const CefString& message)
{
    if ( masterLogEnabled == LOG_DISABLED ) return;
    
    NSString*  msg = [NSString stringWithwstring: message.ToWString()];
    YLog(LOG_JS, msg);
    return;
    
    // ignore code below for now - trying to format the JS logs better
    {
        NSScanner* scanner = [NSScanner scannerWithString: msg];
        NSString* buffer = nil;
        BOOL rc;
        
        // 15:28:41.914:main:<unknown>:shell.js:63:Caffeine.Desktop.windowClosed(): Shell: closeWindow for target=main
        rc = [scanner scanInt:NULL]; if ( !rc ) goto error;
        rc = [scanner scanString:@":" intoString:&buffer]; if ( !rc ) goto error;
        
        rc = [scanner scanInt:NULL]; if ( !rc ) goto error;
        rc = [scanner scanString:@":" intoString:&buffer]; if ( !rc ) goto error;
        
        rc = [scanner scanFloat:NULL]; if ( !rc ) goto error;
        rc = [scanner scanString:@":" intoString:&buffer]; if ( !rc ) goto error;
        
        // final scan
        rc = [scanner scanUpToString:@"" intoString:&buffer]; if ( !rc ) goto error;
        
        /*
         static NSString* previousMsg = nil;
         static int nrPreviousRepeats = 0;
         
         if ( previousMsg && [previousMsg compare:buffer] == NSOrderedSame )
         {
         nrPreviousRepeats++;
         }
         else
         {
         if ( nrPreviousRepeats > 0 )
         {
         // LOG_JS messages are not allowed to use c-style formats, to prevent user input with c-style formating
         /// making it to the logs
         NSString* msg = [NSString stringWithFormat:@"(previous msg was repeated %d times)", nrPreviousRepeats];
         YLog(LOG_JS, msg);
         nrPreviousRepeats = 0;
         }
         previousMsg = buffer;
         
         YLog(LOG_JS, buffer);
         }
         */
        
        //NSString* logMsg = [NSString stringWithFormat:@"%d %@", browser, buffer];
        NSString* logMsg = [NSString stringWithFormat:@"%@", buffer];
        
        YLog(LOG_JS, logMsg);
        return;
    }
error:
    YLog(LOG_JS, msg);
     
}

#pragma mark ------ user agent -----

//NSString* userAgent = @"Mozilla/4.0 (compatible; MSIE 5.5)";
//NSString* userAgent = @"CaffeineV2 (Mac)";

void setUserAgentVersion()
{
    // initialize user agent
    NSString* verStr = nil;
    
    if ( gCurrentOS == -1 )
        setCurrentOS();
    
    if ( gCurrentOS == OSX106 )
    {
        verStr = @"CaffeineV2 (Mac 10.6)";
    }
    else if ( gCurrentOS == OSX107 )
    {
        verStr = @"CaffeineV2 (Mac 10.7)";
    }
    else if ( gCurrentOS == OSX108 )
    {
        verStr = @"CaffeineV2 (Mac 10.8)";
    }
    else if ( gCurrentOS == OSX109 )
    {
        verStr = @"CaffeineV2 (Mac 10.9)";
    }
    else
    {
        verStr = @"CaffeineV2 (Mac 10.10)";
    }
    YLog(LOG_NORMAL, @"Setting user agent as %@  (gCurrent=%d)", verStr, gCurrentOS);
    if ( verStr )
        userAgent = [verStr UTF8String];
}

void loadLocalizedString(const char* key, std::wstring value)
{
    NSString* keyStr = [NSString stringWithUTF8String:key];
    NSString* str = NSLocalizedString(keyStr, keyStr);
    
    value = [str getwstring];
}


#pragma mark ------ Persistance ----

void closePersistentDB()
{
    @try
    {
        [[YPreferencesManager sharedManager] saveUnsavedChanges];
    }
    @catch (NSException *e)
    {
        YLog(LOG_MAXIMUM, @"Exception in GetPersistentValues  %@", [e description]);
    }
}

bool DeletePersistentValue(std::wstring key)
{
    @try
    {
        NSString* keyStr = [NSString stringWithwstring:key];
        return [[YPreferencesManager sharedManager] removePref: keyStr];
    }
    @catch (NSException *e)
    {
        YLog(LOG_MAXIMUM, @"Exception in DeletePersistentValue for key %s - %@", key.c_str(), [e description]);
    }
}

bool SetPersistentValue(const std::wstring key, const std::wstring value)
{
    @try
    {
        NSString* keyStr = [NSString stringWithwstring:key];
        NSString* valStr = [NSString stringWithwstring: value];
        
        bool rt = [[YPreferencesManager sharedManager] setPrefValue:valStr forKey:keyStr];
        
        YLog(LOG_ONLY_IN_DEBUG, @"SetPersistentValue: %@,%@", keyStr, valStr);
        return rt;
    }
    @catch (NSException *e)
    {
        YLog(LOG_MAXIMUM, @"Exception in SetPersistentValue for key %s - %@", key.c_str(), [e description]);
    }
}

PersistentValue GetPersistentValue(std::wstring key)
{
    @try
    {
        NSString* keyStr = [NSString stringWithwstring:key];
        NSString* valStr = [[YPreferencesManager sharedManager] getPrefValueFor:[NSString stringWithwstring:key]];
        YLog(LOG_ONLY_IN_DEBUG, @"GetPersistentValue: %@,%@", keyStr, valStr);
        
        if ( valStr )
        {
            PersistentValue retval;
            retval = make_pair(key, [valStr getwstring]);
            return retval;
        }
        else
        {
            PersistentValue retval;
            std::wstring empty;
            retval = make_pair(key, empty);
            return retval;
        }
    }
    @catch (NSException *e)
    {
        YLog(LOG_MAXIMUM, @"Exception in GetPersistentValue for key %s - %@", key.c_str(), [e description]);
    }
}

PersistentValues GetPersistentValues()
{
    @try
    {
        PersistentValues retval;
        NSDictionary* prfs = [[YPreferencesManager sharedManager] getAllPrefs];
        if ( prfs && [prfs count] > 0 )
        {
            for (NSString* key in [prfs allKeys])
            {
                retval [ [key getwstring] ] = [[prfs objectForKey:key] getwstring];
            }
        }
        return retval;
        
    }
    @catch (NSException *e)
    {
        YLog(LOG_MAXIMUM, @"Exception in GetPersistentValues  %@", [e description]);
    }
}

void removeAllPersistentValues()
{
    @try
    {
        [[YPreferencesManager sharedManager] removeAllPrefs];
    }
    @catch (NSException *e)
    {
        YLog(LOG_MAXIMUM, @"Exception in removeAllPersistentValues  %@", [e description]);
    }
    
}
