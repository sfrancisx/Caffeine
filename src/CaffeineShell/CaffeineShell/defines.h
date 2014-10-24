#ifndef CAFFEINE_DEFINES_H
#define CAFFEINE_DEFINES_H
#pragma once

#ifdef OS_WIN
#define PLATFORM                L"Windows"
#else
#define PLATFORM                L"Mac"
#endif  //  OS_WIN

#define COMPANY                 L"Your Company Here"
#define PRODUCT                 L"Caffeine"
#define FULL_PRODUCT            COMPANY PRODUCT
#define APP_CACHE_NAME          FULL_PRODUCT L"-app-cache"
#define EXE_NAME                FULL_PRODUCT L".exe"

#define REG_APP_PATH            L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\" EXE_NAME L"\\"
#define CRASH_LOGS_PATH         L"\\CrashRpt\\UnsentCrashReports\\" FULL_PRODUCT L"_1.0.0"
#define DOWNLOAD_KEY_PATH       L"Software\\" COMPANY L"\\Caffeine"
#define UPDATE_KEY_PATH         L"Software\\" COMPANY L"\\Update"
#define UPDATE_CLIENTS_KEY_PATH UPDATE_KEY_PATH L"\\Clients\\"

#define DIAGNOSTICS_URL         L"SOME.URL.TO.USE"
#define INTERNAL_DOMAIN         L"SOME.DOMAIN.TO.USE"
#define COOKIE_DOMAIN           "SOME.DOMAIN.TO.USE"

#define USER_AGENT              L"CaffeineV1 (" PLATFORM L")"
#define PERSISTENT_STORE_PATH   L"Software\\" COMPANY L"\\" PRODUCT L"\\Persist"


#endif // CAFFEINE_DEFINES_H