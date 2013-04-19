//
//  FirstViewController.h
//  PomeloClient-WebSocket
//
//  Created by ETiV on 04/19/13.
//  Copyright (c) 2013 ETiV. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PomeloWS.h"

@interface FirstViewController : UIViewController <PomeloWSDelegate, UIAlertViewDelegate>
{
  BOOL signingIn;
  BOOL chatting;
}

@property (nonatomic, readonly) PomeloWS *client;
@property (weak, nonatomic) IBOutlet UILabel *hostName;
@property (weak, nonatomic) IBOutlet UILabel *lastStatus;
@property (weak, nonatomic) IBOutlet UILabel *talkPerson;
@property (weak, nonatomic) IBOutlet UILabel *chatContent;

- (IBAction)onConnectQuery:(id)sender;

- (IBAction)onQueryRequest:(id)sender;

- (IBAction)onSendEntry:(id)sender;
- (IBAction)onSendChat:(id)sender;
@end