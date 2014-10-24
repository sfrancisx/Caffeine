//  Copyright Yahoo! Inc. 2013-2014
#ifndef LANGUAGE_CODES_H
#define LANGUAGE_CODES_H
#pragma once

#include "defines.h"
#include <Windows.h>

#define LOCALE_PATH            TEXT("Software\\") COMPANY TEXT("\\") PRODUCT
#define LANG_VALUE             TEXT("lang")
#define DEFAULT_LANG_CODE      (1033)

bool InternalGetLangCode(HKEY hKey, PDWORD val);
DWORD SetLangCode(DWORD CodeToSet);
DWORD GetLangCode();

#endif  //  LANGUAGE_CODES_H