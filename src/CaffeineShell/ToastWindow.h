//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_TOAST_WINDOW_H
#define CAFFEINE_TOAST_WINDOW_H
#pragma once

//  Includes
#include <windows.h>
#include <commdlg.h>
#include <string>

#define TOASTTIMER (7538)
#define ToastTimerPollIntervalMS (100)

HWND InitToastWindowInstance(
    HINSTANCE hInstance,
    PTCHAR szWindowClass, 
    PTCHAR szTitle,
    POINT attrib,
    std::string::const_pointer pbrowser_id,
    std::string::const_pointer initArg
);

int GetToastWindowHeight();
ATOM RegisterToastWindowClass(HINSTANCE hInstance, PTCHAR szWindowClass);
LRESULT CALLBACK ToastWindowWndProc(HWND, UINT, WPARAM, LPARAM);

#endif  //  CAFFEINE_TOAST_WINDOW_H