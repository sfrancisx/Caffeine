//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_ITUNES_WIN_H
#define CAFFEINE_ITUNES_WIN_H
#pragma once


void isITunesOn(CefRefPtr<CefV8Value>& retval );
void getITunesPlayerState(CefRefPtr<CefV8Value>& retval );
void getITunesSong(CefRefPtr<CefV8Value>& retval );
void getITunesAlbum(CefRefPtr<CefV8Value>& retval );
void getITunesArtist(CefRefPtr<CefV8Value>& retval );
void getITunesTimeUntilEnd(CefRefPtr<CefV8Value>& retval );
void getITunesPlayerPosition(CefRefPtr<CefV8Value>& retval );
void getITunesShowName(CefRefPtr<CefV8Value>& retval );
void getITunesVideoKind(CefRefPtr<CefV8Value>& retval );
void getITunesCurrentStreamTitle(CefRefPtr<CefV8Value>& retval );
void getITunesSeasonNumber(CefRefPtr<CefV8Value>& retval );
void getITunesEpisodeNumber(CefRefPtr<CefV8Value>& retval );
void ITunesPlayPreview(std::string& previewURL );
void getITunesTrackInfo(CefRefPtr<CefDictionaryValue>& TrackInfo );

#endif  //  CAFFEINE_ITUNES_WIN_H