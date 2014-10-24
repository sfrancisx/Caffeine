//
//  CaffeineClientApp_mac.cpp
//  McBrewery
//
//  Created by Fernando on 6/24/13.
//  Copyright (c) 2014 Yahoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#include "include/cef_base.h"
#pragma clang diagnostic pop
#include "CaffeineClientApp.h"  // NOLINT(build/include)
#include "McBrewery/mac_util.h"
#import "CommonDefs.h"
#import <Cocoa/Cocoa.h>
#import "NSString_NSString_wstring.h"
#import "YMKeyChain.h"
#import "YLog.h"
#import "YPreferencesManager.h"

#ifdef ENABLE_MUSIC_SHARE
#include "CaffeineITunesMac.h"
#endif

bool IsValidRequestURL(std::string url)
{
    return true;
    /*
    bool retval = true;
    
    if (strncmp("file://", url.c_str(), 7)==0)
    {
        url.erase(0, 7);
        //  Exclude paths with // in them to prevent navigation to long path names and
        //  exclude paths with ':' in them to prevent navigation to absolute paths.
        //  Chromium doesn't seem to allow using relative paths.
        //  TODO:  All of our file:// urls should eventually be handled by a custom
        //  TODO:  scheme handler.
        retval = (url.find("//") == std::string::npos && url.find(":") == std::string::npos);
    }
    
    return retval;
    */
}

void ExecuteHasFocus(CefRefPtr<CaffeineClientApp>& client_app,
                     const CefV8ValueList& arguments,
                     CefRefPtr<CefV8Value>& retval )
{
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_6 )
    {
        if (client_app->windowIsKeyWindow )
            retval = CefV8Value::CreateBool(true);
        else
            retval = CefV8Value::CreateBool(false);
    }
    else
    {
        NSRunningApplication* appl = [[NSWorkspace sharedWorkspace] frontmostApplication];
        
        if ( appl.processIdentifier == client_app->browserPID )
            retval = CefV8Value::CreateBool(true);
        else
            retval = CefV8Value::CreateBool(false);
    }
}

void GetZippedLogFiles(CefRefPtr<CefV8Value>& retval)
{
    /*
    // dump network trace
    CefRefPtr<CefBrowser> browser = AppGetMainHandler()->GetBrowser();
    CefRefPtr<CefFrame> frame = browser->GetMainFrame();
    frame->ExecuteJavaScript(
                             "Caffeine.Network.Transport.getNetworkTrace(); ",
                             frame->GetURL(),
                             0
                             );
    */
    compressLogFilesForEmail();
    retval = CefV8Value::CreateString([zippedLogFiles() UTF8String]);
}


void CaffeineClientApp::RemoveAllUserTokens()
{
    userTokens.erase(userTokens.begin(), userTokens.end());
}

void CaffeineClientApp::SetUserToken(const std::string& user, const std::string& token)
{
    userTokens[user] = token;
    
    /*
    YMKeyChain* kc = [YMKeyChain sharedInstance];
    [kc setToken:[NSString stringWithUTF8String:token.c_str()] forUserName:[NSString stringWithUTF8String:user.c_str()]];
    */
}

std::string CaffeineClientApp::GetUserToken(const std::string& user)
{
    if (userTokens.find(user) != userTokens.end())
    {
        return userTokens[user];
    }

    /*
    YMKeyChain* kc = [YMKeyChain sharedInstance];
    NSString* token = [kc tokenForUserName:[NSString stringWithUTF8String:user.c_str()]];
    if ( token != nil )
    {
        return [token UTF8String];
    }
     */
    std::string  ret = "";
    return ret;
}

void CaffeineClientApp::RemoveUserToken(const std::string&user)
{
    userTokens.erase(user);
    /*
    YMKeyChain* kc = [YMKeyChain sharedInstance];
    [kc removeTokenForUserName:[NSString stringWithUTF8String:user.c_str()]];
    */
}

std::wstring  CaffeineClientApp::GetIPbyName(const std::wstring& hostName)
{
    NSHost* host = [NSHost hostWithName:[NSString stringWithwstring:hostName]];
    return [host.address getwstring];
}

const char* CaffeineClientApp::GetUpdateChannel()
{
    NSString* channel = getUpdateChannel();
    if ( [@"Dev0" isEqualToString: channel] )  ; // DONOTHING - so it wont upset the automatiom
    else if ( [channel rangeOfString:@"Dev" options:NSCaseInsensitiveSearch].location != NSNotFound ) {
        channel = @"Developer";
    }
    return [channel UTF8String];
}

std::string CaffeineClientApp::GetIP()
{
    NSHost* host = [NSHost currentHost];
    std::string ip = [[host address] UTF8String];
    return ip;
}

#pragma mark ============ encrypt/decrypt

std::string CaffeineClientApp::encrypt(const CefString &plaintext)
{
    NSString* textStr = [NSString stringWithUTF8String: plaintext.ToString().c_str()];
    NSData* textData = [textStr dataUsingEncoding:NSUTF8StringEncoding] ;
    
    NSString* convertedStr = [textData base64EncodedStringWithOptions: NSDataBase64Encoding64CharacterLineLength];
    
    std::string retval = [convertedStr UTF8String];
    return retval;
}

CefString CaffeineClientApp::decrypt(const CefString &blob)
{
    NSString* convertedStr = [NSString stringWithUTF8String: blob.ToString().c_str()];
    NSData* textData = [[NSData alloc ] initWithBase64EncodedString: convertedStr options:NSDataBase64Encoding64CharacterLineLength] ;
    NSString *decodedString = [[NSString alloc] initWithData:textData encoding:NSUTF8StringEncoding];

    std::string retval = [decodedString UTF8String];
    return retval;
}

void CaffeineClientApp::SetRenderProcessCreationTime(const CefTime time)
{
    renderProcessExecutionCreationTime = time;
}

CefTime CaffeineClientApp::getRenderProcessCreationTime()
{
    return renderProcessExecutionCreationTime;
}

bool CaffeineClientApp::isInternalIP()
{
    return isInsideInternalNetwork;
}

#pragma mark ======= RTT2 ===================

// 0 - socket#
// 1 - state
// 2 - error code (0 no error)
// OPTIONAL: 3 - read data
bool CaffeineClientApp::InvokeSocketMethod(CefRefPtr<CefListValue> values)
{
    ASSERT( values->GetSize() >= 3 );
    
    SOCKET s = values->GetInt(0);
    CefString state = values->GetString(1);
    int32 error_code = values->GetInt(2);
    CefString strData;
    
    if (values->GetSize() == 4 )
    {
        strData = values->GetString(3);
    }

    YLog(LOG_ONLY_IN_DEBUG, @"RTT2: InvokeSocketMethod called - socket %d - %s (%d)", s, state.ToString().c_str(), error_code);

    bool retval = false;
    
    auto i = sMap.find(s);
    if(i!=sMap.end())
    {
        //  First, try looking up the callback in the socket callback map.
        auto cb = i->second.find(state);
        if(cb!=i->second.end())
        {
            auto ctx = (cb->second).first;
            ctx->Enter();
            CefV8ValueList args;
            CefRefPtr<CefV8Value> CallbackArg = CefV8Value::CreateObject(NULL);
            CallbackArg->SetValue("handle", CefV8Value::CreateInt(s), V8_PROPERTY_ATTRIBUTE_NONE);
            
            //  If it's an error, it's handled a little differently.
            if (state == "error")
            {
                CallbackArg->SetValue("errorCode", CefV8Value::CreateInt(error_code), V8_PROPERTY_ATTRIBUTE_NONE);
            }
            //  The other cases have two arguments.
            else if (state != "close") //  "read" or "connect" cases
            {
                args.push_back(CefV8Value::CreateNull());
                CallbackArg->SetValue("status", CefV8Value::CreateString("success"), V8_PROPERTY_ATTRIBUTE_NONE);
                
                if (state == "read")
                {
                    int bytes_recvd = (int)strData.length();
                    CallbackArg->SetValue("nBytes", CefV8Value::CreateInt(bytes_recvd), V8_PROPERTY_ATTRIBUTE_NONE);
                    CallbackArg->SetValue("data", CefV8Value::CreateString(strData), V8_PROPERTY_ATTRIBUTE_NONE);
                }
            }
            args.push_back(CallbackArg);
            
            (cb->second).second->ExecuteFunction(NULL, args);
            ctx->Exit();
            YLog(LOG_ONLY_IN_DEBUG, @"RTT2: %s callback sent", state.ToString().c_str() );
            
            //  TODO:  We should actually call read to make sure we've read all of the data before
            //  TODO:  cleaning up.  Probably should do the same thing for the error case too.
            if (state == "error" || state == "close")
            {
                //  Clean up the sockets maps
                RemoveSocketCallback(s);
                wbMap.erase(s);
            }
            
            retval = true;
        }
        
        // write - todo 
        //  Otherwise, if we can write handle it.
        else if (state == "write")
        {
            retval = true;
        }
    }
    
    return retval;
}

bool CaffeineClientApp::InvokeSocketMethod(SOCKET s, CefString state, int32 error_code)
{
    return true;
}

void CaffeineClientApp::ShellLog(const std::wstring& msg)
{    
    YLog(LOG_NORMAL, [NSString stringWithwstring:msg]);
}


void shellLogMac( const std::string& msg)
{
    YLog(LOG_NORMAL, [NSString stringWithUTF8String: msg.c_str()]);
}

