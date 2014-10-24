//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_ITUNES_WIN_H
#define CAFFEINE_ITUNES_WIN_H
#pragma once

void isITunesOn(CefRefPtr<CefDictionaryValue>& isOn);
void ITunesPlayPreview(std::string& previewURL );
void getITunesTrackInfo(CefRefPtr<CefDictionaryValue>& TrackInfo );
void getInstalledPlayers(CefRefPtr<CefDictionaryValue>& InstalledPlayers );

#endif  //  CAFFEINE_ITUNES_WIN_H