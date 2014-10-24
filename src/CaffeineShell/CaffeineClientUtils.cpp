//  Copyright Yahoo! Inc. 2013-2014
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "CaffeineClientUtils.h"
#include "CaffeineClientHandler.h"
//#include <stdio.h>
#include <cstdlib>
#include <sstream>
#include <string>
#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_command_line.h"
#include "include/cef_frame.h"
#include "include/cef_runnable.h"
#include "include/cef_web_plugin.h"
using namespace std;

namespace {

    // Return the int representation of the specified string.
    int GetIntValue(const CefString& str) {
        if (str.empty())
            return 0;

        string stdStr = str;
        return atoi(stdStr.c_str());
    }

}  // namespace

CefRefPtr<CefCommandLine> g_command_line;

void AppInitCommandLine(int argc, const char* const* argv) {
    g_command_line = CefCommandLine::CreateCommandLine();
#if defined(OS_WIN)
    g_command_line->InitFromString(::GetCommandLineW());
#else
    g_command_line->InitFromArgv(argc, argv);
#endif
}

// Returns the application command line object.
CefRefPtr<CefCommandLine> AppGetCommandLine() {
    return g_command_line;
}


void DumpRequestContents(CefRefPtr<CefRequest> request, string& str)
{
    stringstream ss;
    
    ss << "URL: " << string(request->GetURL());
    ss << "\nMethod: " << string(request->GetMethod());
    
    CefRequest::HeaderMap headerMap;
    request->GetHeaderMap(headerMap);
    if (headerMap.size() > 0) {
        ss << "\nHeaders:";
        CefRequest::HeaderMap::const_iterator it = headerMap.begin();
        for (; it != headerMap.end(); ++it) {
            ss << "\n\t" << string((*it).first) << ": " <<
            string((*it).second);
        }
    }
    
    CefRefPtr<CefPostData> postData = request->GetPostData();
    if (postData.get()) {
        CefPostData::ElementVector elements;
        postData->GetElements(elements);
        if (elements.size() > 0) {
            ss << "\nPost Data:";
            CefRefPtr<CefPostDataElement> element;
            CefPostData::ElementVector::const_iterator it = elements.begin();
            for (; it != elements.end(); ++it) {
                element = (*it);
                if (element->GetType() == PDE_TYPE_BYTES) {
                    // the element is composed of bytes
                    ss << "\n\tBytes: ";
                    if (element->GetBytesCount() == 0) {
                        ss << "(empty)";
                    } else {
                        // retrieve the data.
                        size_t size = element->GetBytesCount();
                        char* bytes = new char[size];
                        element->GetBytes(size, bytes);
                        ss << string(bytes, size);
                        delete [] bytes;
                    }
                } else if (element->GetType() == PDE_TYPE_FILE) {
                    ss << "\n\tFile: " << string(element->GetFile());
                }
            }
        }
    }
    
    str = ss.str();
}

