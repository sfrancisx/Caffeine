//
//  YLoginUtils.h
//  McBrewery
//
//  Created by Fernando on 9/5/13.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

// Non-Sandboxed
BOOL willStartAtLogin ( NSURL *itemURL );
void setStartAtLogin ( NSURL *itemURL, BOOL enabled);

// Sandboxed
BOOL startAtLoginForSandboxed();
void setStartAtLoginForSandboxed(BOOL flag);