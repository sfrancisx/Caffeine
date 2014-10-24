// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "CaffeineClientApp.h"
#include "CaffeineClientRender.h"
#include "cefclient/scheme_test.h"

// static
void CaffeineClientApp::CreateRenderDelegates(RenderDelegateSet& delegates) {
    //  caffeine_client_renderer::CreateRenderDelegates(delegates);
    //    delegates.insert(new CaffeineClientApp::RenderDelegate);
}

// static
void CaffeineClientApp::RegisterCustomSchemes(
    CefRefPtr<CefSchemeRegistrar> registrar,
    std::vector<CefString>& cookiable_schemes) {
        scheme_test::RegisterCustomSchemes(registrar, cookiable_schemes);
}
