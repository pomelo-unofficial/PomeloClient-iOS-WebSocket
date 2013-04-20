//
// Created by ETiV on 13-4-19.
// Copyright (c) 2013 ETiV. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "PomeloWS.h"
#import "PWSProtocol.h"
#import "PomeloWSErrors.h"
#import "PomeloWSProtobuf.h"

static NSString *const PWS_CLIENT_KEY_TYPE = @"type";
static NSString *const PWS_CLIENT_VALUE_TYPE = @"pomelo-client.ios.websocket";

static NSString *const PWS_CLIENT_KEY_VERSION = @"version";
static NSString *const PWS_CLIENT_VALUE_VERSION = @"0.0.1";

static NSString *const kPWSHandshakeDataSys = @"sys";
NSString *const kPWSHandshakeDataUser = @"user";

static NSString *const kPWSURLFormat = @"ws://%@:%d/";

static NSUInteger kPWSNotifyReqID = 0;

/**
 *    Time
 * 1st. on the connection created
 * 3rd. after pomelo client initialed
 * 4th. disconnect
 */
// 已连接,但尚未初始化时
NSString *const kPWSConnectCallback = @"__connectCallback__";
// 以用户定义的连接参数作为回调参数的callback
NSString *const kPWSUserCallback = @"__userCallback__";
// 经过握手,初始化后
NSString *const kPWSInitCallback = @"__initCallback__";
// 断开连接时
NSString *const kPWSDisconnectCallback = @"__disconnectCallback__";

#define MAKE_ROUTE_KEY(key) [NSString stringWithFormat:@"route_%u", key]
#define MAKE_CALLBACK_KEY(key) [NSString stringWithFormat:@"callback_%u", key]

typedef enum {
  PWS_RES_OK = 200,
  PWS_RES_FAIL = 500,
  PWS_RES_OLD_CLIENT = 501
} PomeloResponseStatusCode;


@interface PomeloWS (
private)

- (NSUInteger)timeNow;

- (void)error:(PomeloErrorCode)errCode;

- (void)send:(NSData *)data;

- (void)setTimeout:(BOOL *)timeoutFnShouldExe withSelector:(SEL)tocb_selector andObject:(id)object inDelay:(NSUInteger)delay;

- (void)clearTimeout:(BOOL *)timeoutFnShouldExe;

- (void)tocb_heartBeat:(NSData *)data;

- (void)tocb_heartBeatTimeout;

- (void)processPackage:(PWSPackage *)package;

- (void)onHandshake:(NSData *)data;

- (void)onHeartBeat:(NSData *)data;

- (void)onData:(NSData *)data;

- (void)onKick:(NSData *)data;

- (void)heartbeatInit:(NSDictionary *)dict;

- (void)dataInit:(NSDictionary *)data;

- (void)processMessage:(PWSMessage *)msg;

- (void)sendMessage:(NSInteger)reqId withRoute:(NSString *)route andMsg:(NSDictionary *)msg;

- (id)deCompose:(PWSMessage *)msg;

@end

@implementation PomeloWS {

}

#pragma mark - init
- (id)initWithDelegate:(id <PomeloWSDelegate>)delegate {
  self = [super init];
  if (self) {
    _delegate = delegate;

    _reqId = 0;
    _callbacks = [NSMutableDictionary dictionaryWithCapacity:8];
    _routeMap = [NSMutableDictionary dictionaryWithCapacity:8];

    _heartbeatInterval = 0;
    _heartbeatTimeout = 0;
    _nextHeartbeatTimeout = 0;
    _gapThreshold = 100;   // heartbeat gap threashold

    _heartbeatShouldExe = NO;
    _heartbeatTimeoutShouldExe = NO;

    _handShakeData_Sys = [[NSDictionary alloc] initWithObjectsAndKeys:
        PWS_CLIENT_VALUE_TYPE, PWS_CLIENT_KEY_TYPE,
        PWS_CLIENT_VALUE_VERSION, PWS_CLIENT_KEY_VERSION, nil];
    _handShakeData_User = [NSDictionary dictionary];

    _data = [NSMutableDictionary dictionary];
  }

  return self;
}

#pragma mark - connect
- (void)connectToHost:(NSString *)host onPort:(NSInteger)port {
  // done
  [self connectToHost:host onPort:port withCallback:nil];
}

- (void)connectToHost:(NSString *)host onPort:(NSInteger)port withCallback:(PomeloWSCallback)callback {
  // done
  NSDictionary *params = nil;
  if (callback) {
    params = [[NSDictionary alloc] initWithObjectsAndKeys:callback, kPWSInitCallback, nil];
  }
  [self connectToHost:host onPort:port withParams:params];
}

- (void)connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params {
  // done
  NSDictionary *userHandshakeBuffer = nil;
  PomeloWSCallback callback = nil;
  if (params != nil) {
    userHandshakeBuffer = [params objectForKey:kPWSHandshakeDataUser];
    if (userHandshakeBuffer) {
      _handShakeData_User = userHandshakeBuffer;
    }

    callback = [params objectForKey:kPWSConnectCallback];
    if (callback) {
      [_callbacks setObject:callback forKey:kPWSConnectCallback];
    }

    callback = [params objectForKey:kPWSUserCallback];
    if (callback) {
      [_callbacks setObject:callback forKey:kPWSUserCallback];
    }

    callback = [params objectForKey:kPWSInitCallback];
    if (callback) {
      [_callbacks setObject:callback forKey:kPWSInitCallback];
    }
  }

  // build handshake buffer structure
  /**
   var handshakeBuffer = {
      'sys': {
          type: WS_CLIENT_VALUE_TYPE,
          version: WS_CLIENT_VALUE_VERSION
      },
      'user': {
      }
   }
   */
  _handShakeData = [[NSDictionary alloc] initWithObjectsAndKeys:
      _handShakeData_Sys, kPWSHandshakeDataSys,
      _handShakeData_User, kPWSHandshakeDataUser, nil];

  NSString *urlStr = [NSString stringWithFormat:kPWSURLFormat, host, port];

  _webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:urlStr]];
  _webSocket.delegate = self;
  [_webSocket open];
}

#pragma mark - disconnect
- (void)disconnect {
  // done
  [self disconnectWithCallback:nil];
}

- (void)disconnectWithCallback:(PomeloWSCallback)callback {
  // done
  if (callback) {
    [_callbacks setObject:callback forKey:kPWSDisconnectCallback];
  }
  // dont need any readyStage check. lib SocketRocket will do it.
  [_webSocket close];
}

#pragma mark - SRWebSocketDelegate implement

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
  NSLog(@"did ws open ======> WS: %@", webSocket);

  // on connected
  // todo consider don't invoke this callback
  PomeloWSCallback callback = [_callbacks objectForKey:kPWSConnectCallback];
  if (callback != nil) {
    callback(self);
    [_callbacks removeObjectForKey:kPWSConnectCallback];
  }
  // todo consider move this callback to connection has been initialed
  if ([_delegate respondsToSelector:@selector(PomeloDidConnect:)]) {
    [_delegate PomeloDidConnect:self];
  }

  NSData *handshakeObj = [PWSProtocol packageEncodeWithType:PWS_PT_HANDSHAKE andBody:[PWSProtocol strEncode:[PomeloWS encodeJSON:_handShakeData error:nil]]];
  [self send:handshakeObj];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
  NSLog(@"did ws message ===> WS: %@, MSG: %@", webSocket, message);

  [self processPackage:[PWSProtocol packageDecode:message]];
}

- (void)webSocket:(SRWebSocket *)webSocket
 didFailWithError:(NSError *)error {
  // done
  NSLog(@"did ws error =====> WS: %@, ERR: %@", webSocket, error);
}

- (void)webSocket:(SRWebSocket *)webSocket
 didCloseWithCode:(NSInteger)code
           reason:(NSString *)reason
         wasClean:(BOOL)wasClean {
  // done
  // callback method
  PomeloWSCallback callback = [_callbacks objectForKey:kPWSDisconnectCallback];
  if (callback != nil) {
    callback(self);
    [_callbacks removeObjectForKey:kPWSDisconnectCallback];
  }
  // call delegate method
  if ([_delegate respondsToSelector:@selector(PomeloDidDisconnect:withError:)]) {
    [_delegate PomeloDidDisconnect:self withError:[NSError errorWithDomain:POMELO_ERROR_DOMAIN code:code userInfo:nil]];
  }
}

#pragma mark - main api

- (void)requestWithRoute:(NSString *)route andParams:(NSDictionary *)params andCallback:(PomeloWSCallback)callback {
  if (route == nil) {
    return;
  }

  if (params == nil) {
    params = [NSDictionary dictionary];
  }

  if (callback == nil) {
    // callback cannot be nil
    // otherwize you may need to use notify
    [self error:PWS_ERR_CALLBACK_CANT_BE_NIL];
  }

  [self sendMessage:(++_reqId) withRoute:route andMsg:params];

  [_routeMap setObject:route forKey:MAKE_ROUTE_KEY(_reqId)];
  [_callbacks setObject:callback forKey:MAKE_CALLBACK_KEY(_reqId)];
}

- (void)notifyWithRoute:(NSString *)route andParams:(NSDictionary *)params {
  if (params == nil) {
    params = [NSDictionary dictionary];
  }

  [self sendMessage:kPWSNotifyReqID withRoute:route andMsg:params];
}

- (void)onRoute:(NSString *)route withCallback:(PomeloWSCallback)callback {
  // done
  NSMutableArray *array = [_callbacks objectForKey:route];
  if (array == nil) {
    array = [NSMutableArray arrayWithCapacity:1];
    [_callbacks setObject:array forKey:route];
  }

  [array addObject:[callback copy]];
}

- (void)offRoute:(NSString *)route {
  // done
  [_callbacks removeObjectForKey:route];
}

#pragma mark - JSON helper
+ (id)decodeJSON:(NSData *)data error:(NSError **)error {
  return [NSJSONSerialization JSONObjectWithData:data
                                         options:0
                                           error:error];
}

+ (NSString *)encodeJSON:(id)object error:(NSError **)error {
  NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                 options:0
                                                   error:error];
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end

#pragma mark - PomeloWS private methods

@implementation PomeloWS (
private)

- (NSUInteger)timeNow {
  NSDate *date = [NSDate date];
  return (NSUInteger) ([date timeIntervalSince1970] * 1000);
}

- (void)error:(PomeloErrorCode)errCode {
  if ([_delegate respondsToSelector:@selector(PomeloDidDisconnect:withError:)]) {
    [_delegate PomeloDidDisconnect:self withError:[NSError errorWithDomain:POMELO_ERROR_DOMAIN code:errCode userInfo:nil]];
  } else {
    NSString *err = [NSString stringWithFormat:@"Error occurred: 0x%08X, Domain %@.", errCode, POMELO_ERROR_DOMAIN];
    [NSException raise:err format:nil];
  }
}

- (void)send:(NSData *)data {
  [_webSocket send:data];
}

// done
- (void)setTimeout:(BOOL *)timeoutFnShouldExe withSelector:(SEL)tocb_selector andObject:(id)object inDelay:(NSUInteger)delay {
  *timeoutFnShouldExe = YES;
  [self performSelector:tocb_selector withObject:object afterDelay:(delay * 0.001)];
}

// done
- (void)clearTimeout:(BOOL *)timeoutFnShouldExe {
  *timeoutFnShouldExe = NO;
}

- (void)tocb_heartBeat:(NSData *)data {
  if (_heartbeatShouldExe == NO) {
    return;
  }
  [self clearTimeout:&_heartbeatShouldExe];
  [self send:data];

  _nextHeartbeatTimeout = [self timeNow] + _heartbeatTimeout;

  [self setTimeout:&_heartbeatTimeoutShouldExe withSelector:@selector(tocb_heartBeatTimeout) andObject:nil inDelay:_heartbeatTimeout];
}

- (void)tocb_heartBeatTimeout {
  if (_heartbeatTimeoutShouldExe == NO) {
    return;
  }
  NSInteger gap = _nextHeartbeatTimeout - [self timeNow];
  if (gap > _gapThreshold) {
    [self setTimeout:&_heartbeatTimeoutShouldExe withSelector:@selector(tocb_heartBeatTimeout) andObject:nil inDelay:gap];
  } else {
    // error
    [self error:PWS_ERR_HEARTBEAT_FAIL];
    [self disconnect];
  }
}

- (void)processPackage:(PWSPackage *)package {
  switch ([DICT_KEY(package, @"type") unsignedIntegerValue]) {
    case PWS_PT_HANDSHAKE:
      [self onHandshake:DICT_KEY(package, @"body")];
      break;
    case PWS_PT_HEARTBEAT:
      [self onHeartBeat:DICT_KEY(package, @"body")];
      break;
    case PWS_PT_DATA:
      [self onData:DICT_KEY(package, @"body")];
      break;
    case PWS_PT_KICK:
      [self onKick:DICT_KEY(package, @"body")];
      break;
    default:
      NSLog(@"Unknown Package Type.");
      break;
  }
}

- (void)onHandshake:(NSData *)data {
  NSDictionary *obj = [PomeloWS decodeJSON:data error:nil];

  int statusCode = [[obj valueForKey:@"code"] intValue];

  if (PWS_RES_OLD_CLIENT == statusCode) {
    [self error:PWS_ERR_OLD_CLIENT];
    return;
  }

  if (PWS_RES_OK != statusCode) {
    [self error:PWS_ERR_HANDSHAKE_FAIL];
    return;
  }

  [self heartbeatInit:obj];
  [self dataInit:obj];

  NSData *ackHandshake = [PWSProtocol packageEncodeWithType:PWS_PT_HANDSHAKE_ACK andBody:nil];
  [self send:ackHandshake];

  PomeloWSCallback callback = [_callbacks objectForKey:kPWSUserCallback];
  if (callback != nil) {
    callback([obj objectForKey:kPWSHandshakeDataUser]);
    [_callbacks removeObjectForKey:kPWSUserCallback];
  }

  callback = [_callbacks objectForKey:kPWSInitCallback];
  if (callback != nil) {
    callback(self);
    [_callbacks removeObjectForKey:kPWSInitCallback];
  }
}

- (void)onHeartBeat:(NSData *)data {
  if (_heartbeatInterval == 0) {
    return;
  }

  if (_heartbeatTimeoutShouldExe) {
    [self clearTimeout:&_heartbeatTimeoutShouldExe];
  }

  if (_heartbeatShouldExe) {
    // already in a heartbeat interval
    return;
  }

  NSData *obj = [PWSProtocol packageEncodeWithType:PWS_PT_HEARTBEAT andBody:nil];
  [self setTimeout:&_heartbeatShouldExe
      withSelector:@selector(tocb_heartBeat:)
         andObject:obj
           inDelay:_heartbeatInterval];
}

- (void)onData:(NSData *)data {
//  id decodedData = [PWSProtocol messageDecode:data];
//
//  if ([decodedData isKindOfClass:[NSArray class]]) {
//    [self processMessageBatch:decodedData];
//  } else if ([decodedData isKindOfClass:[NSDictionary class]]) {
//    [self processMessage:decodedData];
//  }
  PWSMessage *msg = [PWSProtocol messageDecode:data];
  if ([DICT_KEY(msg, @"msgId") unsignedIntegerValue] > 0) {
    [msg setObject:[_routeMap objectForKey:MAKE_ROUTE_KEY([DICT_KEY(msg, @"msgId") unsignedIntegerValue])] forKey:@"route"];
    [_routeMap removeObjectForKey:MAKE_ROUTE_KEY([DICT_KEY(msg, @"msgId") unsignedIntegerValue])];
    if (DICT_KEY(msg, @"route") == nil) {
      return;
    }
  }

  [msg setObject:[self deCompose:msg] forKey:@"body"];
  [self processMessage:msg];
}

- (void)onKick:(NSData *)data {
  // ignore for now todo trigger 'onKick' event to invoke onKick callbacks
}

- (void)heartbeatInit:(NSDictionary *)dict {
  // DONE
  id dictSysValue = [dict objectForKey:kPWSHandshakeDataSys];
  NSUInteger heartbeat = 0;

  if ([dictSysValue isKindOfClass:[NSDictionary class]]) {
    heartbeat = [[dictSysValue valueForKey:@"heartbeat"] unsignedIntegerValue];
    if (heartbeat > 0) {
      _heartbeatInterval = heartbeat * 1000;
      _heartbeatTimeout = _heartbeatInterval * 2;
    } else {
      _heartbeatInterval = 0;
      _heartbeatTimeout = 0;
    }
  }
}

- (void)dataInit:(NSDictionary *)data {
//  NSLog(@"data init :: %@", data);
  if (data == nil || [data objectForKey:@"sys"] == nil) {
    return;
  }

  if (_data == nil) {
    _data = [NSMutableDictionary dictionary];
  }

  NSDictionary *initDict = [[data objectForKey:@"sys"] objectForKey:@"dict"];
  NSDictionary *initProtos = [[data objectForKey:@"sys"] objectForKey:@"protos"];

  // Init compress dict
  if (initDict != nil) {
    [_data setObject:initDict forKey:@"dict"];
    [_data setObject:[NSMutableDictionary dictionaryWithCapacity:[initDict count]] forKey:@"abbrs"];

    NSMutableDictionary *dataAbbrs = [_data objectForKey:@"abbrs"];

    for (NSString *routeKey in initDict) {
      [dataAbbrs setObject:routeKey forKey:[initDict objectForKey:routeKey]];
    }
  }

  if (initProtos != nil) {
    NSDictionary *serverProtos = [initProtos objectForKey:@"server"];
    NSDictionary *clientProtos = [initProtos objectForKey:@"client"];
    if (serverProtos == nil) {
      serverProtos = [NSDictionary dictionary];
    }
    if (clientProtos == nil) {
      clientProtos = [NSDictionary dictionary];
    }

    [_data setObject:[NSDictionary dictionaryWithObjectsAndKeys:serverProtos, @"server", clientProtos, @"client", nil] forKey:@"protos"];

    [PomeloWSProtobuf protosInit:[NSDictionary dictionaryWithObjectsAndKeys:serverProtos, @"decoderProtos", clientProtos, @"encoderProtos", nil]];
  }
}

- (void)processMessage:(PWSMessage *)msg {
  if ([DICT_KEY(msg, @"msgId") unsignedIntegerValue] == 0) {
    // server push message
    NSArray *array = [_callbacks objectForKey:DICT_KEY(msg, @"route")];
    if (array != nil) {
      for (PomeloWSCallback cb in array) {
        cb(DICT_KEY(msg, @"body"));
      }
    }
  } else {
    PomeloWSCallback cb = [_callbacks objectForKey:MAKE_CALLBACK_KEY( [DICT_KEY(msg, @"msgId") unsignedIntegerValue] )];
    if (cb != nil) {
      cb(DICT_KEY(msg, @"body"));
      [_callbacks removeObjectForKey:MAKE_CALLBACK_KEY( [DICT_KEY(msg, @"msgId") unsignedIntegerValue] )];
    }
  }

}

- (void)processMessageBatch:(NSArray *)msgs {
  for (PWSMessage *msg in msgs) {
    [self processMessage:msg];
  }
}

- (void)sendMessage:(NSInteger)reqId withRoute:(NSString *)route andMsg:(NSDictionary *)msg {
  PWSMessageType type = (reqId > 0) ? PWS_MT_REQUEST : PWS_MT_NOTIFY;
  NSLog(@"sendmsg :: %@", msg);

  // todo check for protobuf compress
  // blow is msg = Protocol.strencode(JSON.stringify(msg));
  NSData *msgSent = [PWSProtocol strEncode:[PomeloWS encodeJSON:msg error:nil]];

  BOOL compressRoute = NO;
  NSDictionary *dataDict = [_data objectForKey:@"dict"];
  NSNumber *routeCompressed = nil;
  if (dataDict != nil && [dataDict objectForKey:route] != nil) { // route here is string
    routeCompressed = [dataDict objectForKey:route];
    compressRoute = YES;
  }

  NSLog(@"sendMessage routeCompresed Number :: %@", routeCompressed);
  msgSent = [PWSProtocol messageEncodeWithID:reqId andType:type andCompress:compressRoute andRoute:(compressRoute ? routeCompressed : route) andBody:msgSent];

  NSData *packet = [PWSProtocol packageEncodeWithType:PWS_PT_DATA andBody:msgSent];
  [self send:packet];
}

- (id)deCompose:(PWSMessage *)msg {
  NSDictionary *protos = (nil != [_data objectForKey:@"protos"]) ? ([[_data objectForKey:@"protos"] objectForKey:@"server"]) : ([NSDictionary dictionary]);
  NSDictionary *abbrs = [_data objectForKey:@"abbrs"];
  NSString *route = [msg objectForKey:@"route"];

  // typeof msg.compressRoute == __NSCFBoolean
  if ([[msg objectForKey:@"compressRoute"] boolValue]) {
    if ([abbrs objectForKey:@"route"] == nil) {
      return [NSDictionary dictionary];
    }

    route = [abbrs objectForKey:route];
    [msg setObject:route forKey:@"route"];
  }

  if ([protos objectForKey:route] != nil) {
    return [PomeloWSProtobuf decodeWithRoute:route andData:[msg objectForKey:@"body"]];
  } else {
    return [PomeloWS decodeJSON:[msg objectForKey:@"body"] error:nil];
  }
}

@end

#undef MAKE_ROUTE_KEY
#undef MAKE_CALLBACK_KEY
