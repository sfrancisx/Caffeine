//
//  YReportProblemWindowController.m
//  McBrewery
//
//  Created by pereira on 5/2/13.
//  Copyright (c) 2014 Caffeine. All rights reserved.
//

#import "YReportProblemWindowController.h"
#import "mac_util.h"
#import "YAppDelegate.h"
#import "NSString_NSString_wstring.h"
#import "NSString_YMAdditions.h"

//NSString* kMailList = @"brewerydiagnostics@Caffeine.com";
NSString* kMailList = @"caffeine-dt-dev@Caffeine-inc.com";


extern NSString* screenshotFileName;
extern NSString* kDiagDescription;

void sendCrashReports(std::wstring comments, CefRefPtr<CefURLRequest> url_request);

@interface YReportProblemWindowController()

@end

@implementation YReportProblemWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    //[mailName setStringValue: [NSString stringWithFormat:@"Sending mail as %@@Caffeine-inc.com", NSUserName()]];
    //[mailName setStringValue: [NSString stringWithFormat:@"Sending mail as %@", NSUserName()]];

    //[replyTo setStringValue: [NSString stringWithFormat:@"%@@Caffeine-inc.com", NSUserName()]];
    
    [crashWarning setHidden: !sendCrashReportIfExists()];
    zipFile = nil;
}

- (BOOL)control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector
{
    BOOL result = NO;
    
    if (commandSelector == @selector(insertNewline:))
    {
        // new line action:
        // always insert a line-break character and don’t cause the receiver to end editing
        [textView insertNewlineIgnoringFieldEditor:self];
        result = YES;
    }
    else if (commandSelector == @selector(insertTab:))
    {
        // tab action:
        // always insert a tab character and don’t cause the receiver to end editing
        [textView insertTabIgnoringFieldEditor:self];
        result = YES;
    }
    
    return result;
}


- (IBAction)sendMailList:(id)sender
{
    if ( [sendScreenshot state] == NSOffState )
    {
        deleteScreenshot();
    }

    NSProcessInfo* currentProcess = [NSProcessInfo processInfo];
    NSString *descriptionText = [NSString stringWithFormat:@"Update Channel: %@\nMac OSX %@\n%@ Build %@\n\nComments:\n\n%@",
                                 getUpdateChannel(),
                                 [currentProcess operatingSystemVersionString],
                                 kAppTitle,
                                 [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                                 [messageText string]
                                 ];
    
    NSError* error;
    [descriptionText writeToFile:[[NSString stringWithFormat:@"~/Library/Logs/%@",kDiagDescription] stringByExpandingTildeInPath]
                                  atomically:FALSE
                        encoding:NSUTF8StringEncoding
                           error:&error];
    
    if ( error )
    {
        YLog(LOG_NORMAL, @"Error writing description to %@: %@", kDiagDescription, [error description]);
    }
        
    [self uploadCrash];
    //[self sendMailTo:kMailList];
    //[[self window] close];
}


- (IBAction)cancel:(id)sender {
    deleteScreenshot();
    removeCrashReportIfItExists();
    [[self window] close];
}


#pragma mark == upload file ====


static NSString* zipFile = nil;


- (void) uploadCrash
{
    NSString *descriptionText = [[messageText string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([descriptionText length] > kDescriptionParameterMaxLength) {
        descriptionText = [[descriptionText substringToIndex:kDescriptionParameterMaxLength] stringByAppendingString:@"..."];
    }
    
    if ( descriptionText == nil || descriptionText.length == 0 )
    {
        NSProcessInfo* currentProcess = [NSProcessInfo processInfo];
        
        descriptionText = [NSString stringWithFormat:@"%@, %@",
                           getUpdateChannel(),
                           [currentProcess operatingSystemVersionString]];
    }

    YAppDelegate* appDel = (YAppDelegate*)[NSApp delegate];
    if ( appDel->isTheAppLoggedIn )
    {
        sendCrashReports( [descriptionText getwstring], url_request);
    }
    else
    {
        [self cantSendLogs];
    }
    
    if ( 0) // try using default cookies -- disabled
    {
        NSString* buildNo = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        
        zipFile = compressLogFilesForEmail();
        NSData *zipData = [NSData dataWithContentsOfMappedFile:zipFile];
        
        NSString *baseURL = [NSString stringWithFormat: @"%@/upload?intl=%@&f=report.zip&bn=%@&r=%@&fr=0%@%@&vid=%d",
                             NSLocalizedStringFromTable(@"http://submit.msg.Caffeine.com", @"URLs", @"Problem Report form submit - YMReportProblemWindowController.m"),
                             appDel->currentLocale,
                             [buildNo stringByEncodingIllegalURLCharacters],
                             [descriptionText stringByEncodingIllegalURLCharacters],
                             @"0100",   // OTHER category
                             @"0100",
                             kYMVendorID];
        
        YLog(LOG_NORMAL, @"Submit Diagnostics with URL=%@", baseURL);
        
        NSURL *url = [NSURL URLWithString:baseURL];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/zip" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:zipData];
        
        /*
        CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager();
        CefRefPtr<GetCookiesVisitor> visitor = new GetCookiesVisitor(manager);
        manager->VisitUrlCookies(CefString("http://www.Caffeine.com"), true,  static_cast< CefRefPtr<CefCookieVisitor> >(visitor));
        
        NSMutableArray* cookies = [[NSMutableArray alloc] init];
        
        for(CookieVector::iterator it = visitor->cookies_.begin(); it != visitor->cookies_.end(); ++it)
        {
            if ( it->name.length > 0  && it->domain.length > 0  && it->value.length > 0 )
            {
                std::string domain = CefString(&it->domain);
                std::string path = CefString(&it->path);
                std::string name = CefString(&it->name);
                std::string value = CefString(&it->value);
                
                NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSString stringWithUTF8String: domain.c_str()], NSHTTPCookieDomain,
                                            [NSString stringWithUTF8String: path.c_str()], NSHTTPCookiePath,  // IMPORTANT!
                                            [NSString stringWithUTF8String: name.c_str()], NSHTTPCookieName,
                                            [NSString stringWithUTF8String: value.c_str()], NSHTTPCookieValue,
                                            nil];
                NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:properties];
                
                [cookies addObject:cookie];
            }
        }
        
        NSDictionary * headers = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
        YLog(LOG_NORMAL, @"Submit Diagnostic headers=%@", headers);
        
        //[request addValue:cookieString forHTTPHeaderField:@"Cookie"];
        [request setHTTPShouldHandleCookies:NO];
        [request setAllHTTPHeaderFields:headers];
        */
        
        NSURLConnection* urlConn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        if ( urlConn == nil )
        {
            YLog(LOG_NORMAL, @"Error creating NSURLConnection for uploading diagnostics");
        }
    }
    
    //hiding dialog
    [self.window orderOut:self];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    YLog(LOG_NORMAL, @"Logs were successfully transmited to submit.msg");
    connection = nil;
    
    if ( zipFile )
    {
        NSError* error = nil;
        [[NSFileManager defaultManager] removeItemAtPath: zipFile error:&error];
        if ( error )
        {
            YLog(LOG_NORMAL, @"Error removing diagnostics zipfile %@", zipFile);
        }
        zipFile = nil;
    }

    [[self window] close];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    YLog(LOG_NORMAL, @"Logs FAILED to be transmited to submit.msg - %@ - going to use mail reporting", [error description]);
    connection = nil;
    
    
    if ( zipFile )
    {
        NSError* error = nil;
        [[NSFileManager defaultManager] removeItemAtPath: zipFile error:&error];
        if ( error )
        {
            YLog(LOG_NORMAL, @"Error removing diagnostics zipfile %@", zipFile);
        }
        zipFile = nil;
    }
    
    [[self window] close];
}

- (void) cantSendLogs
{
    if ( zipFile == nil )
        zipFile = compressLogFilesForEmail();
    
    NSString* logPath = [NSString stringWithFormat:@"%@.zip", kLogFilesZip];
    int counter = 0;
    while ([[NSFileManager defaultManager] fileExistsAtPath: [logPath stringByExpandingTildeInPath]] && counter < 100)
    {
        logPath = [NSString stringWithFormat:@"%@%03d.zip", kLogFilesZip, ++counter];
    }
    
    NSError* error = nil;
    [[NSFileManager defaultManager] moveItemAtPath: zipFile toPath:[logPath stringByExpandingTildeInPath] error:&error];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: kAppTitle];

    if ( error  )
    {
        YLog(LOG_MAXIMUM, @"Error saving logfile:%@ %@",logPath, [error localizedDescription]);
        [alert setInformativeText: NSLocalizedString(@"saving_local_file_failed", "saving_local_file_failed") ];
    }
    else
    {
        NSString* msg = [NSString stringWithFormat:@"%@ %@",  NSLocalizedString(@"submit_local_file", "submit_local_file") , logPath];
        [alert setInformativeText:msg];
    }
    [alert addButtonWithTitle:@"Ok"];
    [alert runModal];
    alert = nil;
}

- (void) crashWasUploaded:(BOOL) status
{
    static int numberOfAttempts = 0;
    YLog(LOG_NORMAL, @"Upload diagnostics had a completion of %d - closing - # of attempts:%d", status, numberOfAttempts);
    
    if ( status == FALSE )
    {
        if ( numberOfAttempts == 0 ) // first attempt
        {
            YLog(LOG_NORMAL, @"First attempt - tries to resubmit crash logs - %d", numberOfAttempts);
            [self uploadCrash];
        }
        else
        {
            YLog(LOG_NORMAL, @"After %d attempts, just copying logs to a file and informing user", numberOfAttempts);
            [self cantSendLogs];
        }
        
        numberOfAttempts ++;
    }
    else
    {
        numberOfAttempts = 0;
        
        // tell user the logs were submitted
        NSString* submitOK = NSLocalizedString(@"submit_ok", @"Thank you for submitting diagnostics");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText: @"Caffeine"];
        [alert setInformativeText: submitOK];
        [alert addButtonWithTitle:@"Ok"];
        [alert runModal];
        alert = nil;
        
    }
    
    [[self window] close];
}


@end
