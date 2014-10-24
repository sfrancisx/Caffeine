//  Copyright Yahoo! Inc. 2013-2014
#ifdef _DEBUG
#ifdef CAFFEINE_DEBUG_MEMORY
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif  //  CAFFEINE_DEBUG_MEMORY
#endif  //  _DEBUG

#include "TrackWin.h"
#include <tchar.h>

//  TODO:  Why isn't this in the linker settings?
#pragma comment(lib, "Psapi.lib") 

TrackWin::TrackWin()
{

	iITunes = NULL;
	HRESULT hRes;// = S_FALSE;

	//hRes = CoInitializeEx(NULL, COINIT_MULTITHREADED);
	hRes = CoInitialize(NULL);	


	if(isITunesOn()){
	
		
		// Create itunes interface
		hRes = ::CoCreateInstance(CLSID_iTunesApp, NULL, CLSCTX_LOCAL_SERVER, IID_IiTunes, (PVOID *)&iITunes);
		
	}

}

TrackWin::~TrackWin()
{
	if(iITunes)
		iITunes->Release();
	
	//try{
		CoUninitialize();
	//}
	//catch(...){
	//}
}

bool TrackWin::isITunesOn()
{
	
	const wchar_t *iTunes = L"iTunes.exe";
	HANDLE hProcess = NULL;
	// Get the list of process identifiers.
	DWORD aProcesses[1024], cbNeeded, cProcesses;
    unsigned int i;

    if ( !EnumProcesses( aProcesses, sizeof(aProcesses), &cbNeeded ) )
    {
        return false;
		
    }


    // Calculate how many process identifiers were returned.

    cProcesses = cbNeeded / sizeof(DWORD);

    // Print the name and process identifier for each process.

    for ( i = 0; i < cProcesses; ++i )
    {
        if( aProcesses[i] != 0 )
        {
         
			// To ensure correct resolution of symbols, add Psapi.lib to TARGETLIBS
			// and compile with -DPSAPI_VERSION=1


		    TCHAR szProcessName[MAX_PATH] = TEXT("<unknown>");

			// Get a handle to the process.

			 hProcess = OpenProcess( PROCESS_QUERY_INFORMATION |
					                       PROCESS_VM_READ,
							               FALSE, aProcesses[i] );

			// Get the process name.

			if (NULL != hProcess )
			{
				HMODULE hMod;
				DWORD cbNeededForModules;

				if (EnumProcessModules(hProcess, &hMod, sizeof(hMod), &cbNeededForModules))
				{
					GetModuleBaseName(hProcess, hMod, szProcessName, sizeof(szProcessName)/sizeof(TCHAR));
				}
				CloseHandle( hProcess );
			}

			// Check if iTunes is running

			if (_tcscmp(szProcessName, iTunes ) == 0)
			{
				// Release the handle to the process.
				return true;
			}
		}
    }

	return false;
}

std::wstring TrackWin::getPlayerState()
{
	using std::wstring;

	// String operations done in a wstring, then converted for return
	wstring wstrRet = L"Stopped";
	HRESULT hRes = S_FALSE;

	if(iITunes )
	{ 
		ITPlayerState iIPlayerState;
		hRes = iITunes->get_PlayerState(&iIPlayerState);

		// Add player state, if special
		switch(iIPlayerState)
		{
		case ITPlayerStatePlaying:
			wstrRet = L"Play";
			break;
		case ITPlayerStateStopped:
			wstrRet = L"Stopped";
			break;
		case ITPlayerStateFastForward:
			wstrRet = L"FastForward";
			break;
		case ITPlayerStateRewind:
			wstrRet = L"Rewind";
			break;
		default:
			wstrRet = L"unknown";
			break;
		}
	}
	else
	{
		// iTunes interface not found/failed
		wstrRet = L"";
	}

	return wstrRet;
}

std::wstring TrackWin::getSong()
{
	using std::wstring;

	IITTrack *iITrack = NULL;

	// String operations done in a wstring, then converted for return
	wstring wstrRet = L"";;

	HRESULT hRes = S_FALSE;

	if(iITunes)
	{
		hRes = iITunes->get_CurrentTrack(&iITrack);
	}

	if(hRes == S_OK && iITrack)
	{
		
		BSTR bstrTrack = 0;

		iITrack->get_Name((BSTR *)&bstrTrack);
			
		// Add song title
		if(bstrTrack)
			wstrRet += bstrTrack;
	}

	if(iITrack)
		iITrack->Release();

	return wstrRet;
}

std::wstring TrackWin::getAlbum()
{
	using std::wstring;

	IITTrack *iITrack = NULL;

	// String operations done in a wstring, then converted for return
	wstring wstrRet = L"";

	HRESULT hRes = S_FALSE;

	if(iITunes)
	{
		hRes = iITunes->get_CurrentTrack(&iITrack);
	}	
	if(hRes == S_OK && iITrack)
	{
		BSTR bstrAlbum = 0;

		iITrack->get_Album((BSTR *)&bstrAlbum);
			
		// Add song title
		if(bstrAlbum)
			wstrRet += bstrAlbum;
	}
	
	if(iITrack)
		iITrack->Release();

	return wstrRet;
}

std::wstring TrackWin::getArtist()
{
	using std::wstring;

	IITTrack *iITrack = NULL;

	// String operations done in a wstring, then converted for return
	wstring wstrRet = L"";

	HRESULT hRes = S_FALSE;

	if(iITunes)
	{
		hRes = iITunes->get_CurrentTrack(&iITrack);
	}	

	if(hRes == S_OK && iITrack)
	{
		BSTR bstrArtist = 0;

		iITrack->get_Artist((BSTR *)&bstrArtist);
			
		// Add song title
		if(bstrArtist)
			wstrRet += bstrArtist;
	}

	if(iITrack)
		iITrack->Release();

	return wstrRet;
}
std::wstring TrackWin::getGenre()
{
	using std::wstring;

	IITTrack *iITrack = NULL;

	// String operations done in a wstring, then converted for return
	wstring wstrRet = L"";

	HRESULT hRes = S_FALSE;

	if(iITunes)
	{
		hRes = iITunes->get_CurrentTrack(&iITrack);
	}	

	if(hRes == S_OK && iITrack)
	{
		BSTR bstrGenre = 0;

		iITrack->get_Genre((BSTR *)&bstrGenre);
			
		// Add song title
		if(bstrGenre)
			wstrRet += bstrGenre;
	}

	if(iITrack)
		iITrack->Release();
	return wstrRet;
}

double TrackWin::getPlayerPosition()
{	
	long playerPosition = 0;
	long *playerPositionPtr = &playerPosition;

	if(iITunes)
	{	
		iITunes->get_PlayerPosition(playerPositionPtr);
	}

	return (double)playerPosition;
}

double TrackWin::getTimeUntilEnd()
{	
	IITTrack *iITrack = NULL;
	long timeUntilEnd = 0;
	long *timeUntilEndPtr = &timeUntilEnd;

	HRESULT hRes = S_FALSE;

	if(iITunes)
	{
		hRes = iITunes->get_CurrentTrack(&iITrack);
	}	

	if(hRes == S_OK && iITrack)
	{		
		iITrack->get_Duration(timeUntilEndPtr);

		iITrack->Release();	
	}

	if(iITrack)
		iITrack->Release();

	return (double)timeUntilEnd;
}


int TrackWin::getSeasonNumber()
{
	IITTrack *iITrack = NULL;
	IITFileOrCDTrack *iIFileOrCDTrack = NULL;
	long seasonNumber = 0;
	long *seasonNumberPtr = &seasonNumber;

	HRESULT hRes = S_FALSE;;

	if(iITunes)
	{
		hRes = iITunes->get_CurrentTrack(&iITrack);
	}
	if(hRes == S_OK && iITrack)
	{
		hRes = iITrack->QueryInterface(IID_IITFileOrCDTrack, (PVOID *)&iIFileOrCDTrack);
	}
	if(hRes == S_OK && iIFileOrCDTrack)
	{	
		hRes = iIFileOrCDTrack->get_SeasonNumber(seasonNumberPtr);
	}

	if (iIFileOrCDTrack)
		iIFileOrCDTrack->Release();
	if (iITrack)
		iITrack->Release();
	
	return  (int)seasonNumber;
}

int TrackWin::getEpisodeNumber()
{
	IITTrack *iITrack = NULL;
	IITFileOrCDTrack *iIFileOrCDTrack = NULL;
	long episodeNumber = 0;
	long *episodeNumberPtr = &episodeNumber;

	HRESULT hRes = S_FALSE;

	if(iITunes)
	{
		hRes = iITunes->get_CurrentTrack(&iITrack);
	}
	
	if(hRes == S_OK && iITrack)
	{
		hRes = iITrack->QueryInterface(IID_IITFileOrCDTrack, (PVOID *)&iIFileOrCDTrack);
	}
	if(hRes == S_OK && iIFileOrCDTrack)
	{		
		hRes = iIFileOrCDTrack->get_EpisodeNumber(episodeNumberPtr);
	}

	if (iIFileOrCDTrack)
		iIFileOrCDTrack->Release();
	if (iITrack)
		iITrack->Release();

	return  (int)episodeNumber;
}

std::wstring TrackWin::getShowName()
{
	using std::wstring;

	IITTrack *iITrack = NULL;
	IITFileOrCDTrack *iIFileOrCDTrack = NULL;

	// String operations done in a wstring, then converted for return
	wstring wstrRet = L"";

	HRESULT hRes = S_FALSE;

	// Create interface to current track
	if(iITunes)
	{
		hRes = iITunes->get_CurrentTrack(&iITrack);
	}
	
	// Create sub interface to FileOrCDTrack
	if(hRes == S_OK && iITrack)
	{
		hRes = iITrack->QueryInterface(IID_IITFileOrCDTrack, (PVOID *)&iIFileOrCDTrack);
	}

	// Get videoKind
	if(hRes == S_OK && iIFileOrCDTrack)
	{
		BSTR bstrShowName = 0;

		iIFileOrCDTrack->get_Show((BSTR *)&bstrShowName);
			
		// Add Show Name
		if(bstrShowName)
			wstrRet += bstrShowName;
	}

	if(iIFileOrCDTrack)
		iIFileOrCDTrack->Release();
	if(iITrack)
		iITrack->Release();

	return wstrRet;
}

std::wstring TrackWin::getVideoKind()
{
	using std::wstring;

	//IiTunes *iITunes = 0;
	IITTrack *iITrack = NULL;
	IITFileOrCDTrack *iIFileOrCDTrack = NULL;

	// String operations done in a wstring, then converted for return
	wstring wstrRet = L"unknown";

	HRESULT hRes = S_FALSE;
	// Create interface to current track
	if(iITunes)
	{
		hRes = iITunes->get_CurrentTrack(&iITrack);
	}
	
	// Create sub interface to FileOrCDTrack
	if(hRes == S_OK && iITrack)
	{
		hRes = iITrack->QueryInterface(IID_IITFileOrCDTrack, (PVOID *)&iIFileOrCDTrack);

	}

	// Get videoKind
	if(hRes == S_OK && iIFileOrCDTrack)
	{
		ITVideoKind videoKind = ITVideoKindNone;
		iIFileOrCDTrack->get_VideoKind(&videoKind);

		// Add player state, if special
		switch(videoKind)
		{
			case ITVideoKindNone:
				wstrRet = L"unknown";
				break;
        
			case ITVideoKindMovie:
				wstrRet = L"movie";
				break;
        
			case ITVideoKindMusicVideo:
				wstrRet = L"musicVideo";
				break;
            
			case ITVideoKindTVShow:
				wstrRet = L"TVShow";
				break;

			default:
				wstrRet = L"unknown";
				break;
		}

	}

	if(iITrack)
		iITrack->Release();
	if(iIFileOrCDTrack)
		iIFileOrCDTrack->Release();

	return wstrRet;
}

std::wstring TrackWin::getCurrentStreamTitle()
{
	using std::wstring;
	
	// String operations done in a wstring, then converted for return
	wstring wstrRet = L"";

	if(iITunes)
	{
		BSTR bstrStreamTitle = NULL; 
		iITunes->get_CurrentStreamTitle((BSTR *)&bstrStreamTitle);
			
		// Add song title
		if(bstrStreamTitle)
			wstrRet += bstrStreamTitle;
	}

	return wstrRet;
}

std::map<std::wstring, std::wstring> TrackWin::getTrackInfo()
{	using std::wstring;

    std::map<wstring, wstring> trackInfo;
	trackInfo[L"isITunesOn"] =			L"0";
    trackInfo[L"playerState"] =			L"NotPlaying";
    trackInfo[L"song"] =					L"";
    trackInfo[L"album"] =				L"";
    trackInfo[L"artist"] =				L"";
	trackInfo[L"showName"] = TrackWin::getShowName();
    trackInfo[L"showName"] =				L"";
    trackInfo[L"videoKind"] =			L"unknown";
    trackInfo[L"currentStreamTitle"] =	L"";
	trackInfo[L"genre"] =	L"";
    trackInfo[L"playerPosition"] =		L"0.0";
    trackInfo[L"timeUntilEnd"] =			L"0.0";
    trackInfo[L"seasonNumber"] =			L"0";
    trackInfo[L"episodeNumber"] =		L"0";


    if( !TrackWin::isITunesOn() )
        return trackInfo;
    
	if(iITunes)
    {
        trackInfo[L"isITunesOn"] = L"1";
		trackInfo[L"playerState"] = TrackWin::getPlayerState();
		trackInfo[L"song"] = TrackWin::getSong();
		trackInfo[L"album"] = TrackWin::getAlbum();
		trackInfo[L"artist"] = TrackWin::getArtist();
		trackInfo[L"genre"] = TrackWin::getGenre();
		trackInfo[L"showName"] = TrackWin::getShowName();
		trackInfo[L"videoKind"] = TrackWin::getVideoKind();
		trackInfo[L"currentStreamTitle"] = TrackWin::getCurrentStreamTitle();
		trackInfo[L"playerPosition"] = std::to_wstring((long double)TrackWin::getPlayerPosition());
		trackInfo[L"timeUntilEnd"] = std::to_wstring((long double)TrackWin::getTimeUntilEnd());
		trackInfo[L"seasonNumber"] = std::to_wstring((long double)TrackWin::getSeasonNumber());
		trackInfo[L"episodeNumber"] = std::to_wstring((long double)TrackWin::getEpisodeNumber());
    }
    
    return trackInfo;
}


