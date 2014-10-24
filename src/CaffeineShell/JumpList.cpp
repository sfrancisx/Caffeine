//  Copyright Yahoo! Inc. 2013-2014
//  This file needs Win7 (or later) support.
#define NTDDI_VERSION NTDDI_WIN7
#define _WIN32_WINNT  _WIN32_WINNT_WIN7
#define WINVER        _WIN32_WINNT_WIN7

#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "JumpList.h"
#include "CaffeineStringManager.h"
#include "resource.h"

#include <Windows.h>
#include <Propvarutil.h>
#include <atlbase.h>
#include <propkey.h>

//  TODO:  Why isn't this class data?
extern LPCTSTR g_szAppIDForTaskBar;
extern CaffeineStringManager StringManager;

JumpList::JumpList()
{
	CoInitialize(0);
}

JumpList::JumpList(const JumpList &original)
{
    _tcsncpy(szDescription, original.szDescription, INFOTIPSIZE);
}

JumpList::~JumpList()
{
	CoUninitialize();
}

/*
 * Add a task to the jumplist to enale the user to exit the application
 */
bool JumpList::AddJumpListExitTask(IObjectCollection* pObjColl)
{
	// Get the path to the EXE, which we use as the path and icon path for each jump list task.
	TCHAR szExePath[MAX_PATH];

	GetModuleFileName ( NULL, szExePath, _countof(szExePath) );

	// Create a shell link COM object.
	HRESULT hr;
	CComPtr<IShellLink> pLink;

	hr = pLink.CoCreateInstance ( CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER );

	if ( FAILED(hr) )
	{
		return false;
	}

	// Set the executable path
	hr = pLink->SetPath ( szExePath );

	if ( FAILED(hr) )
	{
		return false;
	}

	// Set the arguments
	hr = pLink->SetArguments ( L"--exit" );

	if ( FAILED(hr) )
	{
		return false;
	}

    // Set the link description (tooltip on the jump list item)
	hr = pLink->SetDescription (szDescription);

	if ( FAILED(hr) )
	{
		return false;
	}

	// Set the link title (the text of the jump list item). This is kept in the
	// object's property store, so QI for that interface.
	CComQIPtr<IPropertyStore> pPropStore = pLink;
	PROPVARIANT pv;

	if ( !pPropStore )
		return false;

	hr = InitPropVariantFromString ( CT2CW(szDescription), &pv );

	if ( FAILED(hr) )
	{
		return false;
	}

	// Set the title property.
	hr = pPropStore->SetValue ( PKEY_Title, pv );

	PropVariantClear ( &pv );

	if ( FAILED(hr) )
	{
		return false;
	}

	// Save the property changes.
	hr = pPropStore->Commit();

	if ( FAILED(hr) )
	{
		return false;
	}

	// Add this shell link to the object collection.
	hr = pObjColl->AddObject ( pLink );

	return SUCCEEDED(hr);
}

/*
 * Set up the jumplist for the application
 */
bool JumpList::SetUpJumpList(HINSTANCE hInstance)
{
    StringManager.LoadString(IDS_EXIT_CAFFEINE, szDescription, INFOTIPSIZE);
//    LoadString(hInstance, IDS_EXIT_CAFFEINE, szDescription, INFOTIPSIZE);

	HRESULT hr;
	CComPtr<ICustomDestinationList> pDestList;

	hr = pDestList.CoCreateInstance ( CLSID_DestinationList, NULL, CLSCTX_INPROC_SERVER );

	if ( FAILED(hr) ) {
		return false;
	}

	hr = pDestList->SetAppID ( g_szAppIDForTaskBar );

	if ( FAILED(hr) ) {
		return false;
	}

	UINT cMaxSlots;
	CComPtr<IObjectArray> pRemovedItems;

	hr = pDestList->BeginList ( &cMaxSlots, IID_PPV_ARGS(&pRemovedItems) );

	if ( FAILED(hr) ) {
		return false;
	}

	// Create an object collection to hold the custom tasks.
	CComPtr<IObjectCollection> pObjColl;

	hr = pObjColl.CoCreateInstance ( CLSID_EnumerableObjectCollection, NULL, CLSCTX_INPROC_SERVER );

	if ( FAILED(hr) )
		return false;

	// Add our custom tasks to the collection.
	if ( !AddJumpListExitTask ( pObjColl ) ) {
		return false;
	}

	// Get an IObjectArray interface for AddUserTasks.
	CComQIPtr<IObjectArray> pTasksArray = pObjColl;

	if ( !pTasksArray ) {
		return false;
	}

	// Add the tasks to the jump list.
	hr = pDestList->AddUserTasks ( pTasksArray );

	if ( FAILED(hr) ) {
		return false;
	}

	// Save the jump list.
	hr = pDestList->CommitList();

	return SUCCEEDED(hr);
}

/*
 * Remove all tasks that have been assigned to the jumplist
 */
void JumpList::RemoveAllTasks()
{
	HRESULT hr;
	CComPtr<ICustomDestinationList> pDestList;

	hr = pDestList.CoCreateInstance ( CLSID_DestinationList, NULL, CLSCTX_INPROC_SERVER );

	if ( FAILED(hr) ) {
		return;
	}

	pDestList->DeleteList(g_szAppIDForTaskBar);
}