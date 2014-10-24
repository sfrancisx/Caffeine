//
//  YStreamComm.m
//  McBrewery
//
//  Created by Fernando Pereira on 2/19/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YStreamComm.h"
#import "YLog.h"


#pragma mark -------------------------- YSTreamComm ------------------------------------


@interface YStreamComm ()  <NSStreamDelegate>

@property SOCKET                                socketID;

@property (atomic, strong) NSString*            hostName;
@property UInt32                                port;
@property BOOL                                  useSSL;

// Streams support
@property (atomic, strong) NSInputStream        *inputStream;
@property (atomic, strong) NSOutputStream       *outputStream;

// WRITE queue buffers
@property (atomic, strong) NSMutableOrderedSet* sendQueue;


- (void) readData:(NSInputStream *)theStream;
- (void) sendData:(NSOutputStream *)theStream data:(NSData*) data;

- (void) sendNextRequestInQueue;

- (void) open:(BOOL) useSSL;
- (void) tryReopening;

@end

#define NEEDS_REOPENING(strm) (strm.streamStatus == NSStreamStatusNotOpen || strm.streamStatus == NSStreamStatusClosed || strm.streamStatus == NSStreamStatusAtEnd)


@implementation YStreamComm

- (id) initWithHost:(SOCKET)sid host:(NSString*)h andPort:(UInt32) p
{
    if ( self = [super init])
    {
        self.socketID = sid;
        self.hostName = [h copy];
        if ( !self.hostName )
        {
            YLog(LOG_NORMAL, @"RTT2: %@ is not a valid URL", self.hostName);
        }
        self.port = p;
        
        // initialize streams
        self.inputStream = nil;
        self.outputStream = nil;
        
        self.sendQueue = [NSMutableOrderedSet orderedSet];
        
        YLog(LOG_NORMAL, @"RTT2: socket stream init for host %@ and port %d", h, p);
        return self;
    }
    return nil;
}

- (BOOL) startConnection:(BOOL) useSSL completion:(void (^)(BOOL success))connectionBlock
{
    self.useSSL = useSSL;
    
    if ( self.hostName == nil )
    {
        YLog(LOG_NORMAL, @"RTT2: we couldn't connect to the RTT server");
        return FALSE;
    }
    
    YLog(LOG_NORMAL, @"RTT2: Current host is %@, port is %d useSSL=%d", self.hostName, self.port, useSSL);
    
    @try
    {
        [self open:useSSL];
        
        YLog(LOG_NORMAL, @"RTT2: socket stream connected inputStream=%lu outputStream=%lu",
             [self.inputStream streamStatus],
             [self.outputStream streamStatus]);
        
        YLog(LOG_NORMAL, @"RTT2: socketed Thread initialized");
        
        
        connectionBlock(TRUE);
        
    } @catch (NSException *e) {
        
        YLog(LOG_NORMAL, @"RTT2: caught exception inside running socket thread: %@", [e description]);
        
    }
    
    return TRUE;
}

- (void) open:(BOOL) useSSL
{
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)self.hostName, self.port, &readStream, &writeStream);
    
    if ( useSSL )
    {
        NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
//                                  @NO, kCFStreamSSLAllowsExpiredCertificates,
//                                  @NO, kCFStreamSSLAllowsExpiredRoots,
//                                  @NO, kCFStreamSSLAllowsAnyRoot,
                                  @YES, kCFStreamSSLValidatesCertificateChain,
                                  self.hostName, kCFStreamSSLPeerName,
                                  kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
                                  nil];
        
        CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, (CFTypeRef)settings);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, (CFTypeRef)settings);
    }
    
    self.outputStream = CFBridgingRelease(writeStream);
    self.inputStream = CFBridgingRelease(readStream);
    
    [self.inputStream setDelegate:self];
    [self.outputStream setDelegate:self];
    
    [self.inputStream open];
    [self.outputStream open];
    
    NSRunLoop *loop = [NSRunLoop currentRunLoop];
    [self.inputStream scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
    
}

- (void) closeConnection:(void (^) (void))doneBlock
{
    YLog(LOG_ONLY_IN_DEBUG, @"RTT2: Socket %d got closeConnection", self.socketID);

    if ( self.inputStream != nil )
    {
        [self.inputStream close];
        [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.inputStream setDelegate:nil];
        self.inputStream = nil;
        YLog(LOG_ONLY_IN_DEBUG, @"RTT2: Closing input stream");
    }
    
    if ( self.outputStream != nil )
    {
        [self.outputStream close];
        [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream setDelegate:nil];
        self.outputStream = nil;
        YLog(LOG_ONLY_IN_DEBUG, @"RTT2: Closing output stream");
    }
    if ( doneBlock )
    {
        doneBlock();
    }
}

- (void) tryReopening
{
    [self closeConnection: nil];
    [self.delegate sendErrorCallback:self.socketID error:nil];
}


- (void) gotWriteData:(NSData*)outputData completion:(void (^) (BOOL success))writeCallback
{
    if ( NEEDS_REOPENING(self.outputStream) )
    {
        YLog(LOG_NORMAL, @"RTT2: The sockets have a problem and needs to be re-opened");

        writeCallback(FALSE);
        
        [self.delegate sendErrorCallback:self.socketID error:nil];
        return;
    }
    
#ifdef DEBUG
    NSLog(@"RTT2 Debug - next line:\n%@\nSIZE:%lu",
          [[NSString alloc] initWithData: outputData encoding:NSUTF8StringEncoding], outputData.length);
#endif
    
    if ( self.outputStream.hasSpaceAvailable )
    {
        [self sendData: self.outputStream data:outputData];
    }
    else
    {
        [self.sendQueue addObject: outputData];
    }
    writeCallback(TRUE);
}

- (void) sendNextRequestInQueue
{
    NSData *request = [self.sendQueue lastObject];
    if (request)
    {
        [self.sendQueue removeObject:request];
        [self sendData: self.outputStream data:request];
    }
}

- (void) sendData: (NSOutputStream *)theStream data: (NSData*) data
{
    YLog(LOG_ONLY_IN_DEBUG,
         @"RTT2: Sending data for stream with socket - stream is ready to write:%d - buffer %d queued:%d",
          [theStream hasSpaceAvailable] , data.length, self.sendQueue.count );
    
    if  (!theStream || !theStream.hasSpaceAvailable )
        return;
    
    if ( NEEDS_REOPENING(theStream) )
    {
        YLog(LOG_ONLY_IN_DEBUG, @"RTT2: sending data, but the sockets needs to be re-opened");
        [self tryReopening];
        return;
    }
    
    if ( [self.sendQueue count] > 0 )
    {
        [self sendNextRequestInQueue];
    }
    
    if ( ! data || data.length == 0 )
        return;
    
    NSInteger bytesWritten = 0;
    if ( theStream.hasSpaceAvailable )
    {
        uint8_t *writeBytes = (uint8_t *)[data bytes];
        bytesWritten = [self.outputStream write:writeBytes maxLength:data.length];
        
        YLog(LOG_ONLY_IN_DEBUG, @"RTT2: sent %lu bytes - total available was %lu", bytesWritten, data.length);
        if ( bytesWritten <= 0 )
        {
            YLog(LOG_NORMAL, @"Failed to write data, %d", bytesWritten);
        }
    }
    
    if ( bytesWritten == 0 && data.length > 0 )
        [self.sendQueue addObject: data];
}

- (void) readData:(NSInputStream *)theStream
{
    NSMutableData* readData = [NSMutableData data];
    
    NSUInteger totalLen = 0;
    uint8_t buffer[YSTREAM_MAX_BUFFER_SIZE];
    
    if ( NEEDS_REOPENING(theStream) )
    {
        YLog(LOG_ONLY_IN_DEBUG, @"RTT2: Received READ data, but the sockets needs to be re-opened");
        [self tryReopening];
        return;
    }
    
    while (theStream.hasBytesAvailable)
    {
        NSUInteger len = 0;
        NSInteger result = 0;
        
        memset(buffer, 0, YSTREAM_MAX_BUFFER_SIZE);
        result = [theStream read:buffer maxLength:YSTREAM_MAX_BUFFER_SIZE];
        
        if(result < 0)
        {
            YLog(LOG_NORMAL, @"RTT2: Error: in NSStreamEventHasBytesAvailable - checking connection/trying to solve it");
            [self tryReopening];
            return;
        }
        else
        {
            len = result;
        }
        
        // if we got data correctly
        if ( len > 0 && *buffer )
        {
            YLog(LOG_ONLY_IN_DEBUG, @"RTT2: readData (s# %d): got %lu bytes - buffer:%s", self.socketID, (unsigned long)len, buffer);
            
            [readData appendBytes:buffer length:len];
            
            totalLen += len;

        }
        else if ( len > 0 && *buffer == 0 )
        {
            YLog(LOG_MAXIMUM, @"Got %lu bytes but buffer=%s", len, buffer);
        }
    }
    
    if ( readData.length > 0 )
    {
        [self.delegate sendReadCallback:self.socketID  data:[[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding] ];
    }
}


- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
    YLog(LOG_ONLY_IN_DEBUG, @"RTT2: stream event %lu - stream status = %ld", (unsigned long)streamEvent, [theStream streamStatus]);
    
    if ( NEEDS_REOPENING(theStream))
    {
        [self tryReopening];
    }
    
    switch (streamEvent) {
            
        case NSStreamEventHasBytesAvailable:
            //YLog(LOG_NORMAL, @"RTT2: input stream has bytes available");
            [self readData: (NSInputStream *)theStream];
            break;
            
        case NSStreamEventHasSpaceAvailable:
            // sendData will call the callback when the data buffer is emptied
            [self sendData: (NSOutputStream *)theStream data:nil];
            break;
            
            // situations where socket needs to be RE-OPENED
        case NSStreamEventErrorOccurred:
            {
                NSError *theError = [theStream streamError];
                YLog(LOG_NORMAL, @"RTT2: Error in stream event, closing - %@", [theError description]);
                [self.delegate sendErrorCallback:self.socketID error:theError];
                // Error was called - error callback will try to close it
            }
            break;
            
            // ignore
        case NSStreamEventOpenCompleted:
            if ( [theStream isKindOfClass:[NSOutputStream class]])
            {
                YLog(LOG_ONLY_IN_DEBUG, @"RTT2: Stream OPEN for output completed ");
            }
            else
            {
                YLog(LOG_ONLY_IN_DEBUG, @"RTT2: Stream OPEN for input completed ");
            }
            
        case NSStreamEventEndEncountered:
        case NSStreamEventNone:
        default:
            break;
    }
}

@end
