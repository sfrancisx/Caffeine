//  Copyright Yahoo! Inc. 2013-2014
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "CaffeineStringManager.h"
#include "LanguageCodes.h"
#include <Windows.h>
#include <atlbase.h>
#include <string.h>
#include <tchar.h>
#include <algorithm>
#include <string>
using namespace std;

#define MAX_STRING_RESOURCE (100)

CaffeineStringManager::CaffeineStringManager()
: hResources(NULL)
{
}

CaffeineStringManager::CaffeineStringManager(HINSTANCE hResources)
: hResources(hResources)
{
}

CaffeineStringManager::CaffeineStringManager(const CaffeineStringManager &original)
: hResources(original.hResources)
{
}

HINSTANCE CaffeineStringManager::SetHInstance(HINSTANCE hResources)
{
    this->hResources = hResources;

    return hResources;
}

LPTSTR CaffeineStringManager::LoadString(UINT idString, LPTSTR buffer, UINT buffer_size)
{
    *buffer = 0;
    //  TODO:  The lang code logic could move into the constructor.
    LPCWSTR szStringResource = FindStringResourceEx(hResources, idString, LANGIDFROMLCID(GetLangCode()));
    if (!szStringResource) 
    {
        szStringResource = FindStringResourceEx(hResources, idString, LANGIDFROMLCID(DEFAULT_LANG_CODE));
    }

    if (szStringResource)
    {
        UINT string_size = UINT(*szStringResource);
        _tcsncpy_s(buffer, buffer_size, szStringResource + 1, min(buffer_size-1, string_size));
    }

    return buffer;
}

string CaffeineStringManager::LoadString(UINT idString, string &string)
{
    TCHAR szStringBuffer[MAX_STRING_RESOURCE];

    return (string = CT2CA(LoadString(idString, szStringBuffer, MAX_STRING_RESOURCE)));
}

//  Based on http://blogs.msdn.com/b/oldnewthing/archive/2004/01/30/65013.aspx
#pragma warning(disable:4244)  //  LangId gets converted to a WORD
//  TODO:  Do we really need a UINT for LangId
LPCTSTR CaffeineStringManager::FindStringResourceEx(HINSTANCE hInst, UINT uId, UINT LangId)
{
    // Convert the string ID into a bundle number
    LPCWSTR pwsz = NULL;
    HRSRC hrsrc = FindResourceEx(hResources, RT_STRING, MAKEINTRESOURCE(uId / 16 + 1), LangId);

    if (hrsrc) 
    {
        HGLOBAL hglob = LoadResource(hResources, hrsrc);
        if (hglob) 
        {
            pwsz = static_cast<LPCWSTR>(LockResource(hglob));
            if (pwsz) 
            {
                // okay now walk the string table
                for (unsigned i = 0; i < (uId & 15); ++i) 
                {
                    pwsz += 1 + (UINT)*pwsz;
                }
                UnlockResource(pwsz);
            }
            FreeResource(hglob);
        }
    }
    return pwsz;
}
#pragma warning(default:4244)  //  LangId gets converted to a WORD
