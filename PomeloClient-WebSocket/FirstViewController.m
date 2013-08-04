//
//  FirstViewController.m
//  PomeloClient-WebSocket
//
//  Created by ETiV on 04/19/13.
//  Copyright (c) 2013 ETiV. All rights reserved.
//

#import "FirstViewController.h"

#import "PBCodec.h"

@interface FirstViewController ()

@end

@implementation FirstViewController

@synthesize client, hostName, lastStatus, chatContent, talkPerson;

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  signingIn = NO;
  chatting = NO;
  client = [[PomeloWS alloc] initWithDelegate:self];

  [self.client onRoute:@"onChat" withCallback:^(id arg){
    NSLog(@"onChat :: %@", arg);
    NSDictionary *dict = arg;
    NSString *from = [dict objectForKey:@"from"];
    NSString *to = [dict objectForKey:@"target"];
    talkPerson.text = [NSString stringWithFormat:@"%@ said to %@", from, ( [to isEqualToString:@"*"] ? @"AllPeople" : to )];
    chatContent.text = [[dict objectForKey:@"msg"] description];
  }];

  [self.client onRoute:@"onAdd" withCallback:^(id arg){
    NSLog(@"onAdd :: %@", arg);
    NSDictionary *dict = arg;
    lastStatus.text = [NSString stringWithFormat:@"user enter : %@", [dict objectForKey:@"user"]];
  }];

  [self.client onRoute:@"onLeave" withCallback:^(id arg){
    NSLog(@"onLeave :: %@", arg);
    NSDictionary *dict = arg;
    lastStatus.text = [NSString stringWithFormat:@"user leave : %@", [dict objectForKey:@"user"]];
  }];

  // http://stackoverflow.com/questions/5172421/generate-a-random-float-between-0-and-1

  #define ARC4RANDOM_MAX      0xFFFFFFFF
  int loop = 10000;
  // test uint64
  uint64_t limit = 0x3FFFFFFFFFFFFFFF;
  // limit = 0xFFFFFFFF;
  for (int i = 0; i< loop; i++) {
    double val = ((double)arc4random() / ARC4RANDOM_MAX);
    uint64_t number = (uint64_t)(val * limit);
    NSMutableData* data = [PBCodec encodeUInt64:number];
    uint64_t result = [PBCodec decodeUInt64:data];
    NSLog(@"dat: %@ => src: %llu => dst: %llu", data, number, result);
    assert(number == result);
  }

  // test sint64
  limit = 0xfffffffffffff;
  // limit = 0x7FFFFFFF;
  for (int i = 0; i< loop; i++) {
    int flag = ((double)arc4random() / ARC4RANDOM_MAX) > 0.5 ? -1 : 1;
    double val = ((double)arc4random() / ARC4RANDOM_MAX);

    int64_t number = (int64_t)(val * limit) * flag;
    NSMutableData* data = [PBCodec encodeSInt64:number];
    int64_t result = [PBCodec decodeSInt64:data];
    NSLog(@"dat: %@ => src: %lld => dst: %lld", data, number, result);
    assert(number == result);
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction)onConnectQuery:(id)sender {
  [self.client connectToHost:@"127.0.0.1" onPort:3014 withParams:[NSDictionary dictionaryWithObjectsAndKeys:[NSDictionary dictionaryWithObjectsAndKeys:@"val1", @"key1", @"val2", @"key2", nil], kPWSHandshakeDataUser, nil]];
}

- (IBAction)onQueryRequest:(id)sender {
  [self.client requestWithRoute:@"gate.gateHandler.queryEntry" andParams:[NSDictionary dictionaryWithObjectsAndKeys:@"etiv", @"uid", nil] andCallback:^(id arg) {
    NSDictionary *dict = arg;
    if ([[dict objectForKey:@"code"] unsignedIntegerValue] == 200) {
      [self.client disconnect];

      [self.client connectToHost:[dict objectForKey:@"host"] onPort:[[dict objectForKey:@"port"] unsignedIntegerValue] withCallback:^(id arg) {
        NSLog(@"connected port %u ... %@", [[dict objectForKey:@"port"] unsignedIntegerValue], arg);
      }];
    }
  }];
}

- (IBAction)onSendEntry:(id)sender {
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"input name" message:nil delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
  alert.alertViewStyle = UIAlertViewStylePlainTextInput;
  signingIn = YES;
  [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
  UITextField *text = [alertView textFieldAtIndex:0];
  if (signingIn) {
    signingIn = NO;
    [self.client requestWithRoute:@"connector.entryHandler.enter" andParams:[NSDictionary dictionaryWithObjectsAndKeys:text.text, @"username", @"channel", @"rid", nil] andCallback:^(id arg) {
      NSLog(@"response :: connector.entryHandler.enter :: %@", arg);
      hostName.text = text.text;
    }];
  } else if (chatting) {
    chatting = NO;
    [self.client requestWithRoute:@"chat.chatHandler.send" andParams:[NSDictionary dictionaryWithObjectsAndKeys:text.text, @"content", @"channel", @"rid", @"*", @"target", hostName.text, @"from", nil] andCallback:^(id arg){
      NSLog(@"response for chat.chatHandler.send :: %@", arg);
    }];
  }
}

- (IBAction)onSendChat:(id)sender {
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"chat content" message:nil delegate:self cancelButtonTitle:@"Send" otherButtonTitles:nil];
  alert.alertViewStyle = UIAlertViewStylePlainTextInput;
  chatting = YES;
  [alert show];
}

- (void)viewDidUnload {
    [self setHostName:nil];
    [self setLastStatus:nil];
    [self setTalkPerson:nil];
    [self setChatContent:nil];
    [super viewDidUnload];
}
@end