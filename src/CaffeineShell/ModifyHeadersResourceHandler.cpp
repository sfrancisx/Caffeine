//  Copyright Yahoo! Inc. 2013-2014
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "ModifyHeadersResourceHandler.h"
#include <algorithm> 
#include <functional> 
#include <cctype>
#include <locale>
using namespace std;

ModifyHeadersResourceHandler::ModifyHeadersResourceHandler(const CefRefPtr<CefRequest> &request)
    :bCompleted(false),
     bContinueNeedsCalling(false),
     content_length(-1),
     bytes_received_so_far(0),
     bytes_copied_so_far(0)
{
    request->SetFlags(UR_FLAG_REPORT_RAW_HEADERS);
    //  Make the request and store it off
    current_request = CefURLRequest::Create(request, this);
}

ModifyHeadersResourceHandler::~ModifyHeadersResourceHandler()
{
}

bool ModifyHeadersResourceHandler::ProcessRequest(CefRefPtr<CefRequest> request, CefRefPtr<CefCallback> callback)
{
    current_callback = callback;
    bContinueNeedsCalling = true;
    return true;
}

void ModifyHeadersResourceHandler::GetResponseHeaders(CefRefPtr<CefResponse> response, int64& response_length, CefString& redirectUrl)
{
    response->SetMimeType("application/octet-stream");
    response->SetStatus(200);
    response_length = content_length;

    //  Set Headers
    header_map_.insert(CefResponse::HeaderMap::value_type("Cache-Control", "max-age=259200"));
    response->SetHeaderMap(header_map_);
}

bool ModifyHeadersResourceHandler::ReadResponse(void* data_out, int bytes_to_read, int& bytes_read, CefRefPtr<CefCallback> callback)
{
    bool retval = true;
    int64 num_uncopied_bytes = bytes_received_so_far - bytes_copied_so_far,
        num_bytes_to_copy = 0;

    if (num_uncopied_bytes > 0)
    {
        //  We put some hacky logic in to handle a CEF bug.  We need to trigger one additional read after the
        //  request has completed.
        num_bytes_to_copy = min<int64>(bytes_to_read, (bCompleted? num_uncopied_bytes/2 + 1 : num_uncopied_bytes));
        //  Do we need to synchronize access to the buffer?
        ::memcpy(data_out, &buffer[bytes_copied_so_far], static_cast<size_t> (num_bytes_to_copy));
        if (num_bytes_to_copy == num_uncopied_bytes)
        {
            bytes_received_so_far = bytes_copied_so_far = 0;
        }
        else
        {
            bytes_copied_so_far += num_bytes_to_copy;
        }
    }
    else
    {
        bContinueNeedsCalling = true;
        current_callback = callback;
    }
    bytes_read = static_cast<int>(num_bytes_to_copy);

    //  TODO:  Handle the case where the data length wasn't known.
    retval = !(bCompleted && (bytes_received_so_far == bytes_copied_so_far));
    return retval;
}

void ModifyHeadersResourceHandler::Cancel()
{
    //  Cancel the url request
    current_request->Cancel();
}


void ModifyHeadersResourceHandler::OnRequestComplete(CefRefPtr<CefURLRequest> request)
{
    bCompleted = true;

    if(bContinueNeedsCalling)
    {
        bContinueNeedsCalling = false;
        current_callback->Continue();
    }
}

//  Right now, if you were to return this resource handler to a POST request.  The progress events don't seem to
//  happen.  Do we need to set the UR_FLAG_REPORT_UPLOAD_PROGRESS flag?  Would this fix it for the JS too?
void ModifyHeadersResourceHandler::OnUploadProgress(CefRefPtr<CefURLRequest> request, uint64 current, uint64 total)
{
}

void ModifyHeadersResourceHandler::OnDownloadProgress(CefRefPtr<CefURLRequest> request, uint64 current, uint64 total)
{
    content_length = total;
}

void ModifyHeadersResourceHandler::OnDownloadData(CefRefPtr<CefURLRequest> request, const void* data, size_t data_length)
{
    ::memcpy(&buffer[bytes_received_so_far], data, data_length);
    bytes_received_so_far += data_length;
    //  TODO:  ASSERT that we haven't overrun the buffer

    if(bContinueNeedsCalling && bytes_received_so_far > CAFFEINE_BUFFER_LEAD)
    {
        bContinueNeedsCalling = false;
        current_callback->Continue();
    }
}

