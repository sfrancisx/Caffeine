//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_JUMPLIST_H
#define CAFFEINE_JUMPLIST_H
#pragma once

#include <Windows.h>
#include <Shobjidl.h>
#include <string>

//  TODO:  Should these just be namespaced functions?
class JumpList
{
    public:
        JumpList();
        JumpList(const JumpList &);
        ~JumpList();

        //  TODO:  Shouldn't this really be the constructor?
	    bool SetUpJumpList(HINSTANCE);
	    void RemoveAllTasks();

        TCHAR szDescription[INFOTIPSIZE];

    private:
	    bool AddJumpListExitTask(IObjectCollection* pObjColl);
};

#endif  //  CAFFEINE_JUMPLIST_H