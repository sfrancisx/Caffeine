//
//  YRTTManager.m
//  McBrewery
//
//  Created by Fernando Pereira on 5/7/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import "YRTTManager.h"
#import "YStreamComm.h"
#import "YLog.h"


#define kConnectCallBack    "connect"
#define kReadCallBack       "read"
#define kErrorCallBack      "error"
#define kCloseCallBack      "close"

void createCallback(SOCKET s, const char* callbackName, int errorCode, NSString* data);



@interface YRTTManager () <YStreamCommDelegate>

@property (atomic,strong) NSMutableDictionary*      sockets;

@property BOOL                                      rttIsDisabled;

- (void) createCallback:(SOCKET)s callback:(const char*) callbackName error:(int)error data:(NSString*) data;

@end


@implementation YRTTManager

#pragma mark ---- public calls -----

+ (id) sharedManager
{
    static YRTTManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (id)init
{
    if (self = [super init])
    {
        self.sockets = [[NSMutableDictionary alloc] init];
        
        self.rttIsDisabled = false;
    }
    return self;
}

- (void) netloss
{
    if ( self.rttIsDisabled ) return;
    @try
    {
        for (NSNumber* nsock in [self.sockets allKeys])
        {
            //YStreamComm* sock = [self.sockets objectForKey:nsock];
            [self closeSocket: [nsock intValue]];
        }
    
    }
    @catch (NSException *e)
    {
        YLog(LOG_NORMAL, @"RTT2: caught exception when trying to call netloss %@", [e description]);
    }
}

- (void) terminateRTT
{
    YLog(LOG_NORMAL, @"RTT2: terminateNow called. setting running thread to false, rttDisable to true");
    self.rttIsDisabled = true;
    
    for (NSNumber* nsock in [self.sockets allKeys])
    {
        __block YStreamComm* sock = [self.sockets objectForKey:nsock];
        [sock closeConnection:  ^(void) {
            
                [self.sockets removeObjectForKey: nsock];
                
        }];
    }
}

- (SOCKET)  createSocket:host port:(uint32)port useSSL:(bool)useSSL socket:(SOCKET) curr;
{
    if ( self.rttIsDisabled ) return 0;
    
    YLog(LOG_NORMAL, @"RTT2: Creating a new socket for %@, port %d - #%d", host, port, curr);
    
    YStreamComm* sock = [[YStreamComm alloc] initWithHost:curr host:host andPort:port];
    sock.delegate = self;
    [self.sockets setObject:sock forKey:[NSNumber numberWithInt:curr]];
    
    [sock startConnection:useSSL completion:^(BOOL result) {
        
        YLog(LOG_NORMAL, @"RTT2: Getting completion block for startConnection (result=%d), s:%#", result, curr);
        [self createCallback:curr callback:(result?kConnectCallBack:kErrorCallBack) error:0 data:nil];
    }];
    
    return curr;
}

- (void) writeToSocket:(SOCKET)s data:(NSData*) data;
{
    if ( self.rttIsDisabled ) return;
    @try
    {
        YStreamComm* sock = [self.sockets objectForKey:[NSNumber numberWithInt:s]];
        if ( sock == nil ) return;
        
        [sock gotWriteData:data completion: ^(BOOL result) {
            
            YLog(LOG_ONLY_IN_DEBUG, @"RTT2: Getting write block result = %d, socket=%d", result, s);
            if ( result == FALSE )
                YLog(LOG_NORMAL, @"RTT2: error writing to socket");
        }];

        /*
        if ( values[2].get() )
        {
            YLog(LOG_ONLY_IN_DEBUG, @"RTT2: Sending write callback from main queue result");
            ctx->Enter();
            
            CefRefPtr<CefV8Value> CallbackArg1 = CefV8Value::CreateNull();
            CefRefPtr<CefV8Value> CallbackArg2 = CefV8Value::CreateObject(NULL);
            CallbackArg2->SetValue("status", CefV8Value::CreateString("success"), V8_PROPERTY_ATTRIBUTE_NONE);
            
            CefV8ValueList args;
            args.push_back(CallbackArg1);
            args.push_back(CallbackArg2);
            
            values[2]->ExecuteFunction(NULL, args);
            
            ctx->Exit();
        }
         */
    }
    @catch (NSException *e)
    {
        
        YLog(LOG_NORMAL, @"RTT2: caught exception when trying to send a write: %@", [e description]);
    }
}

- (void) createCallback:(SOCKET)s callback:(const char*) callbackName error:(int)errorCode data:(NSString*) data
{
    if ( self.rttIsDisabled ) return;
    @try
    {
        YLog(LOG_ONLY_IN_DEBUG, @"RTT2: sending callback %s error=%d currSocket=%d (counter=%d)",
             callbackName, errorCode, s, [self.sockets count]);
        
        createCallback(s, callbackName, errorCode, data);
        
        
    }
    @catch (NSException *e)
    {
        YLog(LOG_NORMAL, @"RTT2: caught exception when trying to send a callback: %@", [e description]);
    }
}

- (void)  closeSocket:(SOCKET) s
{
    if ( self.rttIsDisabled ) return;
    YLog(LOG_NORMAL, @"RTT2: rttjs closing the socket %d", s);
    
    __block YStreamComm* sock = [self.sockets objectForKey:[NSNumber numberWithInt:s]];
    if ( sock == nil ) return;
    
    [sock closeConnection:  ^(void) {
        
        [self.sockets removeObjectForKey: [NSNumber numberWithInt:s]];
        YLog(LOG_NORMAL, @"RTT2: socket closed: %d ", s);
        
        [self createCallback:s callback:kCloseCallBack error:0 data:nil];
    }];
    
}

#pragma mark --- delegate methods for YSocketStream

- (void) sendReadCallback:(SOCKET)s data:(NSString*) data
{
    YLog(LOG_ONLY_IN_DEBUG, @"RTT2: called read callback for socket %d - data size:%d", s, data.length);
    if ( data == nil  ) return;
    [self createCallback:s callback:kReadCallBack error:0 data:[data copy]];
}

- (void) sendErrorCallback:(SOCKET)s error:(NSError*) error
{
    int errNum = 0;
    if ( error )
    {
        errNum = (int)error.code;
        YLog(LOG_MAXIMUM, @"RTT2: calling error (%d) callback for socket %d", errNum, s);
    }
    
    __block YStreamComm* sock = [self.sockets objectForKey:[NSNumber numberWithInt:s]];
    if ( sock == nil ) return;
    
    [sock closeConnection:  ^(void) {
        
        sock = nil;
        [self.sockets removeObjectForKey: [NSNumber numberWithInt:s]];
        
        YLog(LOG_NORMAL, @"RTT2: socket %d is closed ", s);
        [self createCallback:s callback: (errNum ? kErrorCallBack : kCloseCallBack)  error:errNum data:nil];
    }];
    
    YLog(LOG_ONLY_IN_DEBUG, @"RTT2: called error/close callback for socket %d", s);
}

@end


