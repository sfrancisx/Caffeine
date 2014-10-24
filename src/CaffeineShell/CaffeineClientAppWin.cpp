//
//  CaffeineClientApp_win.cpp
//  McBrewery
//
//  Created by Fernando on 6/24/13.
//  Copyright (c) 2014 Yahoo! All rights reserved.
//
//  Defines
#define B64_BUFFER_LEN (4096)

//  Includes
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "defines.h"
#include <string>
#include <map>
#include "CaffeineClientApp.h"  // NOLINT(build/include)
#include "CaffeineClientUtils.h"

#ifdef ENABLE_MUSIC_SHARE
	#include "CaffeineITunesWin.h"
	#include "TrackWin.h"
#endif

#include "RemoteWindow.h"
#include <Rpc.h>
#include <Shlobj.h>
#include <winsock2.h>
#include <WinCrypt.h>
#include <atlenc.h>
#include <Strsafe.h>
#include <sstream>
#include "zip.h"

using namespace std;

const DWORD BufferTooBigSize = 400*1024*1024;
LONG log_count = 0;

extern CaffeineSettings CaffeineSettings;

#define DNS_DOMAIN_LENGTH 256

// TODO: return the IP
string CaffeineClientApp::GetIP()
{
    string ip = "127.0.0.1";
    return ip;
}


//  TODO:  Dynamically size the base64 buffers
string CaffeineClientApp::encrypt(const CefString &plaintext)
{
    DATA_BLOB DataIn = {0,};
    DATA_BLOB DataOut = {0,};
    string ConvertedData = plaintext.ToString();
    string retval;
    
    DataIn.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(ConvertedData.data()));
    DataIn.cbData = ConvertedData.length();

    string temp;

    if(CryptProtectData(&DataIn, TEXT("Login Token"), NULL, NULL, NULL, 0, &DataOut))
    {
        char B64Buf[B64_BUFFER_LEN] = {0,};
        int B64BufLen = B64_BUFFER_LEN;

        if (Base64Encode(DataOut.pbData, DataOut.cbData, B64Buf, &B64BufLen, ATL_BASE64_FLAG_NOCRLF))
        {
            retval = string(B64Buf);
        }

        LocalFree(DataOut.pbData);
    }

    return retval;
}

CefString CaffeineClientApp::decrypt(const CefString &blob)
{
    string ConvertedData = blob.ToString();
    string retval;

    BYTE B64DecodeBuf[B64_BUFFER_LEN] = {0,};
    int B64DecodeBufLen = B64_BUFFER_LEN;

    if (Base64Decode(ConvertedData.data(), ConvertedData.length(), B64DecodeBuf, &B64DecodeBufLen))
    {
        DATA_BLOB DataIn = {0,};
        DATA_BLOB DataOut = {0,};

        DataIn.pbData = B64DecodeBuf;
        DataIn.cbData = B64DecodeBufLen;

        if(CryptUnprotectData(&DataIn, NULL, NULL, NULL, NULL, 0, &DataOut))
        {
            retval = string(reinterpret_cast<char *>(DataOut.pbData), static_cast<size_t>(DataOut.cbData));
            LocalFree(DataOut.pbData);
        }
    }

    return retval;
}

wstring CaffeineClientApp::GetLatestVersion(wstring GUID)
{
	wstring ver(L"1.0.0.0");

    TCHAR registryPath[MAX_PATH] = UPDATE_CLIENTS_KEY_PATH;
	StringCchCat(registryPath, MAX_PATH, GUID.c_str()); 

	HKEY hKey;
    LONG errorCode = RegOpenKeyEx(HKEY_LOCAL_MACHINE, registryPath, 0, KEY_READ, &hKey);
	ASSERT(errorCode == ERROR_SUCCESS);
	if (errorCode != ERROR_SUCCESS)
	{
		return ver;
	}
	
	TCHAR latestVersion[100];
	DWORD bufSize = sizeof(latestVersion);

	errorCode = RegQueryValueEx(hKey, L"pv", NULL, NULL, reinterpret_cast<LPBYTE>(&latestVersion), &bufSize);
	ASSERT(errorCode == ERROR_SUCCESS);
	if (errorCode != ERROR_SUCCESS)
	{
		return ver;
	}

	::RegCloseKey(hKey);
	ver = latestVersion;
	
	return ver;
}

wstring CaffeineClientApp::GetWindowState()
{
    wstring state(L"normal");

    WINDOWPLACEMENT wp;
    GetWindowPlacement(hwndRender, &wp);

    switch (wp.showCmd)
    {
        case SW_SHOWMINIMIZED:
            state = L"minimized";
            break;
        case SW_SHOWMAXIMIZED:
            state = L"maximized";
            break;
    }

    return state;
}

bool CaffeineClientApp::PostCrashLogs(CefString CrashLog, CefString AppVersion, CefString UserDescription)
{
    CefRefPtr<CefRequest> request = CefRequest::Create();
    wstring url(DIAGNOSTICS_URL);

    request->SetURL(url);
    request->SetMethod("POST");
    request->SetFlags(UR_FLAG_ALLOW_CACHED_CREDENTIALS|UR_FLAG_REPORT_UPLOAD_PROGRESS);
    
    // Add post data to the request.  The correct method and content-
    // type headers will be set by CEF.
    CefRefPtr<CefPostDataElement> Data = CefPostDataElement::Create();
//    Data->SetToFile(CrashLog);
    //  TODO:  Consider creating a memory mapped file
    HANDLE hZipFile = CreateFile(CrashLog.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    DWORD BigBufferSize = GetFileSize(hZipFile, NULL);
    if (BigBufferSize != INVALID_FILE_SIZE)
    {
        LPBYTE BigBuffer = new BYTE[BigBufferSize];

        DWORD dwBytesRead = 0;
        ReadFile(hZipFile, BigBuffer, BigBufferSize, &dwBytesRead, NULL);
        CloseHandle(hZipFile);
        Data->SetToBytes(dwBytesRead, BigBuffer);
    
        CefRefPtr<CefPostData> POSTBody = CefPostData::Create();
        POSTBody->AddElement(Data);
        request->SetPostData(POSTBody);

        CefRequest::HeaderMap headerMap;
        request->GetHeaderMap(headerMap);
        headerMap.insert(make_pair("Content-Type", "application/zip"));
        request->SetHeaderMap(headerMap);
    
//        CefV8Context::GetCurrentContext()->GetFrame()->LoadRequest(request);

        // Create the client instance.
        CefRefPtr<CaffeineRequestClient> client = new CaffeineRequestClient();
    
        // Start the request. MyRequestClient callbacks will be executed asynchronously.
        CefRefPtr<CefURLRequest> url_request = CefURLRequest::Create(request, client.get());
        
        delete [] BigBuffer;
    }

    return true;
}

void CaffeineClientApp::InsertDescriptionIntoCrashLogs(const wstring& file, const wstring& description)
{
    zipFile zf = zipOpen64(file.c_str(), APPEND_STATUS_ADDINZIP);

    if( !zf ) {
        ShellLog(L"Could not open the zip to add the description");
        return;
    }

    zip_fileinfo info = {0};
    if( zipOpenNewFileInZip( zf, "description.txt", &info, NULL, 0, NULL, 0, NULL, 0, Z_DEFAULT_COMPRESSION ) != ZIP_OK )
    {
        ShellLog(L"Could not open the new description file in zip");
        zipClose(zf, NULL );
        return;
    }

    string str(description.begin(), description.end());
    if( zipWriteInFileInZip( zf, (void*)str.c_str(), str.size() ) != ZIP_OK )
    {
        ShellLog(L"Could not write description to the new description file in zip");
        zipCloseFileInZip( zf );
        zipClose( zf, NULL );
        return;
    }

    zipCloseFileInZip(zf);
    zipClose(zf, NULL);
}

bool CaffeineClientApp::UploadCrashLogs(CefString AppVersion, CefString UserDescription)
{
    bool retval = false;
    HANDLE hFind = INVALID_HANDLE_VALUE;
    WIN32_FIND_DATA ffd;

    //  Get the crash logs folder and append '\*.zip' to it.
    wstring CrashDir = GetCrashLogsDirectory();
    wstring ZippedLogs = CrashDir + L"\\*.zip";

    // Find the first file in the directory.
    hFind = FindFirstFile(ZippedLogs.c_str(), &ffd);
    if (INVALID_HANDLE_VALUE != hFind) 
    {
        do
        {
            TCHAR szFullPath[MAX_PATH*2] = {0,};

            StringCchCopy(szFullPath, MAX_PATH*2, CrashDir.c_str());
            PathAppend(szFullPath, ffd.cFileName);

            InterlockedIncrement(&log_count);

            InsertDescriptionIntoCrashLogs(szFullPath, UserDescription.ToWString());
            PostCrashLogs(szFullPath, AppVersion, UserDescription);
        } while (FindNextFile(hFind, &ffd) != 0);
        FindClose(hFind);

        retval = true;
    }

    return retval;
}

void CaffeineClientApp::DeleteCrashLogs()
{
    TCHAR szFullPath[MAX_PATH*2] = {0,};
    SHFILEOPSTRUCT sfo = {0,};

    StringCchCopy(szFullPath, MAX_PATH*2 - 1, GetCrashLogsDirectory().c_str());
    StringCchCat(szFullPath, MAX_PATH*2 - 1, TEXT("\\*"));
    szFullPath[::_tcslen(szFullPath)+1] = 0;

    sfo.hwnd = NULL;  //  TODO:  Should this be the app?
    sfo.wFunc = FO_DELETE;
    sfo.fFlags = FOF_SILENT | FOF_NOCONFIRMATION | FOF_NOERRORUI;
    sfo.pFrom = szFullPath;
    sfo.pTo =  NULL;
    SHFileOperation(&sfo);
}

wstring CaffeineClientApp::GetCrashLogsDirectory()
{
    wstring retval;
    TCHAR szLogsDir[MAX_PATH] = {0,};

    if(SUCCEEDED(::SHGetFolderPath(NULL, 
        CSIDL_LOCAL_APPDATA|CSIDL_FLAG_CREATE, 
        NULL, 
        0, 
        szLogsDir))) 
    {
        StringCchCat(szLogsDir, MAX_PATH, CRASH_LOGS_PATH);
        retval = szLogsDir;
    }

    return retval;
}

int CaffeineClientApp::GetCrashLogCount()
{
    int retval = 0;
    HANDLE hFind = INVALID_HANDLE_VALUE;
    WIN32_FIND_DATA ffd;

    //  Get the crash logs folder and append '\*.zip' to it.
    wstring CrashDir = GetCrashLogsDirectory();
    wstring ZippedLogs = CrashDir + L"\\*.zip";

    // Find the first file in the directory.
    hFind = FindFirstFile(ZippedLogs.c_str(), &ffd);
    if (INVALID_HANDLE_VALUE != hFind) 
    {
        do
        {
            ++retval;
        } while (FindNextFile(hFind, &ffd) != 0);
        FindClose(hFind);
    }

    return retval;
}

wstring CaffeineClientApp::GetLatestApplicationPath()
{
	wstring path(L"");

    TCHAR registryPath[] = REG_APP_PATH;

	HKEY hKey;
    LONG errorCode = RegOpenKeyEx(HKEY_LOCAL_MACHINE, registryPath, 0, KEY_READ, &hKey);
	ASSERT(errorCode == ERROR_SUCCESS);
	if (errorCode != ERROR_SUCCESS)
	{
		return path;
	}
	
	TCHAR latestPath[100];
	DWORD bufSize = sizeof(latestPath);

	errorCode = RegQueryValueEx(hKey, L"", NULL, NULL, reinterpret_cast<LPBYTE>(&latestPath), &bufSize);
	ASSERT(errorCode == ERROR_SUCCESS);
	if (errorCode != ERROR_SUCCESS)
	{
		return path;
	}

	::RegCloseKey(hKey);
	path = latestPath;
	
	return path;
}

// translate hostname into IP:
// code from MSDN:
// http://msdn.microsoft.com/en-us/library/windows/desktop/ms738520%28v=vs.85%29.aspx
//
wstring CaffeineClientApp::GetIPbyName(const wstring& hostName)
{
    return ::GetIPbyName(hostName);
}

CefTime CaffeineClientApp::getRenderProcessCreationTime() {
	// Get process start time for the render process
	FILETIME cpuTime, sysTime, creationTime, exitTime;

	CefTime processTime;
	if (GetProcessTimes(GetCurrentProcess(), &creationTime, &exitTime, &sysTime, &cpuTime)) {
		ULONGLONG ull = reinterpret_cast<const ULONGLONG&>(creationTime);
		ull -= 116444736000000000;
		ull /= 10000000;

		processTime.SetTimeT(static_cast<time_t>(ull));
	}

	return processTime;
}

bool CaffeineClientApp::isInternalIP()
{
    TCHAR buffer[DNS_DOMAIN_LENGTH] = {0,};
    DWORD dwSize = sizeof(buffer)/sizeof(TCHAR);

    if (GetComputerNameEx(ComputerNameDnsDomain, buffer, &dwSize))
    {
		wstring temp(buffer);
        //  Mac has a global transform().  So, we namespace this.
        transform(temp.begin(), temp.end(), temp.begin(), ::tolower);

        if (temp.find(INTERNAL_DOMAIN) != wstring::npos)
        {
			return true;
        }
    }

	return false;
}

bool CaffeineClientApp::InvokeSocketMethod(CefRefPtr<CefListValue> values)
{
    SOCKET s = values->GetInt(0);
    CefString state = values->GetString(1);
    int32 error_code = 0;
    if (values->GetSize() == 3)
    {
        error_code = values->GetInt(2);
    }

    return InvokeSocketMethod(s, state, error_code);
}

bool CaffeineClientApp::InvokeSocketMethod(SOCKET s, CefString state, int32 error_code)
{
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
                    CaffeineSocketClient sc = scMap.find(s)->second;

                    vector<char> buffer(4096);
                    int bytes_recvd = sc.recv(&buffer.front(), buffer.size()-1, 0);
                    //  TODO:  Handle real errors on a read.
                    if(bytes_recvd<=0 /*&& (WSAEWOULDBLOCK == error_code || 0 == error_code)*/) 
                    {
                        bytes_recvd = 0;
                        NonBlockingSocketWrite(s);
                        ctx->Exit();
                        return true;
                    }
                    buffer[bytes_recvd] = 0;

                    CallbackArg->SetValue("nBytes", CefV8Value::CreateInt(bytes_recvd), V8_PROPERTY_ATTRIBUTE_NONE);
                    CallbackArg->SetValue("data", CefV8Value::CreateString(buffer.data()), V8_PROPERTY_ATTRIBUTE_NONE);
                }
            }
            args.push_back(CallbackArg);

            (cb->second).second->ExecuteFunction(NULL, args);
            ctx->Exit();

            //  TODO:  We should actually call read to make sure we've read all of the data before 
            //  TODO:  cleaning up.  Probably should do the same thing for the error case too.
            if (state == "error" || state == "close")
            {
                closesocket(s);
                //  Clean up the sockets maps
                RemoveSocketCallback(s);
                wbMap.erase(s);
                scMap.erase(s);
            }

            retval = true;
        }
        //  Otherwise, if we can write handle it.
        else if (state == "write")
        {
            NonBlockingSocketWrite(s);
            retval = true;
        }
    }

    return retval;
}

void CaffeineClientApp::NonBlockingSocketWrite(SOCKET s)
{
    auto wb = wbMap.find(s);  //  s should exist
    auto& data_list = wb->second;

    //  What if an error happens in the middle of draining the list
    while(data_list.size())
    {
        auto data = data_list.front();
        CaffeineSocketClient sc = scMap.find(s)->second;
        //  Write the data and call the callback
        auto bytes_sent = sc.send(data.first.data(), data.first.size(), 0);

        if(bytes_sent>=0 && static_cast<int>(data.first.size())>bytes_sent)
        {
            data.first.erase(bytes_sent);
        }
        else
        {
            //  Call the callback
            auto ctx = data.second.first;
            ctx->Enter();

            CefRefPtr<CefV8Value> CallbackArg1;
            CefRefPtr<CefV8Value> CallbackArg2 = CefV8Value::CreateObject(NULL);

            if(bytes_sent == SOCKET_ERROR)
            {
                int error_code = WSAGetLastError();
                if (WSAEWOULDBLOCK != error_code && 0 != error_code)
                {
                    CallbackArg1 = CefV8Value::CreateBool(true);
                    CallbackArg2->SetValue("status", CefV8Value::CreateString("error"), V8_PROPERTY_ATTRIBUTE_NONE);
                    CallbackArg2->SetValue("errorCode", CefV8Value::CreateInt(::WSAGetLastError()), V8_PROPERTY_ATTRIBUTE_NONE);
                    CallbackArg2->SetValue("handle", CefV8Value::CreateInt(s), V8_PROPERTY_ATTRIBUTE_NONE);
                }
                else
                {
                    //  The socket can't write anymore.
                    ctx->Exit();
                    break;
                }
            }
            else
            {
                CallbackArg1 = CefV8Value::CreateNull();
                CallbackArg2->SetValue("status", CefV8Value::CreateString("success"), V8_PROPERTY_ATTRIBUTE_NONE);
            }

            data_list.pop_front();
            CefV8ValueList args;
            args.push_back(CallbackArg1);
            args.push_back(CallbackArg2);
            data.second.second->ExecuteFunction(NULL, args);

            ctx->Exit();
        }
    }
}

//  TODO:  Switch over to unicode
string GenerateUUID() {
    UUID newUUID;
    unsigned char *tmp=NULL;
    UuidCreate(&newUUID);
    UuidToStringA(&newUUID, &tmp);
    string uuid((char *)tmp);
    RpcStringFreeA(&tmp);
    
    return uuid;
}

void GetZippedLogFiles(CefRefPtr<CefV8Value>& retval)
{
    retval = CefV8Value::CreateString("");
}


void ExecuteHasFocus(CefRefPtr<CaffeineClientApp>& client_app,
                     const CefV8ValueList& arguments,
                     CefRefPtr<CefV8Value>& retval )
{
    retval = CefV8Value::CreateBool(::GetForegroundWindow() == client_app->hwndRender);
}

wstring CaffeineClientApp::GetEphemeralState() 
{
    if (ephemeralState != L"{}")
    {
        wstring temp = decrypt(ephemeralState);
        ephemeralState = L"{}";
        return temp;
    }

    return ephemeralState;
}

void CaffeineClientApp::AppendStringToFile(const wstring& fileName, const wstring& msg)
{
    FILE* file = _wfopen(fileName.c_str(), L"a");

    wstringstream ss;
    if (file) {
        ss << msg << endl;

        fputws(ss.str().c_str(), file);
        fclose(file);
    }
    else
    {
        ss << "Could not open file " << fileName << " to write";
        ShellLog(ss.str());
    }
}

// Shell log output
void CaffeineClientApp::ShellLog(const wstring& msg)
{
    // create the message
    AutoLock lock_scope(this);
    struct _stat buf = {0,};
    int result = _wstat(CaffeineSettings.console_log.c_str(), &buf);
    if(0 == result)
    {
        //  TODO:  Fix the hack that only allows main to back up the file.
        if ((buf.st_size > CAFFEINE_MAX_LOG_SIZE)&&(myUUID == "main"))
        {
            BackupFile(CaffeineSettings.console_log);
        }
    }

    AppendStringToFile(CaffeineSettings.console_log, msg);
}

#ifdef ENABLE_MUSIC_SHARE
void getITunesTrackInfo(CefRefPtr<CefDictionaryValue>& TrackInfo)
{
	TrackWin *aTrack = new TrackWin;
    map<wstring, wstring> _trackInfo = aTrack->getTrackInfo();
	delete aTrack;

        for(map<wstring,wstring>::iterator iter = _trackInfo.begin(); iter != _trackInfo.end(); ++iter)
		{
            CefString cefKey = iter->first;
            CefString cefValue = iter->second;
            TrackInfo->SetString((const CefString)cefKey, (const CefString)cefValue);
        }

}

void isITunesOn(CefRefPtr<CefDictionaryValue>& isOn)
{
	CefString key = L"isOn";
	CefString bT = L"1";
	CefString bF = L"0";

	if( TrackWin::isITunesOn() )
		isOn->SetString((const CefString) key, (const CefString) bT);
	else
		isOn->SetString((const CefString) key, (const CefString) bF);
}

void getInstalledPlayers(CefRefPtr<CefDictionaryValue>& InstalledPlayers )
{	
	HKEY hKey = NULL;
	LONG lResult;

	lResult = RegOpenKeyEx(HKEY_CLASSES_ROOT, TEXT("Applications\\wmplayer.exe\\shell\\open\\command"), 0, KEY_READ, &hKey);
	if (lResult == ERROR_SUCCESS)
		InstalledPlayers->SetString(static_cast<CefString> (TEXT("WMP")), static_cast<CefString> (TEXT("1")) );
	RegCloseKey(hKey);
	
	lResult = RegOpenKeyEx(HKEY_CLASSES_ROOT, TEXT("Applications\\iTunes.exe\\shell\\open\\command"), 0, KEY_READ, &hKey);
	if ( lResult == ERROR_SUCCESS )
		InstalledPlayers->SetString( static_cast<CefString> (TEXT("iTunes")), static_cast<CefString> (TEXT("1")) );
	RegCloseKey(hKey);
}
#endif



