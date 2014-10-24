#include "AppExtensionHandler.h"
#ifdef OS_WIN
#include <atlconv.h>
#endif

using namespace std;

// Transfer a V8 value to a List index.
//  TODO:  Add object support to these functions
void SetListValue(
    CefRefPtr<CefListValue> list, 
    int index,
    CefRefPtr<CefV8Value> value) 
{
    if (value->IsArray()) {
        CefRefPtr<CefListValue> new_list = CefListValue::Create();
        SetList(value, new_list);
        list->SetList(index, new_list);
    } else if (value->IsString()) {
        list->SetString(index, value->GetStringValue());
    } else if (value->IsBool()) {
        list->SetBool(index, value->GetBoolValue());
    } else if (value->IsInt()) {
        list->SetInt(index, value->GetIntValue());
    } else if (value->IsDouble()) {
        list->SetDouble(index, value->GetDoubleValue());
    }
}

// Transfer a V8 array to a List.
void SetList(CefRefPtr<CefV8Value> source, CefRefPtr<CefListValue> target) 
{
    ASSERT(source->IsArray());

    int arg_length = source->GetArrayLength();
    if (arg_length == 0)
        return;

    // Start with null types in all spaces.
    target->SetSize(arg_length);

    for (int i = 0; i < arg_length; ++i)
        SetListValue(target, i, source->GetValue(i));
}

// Transfer a List value to a V8 array index.
void SetListValue(
    CefRefPtr<CefV8Value> list, 
    int index,
    CefRefPtr<CefListValue> value) 
{
    CefRefPtr<CefV8Value> new_value;

    CefValueType type = value->GetType(index);
    switch (type) {
    case VTYPE_LIST: {
        CefRefPtr<CefListValue> new_list = value->GetList(index);
        new_value = CefV8Value::CreateArray(static_cast<int>(new_list->GetSize()));
        SetList(new_list, new_value);
                        } break;
    case VTYPE_BOOL:
        new_value = CefV8Value::CreateBool(value->GetBool(index));
        break;
    case VTYPE_DOUBLE:
        new_value = CefV8Value::CreateDouble(value->GetDouble(index));
        break;
    case VTYPE_INT:
        new_value = CefV8Value::CreateInt(value->GetInt(index));
        break;
    case VTYPE_STRING:
        new_value = CefV8Value::CreateString(value->GetString(index));
        break;
    default:
        break;
    }

    if (new_value.get()) {
        list->SetValue(index, new_value);
    } else {
        list->SetValue(index, CefV8Value::CreateNull());
    }
}

// Transfer a List to a V8 array.
void SetList(CefRefPtr<CefListValue> source, CefRefPtr<CefV8Value> target) 
{
    ASSERT(target->IsArray());

    int arg_length = static_cast<int>(source->GetSize());
    if (arg_length == 0)
        return;

    for (int i = 0; i < arg_length; ++i)
        SetListValue(target, i, source);
}

void SetObjectValue(CefRefPtr<CefDictionaryValue> object, CefString key, CefRefPtr<CefV8Value> value)
{
    if (value->IsObject()) {
        CefRefPtr<CefListValue> new_list = CefListValue::Create();
        SetList(value, new_list);
        object->SetList(key, new_list);
    } else if (value->IsString()) {
        object->SetString(key, value->GetStringValue());
    } else if (value->IsBool()) {
        object->SetBool(key, value->GetBoolValue());
    } else if (value->IsInt()) {
        object->SetInt(key, value->GetIntValue());
    } else if (value->IsDouble()) {
        object->SetDouble(key, value->GetDoubleValue());
    }
}

void SetObjectValue(CefRefPtr<CefV8Value> object, CefString key, CefRefPtr<CefDictionaryValue> value)
{
    CefRefPtr<CefV8Value> new_value;

    CefValueType type = value->GetType(key);
    switch (type) {
    case VTYPE_LIST: 
    {
        CefRefPtr<CefListValue> list = value->GetList(key);
        new_value = CefV8Value::CreateArray(static_cast<int>(list->GetSize()));
        SetList(list, new_value);
        break;
    }
    case VTYPE_BOOL:
        new_value = CefV8Value::CreateBool(value->GetBool(key));
        break;
    case VTYPE_DOUBLE:
        new_value = CefV8Value::CreateDouble(value->GetDouble(key));
        break;
    case VTYPE_INT:
        new_value = CefV8Value::CreateInt(value->GetInt(key));
        break;
    case VTYPE_STRING:
        new_value = CefV8Value::CreateString(value->GetString(key));
        break;
    default:
        break;
    }

    if (new_value.get()) {
        object->SetValue(key, new_value, V8_PROPERTY_ATTRIBUTE_NONE);
    } else {
        object->SetValue(key, CefV8Value::CreateNull(), V8_PROPERTY_ATTRIBUTE_NONE);
    }
}

void SetObject(CefRefPtr<CefV8Value> source, CefRefPtr<CefDictionaryValue> target)
{
    ASSERT(source->IsObject());

    vector<CefString> keys;
    vector<CefString>::iterator i;
    source->GetKeys(keys);

    for(i=keys.begin(); i!=keys.end(); ++i)
    {
        SetObjectValue(target, *i, source->GetValue(*i));
    }
}

void SetObject(CefRefPtr<CefDictionaryValue> source, CefRefPtr<CefV8Value> target)
{
    ASSERT(target->IsObject());

    CefDictionaryValue::KeyList keys;
    CefDictionaryValue::KeyList::iterator i;
    source->GetKeys(keys);

    for(i=keys.begin(); i!=keys.end(); ++i)
    {
        SetObjectValue(target, *i, source);
    }
}

//  Should this be a template?
void SetObject(map<wstring, wstring> source, CefRefPtr<CefV8Value> target)
{
    map<wstring, wstring>::const_iterator i;
    for(i=source.cbegin(); i!=source.cend(); ++i)
    {
        target->SetValue(i->first, CefV8Value::CreateString(i->second), V8_PROPERTY_ATTRIBUTE_NONE);
    }
}

void ClientAppExtensionHandler::LogBrowserError(std::wstring extensionName)
{
    wstring msg = L"Error: browser.get undefined for: " + extensionName;
    client_app_->ShellLog(msg);
}

bool ClientAppExtensionHandler::Execute(const CefString& name,
        CefRefPtr<CefV8Value> object,
        const CefV8ValueList& arguments,
        CefRefPtr<CefV8Value>& retval,
        CefString& exception) 
{
    bool handled = false;

    if (name == "sendIPC")
    {
        ASSERT(arguments.size() == 3);
        ASSERT(arguments[0]->IsString());
        ASSERT(arguments[1]->IsString());
        ASSERT(arguments[2]->IsString());
        if (arguments.size() == 3 && arguments[0]->IsString() && arguments[1]->IsString() && arguments[2]->IsString())
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();

            ASSERT(browser.get());
            if(browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("sendIPC");
                //  What if the browser id is invalid?
                message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue());
                message->GetArgumentList()->SetString(1, arguments[1]->GetStringValue());
                message->GetArgumentList()->SetString(2, arguments[2]->GetStringValue());
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }

            handled = true;
        }
    }
            
    //  We should investigate the possibility of 1) using pop ups and 2) creating the
    //  window on the render (vs. the browser) side.
    //  TODO:  It doesn't look like we use this last string argument
    else if (name == "popupWindow")
    {
        client_app_->ShellLog(L"Window Creation Timing: ClientApp popupWindow ");

        ASSERT(arguments.size() == POPUP_WINDOW_NUMBER_OF_ARGUMENTS);
        ASSERT(arguments[0]->IsString());
        ASSERT(arguments[1]->IsBool());
        ASSERT(arguments[2]->IsInt());
        ASSERT(arguments[3]->IsInt());
        ASSERT(arguments[4]->IsInt());
        ASSERT(arguments[5]->IsInt());
        ASSERT(arguments[6]->IsString());
        ASSERT(arguments[7]->IsBool());
        ASSERT(arguments[8]->IsInt());
        ASSERT(arguments[9]->IsInt());

        CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
        ASSERT(browser.get());

        if (browser.get() && arguments.size() == POPUP_WINDOW_NUMBER_OF_ARGUMENTS &&
            arguments[0]->IsString() &&    // json args
            arguments[1]->IsBool() &&      //  frameless
            arguments[2]->IsInt() &&  // height
            arguments[3]->IsInt() &&  // width
            arguments[4]->IsInt() &&  // left
            arguments[5]->IsInt() &&  // top
            arguments[6]->IsString() &&   // target
            arguments[7]->IsBool()  && // resizable
            arguments[8]->IsInt()  && // minWidth
            arguments[9]->IsInt()  // minHeight
            )
        {
            //  Create a GUID as a string this will be a handle to the new window.
            string uuid = GenerateUUID();

            CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
            message->GetArgumentList()->SetString(0, uuid);
            message->GetArgumentList()->SetString(1, arguments[0]->GetStringValue());
            message->GetArgumentList()->SetBool(2, arguments[1]->GetBoolValue());
            message->GetArgumentList()->SetInt(3, arguments[2]->GetIntValue());
            message->GetArgumentList()->SetInt(4, arguments[3]->GetIntValue());
            message->GetArgumentList()->SetInt(5, arguments[4]->GetIntValue());
            message->GetArgumentList()->SetInt(6, arguments[5]->GetIntValue());
            message->GetArgumentList()->SetString(7, arguments[6]->GetStringValue());
            message->GetArgumentList()->SetBool(8, arguments[7]->GetBoolValue());
            message->GetArgumentList()->SetInt(9, arguments[8]->GetIntValue());
            message->GetArgumentList()->SetInt(10, arguments[9]->GetIntValue());

            browser->SendProcessMessage(PID_BROWSER, message);

            retval = CefV8Value::CreateString(uuid);
            handled = true;
        }
        else
        {
            LogBrowserError(name);
        }
    }
#ifdef OS_WIN
    else if (name == "getUpdaterVersion")
    {
        retval = CefV8Value::CreateString(L"Unknown");
        CRegKey crkOmahaVersion;
        if (ERROR_SUCCESS == crkOmahaVersion.Open(HKEY_LOCAL_MACHINE, UPDATE_KEY_PATH, KEY_READ))
        {
            DWORD dwVersionSize = MAX_PATH;
            WCHAR szVersion[MAX_PATH] = {0,};
            if (ERROR_SUCCESS == crkOmahaVersion.QueryStringValue(L"version", szVersion, &dwVersionSize))
            {
                retval = CefV8Value::CreateString(szVersion);
            }
        }
        handled = true;
    }
    else if (name == "toastWindow")
    {
        ASSERT(arguments.size() == 2);
        ASSERT(arguments[0]->IsString());
        ASSERT(arguments[1]->IsUndefined() || arguments[1]->IsString());
                    
        CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
        ASSERT(browser.get());

        if (browser.get() && arguments.size() == 2 &&
                arguments[0]->IsString() && arguments[1]->IsString())
        {
            //  Create a GUID as a string this will be a handle to the new window.
            string uuid = "-1";

            if (IsWindowsVistaOrGreater() )
            {
                uuid = GenerateUUID();

                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetString(0, uuid);
                message->GetArgumentList()->SetString(1, arguments[0]->GetStringValue());

                browser->SendProcessMessage(PID_BROWSER, message);
            }

            retval = CefV8Value::CreateString(uuid);
            handled = true;
        }
        else
        {
            LogBrowserError(name);
        }
    }
    
#else
    
    else if (name == "getUpdaterVersion")
    {
        retval = CefV8Value::CreateString(L"1.0");
        handled = true;
    }
    
#endif
    else if (name == "getWindow" )
    {
        //ASSERT(arguments.size() == 1);
        //ASSERT(arguments[0]->IsString());

        handled = false;

        if ( handled == false )
        {
            retval = CefV8Value::CreateString("");
            handled = true;
        }
    }

    // V8Extensions to activate/flash a particular window
    //  arguments need to be in the form: function( UUID )
    else if (name == "activateWindow" ||
                name == "startFlashing"  ||
                name == "stopFlashing")
    {
        ASSERT(arguments.size() <= 2);
        ASSERT(arguments[0]->IsString());
        if (arguments.size() <= 2 && arguments[0]->IsString())
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());

            if ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                //  What if the browser id is invalid?
                message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue());
                if (name == "startFlashing")
                {
                    message->GetArgumentList()->SetBool(1, arguments[1]->GetBoolValue());
                }
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
            handled = true;
        }
    }

    else if (name == "activateApp")
    {
        ASSERT(arguments.size() == 0);
                    
        if (arguments.size() == 0)
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
                        
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
        }
        handled = true;
    }

    else if (name == "showWindow"     ||
                name == "hideWindow" )
    {
        ASSERT(arguments.size() == 1);
                    
        if (arguments.size() == 1)
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
                                                
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                            
                if (arguments[0]->GetStringValue().length() != 0) {
                    message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue());
                } else {
                    message->GetArgumentList()->SetString(0, client_app_->myUUID);
                }
                            
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }

    else if (name == "setUserAgent")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsString());

        if (arguments.size() == 1 && arguments[0]->IsString())
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());

            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                //  What if the browser id is invalid?
                message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue());
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }

            handled = true;
        }
    }
            
    else if (name == "setBrowserValue")
    {
        ASSERT(arguments.size() == 2);
        ASSERT(arguments[0]->IsInt());
        ASSERT(arguments[1]->IsString());
                    
        if (arguments.size() == 2 && arguments[0]->IsInt() && arguments[1]->IsString())
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
                        
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                //  What if the browser id is invalid?
                message->GetArgumentList()->SetInt(0, arguments[0]->GetIntValue());
                message->GetArgumentList()->SetString(1, arguments[1]->GetStringValue());
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }

    else if (name == "openFile")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsString());

        if ( arguments.size() == 1 && arguments[0]->IsString() )
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue());
                            
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }

            handled = true;

        }
    }

#if defined(OS_WIN)
    else if (name == "getInstallerStats")
    {
        retval = CefV8Value::CreateString(GetInstallerStats());
        handled = true;
    }
    else if (name == "getLangCode")
    {
        ASSERT(arguments.size() == 0);
        if (arguments.size() == 0)
        {
            retval = CefV8Value::CreateUInt(GetLangCode());
            handled = true;
        }
    }

    else if (name == "setLangCode")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsUInt());

        if (arguments.size() == 1 && arguments[0]->IsUInt())
        {
            SetLangCode(static_cast<DWORD>(arguments[0]->GetUIntValue()));
            handled = true;
        }
    }
    else if (name == "restartApplication")
    {
        ASSERT(arguments.size() == 0);

        if (arguments.size() == 0)
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());

            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                CefString path = client_app_->GetLatestApplicationPath();
                message->GetArgumentList()->SetString(0, path);

                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }

            handled = true;
        }
    }

    else if (name == "getWindowState" )
    {
        ASSERT(arguments.size() == 0);

        if ( arguments.size() == 0 )
        {
            CefString state = client_app_->GetWindowState();
            retval = CefV8Value::CreateString(state);
            handled = true;
        }
    }

    else if (name == "getLatestVersion")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsString());
        if (arguments.size() == 1 && arguments[0]->IsString())
        {
            CefString version = client_app_->GetLatestVersion(arguments[0]->GetStringValue().ToWString());
            retval = CefV8Value::CreateString(version);
            handled = true;
        }
    }

#endif

    else if (name == "setPrefixMapping")
    {
        ASSERT(arguments.size() == 2);
        ASSERT(arguments[0]->IsString());
        ASSERT(arguments[1]->IsString());

        if (arguments.size() == 2 && arguments[0]->IsString() && arguments[1]->IsString())
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());

            if ( browser.get() )
            {
                //  TODO:  Need a "copy all args into argument list" function
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue());
                message->GetArgumentList()->SetString(1, arguments[1]->GetStringValue());
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
                        

            handled = true;
        }
    }

    else if (name == "hasFocus")
    {
        ASSERT(arguments.size() == 0);

        if (arguments.size() == 0)
        {
            ExecuteHasFocus(client_app_, arguments, retval);
            handled = true;
        }
    }
            
#if defined(OS_WIN)  
    else if (name == "getChannelGUIDs") 
    {
        ASSERT(arguments.size() == 0);
        if (arguments.size() == 0)
        {
            GUIDList guids = GetChannelGUIDs();
            retval = CefV8Value::CreateArray(guids.size());
            GUIDList::iterator i = guids.begin();
            for(unsigned int j=0; j<guids.size(); ++i, ++j)
            {
                retval->SetValue(j, CefV8Value::CreateString(i->c_str()));
            }
            handled = true;
        }
    }
#else
    else if (name == "getUpdateChannel")
    {
        ASSERT(arguments.size() == 0);
                    
        if (arguments.size() == 0)
        {
            retval = CefV8Value::CreateString( client_app_->GetUpdateChannel() );
            handled = true;
        }
    }
#endif
            
    else if (name == "getIP")
    {
        ASSERT(arguments.size() == 0);
        if (arguments.size() == 0)
        {
#if defined(OS_WIN)  
            char hostname[MAX_PATH] = {0,};

            gethostname(hostname, MAX_PATH);
            wstring host = CA2T(hostname);
            retval = CefV8Value::CreateString(client_app_->GetIPbyName(host));
#else
            retval = CefV8Value::CreateString( client_app_->GetIP() );
#endif
            handled = true;
        }
    }
    else if (name == "getIPbyName")
    {
        ASSERT(arguments.size() == 1);
                    
        if (arguments.size() == 1 && arguments[0]->IsString())
        {
            wstring hostName = arguments[0]->GetStringValue();
            hostName = client_app_->GetIPbyName(hostName);
            retval = CefV8Value::CreateString(hostName);
            handled = true;
        }
    }

    else if (name == "showFileSaveAsDialog")
    {
        ASSERT(arguments.size() == 1);
                    
        if (arguments.size() == 1 && arguments[0]->IsBool())
        {
            client_app_->showFileSaveAsDialog = arguments[0]->GetBoolValue();
            handled = true;
        }
    }

    else if (name == "createSocket")
    {
        handled = false;
                    
        if(arguments.size() == 7 &&
            arguments[0]->IsString() &&
            arguments[1]->IsInt() &&
            arguments[2]->IsBool() &&
            arguments[3]->IsFunction() &&
            arguments[4]->IsFunction() &&
            arguments[5]->IsFunction() &&
            arguments[6]->IsFunction()
            )
        {

#ifdef __APPLE__
                        
            static SOCKET created_socket = 0;
                        
            // we normally only have 1 socket open at a time, but there might be concurency issues
            // and we might have callbacks for 2 or so sockets at a time
            // but don't want to just increase numbers ad infinitieum
            if ( ++created_socket > 100 )
                created_socket = 1;
                        
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                client_app_->SetSocketCallback(created_socket, "read", CefV8Context::GetCurrentContext(), arguments[3]);
                client_app_->SetSocketCallback(created_socket, "error", CefV8Context::GetCurrentContext(), arguments[4]);
                client_app_->SetSocketCallback(created_socket, "close", CefV8Context::GetCurrentContext(), arguments[5]);
                client_app_->SetSocketCallback(created_socket, "connect", CefV8Context::GetCurrentContext(), arguments[6]);
                            
                // send create socket to the browser proc
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                            
                message->GetArgumentList()->SetInt(0, created_socket);
                message->GetArgumentList()->SetString(1, arguments[0]->GetStringValue());  // hostname
                message->GetArgumentList()->SetInt(2, arguments[1]->GetIntValue());
                message->GetArgumentList()->SetBool(3, arguments[2]->GetBoolValue());
                            
                browser->SendProcessMessage(PID_BROWSER, message);

                handled = true;
            }
                        
#else
            CaffeineSocketClient cs(arguments[0]->GetStringValue().ToWString(), arguments[1]->GetIntValue(), arguments[2]->GetBoolValue(), client_app_->hwndRender);
            SOCKET created_socket = cs;
                        
                        
            if (INVALID_SOCKET != created_socket)
            {
                //  Set up the socket client map
                client_app_->scMap.insert(make_pair(created_socket, cs));
                            
                //  Set up write buffer map
                client_app_->wbMap.insert(make_pair(created_socket, CaffeineClientApp::WriteBufferList()));

                // read, error, close and connect callbacks are the same in Mac/Win
                // write callbacks are treated differently
                            
                //  Set up the socket callbacks
                client_app_->SetSocketCallback(created_socket, "read", CefV8Context::GetCurrentContext(), arguments[3]);
                client_app_->SetSocketCallback(created_socket, "error", CefV8Context::GetCurrentContext(), arguments[4]);
                client_app_->SetSocketCallback(created_socket, "close", CefV8Context::GetCurrentContext(), arguments[5]);
                client_app_->SetSocketCallback(created_socket, "connect", CefV8Context::GetCurrentContext(), arguments[6]);
                            
                cs.connect();
                            
                handled = true;
            } 
#endif
        }
        else
        {
            client_app_->ShellLog(L"RTT2: ERROR: createSocket called with wrong arguments");
        }
                    
    }

    else if (name == "writeSocket")
    {
        handled = false;
        if(arguments.size() == 3 &&
            arguments[0]->IsInt() &&
            arguments[1]->IsString() &&
            arguments[2]->IsFunction()
            )
        {
#ifdef OS_WIN
            SOCKET s = arguments[0]->GetIntValue();
                        
            auto i = client_app_->wbMap.find(s);
            if(i != client_app_->wbMap.end())
            {
                string data = arguments[1]->GetStringValue();
                i->second.push_back(
                                    CaffeineClientApp::WriteBufferItem(data,
                                                                        CaffeineClientApp::CallbackMapEntry(CefV8Context::GetCurrentContext(), arguments[2]))
                                    );
                client_app_->NonBlockingSocketWrite(s);
                handled = true;
            }
#else
                        
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                            
                string data = arguments[1]->GetStringValue();
                            
                message->GetArgumentList()->SetInt(0, arguments[0]->GetIntValue());
                message->GetArgumentList()->SetString(1, data);
                            
                // TODO: write callback
                //message->GetArgumentList()->SetBool(3, arguments[0]->GetBoolValue());
                            
                browser->SendProcessMessage(PID_BROWSER, message);
                            
                handled = true;                            
            }
#endif
        }
        else
            client_app_->ShellLog(L"RTT2: ERROR: writeSocket called with wrong arguments");
                    
    }

    else if (name == "closeSocket")
    {
        if(arguments.size() == 1 && arguments[0]->IsInt())
        {
#ifdef OS_WIN
            SOCKET s = arguments[0]->GetIntValue();
                        
            auto i = client_app_->wbMap.find(s);
            if(i != client_app_->wbMap.end())
            {
                CefRefPtr<CefListValue> values = CefListValue::Create();
                values->SetInt(0, s);
                values->SetString(1, "close");

                client_app_->InvokeSocketMethod(values);
                handled = true;
            }
                        
#else
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                            
                message->GetArgumentList()->SetInt(0, arguments[0]->GetIntValue());
                browser->SendProcessMessage(PID_BROWSER, message);
                            
                handled = true;
            }
#endif
                        
        }
        else
            client_app_->ShellLog(L"RTT2: ERROR: closeSocket called with wrong arguments");
    }

    else if (name == "getUTF8Size")
    {
        string s = arguments[0]->GetStringValue();
        retval = CefV8Value::CreateUInt( static_cast<unsigned int> (s.size()) );
        handled = true;
    }

    else if (name == "getDownloadDirectoryFromUser")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsFunction());
        if(arguments.size() == 1 && arguments[0]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();

            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[0]);

            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if  ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }

            handled = true;
        }
    }
    else if (name == "getDownloadPathFromUser")
    {
        ASSERT(arguments.size() == 2);
        ASSERT(arguments[0]->IsString());
        ASSERT(arguments[1]->IsFunction());
        if(arguments.size() == 2 && arguments[0]->IsString() && arguments[1]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();

            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[1]);

            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if  ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                message->GetArgumentList()->SetString(1, arguments[0]->GetStringValue());
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }

            handled = true;
        }
    }

    else if (name == "resetDownloadDirectory")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsFunction());
        if(arguments.size() == 1 && arguments[0]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();

            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[0]);

            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if  ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }

            handled = true;
        }
    }

    else if (name == "setDownloadPath")
    {
        ASSERT(arguments.size() == 2);
        ASSERT(arguments[0]->IsString());
        ASSERT(arguments[1]->IsFunction());
        if(arguments.size() == 2 && arguments[0]->IsString() && arguments[1]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();

            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[1]);

            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if (browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                message->GetArgumentList()->SetString(1, arguments[0]->GetStringValue());
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }

    else if (name == "getDownloadPath")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsFunction());
        if(arguments.size() == 1 && arguments[0]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();

            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[0]);

            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if(browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }

            handled = true;
        }
    }

    else if (name == "showDirectory")
    {
        ASSERT(arguments.size() == 2);
        ASSERT(arguments[0]->IsString());
        ASSERT(arguments[1]->IsString() || arguments[1]->IsArray());
        if (arguments.size() == 2 && arguments[0]->IsString() && (arguments[1]->IsString() || arguments[1]->IsArray()))
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if  ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue());
                if (arguments[1]->IsString())
                {
                    message->GetArgumentList()->SetString(1, arguments[1]->GetStringValue());
                }
                else
                {
                    CefRefPtr<CefListValue> ListOfFiles = CefListValue::Create();
                    SetList(arguments[1], ListOfFiles);
                    message->GetArgumentList()->SetList(1, ListOfFiles);
                }
                //  Do we really need to send a process message for this?  Can't we just pop Explorer up
                //  right here?
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }

    else if (name == "shakeWindow")
    {
        ASSERT(arguments.size() == 0);
        if (arguments.size() == 0)
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if  ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                
                message->GetArgumentList()->SetString(0, client_app_->myUUID);
                
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
            handled = true;
        }
    }
    
    else if (name == "moveWindowTo")
    {
        ASSERT(arguments.size() == 4);
        if (arguments.size() == 4)
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if  ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                            
                message->GetArgumentList()->SetString(0, client_app_->myUUID);
                            
                message->GetArgumentList()->SetInt(1, arguments[0]->GetIntValue());  //left
                message->GetArgumentList()->SetInt(2, arguments[1]->GetIntValue());  //top
                message->GetArgumentList()->SetInt(3, arguments[2]->GetIntValue());  //height
                message->GetArgumentList()->SetInt(4, arguments[3]->GetIntValue());  //width
                            
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }
            
    else if (name == "getZippedLogFiles")
    {
        ASSERT(arguments.size() == 0);
                    
        if (arguments.size() == 0)
        {
            GetZippedLogFiles(retval);
            handled = true;
        }
    }
            
            
    else if (name == "stateIsNowLoggedIn" || name == "enableSessionMenus" )
    {
        ASSERT(arguments.size() == 1);
                    
        if (arguments.size() == 1)
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if  ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetBool(0, arguments[0]->GetBoolValue());
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
                                                
            handled = true;
        }
    }
            
    else if (name == "messageReceived")
    {
        ASSERT(arguments.size() == 4); // yid, display name, message, and conversation Id
        if (arguments.size() == 4)
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if  ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue());
                message->GetArgumentList()->SetString(1, arguments[1]->GetStringValue());
                message->GetArgumentList()->SetString(2, arguments[2]->GetStringValue());
                message->GetArgumentList()->SetString(3, arguments[3]->GetStringValue());
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
                    
    }
            
    else if (name == "shellSetsLocation")
    {
        ASSERT(arguments.size() == 0);
                    
        if (arguments.size() == 0)
        {
            retval = CefV8Value::CreateBool(client_app_->shellHasLocationData);
            handled = true;
        }
    }
            
    else if (name == "setBadgeCount")
    {
        ASSERT(arguments.size() == 2);
        if (arguments.size() == 2)
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if  ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, arguments[0]->GetIntValue());
                message->GetArgumentList()->SetBool(1, arguments[1]->GetBoolValue());
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }
            
    else if (name == "showViewMenu")
    {
        ASSERT(arguments.size() == 1);
        if (arguments.size() == 1)
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if  ( browser.get())
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetBool(0, arguments[0]->GetBoolValue());
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }

            handled = true;
        }
    }
           
    //  TODO:  Should probably have these functions throw if the conversion failed
    else if (name == "encrypt")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsString());
        if (arguments.size() == 1 && arguments[0]->IsString())
        {
            retval = CefV8Value::CreateString(client_app_->encrypt(arguments[0]->GetStringValue()));
            handled = true;
        }
    }
    else if (name == "decrypt")
    {
        ASSERT(arguments.size() == 1 && arguments[0]->IsString());
        if (arguments.size() == 1 && arguments[0]->IsString())
        {
            retval = CefV8Value::CreateString(client_app_->decrypt(arguments[0]->GetStringValue()));
            handled = true;
        }
    }
    
    else if (name == "setEphemeralState")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsString());

        if (arguments.size() == 1 && arguments[0]->IsString())
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());

            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue().ToWString());

                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }

            handled = true;
        }
    }
#ifdef OS_WIN
    else if (name == "getEphemeralState")
    {
        ASSERT(arguments.size() == 0);
        if (arguments.size() == 0)
        {
            CefString state = client_app_->GetEphemeralState();
            retval = CefV8Value::CreateString(state);
            handled = true;
        }
    }
#endif
    else if (name == "setPersistentValue")
    {
        ASSERT(arguments.size() == 2);
        ASSERT(arguments[0]->IsString());
        ASSERT(arguments[1]->IsString());
        
        if (arguments.size() == 2 && arguments[0]->IsString() && arguments[1]->IsString())
        {
            retval = CefV8Value::CreateBool(SetPersistentValue(arguments[0]->GetStringValue().ToWString(), arguments[1]->GetStringValue().ToWString()));
            handled = true;
        }
    }

    else if (name == "getPersistentValue")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsString());
        
        if (arguments.size() == 1 && arguments[0]->IsString())
        {
            retval = CefV8Value::CreateUndefined();
            PersistentValue pv = GetPersistentValue(arguments[0]->GetStringValue().ToWString());
            if (pv.first == arguments[0]->GetStringValue().ToWString())
            {
                retval = CefV8Value::CreateString(pv.second);
            }
            handled = true;
        }
    }

    else if (name == "removePersistentValue")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsString());
        
        if (arguments.size() == 1 && arguments[0]->IsString())
        {
            retval = CefV8Value::CreateBool(DeletePersistentValue(arguments[0]->GetStringValue().ToWString()));
            handled = true;
        }
    }

    //  Returns an object with all key/value pairs
    else if (name == "getAllPersistentValues")
    {
        ASSERT(arguments.size() == 0);
        
        if (arguments.size() == 0)
        {
            retval = CefV8Value::CreateObject(NULL);
            SetObject(GetPersistentValues(), retval);
            handled = true;
        }
    }
    
#if defined(OS_WIN)
    else if (name == "uploadCrashLogs")
    {
        ASSERT(arguments.size() == 2 && arguments[0]->IsString() && arguments[1]->IsString());
        if(arguments.size() == 2 && arguments[0]->IsString() && arguments[1]->IsString())
        {
            retval = CefV8Value::CreateBool(client_app_->UploadCrashLogs(arguments[0]->GetStringValue(), arguments[1]->GetStringValue()));
            handled = true;
        }
    }
    else if (name == "getCrashLogCount")
    {
        retval = CefV8Value::CreateInt(client_app_->GetCrashLogCount());
        handled = true;
    }
    else if (name == "deleteCrashLogs")
    {
        client_app_->DeleteCrashLogs();
        handled = true;
    }
    else if (name == "triggerDump")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsFunction());
        if(arguments.size() == 1 && arguments[0]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();

            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[0]);

            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }

            handled = true;
        }
    }
#else
    else if (name == "triggerDump")
    {
        // ignored
        handled = true;
    }
            
    else if (name == "getCrashLogCount")
    {
        int val = 0;
        retval = CefV8Value::CreateInt(val);
        handled = true;
    }
    else if (name == "deleteCrashLogs")
    {
        //client_app_->DeleteCrashLogs();
        handled = true;
    }
    else if (name == "getLocale" )
    {
        ASSERT(arguments.size() == 0);
        if (arguments.size() == 0)
        {
            retval = CefV8Value::CreateString(client_app_->currentLocale);
            handled = true;
        }
    }
            
    else if (name == "removeAllUserTokens" )
    {
        ASSERT(arguments.size() == 0);
        if (arguments.size() == 0)
        {
            client_app_->RemoveAllUserTokens();
                        
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }
            
    else if ( name == "removeUserToken")
    {
        ASSERT(arguments.size() == 1);
        if (arguments.size() == 1)
        {
            string user = arguments[0]->GetStringValue();
            client_app_->RemoveUserToken(user);
                        
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetString(0, user);
                browser->SendProcessMessage(PID_BROWSER, message);
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }
    else if (name == "setUserToken")
    {
        ASSERT(arguments.size() == 2);
        if (arguments.size() == 2)
        {
            client_app_->SetUserToken(arguments[0]->GetStringValue(), arguments[1]->GetStringValue());
                        
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue());
                message->GetArgumentList()->SetString(1, arguments[1]->GetStringValue());
                browser->SendProcessMessage(PID_BROWSER, message);
            } 
                        
            handled = true;
        }
    }
            
    else if (name == "getUserToken")
    {
        ASSERT(arguments.size() == 1);
        if (arguments.size() == 1)
        {
            retval = CefV8Value::CreateString( client_app_->GetUserToken( arguments[0]->GetStringValue() ) );
            handled = true;
        }
    }
            
#endif
    else if (name == "isInternalIP")
    {
        ASSERT(arguments.size() == 0);
                    
        if (arguments.size() == 0)
        {
            retval = CefV8Value::CreateBool(client_app_->isInternalIP());
            handled = true;
        }
    }
#ifdef ENABLE_MUSIC_SHARE
    else if (name == "isITunesOn")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsFunction());
        if(arguments.size() == 1 && arguments[0]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();
                        
            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[0]);
                        
            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }
/**
    *  Used in implementing a javascript function.
    *  Calls CaffeineClientAppMac.mm
    */
    else if (name == "ITunesPlayPreview")
    {
            ASSERT(arguments.size() == 1);
            ASSERT(arguments[0]->IsString());
                     
            if (arguments.size() == 1 && arguments[0]->IsString())
            {
                CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
                ASSERT(browser.get());
                if ( browser.get() )
                {
                    CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                    //  What if the browser id is invalid?
                    message->GetArgumentList()->SetString(0, arguments[0]->GetStringValue());
                             
                    browser->SendProcessMessage(PID_BROWSER, message);
                }
                else
                {
                    LogBrowserError(name);
                }
                     
                handled = true;
            }
    }
    else if (name == "getITunesTrackInfo")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsFunction());
        if(arguments.size() == 1 && arguments[0]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();
                        
            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[0]);
                        
            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }
                
    else if (name == "getInstalledPlayers")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsFunction());
        if(arguments.size() == 1 && arguments[0]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();
                        
            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[0]);
                        
            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }
#endif
    else if (name == "setCookie")  // name, value, callback
    {
        ASSERT(arguments.size() == 3);
        ASSERT(arguments[0]->IsString());
        ASSERT(arguments[1]->IsString());
        if (arguments.size() == 3 && arguments[0]->IsString() && arguments[1]->IsString() )
        {
            CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();
                            
                //  Set the callback
                client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[2]);
                            
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                message->GetArgumentList()->SetString(1, arguments[0]->GetStringValue());
                message->GetArgumentList()->SetString(2, arguments[1]->GetStringValue());
                            
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }
                        
                        
            handled = true;
        }
    }
    else if (name == "getITunesTrackInfo")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsFunction());
        if(arguments.size() == 1 && arguments[0]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();
                        
            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[0]);
                        
            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }
                
    else if (name == "getInstalledPlayers")
    {
        ASSERT(arguments.size() == 1);
        ASSERT(arguments[0]->IsFunction());
        if(arguments.size() == 1 && arguments[0]->IsFunction())
        {
            CefRefPtr<CefV8Context> current_context = CefV8Context::GetCurrentContext();
                        
            //  Set the callback
            client_app_->SetMessageCallback(name, CaffeineClientApp::callback_counter, current_context, arguments[0]);
                        
            CefRefPtr<CefBrowser> browser = current_context->GetBrowser();
            ASSERT(browser.get());
            if ( browser.get() )
            {
                CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);
                message->GetArgumentList()->SetInt(0, CaffeineClientApp::callback_counter);
                browser->SendProcessMessage(PID_BROWSER, message);
                ++CaffeineClientApp::callback_counter;
            }
            else
            {
                LogBrowserError(name);
            }
                        
            handled = true;
        }
    }
				
    if (!handled)
        exception = "Invalid method arguments";
    return true;
}

