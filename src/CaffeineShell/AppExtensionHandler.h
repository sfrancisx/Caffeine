#ifndef CAFFEINE_APPEXTENSIONHANDLER_H
#define CAFFEINE_APPEXTENSIONHANDLER_H
#pragma once

#include "CaffeineClientApp.h"
#include "include/cef_app.h"

void SetList(CefRefPtr<CefV8Value> source, CefRefPtr<CefListValue> target);
void SetList(CefRefPtr<CefListValue> source, CefRefPtr<CefV8Value> target);
void SetObject(CefRefPtr<CefV8Value> source, CefRefPtr<CefDictionaryValue> target);
void SetObject(CefRefPtr<CefDictionaryValue> source, CefRefPtr<CefV8Value> target);

class ClientAppExtensionHandler : public CefV8Handler 
{
public:
    explicit ClientAppExtensionHandler(CefRefPtr<CaffeineClientApp> client_app)
        : client_app_(client_app) {
    }

    virtual bool Execute(const CefString& name,
        CefRefPtr<CefV8Value> object,
        const CefV8ValueList& arguments,
        CefRefPtr<CefV8Value>& retval,
        CefString& exception);
private:
    void LogBrowserError(std::wstring extensionName);
    CefRefPtr<CaffeineClientApp> client_app_;
    IMPLEMENT_REFCOUNTING(ClientAppExtensionHandler);
};

#endif  // CAFFEINE_APPEXTENSIONHANDLER_H