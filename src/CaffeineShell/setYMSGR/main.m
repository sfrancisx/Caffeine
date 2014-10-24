//
//  main.m
//  setYMSGR
//
//  Created by Fernando Pereira on 8/1/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#include <xpc/xpc.h>
#include <Foundation/Foundation.h>

static void setYMSGR_peer_event_handler(xpc_connection_t peer, xpc_object_t event) 
{
	xpc_type_t type = xpc_get_type(event);
	if (type == XPC_TYPE_ERROR) {
		if (event == XPC_ERROR_CONNECTION_INVALID) {
			// The client process on the other end of the connection has either
			// crashed or cancelled the connection. After receiving this error,
			// the connection is in an invalid state, and you do not need to
			// call xpc_connection_cancel(). Just tear down any associated state
			// here.
		} else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
			// Handle per-connection termination cleanup.
		}
	} else {
		assert(type == XPC_TYPE_DICTIONARY);
		// Handle the message.
        
		NSString* identif = [NSString stringWithUTF8String: xpc_dictionary_get_string(event, "bid") ];
        
        NSString* uri = @"ymsgr";
        
        OSStatus status =  LSSetDefaultHandlerForURLScheme((__bridge CFStringRef)uri, (__bridge CFStringRef)identif);
        
        if ( status != noErr )
        {
            NSLog(@"Error setting ysmgr link");
        }
        
	}
}

static void setYMSGR_event_handler(xpc_connection_t peer) 
{
	// By defaults, new connections will target the default dispatch
	// concurrent queue.
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		setYMSGR_peer_event_handler(peer, event);
	});
	
	// This will tell the connection to begin listening for events. If you
	// have some other initialization that must be done asynchronously, then
	// you can defer this call until after that initialization is done.
	xpc_connection_resume(peer);
}

int main(int argc, const char *argv[])
{
	xpc_main(setYMSGR_event_handler);
	return 0;
}
