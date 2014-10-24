//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_MODIFY_HEADERS_RESOURCE_HANDLER_H
#define CAFFEINE_MODIFY_HEADERS_RESOURCE_HANDLER_H
#pragma once

#include "include/wrapper/cef_stream_resource_handler.h"
#include "include/cef_urlrequest.h"
#include <string>

#define CAFFEINE_RESOURCE_HANDLER_BUFFER_SIZE (1024*1024*4)  //  4MB
#define CAFFEINE_BUFFER_LEAD (243*1024)  //  243KB
#define MAX_HEADER_LENGTH (16*1024)
#define CARRIAGE_RETURN (0x0D)
#define LINE_FEED (0x0A)

class ModifyHeadersResourceHandler: public CefResourceHandler, public CefURLRequestClient {
    public:
        ModifyHeadersResourceHandler(const CefRefPtr<CefRequest> &request);
        ~ModifyHeadersResourceHandler();

        //  Probably should be a private method
//        bool LineEnds(int location);
//        bool ProcessResponseHeaders();

        // CefResourceHandler methods.
        virtual bool ProcessRequest(CefRefPtr<CefRequest> request, CefRefPtr<CefCallback> callback) OVERRIDE;
        virtual void GetResponseHeaders(CefRefPtr<CefResponse> response, int64& response_length, CefString& redirectUrl) OVERRIDE;
        virtual bool ReadResponse(void* data_out, int bytes_to_read, int& bytes_read, CefRefPtr<CefCallback> callback) OVERRIDE;
        virtual void Cancel() OVERRIDE;

        // CefURLRequestClient methods.
        virtual void OnRequestComplete(CefRefPtr<CefURLRequest> request) OVERRIDE;
        virtual void OnUploadProgress(CefRefPtr<CefURLRequest> request, uint64 current, uint64 total) OVERRIDE;
        virtual void OnDownloadProgress(CefRefPtr<CefURLRequest> request, uint64 current, uint64 total) OVERRIDE;
        virtual void OnDownloadData(CefRefPtr<CefURLRequest> request, const void* data, size_t data_length) OVERRIDE;

    private:
         bool bCompleted;
         bool bContinueNeedsCalling;
         int64 content_length;
         int64 bytes_received_so_far;
         int64 bytes_copied_so_far;
         CefRefPtr<CefURLRequest> current_request;
         CefRefPtr<CefCallback> current_callback;
         CefResponse::HeaderMap header_map_;
         char buffer[CAFFEINE_RESOURCE_HANDLER_BUFFER_SIZE];

    IMPLEMENT_REFCOUNTING(ModifyHeadersResourceHandler);
};

#endif  //  CAFFEINE_MODIFY_HEADERS_RESOURCE_HANDLER_H