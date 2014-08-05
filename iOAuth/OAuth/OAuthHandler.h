//
//  OAuthHandler.h
//  iOAuth
//
//  Created by Laura Skelton on 6/21/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol OAuthHandlerDelegate <NSObject>
- (void)oauthHandlerDidAuthorize;
- (void)oauthHandlerDidFailWithError:(NSString *)errorMessage;
@end

typedef void(^OAuthHandlerSignedRequestCallback)(NSMutableURLRequest *request);

@interface OAuthHandler : NSObject

@property (nonatomic, weak) id <OAuthHandlerDelegate> delegate;

// shared OAuthHandler singleton [OAuthHandler sharedHandler]
+ (OAuthHandler *)sharedHandler;

// use for initial login, with delegate assigned to handle sign in callback and failure
- (void)authenticateWithDelegate:(id)sender;

// use for redirect from login page with authentication code, to request initial access token
- (void)authorizeFromExternalURL:(NSURL *)url delegate:(id)sender;

// use whenever a credentialed request is needed. the signed request is returned in the callback block, and then you can use it to make a request to your API
- (void)signRequest:(NSMutableURLRequest *)request withCallback:(OAuthHandlerSignedRequestCallback)callback;

// call this if you ever receive a message from the API that the token is invalid, or that the request is unauthorized, or a 401 error, and it will request a new access token the next time you make an API call
-(void)tokenShouldRefresh:(id)sender;

@end
