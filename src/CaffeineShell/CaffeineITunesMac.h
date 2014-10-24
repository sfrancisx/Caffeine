//  Copyright Yahoo! Inc. 2013-2014
#ifndef CAFFEINE_ITUNES_MAC_H
#define CAFFEINE_ITUNES_MAC_H
#pragma once

void isITunesOn(std::string name, int retvalInt );
void ITunesPlayPreview(std::string& previewURL );
void getITunesTrackInfo(std::string name, int retvalInt );
void getInstalledPlayers(std::string name, int retvalInt );

#endif  //  CAFFEINE_ITUNES_MAC_H