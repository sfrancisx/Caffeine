//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_REMOTE_WINDOW_H
#define CAFFEINE_REMOTE_WINDOW_H
#pragma once

//  Includes
#include <windows.h>
#include <commdlg.h>
#include <string>

//  TODO:  Put in timers header file.
#define IDLETIMER (1)
#define IdleTimerPollIntervalMS (30000)

#define NETWORKTIMER (2)
#define NetworkTimerPollIntervalMS (15000)

HWND InitRemoteWindowInstance(
    HINSTANCE hInstance, 
    int nCmdShow, 
    PTCHAR szWindowClass, 
    PTCHAR szTitle, 
    std::string::const_pointer pbrowser_id,
    int clientheight, 
    int clientwidth, 
    int left, 
    int top,
    std::string::const_pointer initArg, 
    bool bCreateFrameless,
    bool isResizeable,
    int minWidth,
    int minHeight
);
ATOM RegisterRemoteWindowClass(HINSTANCE hInstance, PTCHAR szWindowClass);
LRESULT CALLBACK RemoteWindowWndProc(HWND, UINT, WPARAM, LPARAM);

#endif  //  CAFFEINE_REMOTE_WINDOW_H