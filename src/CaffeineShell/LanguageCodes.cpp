//  Copyright Yahoo! Inc. 2013-2014
#include "LanguageCodes.h"

DWORD SetLangCode(DWORD CodeToSet)
{
    HKEY hkLangCode = NULL;
    DWORD bufSize = sizeof(DWORD);

    LONG retval = RegCreateKeyEx(HKEY_CURRENT_USER, LOCALE_PATH, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, NULL, &hkLangCode, NULL);
    if (ERROR_SUCCESS == retval)
    {
        RegSetValueEx(hkLangCode, LANG_VALUE, 0, REG_DWORD, reinterpret_cast<const BYTE *>(&CodeToSet), bufSize);
    }
    RegCloseKey(hkLangCode);

    return retval;
}

bool InternalGetLangCode(HKEY TopLevelKey, PDWORD val)
{
    bool retval = false;
    HKEY hKey = NULL;
    DWORD bufSize = sizeof(DWORD);

    if(RegOpenKeyEx(TopLevelKey, LOCALE_PATH, NULL, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS)
    {
        DWORD error = RegQueryValueEx(hKey, LANG_VALUE, NULL, NULL, reinterpret_cast<LPBYTE>(val), &bufSize);

        if(error == ERROR_SUCCESS)
        {
            retval = true;
        }
    }
    RegCloseKey(hKey);

    return retval;
}

DWORD GetLangCode()
{
    DWORD retVal = DEFAULT_LANG_CODE;

    // Try and get lang code from HKCU
    bool success = InternalGetLangCode(HKEY_CURRENT_USER, &retVal);
    if (!success)
    {
        // Try and get lang code from HKLM
        if(InternalGetLangCode(HKEY_LOCAL_MACHINE, &retVal))
        {
            //  Now, set it for the next time.
            SetLangCode(retVal);
        }
    }

    return retVal;
}
