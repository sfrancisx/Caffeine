//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_STRING_MANAGER_H
#define CAFFEINE_STRING_MANAGER_H
#pragma once

#include <Windows.h>
#include <string>

class CaffeineStringManager
{
    public:
        CaffeineStringManager();
        CaffeineStringManager(HINSTANCE hResources);
        CaffeineStringManager(const CaffeineStringManager &original);
        //  Do we need want operator=?

        HINSTANCE SetHInstance(HINSTANCE hResources);

        LPTSTR LoadString(UINT idString, LPTSTR buffer, UINT buffer_size);
        std::string LoadString(UINT idString, std::string &string);

    private:
        LPCTSTR FindStringResourceEx(HINSTANCE hinst, UINT uId, UINT langId);

        HINSTANCE hResources;
};

#endif