//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_TRACK_WIN_H
#define CAFFEINE_TRACK_WIN_H
#pragma once

#include <string>
#include <map>
#include <objbase.h>
#include <psapi.h>
#include "iTunesCOMInterface.h"


class TrackWin
{
	public:
											TrackWin::TrackWin();
											TrackWin::~TrackWin();
		static bool							TrackWin::isITunesOn();
		double								TrackWin::getPlayerPosition();
		double								TrackWin::getTimeUntilEnd();
		int									TrackWin::getSeasonNumber();
		int									TrackWin::getEpisodeNumber();
		std::wstring							TrackWin::getPlayerState();
		std::wstring							TrackWin::getSong();
		std::wstring							TrackWin::getAlbum();
		std::wstring							TrackWin::getArtist();
		std::wstring							TrackWin::getShowName();
		std::wstring							TrackWin::getVideoKind();
		std::wstring							TrackWin::getCurrentStreamTitle();
		std::wstring							TrackWin::getGenre();
		std::map<std::wstring, std::wstring>	TrackWin::getTrackInfo();

	IiTunes *iITunes;
};

#endif  //  CAFFEINE_TRACK_WIN_H
