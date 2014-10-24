//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_MAIN_WINDOW_H
#define CAFFEINE_MAIN_WINDOW_H
#pragma once

#include "CaffeineWindowCommon.h"

#define WM_PENDING_YID  (WM_USER + 1)

//  TODO:  Put in timers header file.
#define IDLETIMER (1)
#define IdleTimerPollIntervalMS (30000)

#define NETWORKTIMER (2)
#define NetworkTimerPollIntervalMS (15000)

//  Includes
#include <windows.h>

HWND InitMainWindowInstance(HINSTANCE hInstance, int nCmdShow, PTCHAR szWindowClass, PTCHAR szTitle);
LRESULT CALLBACK MainWindowWndProc(HWND, UINT, WPARAM, LPARAM);
ATOM RegisterMainWindowClass(HINSTANCE hInstance, PTCHAR szWindowClass);

#endif