//
//  main.m
//  XPCcrashReport
//
//  Created by Fernando Pereira on 8/20/14.
//  Copyright (c) 2014 Yahoo!. All rights reserved.
//

#include <xpc/xpc.h>
#include <Foundation/Foundation.h>

static void XPCcrashReport_peer_event_handler(xpc_connection_t peer, xpc_object_t event) 
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
        
		NSString* appName = [NSString stringWithUTF8String: xpc_dictionary_get_string(event, "name") ];
		NSString* outputFile = [NSString stringWithUTF8String: xpc_dictionary_get_string(event, "file") ];
        
        double timeInterval = xpc_dictionary_get_double(event, "time");
        NSDate*	lastTimeCrashReported = nil;
        
        if ( timeInterval != 0 )
            lastTimeCrashReported = [NSDate dateWithTimeIntervalSince1970: timeInterval];
        
        /*
        size_t data_length = 0ul;
        const char *data_bytes = (const char *)xpc_dictionary_get_data(event, "path", &data_length);
        NSData* bookmark = [NSData dataWithBytes:data_bytes length:data_length];
        NSLog(@"Bookmark lenght=%zu", data_length);
        BOOL bookmarkIsStale = NO;
        NSError* theError = nil;
        NSURL* bookmarkURL = [NSURL URLByResolvingBookmarkData:bookmark
                                                       options:NSURLBookmarkResolutionWithoutUI
                                                 relativeToURL:nil
                                           bookmarkDataIsStale:&bookmarkIsStale
                                                         error:&theError];
        
        if (bookmarkIsStale || (theError != nil)) {
            NSLog(@"Couldn't get file bookmark for crash output (stale:%d) %@", bookmarkIsStale, [theError description]);
            return;
        }
        */
        
        NSDateFormatter* dfmt = [[NSDateFormatter alloc] init];
        [dfmt setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en-US"]];
        [dfmt setTimeZone: [NSTimeZone timeZoneWithAbbreviation: @"PST"]];
        [dfmt setDateStyle: NSDateFormatterFullStyle];
        [dfmt setTimeStyle:NSDateFormatterFullStyle];        
        
        // get a file hanlder from the app
        NSOutputStream *stream = [[NSOutputStream alloc] initToFileAtPath:outputFile append:YES];
        if ( stream )
        {
            NSLog(@"Copying crash logs to %@", outputFile);
            [stream open];
            
            NSString* crashLocation = [@"~/Library/Logs/DiagnosticReports/" stringByExpandingTildeInPath];
            NSLog(@"Reading crash logs from %@ - lastCrashReport=%@", crashLocation, lastTimeCrashReported);
            NSDirectoryEnumerator*	enny = [[NSFileManager defaultManager] enumeratorAtPath: crashLocation];
            
            for (NSString* crashFile in enny)
            {
                if ([crashFile rangeOfString: appName].location != NSNotFound )
                {
                    NSDictionary *attributes = [enny fileAttributes];
                    NSDate *lastModificationDate = [attributes objectForKey:NSFileModificationDate];
                    //NSLog(@"File %@ lastModification Date=%@", crashFile, lastModificationDate);
                    
                    if (lastTimeCrashReported == nil ||  [lastTimeCrashReported earlierDate:lastModificationDate] == lastTimeCrashReported)
                    {
                        if ( stream != nil && [stream hasSpaceAvailable] )
                        {
                            NSString* msg = [NSString stringWithFormat:
                                             @"Crash Date: %@\n%@\n=============================================================================\n",
                                             [dfmt stringFromDate:lastModificationDate],
                                             crashFile
                                             ];
                            
                            NSError* error = nil;
                            NSData* inputData = [NSData dataWithContentsOfFile:[crashLocation stringByAppendingPathComponent: crashFile]
                                                                       options:0
                                                                         error:&error];
                            
                            NSLog(@"Reading crash log at %@, bytes=%lu", crashFile, inputData.length);
                            if ( error )
                            {
                                NSLog(@"Error reading crash file: %@", [error description]);
                            }
                            
                            else if ( inputData.length > 0 )
                            {
                                NSString *contents = [[NSString alloc] initWithBytes:[inputData bytes] length:[inputData length] encoding:NSUTF8StringEncoding];
                                
                                [stream write:(const uint8_t*)[msg dataUsingEncoding:NSUTF8StringEncoding].bytes maxLength:msg.length];
                                
                                NSUInteger writtenBytes = [stream write:(const uint8_t*)[contents dataUsingEncoding:NSUTF8StringEncoding].bytes maxLength:contents.length];                                
                                
                                if ( writtenBytes != inputData.length )
                                {
                                    NSLog(@"Error appending crash file (written only %lu)", writtenBytes);
                                }
                                else
                                {
                                    NSLog(@"Appended %lu bytes", writtenBytes);
                                }
                            }
                            
                        }
                        else
                        {
                            NSLog(@"Error writing to output stream");
                        }
                    }
                }
            }
            
            [stream close];
        }
        else
        {
            NSLog(@"Error opening output file: %@", outputFile);
        }
	}
}

static void XPCcrashReport_event_handler(xpc_connection_t peer) 
{
	// By defaults, new connections will target the default dispatch
	// concurrent queue.
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		XPCcrashReport_peer_event_handler(peer, event);
	});
	
	// This will tell the connection to begin listening for events. If you
	// have some other initialization that must be done asynchronously, then
	// you can defer this call until after that initialization is done.
	xpc_connection_resume(peer);
}

int main(int argc, const char *argv[])
{
	xpc_main(XPCcrashReport_event_handler);
	return 0;
}
